# frozen_string_literal: true

# The Flaky API Drill: a task that times out twice before succeeding,
# run under a retry policy with exponential backoff and a journal.
# The timeline shows every attempt, every backoff gap, and the journal
# proves the whole ordeal - failures included - survived to disk.
#
#   bundle exec ruby examples/flaky_api_drill.rb
#
# Runs offline; the flakiness is scripted so the drill is repeatable.

require_relative "../lib/agentic"
require "tmpdir"

# The error class name must match the retry policy's retryable_errors
class TimeoutError < StandardError; end

JOURNAL = File.join(Dir.tmpdir, "agentic_flaky_drill.journal.jsonl")
File.delete(JOURNAL) if File.exist?(JOURNAL)

journal = Agentic::ExecutionJournal.new(path: JOURNAL)
started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
stamp = -> { format("%5dms", (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000) }

timeline_hooks = journal.lifecycle_hooks(
  after_task_failure: ->(task_id:, task:, failure:, duration:) {
    puts "#{stamp.call}  x attempt failed: #{failure.type} (#{failure.message})"
  },
  after_task_success: ->(task_id:, task:, result:, duration:) {
    puts "#{stamp.call}  + #{task.description} succeeded: #{result.output.inspect}"
  }
)

orchestrator = Agentic::PlanOrchestrator.new(
  concurrency_limit: 1,
  lifecycle_hooks: timeline_hooks,
  retry_policy: {
    max_retries: 3,
    retryable_errors: ["TimeoutError"],
    backoff_strategy: :exponential,
    backoff_base: 0.1
  }
)

# Fails twice with a retryable timeout, then delivers
attempts = 0
sync = Agentic::Task.new(
  description: "sync:accounts",
  agent_spec: {"name" => "AccountSync", "instructions" => "sync"},
  payload: nil
)
orchestrator.add_task(sync, agent: ->(_t) {
  attempts += 1
  puts "#{stamp.call}  > attempt #{attempts} calling the flaky API..."
  raise TimeoutError, "upstream took too long" if attempts < 3

  {"synced" => 42}
})

# An innocent bystander task, to show the plan keeps moving
audit = Agentic::Task.new(
  description: "audit:trail",
  agent_spec: {"name" => "Auditor", "instructions" => "audit"}
)
orchestrator.add_task(audit, [sync], agent: ->(t) {
  "audited #{t.output_of(sync)["synced"]} accounts"
})

puts "FLAKY API DRILL (max 3 retries, exponential backoff from 100ms)"
puts
result = orchestrator.execute_plan
puts
puts "plan: #{result.status} in #{(result.execution_time * 1000).round}ms, " \
  "#{attempts} attempts for one success"

state = Agentic::ExecutionJournal.replay(path: JOURNAL)
failures = state.events.count { |e| e[:event] == "task_failed" }
successes = state.events.count { |e| e[:event] == "task_succeeded" }
puts
puts "the journal remembers the whole ordeal:"
puts "  #{failures} failed attempts and #{successes} successes on disk"
puts "  completed?(\"sync:accounts\") => #{state.completed?("sync:accounts")}  (by name - " \
  "a rerun tomorrow gets new task ids and still knows)"
puts "  completed?(\"audit:trail\")   => #{state.completed?("audit:trail")}"
