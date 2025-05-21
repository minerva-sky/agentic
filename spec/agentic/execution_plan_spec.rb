# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::ExecutionPlan do
  let(:agent_spec) do
    Agentic::AgentSpecification.new(
      name: "Researcher",
      description: "Research expert",
      instructions: "Search latest AI trends"
    )
  end

  let(:task_definition) do
    Agentic::TaskDefinition.new(
      description: "Research AI trends",
      agent: agent_spec
    )
  end

  let(:tasks) do
    [task_definition]
  end

  let(:expected_answer) do
    Agentic::ExpectedAnswerFormat.new(
      format: "PDF",
      sections: ["Summary", "Trends"],
      length: "10 pages"
    )
  end

  let(:execution_plan) { described_class.new(tasks, expected_answer) }

  describe "#initialize" do
    it "sets the tasks and expected_answer" do
      expect(execution_plan.tasks).to eq(tasks)
      expect(execution_plan.expected_answer).to eq(expected_answer)
    end
  end

  describe "#to_h" do
    it "returns a hash representation of the execution plan" do
      hash = execution_plan.to_h
      expect(hash).to be_a(Hash)
      expect(hash[:tasks]).to be_an(Array)
      expect(hash[:tasks].first).to eq(task_definition.to_h)
      expect(hash[:expected_answer]).to eq(expected_answer.to_h)
    end
  end

  describe "#to_s" do
    it "returns a formatted string representation of the execution plan" do
      string = execution_plan.to_s
      expect(string).to include("Research AI trends")
      expect(string).to include("Format: PDF")
      expect(string).to include("Sections: Summary, Trends")
      expect(string).to include("Length: 10 pages")
    end
  end
end
