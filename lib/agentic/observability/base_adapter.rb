# frozen_string_literal: true

module Agentic
  module Observability
    # Base adapter interface for observability outputs
    # Provides common functionality and interface for all adapter types
    class BaseAdapter
      attr_reader :config, :enabled

      def initialize(config = {})
        @config = config
        @enabled = config.fetch(:enabled, true)
        @statistics = {
          events_processed: 0,
          errors: 0,
          last_event_at: nil,
          created_at: Time.now
        }
        @mutex = Mutex.new
        setup
      end

      # Must be implemented by subclasses
      # @param event_data [EventData] The event to handle
      def handle_event(event_data)
        raise NotImplementedError, "Subclasses must implement #handle_event"
      end

      # Enable the adapter
      def enable!
        @enabled = true
        on_enable if respond_to?(:on_enable, true)
      end

      # Disable the adapter
      def disable!
        @enabled = false
        on_disable if respond_to?(:on_disable, true)
      end

      # Check if adapter is enabled
      # @return [Boolean] True if adapter is enabled
      def enabled?
        @enabled
      end

      # Get adapter status and statistics
      # @return [Hash] Status information
      def status
        @mutex.synchronize do
          {
            enabled: enabled?,
            type: adapter_type,
            statistics: @statistics.dup,
            config: safe_config
          }
        end
      end

      # Get just the statistics
      # @return [Hash] Statistics hash
      def statistics
        @mutex.synchronize do
          @statistics.dup
        end
      end

      # Graceful shutdown
      def shutdown
        # Default implementation - override if needed
        disable!
      end

      # Get human-readable adapter type
      # @return [String] Adapter type name
      def adapter_type
        self.class.name.split("::").last.gsub("Adapter", "").downcase
      end

      protected

      # Override in subclasses for initialization
      def setup
        # Default no-op implementation
      end

      # Record successful event processing
      def record_event_processed
        @mutex.synchronize do
          @statistics[:events_processed] += 1
          @statistics[:last_event_at] = Time.now
        end
      end

      # Record error in event processing
      def record_error(error = nil)
        @mutex.synchronize do
          @statistics[:errors] += 1
          @statistics[:last_error] = error&.message
          @statistics[:last_error_at] = Time.now
        end
      end

      # Get configuration safe for logging (remove sensitive data)
      # @return [Hash] Sanitized configuration
      def safe_config
        # Remove potentially sensitive keys
        sensitive_keys = [:password, :token, :api_key, :secret]
        @config.reject { |key, _| sensitive_keys.include?(key.to_sym) }
      end

      # Helper for consistent error handling
      # @param event_data [EventData] The event being processed
      # @yield Block to execute with error handling
      def with_error_handling(event_data)
        return unless enabled?

        begin
          yield
          record_event_processed
        rescue => error
          record_error(error)
          handle_error(error, event_data)
        end
      end

      # Handle errors that occur during event processing
      # @param error [Exception] The error that occurred
      # @param event_data [EventData] The event being processed
      def handle_error(error, event_data)
        message = "#{adapter_type.capitalize} adapter error: #{error.message}"
        if Agentic.logger
          Agentic.logger.warn(message)
          Agentic.logger.debug("Event: #{event_data.type}, Error: #{error.backtrace&.first}")
        else
          warn message
        end
      end
    end
  end
end
