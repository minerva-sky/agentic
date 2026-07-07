# frozen_string_literal: true

# The Incident Report: a nightly batch dies at 3am. The on-call's
# first three questions - what ran? what broke? what do I resume? -
# answered from the journal replay, formatted for the incident
# channel. Nobody greps logs at 3am if the journal can already speak.
#
#   bundle exec ruby examples/incident_report.rb
#
# Runs offline; the outage is scripted.

require_relative "../lib/agentic"
require "tmpdir"

Agentic.logger.level = :fatal

JOURNAL = File.join(Dir.tmpdir, "agentic_incident.journal.jsonl")
File.delete(JOURNAL) if File.exist?(JOURNAL)

journal = Agentic::ExecutionJournal.new(path: JOURNAL)

NIGHTLY = {
  "extract:orders" => {time: 0.05},
  "extract:refunds" => {time: 0.04},
  "transform:ledger" => {time: 0.07, deps: %w[extract:orders extract:refunds]},
  "load:warehouse" => {time: 0.03, deps: %w[transform:ledger],
                       error: Agentic::Errors::LlmAuthenticationError.new("warehouse credentials expired")},
  "verify:totals" => {time: 0.02, deps: %w[load:warehouse]},
  "notify:finance" => {time: 0.01, deps: %w[verify:totals]}
}.freeze

orchestrator = nil
hooks = journal.lifecycle_hooks(
  after_task_failure: ->(task_id:, task:, failure:, duration:) { orchestrator.cancel_plan }
)
orchestrator = Agentic::PlanOrchestrator.new(
  concurrency_limit: 2, lifecycle_hooks: hooks,
  retry_policy: {max_retries: 0, retryable_errors: []}
)

tasks = {}
NIGHTLY.each do |name, spec|
  tasks[name] = Agentic::Task.new(description: name,
    agent_spec: {"name" => name, "instructions" => "run"}, payload: spec)
  orchestrator.add_task(tasks[name], (spec[:deps] || []).map { |d| tasks.fetch(d) }, agent: ->(t) {
    sleep(t.payload[:time])
    raise t.payload[:error] if t.payload[:error]

    :ok
  })
end
orchestrator.execute_plan

# --- the report: everything below reads ONLY the journal ---------------------
state = Agentic::ExecutionJournal.replay(path: JOURNAL)
all_tasks = NIGHTLY.keys
completed = state.completed_descriptions
failed = state.events.select { |e| e[:event] == "task_failed" }
never_ran = all_tasks - completed - failed.map { |f| f[:description] }

puts "INCIDENT REPORT - nightly batch"
puts "=" * 52
puts
puts "impact:"
puts "  #{completed.size}/#{all_tasks.size} tasks completed before the stop"
failed.each do |f|
  puts "  ROOT CAUSE: #{f[:description]} - #{f[:error_type]}"
  puts "              \"#{f[:error]}\""
end
puts
puts "completed (do NOT re-run - outputs are journaled):"
completed.each { |d| puts format("  + %-20s %4.0fms", d, (state.durations[d] || 0) * 1000) }
puts
puts "never started (blocked behind the failure):"
never_ran.each { |d| puts "  . #{d}" }
puts
puts "resume plan:"
puts "  1. rotate the warehouse credentials (error is LlmAuthenticationError:"
puts "     retryable? => false; retrying without fixing creds is theater)"
puts "  2. re-run the batch - completed?(description) will skip the"
puts "     #{completed.size} journaled tasks; only #{all_tasks.size - completed.size} run"
puts format("  3. budget: ~%.0fms of work already banked, don't pay twice",
  state.durations.values.sum * 1000)
