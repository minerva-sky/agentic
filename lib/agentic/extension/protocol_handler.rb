# frozen_string_literal: true

module Agentic
  module Extension
    # The ProtocolHandler standardizes connections to external systems through consistent
    # interface definitions. It enables integration with various APIs, data sources,
    # and services while providing a uniform access pattern regardless of the underlying
    # protocol or system specifics.
    class ProtocolHandler
      # Initialize a new ProtocolHandler
      #
      # @param [Hash] options Configuration options
      # @option options [Logger] :logger Custom logger instance
      # @option options [Hash] :default_headers Default headers for all protocol requests
      def initialize(options = {})
        @logger = options[:logger] || Agentic.logger
        @default_headers = options[:default_headers] || {}
        @protocols = {}
      end

      # Register a protocol implementation
      #
      # @param [Symbol] protocol_name The name of the protocol (e.g., :http, :websocket, :grpc)
      # @param [Object] implementation The protocol implementation
      # @param [Hash] config Protocol-specific configuration
      # @return [Boolean] True if registration was successful
      def register_protocol(protocol_name, implementation, config = {})
        if !valid_protocol?(implementation)
          @logger.error("Protocol implementation for '#{protocol_name}' is invalid")
          return false
        end

        @protocols[protocol_name] = {
          implementation: implementation,
          config: config
        }

        @logger.info("Protocol '#{protocol_name}' registered successfully")
        true
      end

      # Send a request using a registered protocol
      #
      # @param [Symbol] protocol_name The protocol to use
      # @param [String] endpoint The endpoint to send the request to
      # @param [Hash] options Request options including :method, :headers, :body, etc.
      # @return [Hash, nil] The response or nil if the protocol is not registered
      def send_request(protocol_name, endpoint, options = {})
        unless @protocols.key?(protocol_name)
          @logger.error("Protocol '#{protocol_name}' is not registered")
          return nil
        end

        protocol = @protocols[protocol_name]
        options[:headers] = @default_headers.merge(options[:headers] || {})

        begin
          response = protocol[:implementation].send_request(endpoint, options.merge(protocol[:config]))
          @logger.debug("Request sent using '#{protocol_name}' protocol to '#{endpoint}'")
          response
        rescue => e
          @logger.error("Failed to send request using '#{protocol_name}' protocol: #{e.message}")
          nil
        end
      end

      # Get protocol configuration
      #
      # @param [Symbol] protocol_name The protocol to get configuration for
      # @return [Hash, nil] The protocol configuration or nil if not registered
      def protocol_config(protocol_name)
        return nil unless @protocols.key?(protocol_name)

        @protocols[protocol_name][:config]
      end

      # Update protocol configuration
      #
      # @param [Symbol] protocol_name The protocol to update
      # @param [Hash] config The new configuration to merge
      # @return [Boolean] True if update was successful
      def update_protocol_config(protocol_name, config)
        return false unless @protocols.key?(protocol_name)

        @protocols[protocol_name][:config].merge!(config)
        true
      end

      # Check if a protocol is registered
      #
      # @param [Symbol] protocol_name The protocol to check
      # @return [Boolean] True if the protocol is registered
      def protocol_registered?(protocol_name)
        @protocols.key?(protocol_name)
      end

      # List all registered protocols
      #
      # @return [Array<Symbol>] List of registered protocol names
      def list_protocols
        @protocols.keys
      end

      private

      # Check if a protocol implementation is valid
      #
      # @param [Object] implementation The implementation to validate
      # @return [Boolean] True if the implementation is valid
      def valid_protocol?(implementation)
        # Check if implementation has required methods
        implementation.respond_to?(:send_request)
      end
    end
  end
end
