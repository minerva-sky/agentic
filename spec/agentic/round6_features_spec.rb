# frozen_string_literal: true

require "spec_helper"

RSpec.describe "round 6 framework features" do
  def task_named(description)
    Agentic::Task.new(
      description: description,
      agent_spec: {"name" => "worker", "instructions" => "work"}
    )
  end

  describe "graph[:order] and graph[:edges]" do
    it "returns task ids topologically sorted regardless of insertion order" do
      orchestrator = Agentic::PlanOrchestrator.new
      first = task_named("first")
      middle = task_named("middle")
      last = task_named("last")

      # Deliberately inserted backwards
      orchestrator.add_task(last, [middle], agent: ->(_t) { :ok })
      orchestrator.add_task(middle, [first], agent: ->(_t) { :ok })
      orchestrator.add_task(first, agent: ->(_t) { :ok })

      expect(orchestrator.graph[:order]).to eq([first.id, middle.id, last.id])
    end

    it "merges positional and named dependencies into labeled edges" do
      orchestrator = Agentic::PlanOrchestrator.new
      gate = task_named("gate")
      source = task_named("source")
      sink = task_named("sink")

      orchestrator.add_task(gate, agent: ->(_t) { :ok })
      orchestrator.add_task(source, agent: ->(_t) { :ok })
      orchestrator.add_task(sink, [gate], needs: {input: source}, agent: ->(_t) { :ok })

      edges = orchestrator.graph[:edges]

      expect(edges).to contain_exactly(
        {from: gate.id, to: sink.id, label: nil},
        {from: source.id, to: sink.id, label: :input}
      )
      expect(edges).to be_frozen
    end

    it "appends cycle members after the sorted portion instead of dropping them" do
      orchestrator = Agentic::PlanOrchestrator.new
      a = task_named("a")
      b = task_named("b")
      free = task_named("free")

      orchestrator.add_task(a, [b], agent: ->(_t) { :ok })
      orchestrator.add_task(b, [a], agent: ->(_t) { :ok })
      orchestrator.add_task(free, agent: ->(_t) { :ok })

      order = orchestrator.graph[:order]

      expect(order.first).to eq(free.id)
      expect(order).to contain_exactly(free.id, a.id, b.id)
    end
  end

  describe "structured rules" do
    let(:specification) do
      Agentic::CapabilitySpecification.new(
        name: "quote", description: "quotes", version: "1.0.0",
        inputs: {
          mode: {type: "string", required: true},
          weight: {type: "number", required: true}
        },
        rules: {
          :air_weight_limit => {
            message: "air freight is limited to 500kg",
            fields: [:mode, :weight],
            check: ->(i) { i[:mode] != "air" || i[:weight] <= 500 }
          },
          "prose-style rules still work" => ->(i) { i[:weight] >= 1 }
        }
      )
    end

    it "reports structured violations with rule id, message, and fields" do
      validator = Agentic::CapabilityValidator.new(specification)

      expect {
        validator.validate_inputs!(mode: "air", weight: 900)
      }.to raise_error(Agentic::Errors::ValidationError) { |error|
        expect(error.rule_violations).to eq([
          {rule: :air_weight_limit, message: "air freight is limited to 500kg", fields: [:mode, :weight]}
        ])
        expect(error.violations[:base]).to eq(["air freight is limited to 500kg"])
      }
    end

    it "keeps prose rules working alongside structured ones" do
      validator = Agentic::CapabilityValidator.new(specification)

      expect {
        validator.validate_inputs!(mode: "sea", weight: 0)
      }.to raise_error(Agentic::Errors::ValidationError) { |error|
        expect(error.rule_violations).to eq([
          {rule: "prose-style rules still work", message: "prose-style rules still work", fields: []}
        ])
      }
    end
  end

  describe "full jitter" do
    it "draws delays uniformly from [0, delay]" do
      orchestrator = Agentic::PlanOrchestrator.new(
        retry_policy: {backoff_strategy: :constant, backoff_constant: 1.0, backoff_jitter: :full}
      )
      slept = []
      allow(orchestrator).to receive(:sleep) { |delay| slept << delay }

      task = task_named("flaky")
      task.retry_count = 1
      50.times { orchestrator.apply_retry_backoff(task: task) }

      expect(slept).to all(be_between(0.0, 1.0))
      expect(slept.count { |d| d < 0.5 }).to be > 5 # full jitter reaches low values
    end
  end

  describe "windowed RateLimit" do
    it "admits at most ceiling acquisitions per rolling window" do
      limit = Agentic::RateLimit.new(3, per: 0.1)
      stamps = []

      Sync do
        6.times.map {
          Async do
            limit.acquire { stamps << Process.clock_gettime(Process::CLOCK_MONOTONIC) }
          end
        }.each(&:wait)
      end

      windows = stamps.sort
      # The 4th acquisition must start at least one window after the 1st
      expect(windows[3] - windows[0]).to be >= 0.09
      expect(stamps.size).to eq(6)
    end

    it "keeps concurrency mode unchanged when per: is omitted" do
      limit = Agentic::RateLimit.new(2)

      Sync do
        6.times.map { Async { limit.acquire { sleep(0.01) } } }.each(&:wait)
      end

      expect(limit.high_water).to eq(2)
    end
  end
end
