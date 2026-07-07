# frozen_string_literal: true

# The Weekly Check-in: "what did you work on this week?" answered by
# the journal instead of by memory. Runs a few days of plans, then
# writes the check-in from the replay - what shipped, what failed,
# where the time went. Nobody's Friday afternoon was harmed.
#
#   bundle exec ruby examples/weekly_checkin.rb
#
# Runs offline; the "week" is three journaled plan runs.

require_relative "../lib/agentic"
require "tmpdir"

Agentic.logger.level = :fatal

JOURNAL = File.join(Dir.tmpdir, "agentic_weekly.journal.jsonl")
File.delete(JOURNAL) if File.exist?(JOURNAL)

journal = Agentic::ExecutionJournal.new(path: JOURNAL)

# --- the week: three days of plans, journaled as they happen ----------------
def run_day(journal, day, jobs)
  orchestrator = Agentic::PlanOrchestrator.new(
    concurrency_limit: 3,
    lifecycle_hooks: journal.lifecycle_hooks,
    retry_policy: {max_retries: 0, retryable_errors: []}
  )
  jobs.each do |name, spec|
    orchestrator.add_task(Agentic::Task.new(
      description: "#{day}: #{name}",
      agent_spec: {"name" => name, "instructions" => "work"},
      payload: spec
    ), agent: ->(t) {
      sleep(t.payload[:time])
      raise t.payload[:error] if t.payload[:error]

      :done
    })
  end
  orchestrator.execute_plan
end

run_day(journal, "mon", {
  "import customer csv" => {time: 0.08},
  "dedupe records" => {time: 0.05},
  "sync to billing" => {time: 0.03}
})
run_day(journal, "wed", {
  "backfill invoices" => {time: 0.12},
  "email statements" => {time: 0.02, error: "smtp relay refused"},
  "archive quarter" => {time: 0.04}
})
run_day(journal, "fri", {
  "email statements" => {time: 0.02},
  "close the books" => {time: 0.06}
})

# --- the check-in: written from the replay, not from memory ------------------
state = Agentic::ExecutionJournal.replay(path: JOURNAL)

shipped = state.completed_descriptions
failures = state.events.select { |e| e[:event] == "task_failed" }
total_time = state.durations.values.sum
slowest = state.durations.max_by { |_, duration| duration }

puts "WEEKLY CHECK-IN (generated from #{JOURNAL.split("/").last})"
puts
puts "What did you work on this week?"
shipped.each { |item| puts "  - #{item}" }
puts
puts "Anything get stuck?"
failures.each do |failure|
  recovered = state.completed_descriptions.any? { |d| d.split(": ").last == failure[:description].split(": ").last }
  puts "  - #{failure[:description]} (#{failure[:error]})" \
    "#{recovered ? " - recovered later in the week" : " - STILL BROKEN"}"
end
puts
puts "Where did the time go?"
puts format("  %.0fms of tracked work; slowest was \"%s\" at %.0fms",
  total_time * 1000, slowest[0], slowest[1] * 1000)
puts
puts "written by the journal in 0 minutes. the check-in meeting sends"
puts "its regards, from wherever cancelled meetings go."
