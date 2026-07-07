# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

# The concurrency contract: per-method guarantees pinned as specs, not
# just demonstrated by drills. The examples' threads/process drills
# characterize; this file PROMISES - each block names the guarantee its
# @note documentation makes, and fails if the guarantee drifts.
RSpec.describe "concurrency contract" do
  describe "ExecutionJournal#record: thread-safe" do
    it "interleaves parallel writers without tearing or losing lines" do
      path = File.join(Dir.mktmpdir, "contract.journal.jsonl")
      journal = Agentic::ExecutionJournal.new(path: path)

      6.times.map { |t|
        Thread.new do
          50.times { |i| journal.record(:task_succeeded, task_id: "t#{t}-#{i}", description: "t#{t}-#{i}", duration: 0.001, output: "x") }
        end
      }.each(&:join)

      state = Agentic::ExecutionJournal.replay(path: path, mode: :strict)
      expect(state.completed_task_ids.size).to eq(300)
    end
  end

  describe "RateLimit (windowed): thread-safe" do
    it "never over-admits under contending threads (try_acquire)" do
      limit = Agentic::RateLimit.new(40, per: 60)

      admitted = 8.times.map {
        Thread.new { 300.times.count { limit.try_acquire } }
      }.sum(&:value)

      expect(admitted).to eq(40)
    end

    it "admits every blocking acquire exactly once across threads" do
      limit = Agentic::RateLimit.new(4, per: 0.05)
      admissions = Queue.new

      8.times.map { |i|
        Thread.new { limit.acquire { admissions << i } }
      }.each(&:join)

      expect(admissions.size).to eq(8)
      # The high-water mark is part of the promise too: counters share
      # the window mutex, so the mark stays truthful under threads
      expect(limit.high_water).to be <= 4
    end
  end

  describe "RateLimit (concurrency mode): fiber-scoped" do
    it "provides blocking acquisition within one reactor" do
      limit = Agentic::RateLimit.new(2)

      Sync do
        6.times.map { Async { limit.acquire { sleep(0.005) } } }.each(&:wait)
      end

      expect(limit.high_water).to eq(2)
    end

    it "documents the boundary: non-blocking calls work from plain threads" do
      limit = Agentic::RateLimit.new(1)

      expect(Thread.new { limit.try_acquire }.value).to be(true)
    end
  end

  describe "AgentCapabilityRegistry: thread-safe" do
    it "loses no registrations under parallel register/get" do
      registry = Agentic::AgentCapabilityRegistry.instance

      6.times.map { |t|
        Thread.new do
          20.times do |i|
            spec = Agentic::CapabilitySpecification.new(name: "contract-#{t}-#{i}", description: "x", version: "1.0.0")
            Agentic.register_capability(spec, Agentic::CapabilityProvider.new(capability: spec, implementation: ->(inputs) { inputs }))
          end
        end
      }.each(&:join)

      missing = 6.times.sum { |t| 20.times.count { |i| registry.get_provider("contract-#{t}-#{i}").nil? } }
      expect(missing).to eq(0)
    end
  end

  describe "PlanOrchestrator: single-plan, reactor-resident" do
    it "documents the boundary: one orchestrator executes one plan at a time on one reactor" do
      # This is the contract's honest edge: the orchestrator is not a
      # shared-across-threads object. What IS safe to share are the
      # things it emits (graph snapshots - see the Ractor audit) and
      # the journals/limiters it is configured with.
      orchestrator = Agentic::PlanOrchestrator.new
      task = Agentic::Task.new(description: "solo", agent_spec: {"name" => "w", "instructions" => "w"})
      orchestrator.add_task(task, agent: ->(_t) { :ok })

      expect(orchestrator.execute_plan.status).to eq(:completed)
    end
  end
end
