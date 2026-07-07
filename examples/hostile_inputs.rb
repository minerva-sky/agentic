# frozen_string_literal: true

# Hostile Inputs: a parser's real spec is what it does with input
# nobody intended. The journal's replay parses a file that - by the
# journal's own reason for existing - may end mid-write. This probe
# feeds replay the whole rogues' gallery: torn tails, binary garbage,
# giant lines, wrong-shaped JSON. The verdict on the torn tail is the
# one that matters, and today it draws blood. Exit 1 by design.
#
#   bundle exec ruby examples/hostile_inputs.rb
#
# Runs offline; exits 1 until torn-tail recovery ships.

require_relative "../lib/agentic"
require "tmpdir"
require "json"

GOOD = %({"event":"task_succeeded","task_id":"t1","description":"t1","duration":0.1,"output":"ok"})

def replay_verdict(lines)
  path = File.join(Dir.tmpdir, "agentic_hostile.jsonl")
  File.write(path, lines.join("\n"))
  state = Agentic::ExecutionJournal.replay(path: path)
  [:recovered, state.completed_task_ids.size]
rescue => e
  [:crashed, e.class.to_s]
end

PROBES = {
  "clean file (control)" => [GOOD, GOOD.sub("t1", "t2")],
  "torn tail (crash mid-write)" => [GOOD, %({"event":"task_succ)],
  "binary garbage line" => [GOOD, "\x00\x01\xFFnot json at all"],
  "empty + whitespace lines" => [GOOD, "", "   ", GOOD.sub("t1", "t2")],
  "8MB single line" => [GOOD, %({"event":"task_succeeded","task_id":"big","description":"big","duration":0.1,"output":"#{"x" * 8_000_000}"})],
  "valid JSON, wrong shape" => [GOOD, %({"event":"task_succeeded","task_id":42,"duration":"fast"})],
  "unknown event type" => [GOOD, %({"event":"solar_flare","task_id":"t9"})],
  "duplicate success lines" => [GOOD, GOOD]
}.freeze

puts "HOSTILE INPUTS (#{PROBES.size} probes against ExecutionJournal.replay)"
puts
blood = []
PROBES.each do |name, lines|
  verdict, detail = replay_verdict(lines)
  ok = verdict == :recovered
  blood << name unless ok
  puts format("  %-30s %s", name,
    ok ? "recovered (#{detail} task(s) salvaged)" : "CRASHED: #{detail} - ALL recovery denied")
end

puts
if blood.empty?
  puts "  every probe salvaged what was salvageable. the tail is tolerated."
else
  puts "  #{blood.size} probe(s) drew blood: #{blood.join("; ")}."
  puts
  puts "  the torn tail is the indefensible one. a journal exists FOR the"
  puts "  crash - fsync guarantees completed lines survive, but the line"
  puts "  being written AT the crash may land torn, and that is the exact"
  puts "  file every real recovery will read. today one torn byte at the"
  puts "  tail throws JSON::ParserError past every rescue that says"
  puts "  ValidationError, and 100% of the events that WERE durable"
  puts "  become unreachable. nokogiri's whole life is this lesson:"
  puts "  parsers meet real input, and real input is damaged. filed as"
  puts "  the round-13 ask: replay must salvage every whole line and"
  puts "  report (not raise on) a torn tail - recovery tools don't get"
  puts "  to be the second thing that fails. exit 1 until."
end
exit(blood.empty? ? 0 : 1)
