# frozen_string_literal: true

# The Invariant Sentinel: domain invariants checked after EVERY task,
# from a lifecycle hook. When a task leaves the world in an illegal
# state, the sentinel names the task, names the broken law, and stops
# the plan before the corruption compounds. One of the pickers below
# has an off-by-one; watch how far it gets.
#
#   bundle exec ruby examples/invariant_sentinel.rb
#
# Runs offline and deterministically.

require_relative "../lib/agentic"

WAREHOUSE = {stock: {"widget" => 10, "gadget" => 8}, received: {}, picked: {}}

INVARIANTS = {
  "stock is never negative" => -> {
    WAREHOUSE[:stock].values.all? { |count| count >= 0 }
  },
  "stock equals initial + received - picked" => -> {
    WAREHOUSE[:stock].all? do |sku, count|
      initial = {"widget" => 10, "gadget" => 8}.fetch(sku)
      count == initial + WAREHOUSE[:received].fetch(sku, 0) - WAREHOUSE[:picked].fetch(sku, 0)
    end
  }
}.freeze

JOBS = [
  {name: "receive 5 widgets", work: -> {
    WAREHOUSE[:stock]["widget"] += 5
    WAREHOUSE[:received]["widget"] = WAREHOUSE[:received].fetch("widget", 0) + 5
  }},
  {name: "pick 3 gadgets", work: -> {
    WAREHOUSE[:stock]["gadget"] -= 3
    WAREHOUSE[:picked]["gadget"] = WAREHOUSE[:picked].fetch("gadget", 0) + 3
  }},
  {name: "pick 2 widgets (buggy picker)", work: -> {
    WAREHOUSE[:stock]["widget"] -= 3 # decrements 3, records 2: the bug
    WAREHOUSE[:picked]["widget"] = WAREHOUSE[:picked].fetch("widget", 0) + 2
  }},
  {name: "receive 4 gadgets", work: -> {
    WAREHOUSE[:stock]["gadget"] += 4
    WAREHOUSE[:received]["gadget"] = WAREHOUSE[:received].fetch("gadget", 0) + 4
  }}
].freeze

violations = []
orchestrator = nil

sentinel = lambda do |task_id:, task:, result:, duration:|
  INVARIANTS.each do |law, check|
    next if check.call

    violations << {task: task.description, law: law, state: Marshal.load(Marshal.dump(WAREHOUSE))}
    orchestrator.cancel_plan
  end
end

orchestrator = Agentic::PlanOrchestrator.new(
  concurrency_limit: 1, # deterministic order so the culprit is unambiguous
  lifecycle_hooks: {after_task_success: sentinel}
)

previous = nil
JOBS.each do |job|
  task = Agentic::Task.new(
    description: job[:name],
    agent_spec: {"name" => "warehouse", "instructions" => "do the job"},
    payload: job[:work]
  )
  orchestrator.add_task(task, previous ? [previous] : [], agent: ->(t) { t.payload.call || :done })
  previous = task
end

result = orchestrator.execute_plan

puts "INVARIANT SENTINEL: #{INVARIANTS.size} laws watching #{JOBS.size} jobs"
puts
puts "plan status: #{result.status}"
completed = result.results.values.count(&:successful?)
puts "jobs completed before the stop: #{completed} of #{JOBS.size}"
puts

if violations.empty?
  puts "every law held. suspiciously well-behaved."
else
  violations.each do |violation|
    puts "LAW BROKEN: \"#{violation[:law]}\""
    puts "  by: #{violation[:task]}"
    puts "  world state at the moment of arrest:"
    puts "    stock:    #{violation[:state][:stock]}"
    puts "    received: #{violation[:state][:received]}"
    puts "    picked:   #{violation[:state][:picked]}"
  end
  puts
  puts "the plan stopped at the FIRST broken law - 'receive 4 gadgets'"
  puts "never ran. corruption caught at the task that caused it is a"
  puts "bug report; corruption found at month-end close is an incident."
end
