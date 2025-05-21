# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::TaskPlanner do
  let(:goal) { "Generate a market research report on the latest trends in AI technology." }
  let(:llm_config) { Agentic::LlmConfig.new }
  let(:planner) { described_class.new(goal, llm_config) }

  describe "#initialize" do
    it "sets the goal and llm_config" do
      expect(planner.goal).to eq(goal)
      expect(planner.llm_config).to eq(llm_config)
    end

    it "initializes tasks and expected_answer as empty" do
      expect(planner.tasks).to be_empty
      expect(planner.expected_answer).to be_a(Agentic::ExpectedAnswerFormat)
      expect(planner.expected_answer.format).to eq("Undetermined")
      expect(planner.expected_answer.sections).to be_empty
      expect(planner.expected_answer.length).to eq("Undetermined")
    end
  end
end