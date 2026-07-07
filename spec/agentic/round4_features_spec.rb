# frozen_string_literal: true

require "spec_helper"

RSpec.describe "round 4 framework features" do
  def task_named(description, payload: nil)
    Agentic::Task.new(
      description: description,
      agent_spec: {"name" => "worker", "instructions" => "work"},
      payload: payload
    )
  end

  describe "named dependencies (needs:)" do
    it "delivers dependency outputs addressable by name" do
      orchestrator = Agentic::PlanOrchestrator.new
      commits = task_named("commits")
      debt = task_named("debt")
      digest = task_named("digest")

      orchestrator.add_task(commits, agent: ->(_t) { 12 })
      orchestrator.add_task(debt, agent: ->(_t) { 3 })
      orchestrator.add_task(digest, needs: {shipped: commits, owed: debt}, agent: ->(t) {
        "shipped #{t.needs.shipped}, owed #{t.needs[:owed]}"
      })

      result = orchestrator.execute_plan

      expect(result.results[digest.id].output).to eq("shipped 12, owed 3")
    end

    it "combines needs: with positional dependencies" do
      orchestrator = Agentic::PlanOrchestrator.new
      gate = task_named("gate")
      source = task_named("source")
      sink = task_named("sink")
      order = []

      orchestrator.add_task(gate, agent: ->(_t) { order << :gate })
      orchestrator.add_task(source, agent: ->(_t) { :payload })
      orchestrator.add_task(sink, [gate], needs: {input: source}, agent: ->(t) {
        order << :sink
        t.needs.input
      })

      result = orchestrator.execute_plan

      expect(order).to eq([:gate, :sink])
      expect(result.results[sink.id].output).to eq(:payload)
    end
  end

  describe "Task#previous_output" do
    it "returns the sole dependency's output in a chain" do
      orchestrator = Agentic::PlanOrchestrator.new
      first = task_named("first")
      second = task_named("second")

      orchestrator.add_task(first, agent: ->(_t) { "whisper" })
      orchestrator.add_task(second, [first], agent: ->(t) { t.previous_output.upcase })

      result = orchestrator.execute_plan

      expect(result.results[second.id].output).to eq("WHISPER")
    end
  end

  describe "task_slot_acquired hook" do
    it "reports queue wait separately from scheduling" do
      waits = {}
      orchestrator = Agentic::PlanOrchestrator.new(
        concurrency_limit: 1,
        lifecycle_hooks: {
          task_slot_acquired: ->(task_id:, task:, waited:) { waits[task.description] = waited }
        }
      )
      a = task_named("a")
      b = task_named("b")
      orchestrator.add_task(a, agent: ->(_t) { sleep(0.05) || :ok })
      orchestrator.add_task(b, agent: ->(_t) { :ok })

      orchestrator.execute_plan

      expect(waits["a"]).to be < 0.02
      expect(waits["b"]).to be >= 0.04 # queued behind a's 50ms slot
    end
  end

  describe "retry policy consulting failure.retryable?" do
    let(:not_retryable) do
      Class.new(StandardError) {
        def retryable? = false
      }
    end

    it "does not retry when the error itself says no, even if the type list says yes" do
      stub_const("VetoedError", not_retryable)
      attempts = 0
      orchestrator = Agentic::PlanOrchestrator.new(
        retry_policy: {max_retries: 3, retryable_errors: ["VetoedError"]}
      )
      task = task_named("vetoed")
      orchestrator.add_task(task, agent: ->(_t) {
        attempts += 1
        raise VetoedError, "authentication is not going to improve"
      })

      result = orchestrator.execute_plan

      expect(attempts).to eq(1)
      expect(result.results[task.id].failed?).to be true
    end

    it "retries when the error says yes, even if the type list says no" do
      eager = Class.new(StandardError) {
        def retryable? = true
      }
      stub_const("EagerError", eager)
      attempts = 0
      orchestrator = Agentic::PlanOrchestrator.new(
        retry_policy: {max_retries: 2, retryable_errors: [], backoff_strategy: :none}
      )
      task = task_named("eager")
      orchestrator.add_task(task, agent: ->(_t) {
        attempts += 1
        raise EagerError, "try me again" if attempts < 2
        :recovered
      })

      result = orchestrator.execute_plan

      expect(attempts).to eq(2)
      expect(result.results[task.id].output).to eq(:recovered)
    end
  end

  describe "overall status of canceled plans" do
    it "reports :canceled instead of :completed when tasks were canceled" do
      orchestrator = Agentic::PlanOrchestrator.new(
        concurrency_limit: 1,
        lifecycle_hooks: {
          after_task_success: ->(task_id:, task:, result:, duration:) { orchestrator.cancel_plan }
        }
      )
      first = task_named("first")
      second = task_named("never runs")
      orchestrator.add_task(first, agent: ->(_t) { :ok })
      orchestrator.add_task(second, [first], agent: ->(_t) { :ok })

      result = orchestrator.execute_plan

      expect(result.status).to eq(:canceled)
    end
  end

  describe "contract value predicates" do
    let(:specification) do
      Agentic::CapabilitySpecification.new(
        name: "ship_order",
        description: "Ships an order",
        version: "1.0.0",
        inputs: {
          speed: {type: "string", required: true, enum: %w[standard express]},
          quantity: {type: "number", required: true, min: 1, max: 100},
          items: {type: "array", required: true, non_empty: true}
        }
      )
    end

    let(:validator) { Agentic::CapabilityValidator.new(specification) }

    it "accepts values inside the declared constraints" do
      expect {
        validator.validate_inputs!(speed: "express", quantity: 5, items: [:widget])
      }.not_to raise_error
    end

    it "rejects enum violations, out-of-range numbers, and empty arrays by name" do
      expect {
        validator.validate_inputs!(speed: "teleport", quantity: 0, items: [])
      }.to raise_error(Agentic::Errors::ValidationError) { |error|
        expect(error.violations.keys).to contain_exactly(:speed, :quantity, :items)
      }
    end
  end
end
