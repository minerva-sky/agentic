# frozen_string_literal: true

module Agentic
  # Value object representing requirements for an agent
  class AgentSpecification
    # @return [String] The name of the agent
    attr_reader :name

    # @return [String] A description of the agent
    attr_reader :description

    # @return [String] Instructions for the agent
    attr_reader :instructions

    # Initializes a new agent specification
    # @param name [String] The name of the agent
    # @param description [String] A description of the agent
    # @param instructions [String] Instructions for the agent
    def initialize(name:, description:, instructions:)
      @name = name
      @description = description
      @instructions = instructions
    end

    # Returns a serializable representation of the agent specification
    # @return [Hash] The agent specification as a hash
    def to_h
      {
        "name" => @name,
        "description" => @description,
        "instructions" => @instructions
      }
    end

    # Creates an AgentSpecification from a hash
    # @param hash [Hash] The hash representation
    # @return [AgentSpecification] A new agent specification
    def self.from_hash(hash)
      new(
        name: hash["name"],
        description: hash["description"],
        instructions: hash["instructions"]
      )
    end
  end
end
