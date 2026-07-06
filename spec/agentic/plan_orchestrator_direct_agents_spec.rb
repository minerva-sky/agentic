# frozen_string_literal: true

require "spec_helper"
require "timeout"

RSpec.describe Agentic::PlanOrchestrator do
  def task_named(description, payload: nil)
    Agentic::Task.new(
      description: description,
      agent_spec: {"name" => "worker", "instructions" => "work"},
      input: {},
      payload: payload
    )
  end

  describe "per-task agents" do
    it "executes a task with a directly attached callable that receives the task" do
      orchestrator = described_class.new
      task = task_named("double it", payload: 21)

      orchestrator.add_task(task, agent: ->(t) { t.payload * 2 })
      result = orchestrator.execute_plan

      expect(result.status).to eq(:completed)
      expect(result.results[task.id].output).to eq(42)
    end

    it "executes a task with a directly attached agent object" do
      agent = Class.new {
        def execute(_prompt) = "from agent object"
      }.new
      orchestrator = described_class.new
      task = task_named("run it")

      orchestrator.add_task(task, agent: agent)
      result = orchestrator.execute_plan

      expect(result.results[task.id].output).to eq("from agent object")
    end

    it "accepts a block as a plan-wide agent factory" do
      agent = Class.new {
        def execute(_prompt) = "built by factory"
      }.new
      orchestrator = described_class.new
      task = task_named("factory task")
      orchestrator.add_task(task)

      seen = nil
      result = orchestrator.execute_plan do |t|
        seen = t
        agent
      end

      expect(seen).to eq(task)
      expect(result.results[task.id].output).to eq("built by factory")
    end

    it "fails fast when no agent source exists" do
      orchestrator = described_class.new
      orchestrator.add_task(task_named("orphan"))

      expect { orchestrator.execute_plan }.to raise_error(ArgumentError, /no agent/i)
    end

    it "prefers the per-task agent over the plan-wide provider" do
      orchestrator = described_class.new
      task = task_named("mine")
      orchestrator.add_task(task, agent: ->(_t) { "per-task wins" })

      result = orchestrator.execute_plan { |_t| raise "factory should not be consulted" }

      expect(result.results[task.id].output).to eq("per-task wins")
    end
  end

  describe "dependency output piping" do
    it "pipes a dependency's output into the dependent task" do
      orchestrator = described_class.new
      fetch = task_named("fetch")
      transform = task_named("transform")

      orchestrator.add_task(fetch, agent: ->(_t) { {"value" => 10} })
      orchestrator.add_task(transform, [fetch], agent: ->(t) { t.output_of(fetch)["value"] * 3 })

      result = orchestrator.execute_plan

      expect(result.results[transform.id].output).to eq(30)
    end

    it "fans in outputs from multiple dependencies" do
      orchestrator = described_class.new
      east = task_named("east")
      west = task_named("west")
      merge = task_named("merge")

      orchestrator.add_task(east, agent: ->(_t) { 1 })
      orchestrator.add_task(west, agent: ->(_t) { 2 })
      orchestrator.add_task(merge, [east, west], agent: ->(t) {
        t.dependency_outputs.values.sum
      })

      result = orchestrator.execute_plan

      expect(result.results[merge.id].output).to eq(3)
    end

    it "does not deadlock when slot-holders schedule dependents at a tight concurrency limit" do
      # Regression: a diamond graph at concurrency 2 used to deadlock when
      # both slot-holding tasks finished and each blocked spawning its
      # dependents while waiting for the other's slot
      orchestrator = described_class.new(concurrency_limit: 2)
      sources = 3.times.map { |i| task_named("source-#{i}") }
      joins = 2.times.map { |i| task_named("join-#{i}") }
      final = task_named("final")

      sources.each { |t| orchestrator.add_task(t, agent: ->(_t) { sleep(0.01) || :ok }) }
      orchestrator.add_task(joins[0], sources.first(2), agent: ->(_t) { sleep(0.01) || :ok })
      orchestrator.add_task(joins[1], sources.last(2), agent: ->(_t) { sleep(0.01) || :ok })
      orchestrator.add_task(final, joins, agent: ->(_t) { :done })

      result = nil
      Timeout.timeout(5) { result = orchestrator.execute_plan }

      expect(result.status).to eq(:completed)
      expect(result.results[final.id].output).to eq(:done)
    end

    it "accepts Task objects as dependencies" do
      orchestrator = described_class.new
      first = task_named("first")
      second = task_named("second")
      order = []

      orchestrator.add_task(first, agent: ->(_t) { order << :first })
      orchestrator.add_task(second, [first], agent: ->(_t) { order << :second })
      orchestrator.execute_plan

      expect(order).to eq([:first, :second])
    end
  end
end

RSpec.describe Agentic::TaskDefinition do
  describe "#to_task" do
    it "builds an executable task carrying input and payload" do
      definition = described_class.new(
        description: "Summarize",
        agent: Agentic::AgentSpecification.new(name: "S", description: "d", instructions: "i")
      )

      task = definition.to_task(input: {topic: "ruby"}, payload: :domain_thing)

      expect(task).to be_a(Agentic::Task)
      expect(task.description).to eq("Summarize")
      expect(task.input).to eq(topic: "ruby")
      expect(task.payload).to eq(:domain_thing)
    end
  end
end
