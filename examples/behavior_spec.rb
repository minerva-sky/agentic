# frozen_string_literal: true

# The Behavior Spec: ruby/spec exists because "MRI does X" is not a
# specification - it's an implementation detail wearing one. When
# TruffleRuby and JRuby needed to know what Ruby MEANS, the answer
# had to be executable, implementation-neutral, and phrased as
# behavior. Same medicine here: a compliance file for the framework's
# subtlest semantics, in a 30-line mspec so the spec depends on
# nothing it's specifying.
#
#   bundle exec ruby examples/behavior_spec.rb
#
# Runs offline; exits 1 if any pinned behavior drifts.

require_relative "../lib/agentic"

Agentic.logger.level = :fatal

# --- a 30-line mspec: describe/it/should, no dependencies -----------------------
module MSpec
  RESULTS = []

  def self.describe(subject)
    @subject = subject
    yield
  end

  def self.it(behavior)
    yield
    RESULTS << [@subject, behavior, :pass, nil]
  rescue => e
    RESULTS << [@subject, behavior, :FAIL, e.message[0, 50]]
  end

  def self.expect(actual, expected, note = "")
    raise "expected #{expected.inspect}, got #{actual.inspect} #{note}" unless actual == expected
  end
end

# --- the compliance file ---------------------------------------------------------
MSpec.describe "RateLimit windowed admission" do
  MSpec.it "admits exactly ceiling acquisitions, then refuses (boundary is closed)" do
    limit = Agentic::RateLimit.new(3, per: 60)
    MSpec.expect(3.times.count { limit.try_acquire }, 3)
    MSpec.expect(limit.try_acquire, false, "(the ceiling-th+1 must refuse, not queue)")
  end

  MSpec.it "try_acquire without a block still consumes a window slot" do
    limit = Agentic::RateLimit.new(1, per: 60)
    limit.try_acquire
    MSpec.expect(limit.try_acquire, false)
  end

  MSpec.it "resize applies to the NEXT admission decision" do
    limit = Agentic::RateLimit.new(1, per: 60)
    limit.try_acquire
    limit.resize(2)
    MSpec.expect(limit.try_acquire, true, "(old stamps count against the new ceiling)")
    MSpec.expect(limit.try_acquire, false)
  end
end

MSpec.describe "RelationRules presence semantics" do
  MSpec.it "presence means key-given-and-non-nil" do
    check = Agentic::RelationRules.check(relation: :requires, fields: [:a, :b])
    MSpec.expect(check.call({a: 1, b: 2}), true)
    MSpec.expect(check.call({a: 1}), false)
    MSpec.expect(check.call({a: nil, b: nil}), true, "(nil trigger = absent, rule not engaged)")
  end

  MSpec.it "sum_lte treats missing fields as zero, and the boundary as closed" do
    check = Agentic::RelationRules.check(relation: :sum_lte, fields: [:a, :b], limit: 10)
    MSpec.expect(check.call({a: 10}), true, "(missing b contributes 0; 10 <= 10)")
    MSpec.expect(check.call({a: 10, b: 1}), false)
  end
end

MSpec.describe "ExecutionJournal replay semantics" do
  MSpec.it "later events win: a success erases an earlier failure, not vice versa" do
    require "tmpdir"
    path = File.join(Dir.mktmpdir, "j.jsonl")
    j = Agentic::ExecutionJournal.new(path: path)
    j.record(:task_failed, task_id: "t", description: "t", duration: 0.1, error: "x", error_type: "E", retryable: true)
    j.record(:task_succeeded, task_id: "t", description: "t", duration: 0.1, output: nil)
    state = Agentic::ExecutionJournal.replay(path: path)
    MSpec.expect(state.completed_task_ids, ["t"])
    MSpec.expect(state.failed_task_ids, [], "(recovery must clear the failure ledger)")
  end
end

puts "THE BEHAVIOR SPEC (executable semantics, mspec-style)"
puts
MSpec::RESULTS.each do |subject, behavior, status, err|
  puts format("  %-4s %s: %s%s", (status == :pass) ? "ok" : "FAIL", subject, behavior, err ? " - #{err}" : "")
end

failures = MSpec::RESULTS.count { |r| r[2] == :FAIL }
puts
puts "  #{MSpec::RESULTS.size} behaviors pinned, #{failures} drifted."
puts
puts "  why this file exists when the rspec suite already does: the suite"
puts "  tests THIS implementation; this file specifies WHAT ANY"
puts "  implementation must do - the boundary conditions someone porting"
puts "  the limiter to a Ractor, a different VM, or another language"
puts "  needs answered precisely. note what's pinned: the ceiling-th+1"
puts "  refuses (closed boundary), resize counts OLD stamps against the"
puts "  NEW ceiling, nil triggers don't engage requires, and a success"
puts "  erases an earlier failure. every one of those is a choice that"
puts "  could have gone the other way - which is exactly what a spec is:"
puts "  the choices, written down, executable, so 'what the code happens"
puts "  to do' and 'what the code means' stop being the same sentence."
puts "  (this file's own round-14 ask was delivered in round 15: the"
puts "  fiber-vs-thread guarantees are now pinned per method in"
puts "  spec/agentic/concurrency_contract_spec.rb and documented as"
puts "  @note Concurrency contract: on the methods themselves.)"
exit(failures.zero? ? 0 : 1)
