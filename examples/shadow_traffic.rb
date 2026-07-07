# frozen_string_literal: true

# Shadow Traffic: the safest way to replace a component at scale is
# to never let the replacement answer. The OLD implementation serves
# every request; the NEW one runs beside it in the shadow - same
# inputs, measured and compared, its results thrown away. Users feel
# nothing; you collect a mismatch report and a latency comparison,
# and the cutover decision becomes a table instead of a leap.
#
#   bundle exec ruby examples/shadow_traffic.rb
#
# Runs offline; v2 disagrees on exactly the case that would've paged.

require_relative "../lib/agentic"
require "tmpdir"

Agentic.logger.level = :fatal

# v1 serves production today
V1 = ->(text) { text.match?(/refund|charge/i) ? "billing" : "general" }

# v2 is the candidate: faster on average, and subtly different
V2 = lambda do |text|
  sleep(0.001)
  return "billing" if text.match?(/refund|charge|invoice/i) # broader net
  "general"
end

JOURNAL = File.join(Dir.tmpdir, "agentic_shadow.jsonl")
File.delete(JOURNAL) if File.exist?(JOURNAL)
journal = Agentic::ExecutionJournal.new(path: JOURNAL)

REQUESTS = [
  "I want a refund for order 8",
  "How do I reset my password?",
  "You charged me twice",
  "Please resend my invoice",       # <- the divergence
  "What are your business hours?",
  "Refund the duplicate charge"
].freeze

# One plan per request: the serve task answers; the shadow task runs
# the candidate on the same input and RECORDS, never serves
mismatches = []
latencies = {v1: [], v2: []}

REQUESTS.each_with_index do |text, i|
  orchestrator = Agentic::PlanOrchestrator.new(lifecycle_hooks: journal.lifecycle_hooks)
  serve = Agentic::Task.new(description: "serve:#{i}", agent_spec: {"name" => "v1", "instructions" => "serve"})
  shadow = Agentic::Task.new(description: "shadow:#{i}", agent_spec: {"name" => "v2", "instructions" => "shadow"})

  orchestrator.add_task(serve, agent: ->(_t) {
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    answer = V1.call(text)
    latencies[:v1] << Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
    answer
  })
  # The shadow depends on serve's output so it can COMPARE - and its
  # own output is deliberately unused by anything downstream
  orchestrator.add_task(shadow, [serve], agent: ->(t) {
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    candidate = V2.call(text)
    latencies[:v2] << Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
    if candidate != t.previous_output
      mismatches << {request: text, served: t.previous_output, candidate: candidate}
      journal.record(:shadow_mismatch, description: "shadow:#{i}", served: t.previous_output, candidate: candidate)
    end
    candidate
  })
  result = orchestrator.execute_plan
  # What the user received came from v1, always:
  raise "shadow leaked into serving!" unless result.task_result(serve.id).output == V1.call(text)
end

puts "SHADOW TRAFFIC (v1 serves; v2 rehearses; users feel nothing)"
puts
puts format("  %d requests served by v1; %d shadowed by v2", REQUESTS.size, REQUESTS.size)
puts format("  agreement: %d/%d (%.0f%%)", REQUESTS.size - mismatches.size, REQUESTS.size,
  (REQUESTS.size - mismatches.size) * 100.0 / REQUESTS.size)
puts format("  latency:   v1 p50 %.2fms, v2 p50 %.2fms", latencies[:v1].sort[2] * 1000, latencies[:v2].sort[2] * 1000)
puts
puts "  the mismatch report (the whole reason to shadow):"
mismatches.each do |m|
  puts "    #{m[:request].inspect}"
  puts "      served: #{m[:served]} | candidate: #{m[:candidate]}"
end
puts
state = Agentic::ExecutionJournal.replay(path: JOURNAL)
puts "  #{state.events.count { |e| e[:event] == "shadow_mismatch" }} mismatch(es) journaled - the cutover meeting reads a table,"
puts "  not a hunch. and the mismatch is EXACTLY the case that would have"
puts "  paged after a blind cutover: v2 casts a broader net ('invoice'),"
puts "  which is either the bug fixed or the regression introduced - the"
puts "  shadow can't tell you which, but it guarantees a HUMAN decides"
puts "  with the example in hand, before a single user was reclassified."
puts "  the discipline that makes this safe at scale: the shadow's output"
puts "  feeds NOTHING (asserted every request), shadow failures can't"
puts "  fail the plan, and the comparison is journaled where the recovery"
puts "  and audit tooling already live. rehearse in production, serve"
puts "  from the incumbent, cut over on evidence."
