# frozen_string_literal: true

# The Attachment Pipeline: Shrine's central lesson is that file
# uploads are a TWO-PHASE commit wearing a file input - phase one
# (cache) must be instant and disposable, phase two (promote +
# derivatives) is slow, background, and idempotent, because users
# double-submit, workers die mid-thumbnail, and retries must never
# double-bill. A plan with a journal is exactly the right machine
# for phase two.
#
#   bundle exec ruby examples/attachment_pipeline.rb
#
# Runs offline; the "upload" is a hash, the crash is real.

require_relative "../lib/agentic"
require "tmpdir"

Agentic.logger.level = :fatal

STORES = {cache: {}, store: {}}
UPLOAD = {id: "upload-7f3a", filename: "team-photo.jpg", bytes: 48_213}.freeze

# Phase 1 - cache: instant, no processing, happens in the request
STORES[:cache][UPLOAD[:id]] = UPLOAD
puts "THE ATTACHMENT PIPELINE (cache instantly, promote carefully)"
puts
puts "  phase 1 (request): cached #{UPLOAD[:filename]} as #{UPLOAD[:id]} - 0ms of processing"
puts

# Phase 2 - promotion: a journaled plan. Derivative names are the
# idempotency keys, so a crashed promotion resumes instead of re-paying.
JOURNAL_PATH = File.join(Dir.tmpdir, "agentic_promote_#{UPLOAD[:id]}.jsonl")
File.delete(JOURNAL_PATH) if File.exist?(JOURNAL_PATH)

DERIVATIVES = {
  "derive:thumb:200" => 0.02,
  "derive:web:1200" => 0.03,
  "derive:ocr_text" => 0.04
}.freeze

def promotion_plan(upload, crash_at: nil)
  journal = Agentic::ExecutionJournal.new(path: JOURNAL_PATH)
  done = Agentic::ExecutionJournal.replay(path: JOURNAL_PATH)
  orchestrator = Agentic::PlanOrchestrator.new(
    concurrency_limit: 2, lifecycle_hooks: journal.lifecycle_hooks,
    retry_policy: {max_retries: 0, retryable_errors: []}
  )

  derivative_tasks = DERIVATIVES.filter_map do |name, cost|
    next if done.completed?(name) # already paid for - skip, don't re-derive

    task = Agentic::Task.new(description: name, agent_spec: {"name" => name, "instructions" => "derive"})
    orchestrator.add_task(task, agent: ->(_t) {
      raise "worker OOM-killed" if crash_at == name

      sleep(cost)
      "#{name.split(":")[1]} of #{upload[:filename]}"
    })
    task
  end

  unless done.completed?("promote:record")
    promote = Agentic::Task.new(description: "promote:record", agent_spec: {"name" => "promote", "instructions" => "p"})
    orchestrator.add_task(promote, derivative_tasks, agent: ->(_t) {
      STORES[:store][upload[:id]] = upload.merge(promoted: true)
      STORES[:cache].delete(upload[:id])
      "promoted"
    })
  end
  [orchestrator, derivative_tasks.size]
end

# First attempt: the worker dies mid-derivatives
orchestrator, scheduled = promotion_plan(UPLOAD, crash_at: "derive:web:1200")
result = orchestrator.execute_plan
state = Agentic::ExecutionJournal.replay(path: JOURNAL_PATH)
puts "  phase 2, attempt 1 (background): #{scheduled} derivatives scheduled..."
puts "    worker crashed at derive:web:1200 - status: #{result.status}"
puts "    journal holds #{state.completed_descriptions.size} paid derivative(s): #{state.completed_descriptions.join(", ")}"
puts "    record NOT promoted; cache still serves the original. users see a photo, not an error."
puts

# The retry (double-submitted by an anxious user AND the job system)
orchestrator, scheduled = promotion_plan(UPLOAD)
orchestrator.execute_plan
puts "  phase 2, attempt 2 (retry): only #{scheduled} derivative(s) scheduled - the paid ones skipped"
puts "    promoted: #{STORES[:store].key?(UPLOAD[:id])}; cache cleared: #{!STORES[:cache].key?(UPLOAD[:id])}"
puts

third, scheduled = promotion_plan(UPLOAD)
third.execute_plan
puts "  phase 2, attempt 3 (the double-submit): #{scheduled} derivatives scheduled, nothing re-derived,"
puts "    promotion already recorded - idempotent all the way down."
puts
puts "  the shape to steal: CACHE is cheap and lies to nobody (the user's"
puts "  file is safe the instant the request returns); PROMOTION is a"
puts "  journaled plan whose derivative names are idempotency keys, so a"
puts "  crash resumes at the exact thumbnail it died on and a retry"
puts "  re-derives NOTHING. promotion commits the record only after every"
puts "  derivative exists - the record is the two-phase commit's second"
puts "  phase. uploads look like a file input; they're a distributed"
puts "  transaction, and pretending otherwise is where the corrupted"
puts "  avatars come from."
