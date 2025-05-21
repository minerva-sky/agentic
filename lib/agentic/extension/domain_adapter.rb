# frozen_string_literal: true

module Agentic
  module Extension
    # The DomainAdapter integrates domain-specific knowledge into the general agent framework.
    # It provides mechanisms for adapting prompts, tasks, and verification strategies
    # to specific domains like healthcare, finance, legal, etc.
    class DomainAdapter
      # Initialize a new DomainAdapter
      #
      # @param [String] domain The identifier for the domain (e.g., "healthcare", "finance")
      # @param [Hash] options Configuration options
      # @option options [Logger] :logger Custom logger instance
      # @option options [Hash] :domain_config Domain-specific configuration
      def initialize(domain, options = {})
        @domain = domain
        @logger = options[:logger] || Agentic.logger
        @domain_config = options[:domain_config] || {}
        @adapters = {}
        @domain_knowledge = {}

        initialize_default_adapters
      end

      # Register an adapter for a specific component
      #
      # @param [Symbol] component The component to adapt (e.g., :prompt, :task, :verification)
      # @param [Proc] adapter A callable that performs the adaptation
      # @return [Boolean] True if registration was successful
      def register_adapter(component, adapter)
        return false unless adapter.respond_to?(:call)

        @adapters[component] = adapter
        true
      end

      # Add domain-specific knowledge
      #
      # @param [Symbol] key The knowledge identifier
      # @param [Object] knowledge The domain knowledge to store
      def add_knowledge(key, knowledge)
        @domain_knowledge[key] = knowledge
      end

      # Get domain-specific knowledge
      #
      # @param [Symbol] key The knowledge identifier
      # @return [Object, nil] The stored knowledge or nil if not found
      def get_knowledge(key)
        @domain_knowledge[key]
      end

      # Apply domain-specific adaptation to a component
      #
      # @param [Symbol] component The component to adapt
      # @param [Object] target The target to apply adaptation to
      # @param [Hash] context Additional context for adaptation
      # @return [Object] The adapted target
      def adapt(component, target, context = {})
        return target unless @adapters.key?(component)

        adapter = @adapters[component]
        context = context.merge(domain: @domain, domain_knowledge: @domain_knowledge)

        begin
          result = adapter.call(target, context)
          @logger.debug("Applied #{@domain} domain adaptation to #{component}")
          result
        rescue => e
          @logger.error("Failed to apply #{@domain} domain adaptation to #{component}: #{e.message}")
          target # Return original if adaptation fails
        end
      end

      # Check if the adapter supports a specific component
      #
      # @param [Symbol] component The component to check
      # @return [Boolean] True if an adapter exists for the component
      def supports?(component)
        @adapters.key?(component)
      end

      # Get the domain identifier
      #
      # @return [String] The domain identifier
      attr_reader :domain

      # Get domain configuration
      #
      # @return [Hash] The domain configuration
      def configuration
        @domain_config
      end

      private

      # Initialize default adapters for common components
      def initialize_default_adapters
        # Identity adapter (returns input unchanged) as fallback
        identity_adapter = ->(target, _context) { target }

        # Register default adapters for common components
        register_adapter(:prompt, identity_adapter)
        register_adapter(:task, identity_adapter)
        register_adapter(:verification, identity_adapter)
      end
    end
  end
end
