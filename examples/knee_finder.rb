# frozen_string_literal: true

# The Knee Finder: runs the same plan at increasing concurrency limits,
# measures wall time and total queue-wait via the task_slot_acquired
# hook, and recommends the limit where adding lanes stops paying.
# Guessing concurrency limits is a superstition; this is a measurement.
#
#   bundle exec ruby examples/knee_finder.rb
#
# Runs offline; the workload is 12 simulated API calls of mixed latency.

require_relative "../lib/agentic"

# One slow call dominates, as it always does in production
LATENCIES = [0.08, 0.05, 0.12, 0.06, 0.30, 0.05, 0.15, 0.07, 0.05, 0.09, 0.06, 0.12].freeze

def run_at(limit)
  queue_wait = 0.0
  orchestrator = Agentic::PlanOrchestrator.new(
    concurrency_limit: limit,
    lifecycle_hooks: {
      task_slot_acquired: ->(task_id:, task:, waited:) { queue_wait += waited }
    }
  )

  LATENCIES.each_with_index do |latency, i|
    orchestrator.add_task(Agentic::Task.new(
      description: "call-#{i}",
      agent_spec: {"name" => "api", "instructions" => "wait"},
      payload: latency
    ), agent: ->(t) { sleep(t.payload) || :ok })
  end

  result = orchestrator.execute_plan
  {wall: result.execution_time, queue_wait: queue_wait}
end

puts "KNEE FINDER: #{LATENCIES.size} calls, #{(LATENCIES.sum * 1000).round}ms of total IO"
puts
puts "  limit   wall     total queue-wait"

measurements = [1, 2, 3, 4, 6, 8, 12].to_h do |limit|
  m = run_at(limit)
  bar = "#" * (m[:wall] * 40).round
  puts format("  %5d   %4dms   %6dms  %s", limit, m[:wall] * 1000, m[:queue_wait] * 1000, bar)
  [limit, m]
end

# The knee: smallest limit whose wall time is within 15% of the best
best = measurements.values.map { |m| m[:wall] }.min
knee = measurements.find { |_, m| m[:wall] <= best * 1.15 }.first

puts
puts "  recommendation: concurrency_limit #{knee}"
puts "  (smallest limit within 15% of the best wall time - beyond it you"
puts "   hold more connections open to save less time than the jitter)"
