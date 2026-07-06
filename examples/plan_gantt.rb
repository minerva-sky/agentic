# frozen_string_literal: true

# The Plan Gantt: lifecycle hooks timestamp every task, then the run is
# rendered as an ASCII timeline - where your wall clock actually went.
# A diamond dependency graph with a tight concurrency limit makes the
# scheduler's decisions visible to the naked eye.
#
#   bundle exec ruby examples/plan_gantt.rb [concurrency]
#
# Runs offline; task durations are simulated IO.

require_relative "../lib/agentic"

WORK = {
  "fetch:users" => {sleep: 0.12, deps: []},
  "fetch:orders" => {sleep: 0.20, deps: []},
  "fetch:events" => {sleep: 0.08, deps: []},
  "join:activity" => {sleep: 0.10, deps: ["fetch:users", "fetch:events"]},
  "join:revenue" => {sleep: 0.15, deps: ["fetch:users", "fetch:orders"]},
  "report:weekly" => {sleep: 0.06, deps: ["join:activity", "join:revenue"]}
}.freeze

concurrency = (ARGV.first || 2).to_i
timeline = {}
plan_start = nil

hooks = {
  before_task_execution: ->(task_id:, task:) {
    plan_start ||= Process.clock_gettime(Process::CLOCK_MONOTONIC)
    (timeline[task.description] ||= {})[:start] =
      Process.clock_gettime(Process::CLOCK_MONOTONIC) - plan_start
  },
  after_task_success: ->(task_id:, task:, result:, duration:) {
    timeline[task.description][:finish] =
      Process.clock_gettime(Process::CLOCK_MONOTONIC) - plan_start
  }
}

orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: concurrency, lifecycle_hooks: hooks)
tasks = {}
WORK.each do |name, spec|
  task = Agentic::Task.new(
    description: name,
    agent_spec: {"name" => name, "instructions" => "simulate"},
    payload: spec[:sleep]
  )
  tasks[name] = task
  orchestrator.add_task(task, spec[:deps].map { |d| tasks.fetch(d) }, agent: ->(t) {
    sleep(t.payload)
    :done
  })
end

result = orchestrator.execute_plan

# Render: 1 column = 10ms
total = timeline.values.map { |t| t[:finish] }.max
columns = (total * 100).ceil
puts "PLAN GANTT (concurrency #{concurrency}, #{(result.execution_time * 1000).round}ms wall)"
puts
timeline.each do |name, t|
  from = (t[:start] * 100).round
  width = [((t[:finish] - t[:start]) * 100).round, 1].max
  bar = ((" " * from) + ("#" * width)).ljust(columns)
  puts format("  %-16s |%s| %3d-%3dms", name, bar, t[:start] * 1000, t[:finish] * 1000)
end
puts
puts format("  %-16s |%s|", "", (0..columns).step(10).map { |c| (c / 10).to_s.ljust(10) }.join[0, columns + 1])
puts "  (one column = 10ms; numbers along the base are x100ms)"
puts
serial_floor = WORK.values.sum { |w| w[:sleep] }
puts format("  serial floor %.0fms -> actual %.0fms (%.1fx from the scheduler)",
  serial_floor * 1000, result.execution_time * 1000, serial_floor / result.execution_time)
