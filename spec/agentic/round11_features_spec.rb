# frozen_string_literal: true

require "spec_helper"

RSpec.describe "round 11 framework features" do
  def task_named(description)
    Agentic::Task.new(description: description, agent_spec: {"name" => "w", "instructions" => "work"})
  end

  describe "prompt cancel_plan" do
    it "stops in-flight fibers and never starts queued tasks" do
      agent_runs = []
      orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 2)
      6.times do |i|
        orchestrator.add_task(task_named("job#{i}"), agent: ->(t) {
          agent_runs << t.description
          sleep(0.1)
          :ok
        })
      end

      wall = nil
      result = nil
      Sync do
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        runner = Async { result = orchestrator.execute_plan }
        Async do
          sleep(0.02)
          orchestrator.cancel_plan
        end
        runner.wait
        wall = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      end

      expect(result.status).to eq(:canceled)
      expect(wall).to be < 0.09 # not the 300ms a full run would take
      expect(agent_runs.size).to eq(2) # only the two that were mid-flight
    end

    it "can be called from inside a lifecycle hook without stopping itself" do
      orchestrator = Agentic::PlanOrchestrator.new(
        concurrency_limit: 1,
        lifecycle_hooks: {
          after_task_success: ->(task_id:, task:, result:, duration:) { orchestrator.cancel_plan }
        }
      )
      first = task_named("first")
      second = task_named("second")
      orchestrator.add_task(first, agent: ->(_t) { :ok })
      orchestrator.add_task(second, [first], agent: ->(_t) { :ok })

      result = orchestrator.execute_plan

      expect(result.status).to eq(:canceled)
      expect(orchestrator.execution_state[:completed]).to include(first.id)
    end
  end

  describe "fail-fast relation declarations" do
    it "refuses to construct a validator for a sum_lte over an undeclared field" do
      spec = Agentic::CapabilitySpecification.new(
        name: "x", description: "x", version: "1.0.0",
        inputs: {a: {type: "number"}},
        rules: {fits: {relation: :sum_lte, fields: [:a, :ghost], limit: 10}}
      )

      expect {
        Agentic::CapabilityValidator.new(spec)
      }.to raise_error(ArgumentError, /references undeclared input :ghost/)
    end

    it "refuses sum_lte over a declared non-number" do
      spec = Agentic::CapabilitySpecification.new(
        name: "x", description: "x", version: "1.0.0",
        inputs: {a: {type: "number"}, b: {type: "string"}},
        rules: {fits: {relation: :sum_lte, fields: [:a, :b], limit: 10}}
      )

      expect {
        Agentic::CapabilityValidator.new(spec)
      }.to raise_error(ArgumentError, /can only sum declared numbers; :b is not/)
    end

    it "refuses presence relations over undeclared fields (fail-open typos)" do
      spec = Agentic::CapabilitySpecification.new(
        name: "x", description: "x", version: "1.0.0",
        inputs: {express: {type: "boolean"}},
        rules: {customs: {relation: :requires, fields: [:express, :customs_kode]}}
      )

      expect {
        Agentic::CapabilityValidator.new(spec)
      }.to raise_error(ArgumentError, /undeclared input :customs_kode/)
    end
  end

  describe "RateLimit#try_acquire" do
    it "admits without blocking in windowed mode, then answers false" do
      budget = Agentic::RateLimit.new(2, per: 60)

      expect(budget.try_acquire).to be(true)
      expect(budget.try_acquire).to be(true)
      expect(budget.try_acquire).to be(false) # would have BLOCKED under acquire
    end

    it "runs the block only when admitted, in concurrency mode" do
      limit = Agentic::RateLimit.new(1)
      ran = []

      Sync do
        holder = Async { limit.acquire { sleep(0.03) } }
        sleep(0.01)
        expect(limit.try_acquire { ran << :rejected_path }).to be(false)
        holder.wait
      end
      expect(limit.try_acquire { ran << :admitted_path }).to be(true)

      expect(ran).to eq([:admitted_path])
    end
  end

  describe "typed-fields-only projection" do
    it "keeps relations over untyped fields out of draft-07 keywords but in x-agentic-rules" do
      spec = Agentic::CapabilitySpecification.new(
        name: "x", description: "x", version: "1.0.0",
        inputs: {express: {}, customs_code: {type: "string"}},
        rules: {customs: {relation: :requires, fields: [:express, :customs_code]}}
      )

      schema = spec.to_json_schema

      expect(schema).not_to have_key("dependencies")
      expect(schema["x-agentic-rules"].first["relation"]).to eq("requires")
    end
  end
end
