# frozen_string_literal: true

# Schedule Equivalence: a plan's declared meaning is its dependency
# graph - which implies a PROMISE nobody usually tests: outputs must
# not depend on the schedule. Run the same plan at concurrency 1, 2,
# and 8; if the outputs differ, the plan has an undeclared dependency
# smuggled through shared state. This prover runs both an honest plan
# and a smuggler, and shows the exact fix.
#
#   bundle exec ruby examples/schedule_equivalence.rb
#
# Runs offline; exits 1 only if the HONEST plan proves schedule-dependent.

require_relative "../lib/agentic"

Agentic.logger.level = :fatal

CONCURRENCIES = [1, 2, 8].freeze

def outputs_under(concurrency, &builder)
  orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: concurrency)
  tasks = builder.call(orchestrator)
  result = orchestrator.execute_plan
  tasks.to_h { |name, task| [name, result.task_result(task.id).output] }
end

def equivalence_verdict(&builder)
  runs = CONCURRENCIES.to_h { |c| [c, outputs_under(c, &builder)] }
  baseline = runs[CONCURRENCIES.first]
  divergent = runs.reject { |_, outputs| outputs == baseline }.keys
  [runs, divergent]
end

# --- the honest plan: all communication travels the declared edges --------------
honest = lambda do |o|
  a = Agentic::Task.new(description: "count_a", agent_spec: {"name" => "a", "instructions" => "w"})
  b = Agentic::Task.new(description: "count_b", agent_spec: {"name" => "b", "instructions" => "w"})
  sum = Agentic::Task.new(description: "sum", agent_spec: {"name" => "s", "instructions" => "w"})
  o.add_task(a, agent: ->(_t) {
    sleep(rand * 0.01)
    3
  })
  o.add_task(b, agent: ->(_t) {
    sleep(rand * 0.01)
    4
  })
  o.add_task(sum, needs: {a: a, b: b}, agent: ->(t) { t.needs[:a] + t.needs[:b] })
  {a: a, b: b, sum: sum}
end

# --- the smuggler: same shape, but tasks ALSO talk through a shared array --------
def smuggler_plan
  lambda do |o|
    ledger = [] # the contraband channel: order of arrival becomes meaning (fresh per run)
    a = Agentic::Task.new(description: "count_a", agent_spec: {"name" => "a", "instructions" => "w"})
    b = Agentic::Task.new(description: "count_b", agent_spec: {"name" => "b", "instructions" => "w"})
    sum = Agentic::Task.new(description: "sum", agent_spec: {"name" => "s", "instructions" => "w"})
    o.add_task(a, agent: ->(_t) {
      sleep(rand * 0.01)
      ledger << :a
      3
    })
    o.add_task(b, agent: ->(_t) {
      sleep(rand * 0.01)
      ledger << :b
      4
    })
    # The sin: reading who arrived FIRST - information no edge declares
    o.add_task(sum, needs: {a: a, b: b}, agent: ->(t) {
      "#{t.needs[:a] + t.needs[:b]} (#{ledger.first} won the race)"
    })
    {a: a, b: b, sum: sum}
  end
end

puts "SCHEDULE EQUIVALENCE (outputs must not know the schedule)"
puts

_, honest_divergent = equivalence_verdict(&honest)
puts "  honest plan across concurrency #{CONCURRENCIES.join("/")}:"
puts "    #{honest_divergent.empty? ? "identical outputs under every schedule - EQUIVALENT" : "DIVERGED at #{honest_divergent.join(", ")}"}"
puts

# The smuggler needs several attempts because races are shy under observation
diverged = false
5.times do
  runs, divergent = equivalence_verdict(&smuggler_plan)
  next if divergent.empty?

  diverged = true
  puts "  smuggler plan (same graph, plus a shared array on the side):"
  runs.each { |c, outputs| puts format("    concurrency %-2d sum => %s", c, outputs[:sum].inspect) }
  puts "    DIVERGED: at concurrency 1 the schedule is the insertion order,"
  puts "    so :a always wins; under parallelism the race decides. the"
  puts "    output encodes WHO WON A RACE - meaning that travels outside"
  puts "    every declared edge."
  break
end
puts "  (smuggler raced identically this run - rerun to catch it; races are shy)" unless diverged
puts
puts "  the fix is always the same and always boring: whatever the shared"
puts "  state was whispering, SAY IT WITH AN EDGE - needs: hands the sum"
puts "  exactly the values it may know, and the graph becomes the whole"
puts "  truth. ruby/spec taught me that 'works on this implementation'"
puts "  means nothing until the behavior is pinned across VMs; same"
puts "  theorem here with schedules for VMs: a plan isn't correct until"
puts "  its outputs are a function of its GRAPH, and this prover is how"
puts "  you find the plans that are secretly functions of the clock."
exit(honest_divergent.empty? ? 0 : 1)
