# frozen_string_literal: true

# The Live Dashboard: lifecycle hooks publish events onto an
# Async::Queue; a consumer task IN THE SAME REACTOR renders the plan's
# state as it changes. This is the "streaming observability" the
# architecture documents promise, built from a queue and the hooks
# that already exist - about thirty structural lines.
#
#   bundle exec ruby examples/live_dashboard.rb
#
# Runs offline; watch the states flip while the plan executes.

require_relative "../lib/agentic"
require "async/queue"

WORK = {
  "resize:thumbnails" => {sleep: 0.15, deps: []},
  "transcode:video" => {sleep: 0.30, deps: []},
  "extract:captions" => {sleep: 0.10, deps: []},
  "compose:preview" => {sleep: 0.12, deps: ["resize:thumbnails", "extract:captions"]},
  "publish:episode" => {sleep: 0.05, deps: ["compose:preview", "transcode:video"]}
}.freeze

events = Async::Queue.new

hooks = {
  before_task_execution: ->(task_id:, task:) { events.enqueue([:queued, task.description]) },
  after_agent_build: ->(task_id:, task:, agent:, build_duration:) { events.enqueue([:running, task.description]) },
  after_task_success: ->(task_id:, task:, result:, duration:) {
    events.enqueue([:done, task.description, duration])
  },
  plan_completed: ->(plan_id:, status:, execution_time:, tasks:, results:) {
    events.enqueue([:plan_done, status, execution_time])
  }
}

orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 2, lifecycle_hooks: hooks)
tasks = {}
WORK.each do |name, spec|
  task = Agentic::Task.new(
    description: name,
    agent_spec: {"name" => name, "instructions" => "process"},
    payload: spec[:sleep]
  )
  tasks[name] = task
  orchestrator.add_task(task, spec[:deps].map { |d| tasks.fetch(d) }, agent: ->(t) {
    sleep(t.payload)
    :ok
  })
end

started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
stamp = -> { format("%5dms", (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000) }

puts "LIVE DASHBOARD (plan and renderer sharing one reactor, concurrency 2)"
puts

Sync do |host|
  # The renderer: a sibling task consuming the event stream live
  renderer = host.async do
    loop do
      event = events.dequeue
      case event.first
      when :queued then puts "#{stamp.call}  ~ queued   #{event[1]}"
      when :running then puts "#{stamp.call}  > running  #{event[1]}"
      when :done then puts format("%s  + done     %-20s (ran %dms)", stamp.call, event[1], event[2] * 1000)
      when :plan_done
        puts format("%s  = plan %s in %dms", stamp.call, event[1], event[2] * 1000)
        break
      end
    end
  end

  orchestrator.execute_plan
  renderer.wait
end

puts
puts "every line above was printed WHILE the plan ran - the hooks are a"
puts "live event stream, not a post-mortem log"
