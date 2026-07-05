# frozen_string_literal: true

module Agentic
  class Agent
    include FactoryMethods

    configurable :id, :name, :role, :purpose, :backstory, :instructions, :tools, :capabilities, :llm_client

    # Initialize with default values
    def initialize
      @capabilities = {}
      @tools = Set.new
      @llm_client = nil
    end

    # Executes a task using this agent
    # @param task [String, Task] The task to execute, either a task object or a prompt
    # @return [Object] The result of the task execution
    def execute(task)
      if task.is_a?(String)
        # Simple string prompt
        execute_prompt(task)
      else
        # Task object
        task.perform(self)
      end
    end

    # Executes a prompt with structured output schema
    #
    # The schema is a promise this method keeps: execution goes through the
    # LLM client, which enforces structured output. An agent that cannot
    # honor the schema says so instead of silently returning free text.
    #
    # @param prompt [String] The prompt to execute
    # @param schema [Agentic::StructuredOutputs::Schema] The output schema
    # @return [Object] The structured response
    # @raise [Errors::SchemaNotSupportedError] when only capability-based
    #   execution is available, which cannot enforce a schema
    # @raise [Errors::AgentNotConfiguredError] when no execution path exists
    def execute_with_schema(prompt, schema)
      if @llm_client
        response = @llm_client.complete(build_messages(prompt), output_schema: schema)
        if response.successful?
          response.content
        else
          raise Errors::LlmError.new("LLM execution failed: #{response.error.message}", context: {prompt: prompt})
        end
      elsif has_capability?("text_generation")
        raise Errors::SchemaNotSupportedError,
          "A structured-output schema was requested, but this agent only has " \
          "the text_generation capability, which cannot enforce schemas. " \
          "Configure an llm_client, or call #execute for free-form output."
      else
        raise Errors::AgentNotConfiguredError
      end
    end

    # Adds a capability to the agent
    # @param capability_name [String] The name of the capability
    # @param version [String, nil] The version of the capability, or nil for latest
    # @return [Boolean] True if the capability was added successfully
    def add_capability(capability_name, version = nil)
      # Get the capability from the registry
      registry = AgentCapabilityRegistry.instance
      capability = registry.get(capability_name, version)
      raise Errors::CapabilityNotFoundError.new(capability_name, context: "not registered") unless capability

      # Get the provider
      provider = registry.get_provider(capability_name, version)
      raise Errors::CapabilityNotFoundError.new(capability_name, context: "no provider registered") unless provider

      # Add to the agent's capabilities
      @capabilities[capability_name] = {
        specification: capability,
        provider: provider
      }

      # Also add to tools for backward compatibility
      @tools.add(capability_name.to_sym)

      true
    end

    # Checks if the agent has a capability
    # @param capability_name [String] The name of the capability
    # @return [Boolean] True if the agent has the capability
    def has_capability?(capability_name)
      @capabilities.key?(capability_name)
    end

    # Gets the specification for a capability
    # @param capability_name [String] The name of the capability
    # @return [CapabilitySpecification, nil] The capability specification or nil if not found
    def capability_specification(capability_name)
      return nil unless @capabilities[capability_name]
      @capabilities[capability_name][:specification]
    end

    # Executes a capability
    # @param capability_name [String] The name of the capability
    # @param inputs [Hash] The inputs for the capability
    # @return [Hash] The outputs from the capability
    def execute_capability(capability_name, inputs = {})
      unless @capabilities.key?(capability_name)
        raise Errors::CapabilityNotFoundError.new(capability_name, context: "not added to this agent")
      end

      # Get the provider
      provider = @capabilities[capability_name][:provider]

      # Execute the capability
      provider.execute(inputs)
    end

    # Converts the agent to a hash representation
    # @return [Hash] The hash representation
    def to_h
      {
        role: @role,
        purpose: @purpose,
        backstory: @backstory,
        capability_names: @capabilities.keys
      }
    end

    # Creates an agent from a hash representation
    # @param hash [Hash] The hash representation
    # @return [Agent] The agent
    def self.from_h(hash)
      # Capabilities need to be added separately after creation
      # since they require the registry to be available
      build do |a|
        a.role = hash[:role] || hash["role"]
        a.purpose = hash[:purpose] || hash["purpose"]
        a.backstory = hash[:backstory] || hash["backstory"]
      end
    end

    private

    # Executes a simple string prompt
    # @param prompt [String] The prompt to execute
    # @return [String] The response
    def execute_prompt(prompt)
      # If the agent has a text_generation capability, use it
      if has_capability?("text_generation")
        execute_capability("text_generation", {prompt: prompt})[:response]
      elsif @llm_client
        # Use the configured LLM client
        response = @llm_client.complete(build_messages(prompt))
        if response.successful?
          response.content
        else
          raise Errors::LlmError.new("LLM execution failed: #{response.error.message}", context: {prompt: prompt})
        end
      else
        raise Errors::AgentNotConfiguredError
      end
    end

    # Builds messages array for LLM completion
    # @param prompt [String] The user prompt
    # @return [Array<Hash>] The messages array
    def build_messages(prompt)
      messages = []

      # Add system message with agent context
      system_content = build_system_message
      messages << {role: "system", content: system_content} if system_content && !system_content.empty?

      # Add user prompt
      messages << {role: "user", content: prompt}

      messages
    end

    # Builds system message with agent personality and instructions
    # @return [String] The system message content
    def build_system_message
      parts = []

      parts << "You are #{@role}" if @role && !@role.empty?
      parts << "Purpose: #{@purpose}" if @purpose && !@purpose.empty?
      parts << "Background: #{@backstory}" if @backstory && !@backstory.empty?
      parts << "Instructions: #{@instructions}" if @instructions && !@instructions.empty?

      # Add capability information
      if @capabilities && !@capabilities.empty?
        capabilities_list = @capabilities.keys.join(", ")
        parts << "Available capabilities: #{capabilities_list}"
      end

      parts.join("\n\n")
    end
  end
end
