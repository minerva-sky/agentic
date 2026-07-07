# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe "round 9 framework features" do
  describe "RateLimit#resize" do
    it "raises a concurrency ceiling while the limiter is live" do
      limit = Agentic::RateLimit.new(1)

      Sync do
        4.times.map { Async { limit.acquire { sleep(0.01) } } }.each(&:wait)
        expect(limit.high_water).to eq(1)

        limit.resize(3)
        6.times.map { Async { limit.acquire { sleep(0.01) } } }.each(&:wait)
      end

      expect(limit.ceiling).to eq(3)
      expect(limit.high_water).to eq(3)
    end

    it "lowers a windowed ceiling for subsequent admissions" do
      limit = Agentic::RateLimit.new(5, per: 0.1)
      limit.resize(2)
      stamps = []

      Sync do
        3.times.map {
          Async do
            limit.acquire { stamps << Process.clock_gettime(Process::CLOCK_MONOTONIC) }
          end
        }.each(&:wait)
      end

      # With the resized ceiling of 2, the 3rd admission waits a window
      windows = stamps.sort
      expect(windows[2] - windows[0]).to be >= 0.09
    end

    it "rejects non-positive and non-integer ceilings" do
      limit = Agentic::RateLimit.new(2)

      expect { limit.resize(0) }.to raise_error(ArgumentError, /positive Integer/)
      expect { limit.resize(2.5) }.to raise_error(ArgumentError, /positive Integer/)
      expect(limit.ceiling).to eq(2)
    end
  end

  describe "journaled retryable verdicts" do
    it "records the failure's own retryability at write time and replays it" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "run.journal.jsonl")
        journal = Agentic::ExecutionJournal.new(path: path)
        hooks = journal.lifecycle_hooks
        task = Agentic::Task.new(description: "sync", agent_spec: {"name" => "w", "instructions" => "work"})

        transient = Agentic::TaskFailure.from_exception(Agentic::Errors::LlmRateLimitError.new("429"))
        hooks[:after_task_failure].call(task_id: "t1", task: task, failure: transient, duration: 0.1)

        state = Agentic::ExecutionJournal.replay(path: path)

        expect(state.events.last[:retryable]).to be(true)
        expect(state.failures["t1"][:retryable]).to be(true)
      end
    end

    it "preserves a nil verdict when the error expressed no opinion" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "run.journal.jsonl")
        journal = Agentic::ExecutionJournal.new(path: path)
        hooks = journal.lifecycle_hooks
        task = Agentic::Task.new(description: "sync", agent_spec: {"name" => "w", "instructions" => "work"})

        opinionless = Agentic::TaskFailure.from_exception(RuntimeError.new("boom"))
        hooks[:after_task_failure].call(task_id: "t1", task: task, failure: opinionless, duration: 0.1)

        state = Agentic::ExecutionJournal.replay(path: path)

        expect(state.events.last).to have_key(:retryable)
        expect(state.failures["t1"][:retryable]).to be_nil
      end
    end
  end
end
