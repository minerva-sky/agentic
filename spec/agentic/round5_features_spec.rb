# frozen_string_literal: true

require "spec_helper"

RSpec.describe "round 5 framework features" do
  def task_named(description)
    Agentic::Task.new(
      description: description,
      agent_spec: {"name" => "worker", "instructions" => "work"}
    )
  end

  describe "PlanOrchestrator#graph" do
    it "exposes a frozen read-only snapshot of the topology" do
      orchestrator = Agentic::PlanOrchestrator.new
      fetch = task_named("fetch")
      merge = task_named("merge")
      orchestrator.add_task(fetch, agent: ->(_t) { :ok })
      orchestrator.add_task(merge, [fetch], needs: {source: fetch}, agent: ->(_t) { :ok })

      graph = orchestrator.graph

      expect(graph[:tasks].keys).to contain_exactly(fetch.id, merge.id)
      expect(graph[:dependencies][merge.id]).to eq([fetch.id])
      expect(graph[:needs][merge.id]).to eq(source: fetch.id)
      expect(graph).to be_frozen
      expect(graph[:dependencies]).to be_frozen
      expect { graph[:dependencies][merge.id] << "x" }.to raise_error(FrozenError)
    end
  end

  describe "ValidationError#expectations" do
    let(:specification) do
      Agentic::CapabilitySpecification.new(
        name: "ship", description: "ships", version: "1.0.0",
        inputs: {
          speed: {type: "string", required: true, enum: %w[standard express]},
          quantity: {type: "number", required: true, min: 1}
        }
      )
    end

    it "carries the declared contract for each violated key" do
      validator = Agentic::CapabilityValidator.new(specification)

      expect {
        validator.validate_inputs!(speed: "teleport", quantity: 5)
      }.to raise_error(Agentic::Errors::ValidationError) { |error|
        expect(error.expectations.keys).to eq([:speed])
        expect(error.expectations[:speed][:enum]).to eq(%w[standard express])
      }
    end
  end

  describe "cross-field contract rules" do
    let(:specification) do
      Agentic::CapabilitySpecification.new(
        name: "quote", description: "quotes freight", version: "1.0.0",
        inputs: {
          speed: {type: "string", required: true, enum: %w[standard express]},
          quantity: {type: "number", required: true, min: 1}
        },
        rules: {
          "express orders are limited to 10 items" => ->(i) { i[:speed] != "express" || i[:quantity] <= 10 }
        }
      )
    end

    it "passes inputs that satisfy every rule" do
      validator = Agentic::CapabilityValidator.new(specification)

      expect { validator.validate_inputs!(speed: "express", quantity: 10) }.not_to raise_error
      expect { validator.validate_inputs!(speed: "standard", quantity: 500) }.not_to raise_error
    end

    it "reports broken rules under :base after per-key validation passes" do
      validator = Agentic::CapabilityValidator.new(specification)

      expect {
        validator.validate_inputs!(speed: "express", quantity: 11)
      }.to raise_error(Agentic::Errors::ValidationError) { |error|
        expect(error.violations[:base]).to eq(["express orders are limited to 10 items"])
      }
    end
  end

  describe "RateLimit" do
    it "bounds concurrent acquisitions across callers and records the high-water mark" do
      limit = Agentic::RateLimit.new(2)

      Sync do |task|
        8.times.map {
          task.async do
            limit.acquire { sleep(0.01) }
          end
        }.each(&:wait)
      end

      expect(limit.high_water).to eq(2)
      expect(limit.in_flight).to eq(0)
    end

    it "is accepted by LlmClient as limiter:" do
      client = Agentic::LlmClient.new(Agentic::LlmConfig.new, limiter: Agentic::RateLimit.new(1))
      expect(client).to be_a(Agentic::LlmClient)
    end
  end

  describe "jitter default" do
    it "defaults backoff_jitter on and never sleeps a negative delay" do
      orchestrator = Agentic::PlanOrchestrator.new(retry_policy: {backoff_strategy: :constant, backoff_constant: 0.01})
      slept = []
      allow(orchestrator).to receive(:sleep) { |delay| slept << delay }

      task = task_named("flaky")
      task.retry_count = 1
      5.times { orchestrator.apply_retry_backoff(task: task) }

      expect(orchestrator.retry_policy[:backoff_jitter]).to be true
      expect(slept).to all(be >= 0)
      expect(slept.uniq.size).to be > 1 # jitter actually varies the delay
    end
  end
end
