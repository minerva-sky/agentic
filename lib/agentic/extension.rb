# frozen_string_literal: true

module Agentic
  # The Extension module provides extensibility points for the Agentic framework.
  # It includes three main components:
  #
  # 1. DomainAdapter - Adapts the framework for specific domains (e.g., healthcare, finance)
  # 2. ProtocolHandler - Standardizes connections to external systems
  # 3. PluginManager - Coordinates third-party extension loading and registration
  #
  # These components allow users to customize and extend Agentic's capabilities
  # while maintaining a consistent interface.
  module Extension
    class << self
      # Get or create a plugin manager instance
      #
      # @param [Hash] options Configuration options
      # @return [PluginManager] The plugin manager instance
      def plugin_manager(options = {})
        @plugin_manager ||= PluginManager.new(options)
      end

      # Get or create a protocol handler instance
      #
      # @param [Hash] options Configuration options
      # @return [ProtocolHandler] The protocol handler instance
      def protocol_handler(options = {})
        @protocol_handler ||= ProtocolHandler.new(options)
      end

      # Create a domain adapter for a specific domain
      #
      # @param [String] domain The domain identifier
      # @param [Hash] options Configuration options
      # @return [DomainAdapter] A new domain adapter instance
      def domain_adapter(domain, options = {})
        DomainAdapter.new(domain, options)
      end
    end
  end
end
