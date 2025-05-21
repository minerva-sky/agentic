# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::AgentSpecification do
  let(:agent_spec) do
    described_class.new(
      name: "ResearchAgent",
      description: "An agent that performs research",
      instructions: "Research the given topic thoroughly"
    )
  end

  describe "#initialize" do
    it "sets the name, description, and instructions" do
      expect(agent_spec.name).to eq("ResearchAgent")
      expect(agent_spec.description).to eq("An agent that performs research")
      expect(agent_spec.instructions).to eq("Research the given topic thoroughly")
    end
  end

  describe "#to_h" do
    it "returns a hash representation of the agent specification" do
      expect(agent_spec.to_h).to eq({
        "name" => "ResearchAgent",
        "description" => "An agent that performs research",
        "instructions" => "Research the given topic thoroughly"
      })
    end
  end

  describe ".from_hash" do
    let(:hash) do
      {
        "name" => "ResearchAgent",
        "description" => "An agent that performs research",
        "instructions" => "Research the given topic thoroughly"
      }
    end

    it "creates an AgentSpecification from a hash" do
      agent = described_class.from_hash(hash)
      expect(agent).to be_a(described_class)
      expect(agent.name).to eq("ResearchAgent")
      expect(agent.description).to eq("An agent that performs research")
      expect(agent.instructions).to eq("Research the given topic thoroughly")
    end
  end
end
