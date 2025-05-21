# frozen_string_literal: true

module Agentic
  # Default implementation of an agent provider for use in the CLI
  # This provider creates agents based on agent specs in tasks
  class DefaultAgentProvider
    # Creates and returns an agent for a task
    # @param task [Task] The task that needs an agent
    # @return [Agent] The agent created for the task
    def get_agent_for_task(task)
      agent_spec = task.agent_spec

      # Create a new agent using the factory methods
      Agent.new do |a|
        a.name = agent_spec["name"]
        a.role = agent_spec["name"] # Use name as role for simplicity
        a.instructions = agent_spec["instructions"]
      end
    end
  end
end
