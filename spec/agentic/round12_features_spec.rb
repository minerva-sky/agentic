# frozen_string_literal: true

require "spec_helper"

RSpec.describe "round 12 framework features" do
  def task_named(description)
    Agentic::Task.new(description: description, agent_spec: {"name" => "w", "instructions" => "work"})
  end

  describe "remove_task" do
    it "removes a pending leaf and its bookkeeping" do
      orchestrator = Agentic::PlanOrchestrator.new
      root = task_named("root")
      leaf = task_named("leaf")
      orchestrator.add_task(root, agent: ->(_t) { :ok })
      orchestrator.add_task(leaf, [root], agent: ->(_t) { :ok })

      orchestrator.remove_task(leaf)
      graph = orchestrator.graph

      expect(graph[:tasks].keys).to eq([root.id])
      expect(graph[:stats][:leaves]).to eq([root.id])
      expect(orchestrator.execution_state[:pending]).not_to include(leaf.id)
    end

    it "refuses to orphan dependents, naming them" do
      orchestrator = Agentic::PlanOrchestrator.new
      root = task_named("root")
      leaf = task_named("leaf")
      orchestrator.add_task(root)
      orchestrator.add_task(leaf, [root])

      expect {
        orchestrator.remove_task(root)
      }.to raise_error(ArgumentError, /cannot remove root: leaf depend\(s\) on it/)
    end
  end

  describe "rewire_task" do
    it "replaces dependencies and labels in place" do
      orchestrator = Agentic::PlanOrchestrator.new
      ingest = task_named("ingest")
      prices = task_named("prices")
      merge = task_named("merge")
      orchestrator.add_task(ingest)
      orchestrator.add_task(prices) # accidental second root
      orchestrator.add_task(merge, [ingest, prices])

      orchestrator.rewire_task(prices, [ingest])
      orchestrator.rewire_task(merge, needs: {base: ingest, prices: prices})

      graph = orchestrator.graph
      expect(graph[:stats][:roots]).to eq([ingest.id])
      labels = graph[:edges].select { |e| e[:to] == merge.id }.map { |e| e[:label] }
      expect(labels).to contain_exactly(:base, :prices)
    end

    it "refuses wiring to tasks outside the plan" do
      orchestrator = Agentic::PlanOrchestrator.new
      lone = task_named("lone")
      orchestrator.add_task(lone)

      expect {
        orchestrator.rewire_task(lone, ["ghost-id"])
      }.to raise_error(ArgumentError, /unknown task\(s\) ghost-id/)
    end

    it "executes with the rewired shape" do
      orchestrator = Agentic::PlanOrchestrator.new
      first = task_named("first")
      second = task_named("second")
      orchestrator.add_task(first, agent: ->(_t) { "from-first" })
      orchestrator.add_task(second, agent: ->(t) { t.needs[:input] || "unwired" })

      orchestrator.rewire_task(second, needs: {input: first})
      result = orchestrator.execute_plan

      expect(result.task_result(second.id).output).to eq("from-first")
    end
  end

  describe "thread-safe windowed bookkeeping" do
    it "never over-admits under contending threads" do
      limit = Agentic::RateLimit.new(50, per: 60)

      admitted = 8.times.map {
        Thread.new { 500.times.count { limit.try_acquire } }
      }.sum(&:value)

      expect(admitted).to eq(50)
    end

    it "keeps blocking acquire correct under the mutex" do
      limit = Agentic::RateLimit.new(3, per: 0.1)
      stamps = []

      Sync do
        6.times.map {
          Async do
            limit.acquire { stamps << Process.clock_gettime(Process::CLOCK_MONOTONIC) }
          end
        }.each(&:wait)
      end

      expect(stamps.size).to eq(6)
      expect(stamps.sort[3] - stamps.min).to be >= 0.09
    end
  end
end
