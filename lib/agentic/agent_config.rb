# frozen_string_literal: true

module Agentic
  # Configuration object for an Agent
  class AgentConfig
    # @return [String] The name of the agent
    attr_accessor :name

    # @return [String] The role of the agent
    attr_accessor :role

    # @return [String] The backstory or additional context for the agent
    attr_accessor :backstory

    # @return [Array<String>] The tools available to the agent
    attr_accessor :tools

    # @return [LlmConfig] The LLM configuration for the agent
    attr_accessor :llm_config

    # @return [Hash] Additional options for the agent
    attr_accessor :options

    # Initializes a new agent configuration
    # @param name [String] The name of the agent
    # @param role [String] The role of the agent
    # @param backstory [String, nil] The backstory or additional context for the agent
    # @param tools [Array<String>] The tools available to the agent
    # @param llm_config [LlmConfig, nil] The LLM configuration for the agent
    # @param options [Hash] Additional options for the agent
    def initialize(
      name:,
      role:,
      backstory: nil,
      tools: [],
      llm_config: nil,
      options: {}
    )
      @name = name
      @role = role
      @backstory = backstory
      @tools = tools
      @llm_config = llm_config || LlmConfig.new
      @options = options
    end

    # Returns a hash representation of the agent configuration
    # @return [Hash] The agent configuration as a hash
    def to_h
      {
        name: @name,
        role: @role,
        backstory: @backstory,
        tools: @tools,
        llm_config: {
          model: @llm_config.model,
          temperature: @llm_config.temperature
        },
        options: @options
      }
    end
  end
end
