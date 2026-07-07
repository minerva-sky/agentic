# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe "round 7 framework features" do
  def task_named(description)
    Agentic::Task.new(
      description: description,
      agent_spec: {"name" => "worker", "instructions" => "work"}
    )
  end

  describe "RateLimit composition" do
    it "enforces both a window and a ceiling at once" do
      quota = Agentic::RateLimit.new(4, per: 0.1)
      pool = Agentic::RateLimit.new(2)
      limit = quota.and(pool)

      Sync do
        8.times.map { Async { limit.acquire { sleep(0.01) } } }.each(&:wait)
      end

      expect(pool.high_water).to eq(2) # the ceiling held
      expect(quota.high_water).to be <= 4
    end

    it "flattens nested composition" do
      a = Agentic::RateLimit.new(1)
      b = Agentic::RateLimit.new(2)
      c = Agentic::RateLimit.new(3)

      expect(a.and(b).and(c).limits).to eq([a, b, c])
    end
  end

  describe "graph[:stats]" do
    it "reports per-task depth, max depth, and max fan-in" do
      orchestrator = Agentic::PlanOrchestrator.new
      roots = 3.times.map { |i| task_named("root-#{i}") }
      join = task_named("join")
      tail = task_named("tail")

      roots.each { |t| orchestrator.add_task(t, agent: ->(_t) { :ok }) }
      orchestrator.add_task(join, roots, agent: ->(_t) { :ok })
      orchestrator.add_task(tail, [join], agent: ->(_t) { :ok })

      stats = orchestrator.graph[:stats]

      expect(stats[:depth][roots.first.id]).to eq(1)
      expect(stats[:depth][join.id]).to eq(2)
      expect(stats[:depth][tail.id]).to eq(3)
      expect(stats[:max_depth]).to eq(3)
      expect(stats[:max_fan_in]).to eq(3)
    end
  end

  describe "journal durations" do
    it "replays task durations keyed by description" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "durations.jsonl")
        journal = Agentic::ExecutionJournal.new(path: path)

        orchestrator = Agentic::PlanOrchestrator.new(lifecycle_hooks: journal.lifecycle_hooks)
        task = task_named("timed-work")
        orchestrator.add_task(task, agent: ->(_t) { sleep(0.02) || :ok })
        orchestrator.execute_plan

        state = Agentic::ExecutionJournal.replay(path: path)

        expect(state.durations).to have_key("timed-work")
        expect(state.durations["timed-work"]).to be >= 0.015
      end
    end
  end

  describe "retry policy rng injection" do
    it "draws jitter from the injected rng, making timing reproducible" do
      draws = []
      fake_rng = Class.new {
        def initialize(draws) = @draws = draws

        def rand(range)
          @draws << range
          (range.begin + range.end) / 2.0
        end
      }.new(draws)

      orchestrator = Agentic::PlanOrchestrator.new(
        retry_policy: {backoff_strategy: :constant, backoff_constant: 1.0, backoff_jitter: :full, rng: fake_rng}
      )
      allow(orchestrator).to receive(:sleep)

      task = task_named("flaky")
      task.retry_count = 1
      orchestrator.apply_retry_backoff(task: task)

      expect(draws).to eq([0.0..1.0])
      expect(orchestrator).to have_received(:sleep).with(0.5)
    end
  end

  describe "CapabilitySpecification#to_json_schema" do
    let(:specification) do
      Agentic::CapabilitySpecification.new(
        name: "ship", description: "ships", version: "1.0.0",
        inputs: {
          speed: {type: "string", required: true, enum: %w[standard express], description: "Shipping tier"},
          quantity: {type: "number", required: true, min: 1, max: 100},
          items: {type: "array", non_empty: true},
          note: {type: "string"}
        },
        outputs: {tracking: {type: "string", required: true}}
      )
    end

    it "emits draft-07 JSON Schema for inputs" do
      schema = specification.to_json_schema

      expect(schema["required"]).to contain_exactly("speed", "quantity")
      expect(schema["properties"]["speed"]).to eq(
        "type" => "string", "description" => "Shipping tier", "enum" => %w[standard express]
      )
      expect(schema["properties"]["quantity"]).to include("minimum" => 1, "maximum" => 100)
      expect(schema["properties"]["items"]).to include("minItems" => 1)
      expect(schema["properties"]["note"]).to eq("type" => "string")
    end

    it "emits the outputs side on request" do
      schema = specification.to_json_schema(:outputs)

      expect(schema["title"]).to eq("ship outputs")
      expect(schema["required"]).to eq(["tracking"])
    end
  end
end
