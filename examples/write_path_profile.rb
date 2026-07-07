# frozen_string_literal: true

# The Write Path Profile: everyone's first instinct about a slow
# journal is "switch JSON libraries". Before holding that opinion,
# weigh each layer of the write separately - serialize, write, flush,
# fsync - because optimization budgets get spent where the profiler
# points or they get wasted. Spoiler: the disk's honesty is the
# product, and it is also the bill.
#
#   bundle exec ruby examples/write_path_profile.rb
#
# Runs offline; timings are real syscalls on this machine.

require_relative "../lib/agentic"
require "tmpdir"
require "json"

EVENTS = 300
PAYLOAD = {event: "task_succeeded", task_id: "t-123", description: "sync:orders",
           duration: 0.412, output: "x" * 200}.freeze

def bench(events = EVENTS)
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  events.times { |i| yield(i) }
  (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) / events * 1_000_000 # us/event
end

dir = Dir.mktmpdir("agentic_write_path")

# Layer 1: serialization only
serialize = bench { JSON.generate(PAYLOAD) }

# Layer 2: + buffered write (kernel may keep it in page cache forever)
buffered_file = File.open(File.join(dir, "buffered.jsonl"), "a")
buffered = bench { buffered_file.puts(JSON.generate(PAYLOAD)) }

# Layer 3: + flush (userland buffer to kernel, still not durable)
flushed_file = File.open(File.join(dir, "flushed.jsonl"), "a")
flushed = bench { |i|
  flushed_file.puts(JSON.generate(PAYLOAD))
  flushed_file.flush
}

# Layer 4: the real thing - open, flock, puts, flush, FSYNC per event
journal = Agentic::ExecutionJournal.new(path: File.join(dir, "real.jsonl"))
real = bench { |i| journal.record(:task_succeeded, PAYLOAD.merge(task_id: "t-#{i}")) }

# The alternative promise: group commit, now a real constructor knob
# (fsync_every: - the round-13 release cashing this file's own ask)
group_journal = Agentic::ExecutionJournal.new(path: File.join(dir, "group.jsonl"), fsync_every: 20)
group = bench { |i| group_journal.record(:task_succeeded, PAYLOAD.merge(task_id: "t-#{i}")) }
group_journal.sync # the crash-window closes here, explicitly

puts "WRITE PATH PROFILE (#{EVENTS} events per layer, microseconds each)"
puts
rows = {
  "JSON.generate only" => serialize,
  "+ buffered write" => buffered,
  "+ flush to kernel" => flushed,
  "journal.record (flock+fsync)" => real,
  "journal fsync_every: 20" => group
}
rows.each do |name, us|
  puts format("  %-30s %9.1fus   %s", name, us, "#" * [(Math.log10([us, 1].max) * 12).round, 1].max)
end

puts
json_share = serialize / real * 100
puts format("  the ledger: serialization is %.1f%% of the real write. swapping", json_share)
puts "  JSON libraries would optimize a rounding error - the other"
puts format("  %.1f%% is the price of the fsync, which is to say the price of", 100 - json_share)
puts "  the journal's ONLY promise (a crash cannot unwrite what record"
puts "  returned from). the honest knob is group commit - and since"
puts "  round 13 it's a real constructor argument: fsync_every: 20"
puts format("  drops the write to %.0fus, and the constructor's docs name what", group)
puts "  was traded (a crash may eat up to 19 acknowledged events)."
puts "  that's the correct shape for a durability tradeoff: explicit,"
puts "  named, greppable in the diff that chose it - not folklore in a"
puts "  wiki. profile first, name the tradeoff second, and never let"
puts "  anyone optimize the layer the profiler acquitted."
