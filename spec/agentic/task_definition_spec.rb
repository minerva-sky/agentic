# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::TaskDefinition do
  let(:agent) do
    Agentic::AgentSpecification.new(
      name: "ResearchAgent",
      description: "An agent that performs research",
      instructions: "Research the given topic thoroughly"
    )
  end

  let(:task_definition) do
    described_class.new(
      description: "Research AI trends",
      agent: agent
    )
  end

  describe "#initialize" do
    it "sets the description and agent" do
      expect(task_definition.description).to eq("Research AI trends")
      expect(task_definition.agent).to eq(agent)
    end
  end

  describe "#to_h" do
    it "returns a hash representation of the task definition" do
      expect(task_definition.to_h).to eq({
        "description" => "Research AI trends",
        "agent" => {
          "name" => "ResearchAgent",
          "description" => "An agent that performs research",
          "instructions" => "Research the given topic thoroughly"
        }
      })
    end
  end

  describe ".from_hash" do
    let(:hash) do
      {
        "description" => "Research AI trends",
        "agent" => {
          "name" => "ResearchAgent",
          "description" => "An agent that performs research",
          "instructions" => "Research the given topic thoroughly"
        }
      }
    end

    it "creates a TaskDefinition from a hash" do
      task = described_class.from_hash(hash)
      expect(task).to be_a(described_class)
      expect(task.description).to eq("Research AI trends")
      expect(task.agent).to be_a(Agentic::AgentSpecification)
      expect(task.agent.name).to eq("ResearchAgent")
      expect(task.agent.description).to eq("An agent that performs research")
      expect(task.agent.instructions).to eq("Research the given topic thoroughly")
    end
  end
end
