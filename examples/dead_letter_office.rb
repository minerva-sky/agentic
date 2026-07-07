# frozen_string_literal: true

# The Dead Letter Office: three days of journaled runs, every failure
# collected and triaged by what the errors said about themselves -
# retryable failures go on the requeue manifest, non-retryable ones
# get parked with a reason. Nobody re-sends a letter addressed to a
# revoked mailbox.
#
#   bundle exec ruby examples/dead_letter_office.rb
#
# Runs offline; failures are scripted across runs.

require_relative "../lib/agentic"
require "tmpdir"

Agentic.logger.level = :fatal

JOURNAL = File.join(Dir.tmpdir, "agentic_dlo.journal.jsonl")
File.delete(JOURNAL) if File.exist?(JOURNAL)
journal = Agentic::ExecutionJournal.new(path: JOURNAL)

RUNS = [
  {"sync:crm" => Agentic::Errors::LlmTimeoutError.new("read timeout"),
   "sync:billing" => Agentic::Errors::LlmRateLimitError.new("429, slow down"),
   "sync:tickets" => nil},
  {"sync:crm" => nil, # recovers on its own
   "sync:billing" => Agentic::Errors::LlmRateLimitError.new("429, still angry"),
   "sync:warehouse" => Agentic::Errors::LlmAuthenticationError.new("401 key revoked")},
  {"sync:tickets" => Agentic::Errors::LlmServerError.new("502 from upstream"),
   "sync:warehouse" => Agentic::Errors::LlmAuthenticationError.new("401 key revoked")}
].freeze

RUNS.each do |jobs|
  orchestrator = Agentic::PlanOrchestrator.new(
    concurrency_limit: 2, lifecycle_hooks: journal.lifecycle_hooks,
    retry_policy: {max_retries: 0, retryable_errors: []}
  )
  jobs.each do |name, error|
    orchestrator.add_task(Agentic::Task.new(
      description: name, agent_spec: {"name" => name, "instructions" => "sync"},
      payload: error
    ), agent: ->(t) {
      sleep(0.005)
      raise t.payload if t.payload

      :ok
    })
  end
  orchestrator.execute_plan
end

# --- the office: triage from the journal --------------------------------------
state = Agentic::ExecutionJournal.replay(path: JOURNAL)

# A letter is DEAD only if its most recent attempt failed
latest = {}
state.events.each do |event|
  next unless %w[task_succeeded task_failed].include?(event[:event])

  latest[event[:description]] = event
end
dead = latest.values.select { |e| e[:event] == "task_failed" }

# The error taxonomy testifies: rebuild each error's retryability
RETRYABLE = {
  "Agentic::Errors::LlmRateLimitError" => true,
  "Agentic::Errors::LlmServerError" => true,
  "Agentic::Errors::LlmTimeoutError" => true,
  "Agentic::Errors::LlmAuthenticationError" => false,
  "Agentic::Errors::LlmInvalidRequestError" => false
}.freeze

requeue, parked = dead.partition { |e| RETRYABLE.fetch(e[:error_type], false) }
attempts = state.events.select { |e| e[:event] == "task_failed" }.group_by { |e| e[:description] }

puts "DEAD LETTER OFFICE (#{RUNS.size} journaled runs)"
puts
puts "  REQUEUE MANIFEST (transient failures - safe to retry):"
requeue.each do |letter|
  puts format("    %-16s %-42s %d failed attempt(s) on record",
    letter[:description], "#{letter[:error_type].split("::").last}: #{letter[:error]}",
    attempts[letter[:description]].size)
end
puts
puts "  PARKED (retrying will not help - a human must act):"
parked.each do |letter|
  puts format("    %-16s %s", letter[:description], "#{letter[:error_type].split("::").last}: #{letter[:error]}")
end
puts
recovered = latest.values.select { |e| e[:event] == "task_succeeded" && attempts.key?(e[:description]) }
puts "  recovered on their own (failed once, succeeded later - NOT dead):"
recovered.each { |e| puts "    #{e[:description]}" }
puts
puts "  the office triages by MOST RECENT attempt: sync:crm's old timeout"
puts "  doesn't page anyone, and sync:tickets' early success doesn't"
puts "  excuse its newer 502. a dead-letter queue that forgets recoveries"
puts "  pages people for ghosts; one that forgets relapses buries real mail."
