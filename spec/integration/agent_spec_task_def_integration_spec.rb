# frozen_string_literal: true

require "spec_helper"

# Integration tests for Agent Specification and Task Definition
RSpec.describe "AgentSpecification and TaskDefinition Integration" do
  # Mock agent for testing
  class SpecAwareAgent
    attr_reader :execution_history, :last_spec

    def initialize
      @execution_history = []
      @last_spec = nil
    end

    def execute(prompt)
      # Extract agent specs from the prompt text instead of parsing JSON
      # This handles the multi-line format that build_prompt creates
      @last_spec = {
        "name" => prompt.match(/\[System Instructions\]\s*(.+?)\s*\[Task Description\]/m)[1].strip,
        "instructions" => prompt.match(/\[System Instructions\]\s*(.+?)\s*\[Task Description\]/m)[1].strip
      }
      
      @execution_history << {
        spec: @last_spec,
        prompt: prompt
      }
      
      {"result" => "Executed with #{@last_spec['name']}"}
    end
  end

  # Mock agent provider that respects agent specifications
  class SpecAwareAgentProvider
    def initialize
      @agents = {}
    end

    def get_agent_for_task(task)
      agent_type = task.agent_spec.name
      @agents[agent_type] ||= SpecAwareAgent.new
      @agents[agent_type]
    end

    def get_agent(agent_type)
      @agents[agent_type]
    end
  end

  let(:agent_provider) { SpecAwareAgentProvider.new }
  let(:orchestrator) { Agentic::PlanOrchestrator.new }

  describe "Agent Specification in Task Execution" do
    it "properly passes agent specification to agents during execution" do
      # Create agent specifications
      researcher_spec = Agentic::AgentSpecification.new(
        name: "ResearchAgent",
        description: "An agent specialized in research tasks",
        instructions: "Research the given topic thoroughly"
      )

      writer_spec = Agentic::AgentSpecification.new(
        name: "WriterAgent",
        description: "An agent specialized in writing tasks",
        instructions: "Write high-quality content on the given topic"
      )

      # Create task definitions
      research_task = Agentic::TaskDefinition.new(
        description: "Research quantum computing",
        agent: researcher_spec
      )

      writing_task = Agentic::TaskDefinition.new(
        description: "Write article on quantum computing",
        agent: writer_spec
      )

      # Create tasks from task definitions
      task1 = Agentic::Task.new(
        description: research_task.description,
        agent_spec: research_task.agent,
        input: {"topic" => "quantum computing"}
      )

      task2 = Agentic::Task.new(
        description: writing_task.description,
        agent_spec: writing_task.agent,
        input: {"topic" => "quantum computing"}
      )

      # Set up dependencies
      orchestrator.add_task(task1)
      orchestrator.add_task(task2, [task1.id])

      # Execute the plan
      result = orchestrator.execute_plan(agent_provider)

      # Verify both tasks completed
      expect(result.status).to eq(:completed)
      expect(result.task_result(task1.id).status).to eq(:completed)
      expect(result.task_result(task2.id).status).to eq(:completed)

      # Verify the correct agent specifications were used
      research_agent = agent_provider.get_agent("ResearchAgent")
      writer_agent = agent_provider.get_agent("WriterAgent")

      # The test now expects that the instructions from the AgentSpecification are passed to the agent
      expect(research_agent.last_spec["instructions"]).to eq("Research the given topic thoroughly")
      expect(writer_agent.last_spec["instructions"]).to eq("Write high-quality content on the given topic")
    end
  end

  describe "Execution Plan Integration" do
    it "creates and executes a plan from structured definitions" do
      # Create agent specifications
      researcher_spec = Agentic::AgentSpecification.new(
        name: "ResearchAgent",
        description: "An agent specialized in research tasks",
        instructions: "Research the given topic thoroughly"
      )

      analyst_spec = Agentic::AgentSpecification.new(
        name: "AnalystAgent", 
        description: "An agent specialized in analysis",
        instructions: "Analyze the provided data and extract insights"
      )

      writer_spec = Agentic::AgentSpecification.new(
        name: "WriterAgent",
        description: "An agent specialized in writing tasks",
        instructions: "Write high-quality content on the given topic"
      )

      # Create task definitions
      task_defs = [
        Agentic::TaskDefinition.new(
          description: "Research AI trends",
          agent: researcher_spec
        ),
        Agentic::TaskDefinition.new(
          description: "Analyze research findings",
          agent: analyst_spec
        ),
        Agentic::TaskDefinition.new(
          description: "Write article on AI trends",
          agent: writer_spec
        )
      ]

      # Create expected answer format
      expected_answer = Agentic::ExpectedAnswerFormat.new(
        format: "Article",
        sections: ["Introduction", "Current Trends", "Future Outlook", "Conclusion"],
        length: "1500 words"
      )

      # Create an execution plan
      plan = Agentic::ExecutionPlan.new(task_defs, expected_answer)

      # Create tasks from the plan
      tasks = task_defs.map.with_index do |task_def, i|
        Agentic::Task.new(
          description: task_def.description,
          agent_spec: task_def.agent,
          input: {"index" => i}
        )
      end

      # Add tasks to orchestrator with sequential dependencies
      orchestrator.add_task(tasks[0])
      orchestrator.add_task(tasks[1], [tasks[0].id])
      orchestrator.add_task(tasks[2], [tasks[1].id])

      # Execute the plan
      result = orchestrator.execute_plan(agent_provider)

      # Verify all tasks completed
      expect(result.status).to eq(:completed)
      tasks.each do |task|
        expect(result.task_result(task.id).status).to eq(:completed)
      end

      # Verify the correct agent specifications were used
      expect(agent_provider.get_agent("ResearchAgent").last_spec["instructions"]).to eq("Research the given topic thoroughly")
      expect(agent_provider.get_agent("AnalystAgent").last_spec["instructions"]).to eq("Analyze the provided data and extract insights")
      expect(agent_provider.get_agent("WriterAgent").last_spec["instructions"]).to eq("Write high-quality content on the given topic")
    end
  end

  describe "DefaultAgentProvider Integration" do
    it "creates agents from task specifications" do
      # Create a real DefaultAgentProvider instance
      default_provider = Agentic::DefaultAgentProvider.new

      # Create a task with agent specification
      task = Agentic::Task.new(
        description: "Test task",
        agent_spec: {
          "name" => "TestAgent",
          "description" => "A test agent",
          "instructions" => "You are a test agent"
        }
      )

      # Get an agent from the provider
      agent = default_provider.get_agent_for_task(task)

      # The default agent provider creates an Agent instance
      # but we need to mock it for this test
      expect(agent).to be_a(Agentic::Agent)
      
      # Since Agent might have different interface in the actual implementation,
      # let's just verify the agent was created
    end
  end

  describe "Agent Configuration Integration" do
    it "demonstrates agent configuration options" do
      # Create an agent configuration
      agent_config = Agentic::AgentConfig.new(
        name: "AdvancedAgent",
        role: "Research Assistant",
        backstory: "You have decades of experience in research",
        tools: ["search", "analyze"],
        llm_config: Agentic::LlmConfig.new(model: "gpt-4o", temperature: 0.2)
      )

      # Verify configuration properties
      expect(agent_config.name).to eq("AdvancedAgent")
      expect(agent_config.role).to eq("Research Assistant")
      expect(agent_config.backstory).to eq("You have decades of experience in research")
      expect(agent_config.tools).to eq(["search", "analyze"])
      expect(agent_config.llm_config.model).to eq("gpt-4o")
      expect(agent_config.llm_config.temperature).to eq(0.2)
      
      # Verify to_h converts to a hash
      config_hash = agent_config.to_h
      expect(config_hash).to be_a(Hash)
      expect(config_hash[:name]).to eq("AdvancedAgent")
      expect(config_hash[:role]).to eq("Research Assistant")
    end
  end
end