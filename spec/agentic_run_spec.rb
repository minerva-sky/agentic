# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Agentic.run" do
  let(:agent_spec) do
    Agentic::AgentSpecification.new(
      name: "Writer",
      description: "Writes things",
      instructions: "Write the requested content"
    )
  end

  let(:execution_plan) do
    Agentic::ExecutionPlan.new(
      [Agentic::TaskDefinition.new(description: "Write a summary", agent: agent_spec)],
      Agentic::ExpectedAnswerFormat.new(format: "text", sections: [], length: "short")
    )
  end

  let(:agent) do
    instance_double(Agentic::Agent, execute: "A fine summary")
  end

  let(:provider) do
    instance_double(Agentic::DefaultAgentProvider, get_agent_for_task: agent)
  end

  before do
    planner = instance_double(Agentic::TaskPlanner, plan: execution_plan)
    allow(Agentic::TaskPlanner).to receive(:new).and_return(planner)
    allow(Agentic::DefaultAgentProvider).to receive(:new).and_return(provider)
  end

  it "plans the goal and executes the resulting tasks in one call" do
    result = Agentic.run("Summarize the support tickets")

    expect(result).to be_a(Agentic::PlanExecutionResult)
    expect(result.successful?).to be true
    expect(result.results.values.map(&:output)).to eq(["A fine summary"])
  end

  it "passes the model override to the planner configuration" do
    Agentic.run("Summarize the support tickets", model: "gpt-4o")

    expect(Agentic::TaskPlanner).to have_received(:new) do |goal, config|
      expect(goal).to eq("Summarize the support tickets")
      expect(config.model).to eq("gpt-4o")
    end
  end

  it "respects the concurrency option" do
    orchestrator = Agentic::PlanOrchestrator.new
    allow(Agentic::PlanOrchestrator).to receive(:new).and_return(orchestrator)

    Agentic.run("Summarize the support tickets", concurrency: 2)

    expect(Agentic::PlanOrchestrator).to have_received(:new).with(concurrency_limit: 2)
  end
end
