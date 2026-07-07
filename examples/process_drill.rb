# frozen_string_literal: true

# The Process Drill: threads share a Mutex; PROCESSES share nothing
# but the file. The journal claims flock+fsync, which is a promise
# about processes - so this drill forks real ones, points them all at
# one journal, and lets the kernel referee. Then replay must find
# every event whole: no torn lines, no interleaved halves, no losses.
#
#   bundle exec ruby examples/process_drill.rb
#
# Runs offline; exits 1 if any process's write was torn or lost.

require_relative "../lib/agentic"
require "tmpdir"
require "json"

Agentic.logger.level = :fatal

PROCESSES = 4
EVENTS = 250
PATH = File.join(Dir.tmpdir, "agentic_process_drill.journal.jsonl")
File.delete(PATH) if File.exist?(PATH)

pids = PROCESSES.times.map do |p|
  fork do
    journal = Agentic::ExecutionJournal.new(path: PATH)
    EVENTS.times do |i|
      journal.record(:task_succeeded,
        task_id: "p#{p}-#{i}", description: "p#{p}-#{i}",
        duration: 0.001, output: "payload-#{p}-" + ("x" * (50 + (i % 100))))
    end
    exit!(0)
  end
end
statuses = pids.map { |pid| Process.wait2(pid).last.exitstatus }

# --- the referee ----------------------------------------------------------------
lines = File.readlines(PATH)
torn = lines.reject do |line|
  JSON.parse(line)
  true
rescue JSON::ParserError
  false
end
state = Agentic::ExecutionJournal.replay(path: PATH)
expected = PROCESSES * EVENTS
per_process = PROCESSES.times.map { |p|
  state.completed_task_ids.count { |id| id.start_with?("p#{p}-") }
}

puts "PROCESS DRILL (#{PROCESSES} forked writers x #{EVENTS} events, one journal)"
puts
puts format("  processes exited cleanly:  %s", statuses.all?(&:zero?) ? "yes" : "NO")
puts format("  lines on disk:             %d/%d", lines.size, expected)
puts format("  torn lines:                %d", torn.size)
puts format("  replay recovered per proc: %s", per_process.join(", "))
puts

ok = statuses.all?(&:zero?) && lines.size == expected && torn.empty? && per_process.all?(EVENTS)
if ok
  puts "  the flock claim is now a certificate, not a comment: four"
  puts "  processes - separate GVLs, separate heaps, separate everything -"
  puts "  interleaved a thousand writes into one file and the kernel's"
  puts "  advisory lock kept every line whole. this is the half of the"
  puts "  journal's promise the threads drill couldn't reach: a Mutex"
  puts "  means nothing across fork(2); only the fd-level lock does."
  puts "  crash-recovery tooling stands on exactly this property."
else
  puts "  DRILL FAILED - the promise about processes is broken."
end
exit(ok ? 0 : 1)
