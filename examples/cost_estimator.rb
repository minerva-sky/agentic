# frozen_string_literal: true

# The Cost Estimator: price the plan BEFORE running it - per-task token
# estimates times a pricing table - gate on budget, then reconcile
# estimate against actuals afterward. LLM plans spend real money;
# nobody should learn the bill from the invoice.
#
#   bundle exec ruby examples/cost_estimator.rb [budget_cents]
#
# Runs offline; actual token usage is seeded simulation.

require_relative "../lib/agentic"

# $/1M tokens, input+output blended for the demo
PRICING = {
  "small" => 0.40,
  "large" => 6.00
}.freeze

JOBS = {
  "classify tickets" => {model: "small", est_tokens: 40_000},
  "summarize threads" => {model: "small", est_tokens: 120_000},
  "draft responses" => {model: "large", est_tokens: 60_000},
  "review drafts" => {model: "large", est_tokens: 25_000}
}.freeze

def cents(model, tokens)
  (PRICING.fetch(model) * tokens / 1_000_000 * 100)
end

budget_cents = (ARGV.first || 60).to_i
rng = Random.new(20260707)

orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 2)
tasks = JOBS.map do |name, job|
  task = Agentic::Task.new(
    description: name,
    agent_spec: {"name" => name, "instructions" => "spend wisely"},
    payload: job
  )
  orchestrator.add_task(task, agent: ->(t) {
    sleep(0.01)
    # Actuals drift from estimates, as actuals do (+/- up to 40%)
    drift = 0.8 + rng.rand * 0.6
    {tokens: (t.payload[:est_tokens] * drift).round}
  })
  task
end

# --- pre-flight: price the graph before any token is spent -------------------
estimate = orchestrator.graph[:tasks].values.sum { |t| cents(t.payload[:model], t.payload[:est_tokens]) }

puts "COST ESTIMATOR (budget: #{budget_cents}c)"
puts
puts "  pre-flight estimate:"
JOBS.each do |name, job|
  puts format("    %-20s %-6s ~%6d tokens  ~%5.1fc", name, job[:model], job[:est_tokens],
    cents(job[:model], job[:est_tokens]))
end
puts format("    %-20s %28s %5.1fc", "TOTAL", "", estimate)
puts

if estimate > budget_cents
  puts "  GATE: estimate exceeds budget - plan refused before spending a cent."
  puts "  (raise the budget or downgrade 'draft responses' to the small model)"
  exit 1
end
puts "  GATE: under budget, proceeding."
puts

# --- the run, then the reconciliation ----------------------------------------
result = orchestrator.execute_plan

puts "  reconciliation (estimate vs actual):"
total_actual = 0.0
tasks.each do |task|
  job = task.payload
  actual_tokens = result.results[task.id].output[:tokens]
  actual = cents(job[:model], actual_tokens)
  total_actual += actual
  est = cents(job[:model], job[:est_tokens])
  drift_pct = 100.0 * (actual - est) / est
  puts format("    %-20s est %5.1fc  actual %5.1fc  (%+.0f%%)", task.description, est, actual, drift_pct)
end
puts format("    %-20s est %5.1fc  actual %5.1fc", "TOTAL", estimate, total_actual)
puts
puts "  feed actuals back into est_tokens and next month's estimates"
puts "  stop being folklore. budgets want feedback loops, not faith."
