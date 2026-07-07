# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe "round 8 framework features" do
  def task_named(description)
    Agentic::Task.new(
      description: description,
      agent_spec: {"name" => "worker", "instructions" => "work"}
    )
  end

  describe "stats[:roots] and stats[:leaves]" do
    it "identifies tasks with no dependencies and tasks nothing depends on" do
      orchestrator = Agentic::PlanOrchestrator.new
      root_a = task_named("root-a")
      root_b = task_named("root-b")
      middle = task_named("middle")
      leaf = task_named("leaf")

      orchestrator.add_task(root_a, agent: ->(_t) { :ok })
      orchestrator.add_task(root_b, agent: ->(_t) { :ok })
      orchestrator.add_task(middle, [root_a, root_b], agent: ->(_t) { :ok })
      orchestrator.add_task(leaf, [middle], agent: ->(_t) { :ok })

      stats = orchestrator.graph[:stats]

      expect(stats[:roots]).to contain_exactly(root_a.id, root_b.id)
      expect(stats[:leaves]).to eq([leaf.id])
    end
  end

  describe "journal duration percentiles" do
    it "computes percentiles over accumulated samples across runs" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "history.jsonl")
        journal = Agentic::ExecutionJournal.new(path: path)

        [0.01, 0.02, 0.03, 0.04, 0.10].each_with_index do |duration, i|
          journal.record(:task_succeeded, task_id: "run#{i}", description: "nightly", duration: duration, output: nil)
        end

        state = Agentic::ExecutionJournal.replay(path: path)

        expect(state.duration_samples["nightly"].size).to eq(5)
        expect(state.duration_percentile("nightly", 50)).to be_within(0.001).of(0.03)
        expect(state.duration_percentile("nightly", 100)).to eq(0.10)
        expect(state.duration_percentile("nightly", 50, last: 2)).to be_within(0.001).of(0.07)
        expect(state.duration_percentile("unknown", 50)).to be_nil
      end
    end
  end

  describe "x-agentic-rules in the schema export" do
    it "emits structured rule metadata and omits prose lambdas" do
      spec = Agentic::CapabilitySpecification.new(
        name: "quote", description: "quotes", version: "1.0.0",
        inputs: {mode: {type: "string", required: true}},
        rules: {
          :air_limit => {message: "air max 500kg", fields: [:mode], check: ->(_i) { true }},
          "prose rule" => ->(_i) { true }
        }
      )

      schema = spec.to_json_schema

      expect(schema["x-agentic-rules"]).to eq([
        {"rule" => "air_limit", "message" => "air max 500kg", "fields" => ["mode"]}
      ])
      expect(spec.to_json_schema(:outputs)).not_to have_key("x-agentic-rules")
    end
  end
end
