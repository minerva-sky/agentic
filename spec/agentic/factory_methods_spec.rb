# frozen_string_literal: true

require "rspec"
require_relative "../support/mock_agent"

RSpec.describe Agentic::FactoryMethods do
  describe ".build" do
    it "configures and builds an agent with default values" do
      agent = Agentic::MockAgent.build

      expect(agent.role).to eq("Mock")
      expect(agent.goal).to eq("Default Goal")
      expect(agent.backstory).to eq("Default Backstory")
    end

    it "configures and builds an agent with custom values" do
      agent = Agentic::MockAgent.build do |builder|
        builder.role = "Custom Role"
        builder.goal = "Custom Goal"
        builder.backstory = "Custom Backstory"
      end

      expect(agent.role).to eq("Custom Role")
      expect(agent.goal).to eq("Custom Goal")
      expect(agent.backstory).to eq("Custom Backstory")
    end
  end

  describe "inheritance" do
    it "gives subclasses their parent's configurable attributes and assembly" do
      subclass = Class.new(Agentic::MockAgent)

      agent = subclass.build do |builder|
        builder.role = "Subclassed Role"
      end

      expect(agent.role).to eq("Subclassed Role")
      expect(agent.goal).to eq("Default Goal")
      expect(agent.backstory).to eq("Default Backstory")
    end

    it "keeps subclass additions out of the parent" do
      subclass = Class.new(Agentic::MockAgent) do
        configurable :specialty
      end

      agent = subclass.build { |builder| builder.specialty = "Testing" }

      expect(agent.specialty).to eq("Testing")
      expect(Agentic::MockAgent.build).not_to respond_to(:specialty)
    end
  end
end
