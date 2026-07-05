# frozen_string_literal: true

module Agentic
  # Default implementation of an agent provider for use in the CLI
  # This provider creates agents based on agent specs in tasks
  class DefaultAgentProvider
    # Initialize with optional LLM configuration
    # @param llm_config [LlmConfig, nil] Configuration for the LLM client
    def initialize(llm_config = nil)
      @llm_config = llm_config || LlmConfig.new
    end

    # Creates and returns an agent for a task
    # @param task [Task] The task that needs an agent
    # @return [Agent] The agent created for the task
    def get_agent_for_task(task)
      agent_spec = task.agent_spec

      # Create LLM client for this agent
      llm_client = LlmClient.new(@llm_config)

      # Create a new agent using the factory methods
      Agent.build do |a|
        a.name = agent_spec.name
        a.role = agent_spec.name # Use name as role for simplicity
        a.purpose = agent_spec.description
        a.instructions = agent_spec.instructions
        a.llm_client = llm_client
      end
    end
  end
end
