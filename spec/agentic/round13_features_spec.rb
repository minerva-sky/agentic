# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe "round 13 framework features" do
  let(:good_line) { %({"event":"task_succeeded","task_id":"t1","description":"t1","duration":0.1,"output":"ok"}) }

  def journal_file(*lines)
    path = File.join(Dir.mktmpdir, "run.journal.jsonl")
    File.write(path, lines.join("\n"))
    path
  end

  describe "tolerant replay" do
    it "salvages whole lines around a torn tail and reports the damage" do
      path = journal_file(good_line, %({"event":"task_succ))

      state = Agentic::ExecutionJournal.replay(path: path)

      expect(state.completed_task_ids).to eq(["t1"])
      expect(state).to be_damaged
      expect(state.damage).to eq([{line: 2, reason: "JSON::ParserError"}])
    end

    it "survives binary garbage and shape-broken task lines" do
      path = journal_file(good_line, "\x00\x01\xFFgarbage", %({"event":"task_succeeded","task_id":42}))

      state = Agentic::ExecutionJournal.replay(path: path)

      expect(state.completed_task_ids).to eq(["t1"])
      expect(state.damage.map { |d| d[:line] }).to eq([2, 3])
    end

    it "reports no damage on a clean journal" do
      path = journal_file(good_line)

      expect(Agentic::ExecutionJournal.replay(path: path)).not_to be_damaged
    end
  end

  describe "strict replay" do
    it "raises JournalDamagedError naming the line" do
      path = journal_file(good_line, %({"event":"task_succ))

      expect {
        Agentic::ExecutionJournal.replay(path: path, mode: :strict)
      }.to raise_error(Agentic::Errors::JournalDamagedError, /line 2/) { |e|
        expect(e.line_number).to eq(2)
      }
    end

    it "raises on shape-broken task events too" do
      path = journal_file(%({"event":"task_succeeded","task_id":42}))

      expect {
        Agentic::ExecutionJournal.replay(path: path, mode: :strict)
      }.to raise_error(Agentic::Errors::JournalDamagedError, /String task_id/)
    end
  end

  describe "fsync_every group commit" do
    it "writes and replays identically under group commit" do
      path = File.join(Dir.mktmpdir, "group.journal.jsonl")
      journal = Agentic::ExecutionJournal.new(path: path, fsync_every: 20)

      50.times { |i| journal.record(:task_succeeded, task_id: "t#{i}", description: "t#{i}", duration: 0.001, output: nil) }
      journal.sync

      expect(journal.fsync_every).to eq(20)
      expect(Agentic::ExecutionJournal.replay(path: path).completed_task_ids.size).to eq(50)
    end

    it "rejects a non-positive fsync_every" do
      expect {
        Agentic::ExecutionJournal.new(path: "x.jsonl", fsync_every: 0)
      }.to raise_error(ArgumentError, /positive Integer/)
    end
  end
end
