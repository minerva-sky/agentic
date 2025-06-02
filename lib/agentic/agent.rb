# frozen_string_literal: true

module Agentic
  class Agent
    include FactoryMethods

    configurable :id, :role, :purpose, :backstory, :tools, :capabilities

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

    # Adds a capability to the agent
    # @param capability_name [String] The name of the capability
    # @param version [String, nil] The version of the capability, or nil for latest
    # @return [Boolean] True if the capability was added successfully
    def add_capability(capability_name, version = nil)
      # Get the capability from the registry
      registry = AgentCapabilityRegistry.instance
      capability = registry.get(capability_name, version)
      raise "Capability not found: #{capability_name}" unless capability

      # Get the provider
      provider = registry.get_provider(capability_name, version)
      raise "Provider not found for capability: #{capability_name}" unless provider

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
      raise "Capability not available: #{capability_name}" unless @capabilities.key?(capability_name)

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
      new do |a|
        a.role = hash[:role] || hash["role"]
        a.purpose = hash[:purpose] || hash["purpose"]
        a.backstory = hash[:backstory] || hash["backstory"]
      end

      # Note: Capabilities need to be added separately after creation
      # since they require the registry to be available
    end

    private

    # Executes a simple string prompt
    # @param prompt [String] The prompt to execute
    # @return [String] The response
    def execute_prompt(prompt)
      # If the agent has a text_generation capability, use it
      if has_capability?("text_generation")
        execute_capability("text_generation", {prompt: prompt})[:response]
      else
        # Otherwise, implement default behavior
        # This would typically integrate with the LLM client
        "This is a placeholder response. In a real implementation, this would use an LLM."
      end
    end
  end
end
