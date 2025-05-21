# frozen_string_literal: true

module Agentic
  # Value object representing a task definition
  class TaskDefinition
    # @return [String] A description of the task
    attr_reader :description

    # @return [AgentSpecification] The agent specification for this task
    attr_reader :agent

    # Initializes a new task definition
    # @param description [String] A description of the task
    # @param agent [AgentSpecification] The agent specification for this task
    def initialize(description:, agent:)
      @description = description
      @agent = agent
    end

    # Returns a serializable representation of the task definition
    # @return [Hash] The task definition as a hash
    def to_h
      {
        "description" => @description,
        "agent" => @agent.to_h
      }
    end

    # Creates a TaskDefinition from a hash
    # @param hash [Hash] The hash representation
    # @return [TaskDefinition] A new task definition
    def self.from_hash(hash)
      new(
        description: hash["description"],
        agent: AgentSpecification.from_hash(hash["agent"])
      )
    end
  end
end
