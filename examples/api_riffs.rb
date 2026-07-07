# frozen_string_literal: true

# API Riffs: before an API ships, sketch it three ways and READ the
# call sites out loud - the design work happens in the comparing, not
# the committing. Subject: the journal's group-commit knob (which
# shipped this round as fsync_every:). Here are the three riffs that
# could have been, each runnable, each judged at its call site.
#
#   bundle exec ruby examples/api_riffs.rb
#
# Runs offline; every riff executes against the real journal.

require_relative "../lib/agentic"
require "tmpdir"

Agentic.logger.level = :fatal

def fresh_path(name) = File.join(Dir.tmpdir, "agentic_riff_#{name}.jsonl").tap { |p| File.delete(p) if File.exist?(p) }

def write_events(journal, n = 5)
  n.times { |i| journal.record(:task_succeeded, task_id: "t#{i}", description: "t#{i}", duration: 0.01, output: nil) }
end

puts "API RIFFS: three shapes for one durability knob"
puts

# --- riff 1: the constructor kwarg (what shipped) --------------------------------
puts "  riff 1 - constructor kwarg:"
puts "      journal = ExecutionJournal.new(path:, fsync_every: 20)"
journal = Agentic::ExecutionJournal.new(path: fresh_path(1), fsync_every: 20)
write_events(journal)
journal.sync
puts "    + the trade is visible at construction, greppable in the diff"
puts "      that chose it, and IMMUTABLE - nobody weakens durability"
puts "      mid-flight three files away."
puts "    - it's a magic integer; 20 of WHAT is one docs-lookup away."
puts

# --- riff 2: the policy object ----------------------------------------------------
puts "  riff 2 - a named policy object:"
puts "      journal = ExecutionJournal.new(path:, durability: Durability.grouped(20))"
module Durability
  Every = Struct.new(:n) do
    def to_fsync_every = n
  end

  def self.grouped(n) = Every.new(n)

  def self.strict = Every.new(1)
end
journal = Agentic::ExecutionJournal.new(path: fresh_path(2), fsync_every: Durability.grouped(20).to_fsync_every)
write_events(journal)
journal.sync
puts "    + Durability.strict reads as a SENTENCE; new policies (time-"
puts "      based flushing) get names without new kwargs; the docs live"
puts "      on the object."
puts "    - a whole constant surface for one integer today - the wardrobe"
puts "      is bigger than the costume. YAGNI has a case here."
puts

# --- riff 3: the per-call escape hatch --------------------------------------------
puts "  riff 3 - per-call override:"
puts "      journal.record(event, payload, durable: false)"
class LeakyJournal < Agentic::ExecutionJournal
  def record(event, payload = {}, durable: true, **rest)
    super(event, payload.merge(rest)) # (sketch: durable: false would skip the fsync)
  end
end
journal = LeakyJournal.new(path: fresh_path(3))
write_events(journal)
puts "    + maximal flexibility: hot loops opt out, milestones opt in."
puts "    - and that's the indictment: durability becomes a per-CALL-SITE"
puts "      opinion. the invariant 'this journal survives crashes' stops"
puts "      being a property of the OBJECT and starts being a property of"
puts "      every author's judgment forever. flexibility is where"
puts "      invariants go to die."
puts

puts "  the riff verdict: shape 1 shipped, and the reading explains why -"
puts "  a durability contract belongs to the OBJECT (riff 3 dissolves"
puts "  it), and one integer doesn't yet earn a policy wardrobe (riff 2"
puts "  can arrive later, wrapping the kwarg, if flush-after-100ms ever"
puts "  becomes real). but note what the exercise cost: forty lines and"
puts "  ten minutes, versus the years a shipped API lives. riff BEFORE"
puts "  you commit - call sites read differently than class definitions,"
puts "  and the call site is where your users actually live."
