# frozen_string_literal: true

# The Threads Drill: fibers are polite; threads are not. Everything
# in this gem that claims to be shared-safe gets hammered by real
# Ruby threads - the kind that run truly parallel on JRuby, where
# there is no GVL to be your accidental bodyguard. The journal and
# registry hold. The windowed limiter's bookkeeping is the one to
# watch, and the drill says so out loud.
#
#   bundle exec ruby examples/threads_drill.rb
#
# Runs offline; exits 1 if a guaranteed-safe structure corrupts.

require_relative "../lib/agentic"
require "tmpdir"
require "json"

Agentic.logger.level = :fatal

THREADS = 8
EVENTS = 150
failures = 0

# --- drill 1: the journal under parallel writers --------------------------------
path = File.join(Dir.tmpdir, "agentic_threads.journal.jsonl")
File.delete(path) if File.exist?(path)
journal = Agentic::ExecutionJournal.new(path: path)

THREADS.times.map { |t|
  Thread.new do
    EVENTS.times { |i| journal.record(:task_succeeded, task_id: "t#{t}-#{i}", description: "t#{t}-#{i}", duration: 0.001, output: "x" * 64) }
  end
}.each(&:join)

lines = File.readlines(path)
parseable = lines.count do |line|
  JSON.parse(line)
  true
rescue JSON::ParserError
  false
end
torn = lines.size - parseable
expected = THREADS * EVENTS
failures += 1 if lines.size != expected || torn.positive?
puts "  drill 1 - journal, #{THREADS} threads x #{EVENTS} events:"
puts format("    %d/%d lines written, %d torn - %s", parseable, expected, torn,
  (torn.zero? && lines.size == expected) ? "mutex + flock + fsync held" : "CORRUPTED")
puts

# --- drill 2: the registry under concurrent registration ------------------------
registry = Agentic::AgentCapabilityRegistry.instance
THREADS.times.map { |t|
  Thread.new do
    50.times do |i|
      spec = Agentic::CapabilitySpecification.new(
        name: "cap-#{t}-#{i}", description: "x", version: "1.0.0",
        inputs: {a: {type: "number", required: true}}
      )
      Agentic.register_capability(spec, Agentic::CapabilityProvider.new(capability: spec, implementation: ->(inputs) { inputs }))
      registry.get_provider("cap-#{t}-#{i}")&.execute(a: 1)
    end
  end
}.each(&:join)

missing = THREADS.times.sum { |t| 50.times.count { |i| registry.get_provider("cap-#{t}-#{i}").nil? } }
failures += 1 if missing.positive?
puts "  drill 2 - registry, #{THREADS} threads x 50 register+execute:"
puts format("    %d registrations lost - %s", missing, missing.zero? ? "registry held" : "RACE")
puts

# --- drill 3: the windowed limiter's check-then-act ------------------------------
# try_acquire reads @stamps.size then appends - two steps, no mutex.
# Under the GVL the window between them is narrow; on JRuby it is a
# freeway. The drill hammers it and reports what it saw - honestly.
limit = Agentic::RateLimit.new(50, per: 60)
admitted = THREADS.times.map {
  Thread.new { 200.times.count { limit.try_acquire } }
}.map(&:value).sum

puts "  drill 3 - windowed try_acquire, #{THREADS} threads x 200 attempts (ceiling 50):"
if admitted <= 50
  puts "    admitted #{admitted}/50 - no over-admission OBSERVED. on this VM the"
  puts "    GVL serializes the check-then-act; that is a bodyguard, not a"
  puts "    guarantee. the same code on JRuby runs both steps truly in"
  puts "    parallel, and unsynchronized size-check-then-append is exactly"
  puts "    the shape that over-admits there."
else
  puts "    admitted #{admitted}/50 - OVER-ADMISSION, caught live. no JRuby needed;"
  puts "    the preemption gods were simply feeling honest today."
end
puts
puts "  the journal and registry hold under real threads because they"
puts "  paid for real locks (a Mutex, flock, fsync). the limiter's"
puts "  windowed bookkeeping hasn't paid yet - it works because MRI's"
puts "  scheduler rarely preempts a two-step dance, which is luck"
puts "  wearing a lab coat. filed as the round-12 ask: a Mutex around"
puts "  the stamp bookkeeping, so the answer is the same on every Ruby."

exit(failures.zero? ? 0 : 1)
