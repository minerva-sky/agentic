# frozen_string_literal: true

require "time" # Time#iso8601/Time.parse - require what you use

module Agentic
  # Represents a failure that occurred during task execution
  # @attr_reader [String] message The failure message
  # @attr_reader [String] type The type of failure
  # @attr_reader [Time] timestamp When the failure occurred
  # @attr_reader [Hash] context Additional context about the failure
  class TaskFailure
    attr_reader :message, :type, :timestamp, :context

    # @return [Boolean, nil] Whether the originating error declared itself
    #   retryable (nil when the error expressed no opinion)
    attr_reader :retryable

    # Initializes a new task failure
    # @param message [String] The failure message
    # @param type [String] The type of failure
    # @param context [Hash] Additional context about the failure
    # @param retryable [Boolean, nil] The originating error's own retryability verdict
    # @return [TaskFailure] A new task failure instance
    def initialize(message:, type:, context: {}, retryable: nil)
      @message = sanitize_message(message)
      @type = type
      @timestamp = Time.now
      @context = sanitize_context(context)
      @retryable = retryable
    end

    # Whether the originating error declared itself retryable
    # @return [Boolean, nil] nil when the error expressed no opinion
    def retryable?
      @retryable
    end

    # The nil convention: only an EXPLICIT false verdict is hopeless.
    # An error that expressed no opinion (nil) gets suspicion, not a
    # death sentence - breakers should count strikes against it, not
    # trip instantly. These two predicates split the three-valued
    # verdict at the joint policy code actually cares about.
    # @return [Boolean] True when the error testified retrying can never help
    def hopeless?
      @retryable == false
    end

    # @return [Boolean] True when retrying might help (verdict true or no opinion)
    def possibly_transient?
      !hopeless?
    end

    # Returns a serializable representation of the failure
    # @return [Hash] The failure as a hash
    def to_h
      {
        message: @message,
        type: @type,
        timestamp: @timestamp.iso8601,
        context: @context,
        retryable: @retryable
      }
    end

    # Creates a task failure from an exception, preserving the exception's
    # own retryability verdict when it offers one (e.g. Errors::LlmRateLimitError)
    # @param exception [Exception] The exception
    # @param context [Hash] Additional context about the failure
    # @return [TaskFailure] A new task failure instance
    def self.from_exception(exception, context = {})
      # Sanitize backtrace based on security configuration
      safe_backtrace = if Security::Config.backtrace_sanitization_enabled? && exception.backtrace
        Security::Config.sanitizer.sanitize(exception.backtrace.first(10), context: :backtrace)
      else
        exception.backtrace&.first(10)
      end

      new(
        message: exception.message,
        type: exception.class.name,
        retryable: exception.respond_to?(:retryable?) ? exception.retryable? : nil,
        context: context.merge(
          backtrace: safe_backtrace
        )
      )
    end

    # Creates a task failure from a hash
    # @param hash [Hash] The hash representation of a task failure
    # @return [TaskFailure] A new task failure instance
    def self.from_hash(hash)
      # Handle the case where hash is not actually a hash
      return new(message: "Unknown error", type: "UnknownError") unless hash.is_a?(Hash)

      # Convert string keys to symbols if necessary
      hash = hash.transform_keys(&:to_sym) if hash.keys.first.is_a?(String)

      new(
        message: hash[:message] || "Unknown error",
        type: hash[:type] || "UnknownError",
        context: hash[:context] || {}
      )
    end

    # Get sanitized failure for logging purposes
    # @return [Hash] Sanitized failure data suitable for logging
    def to_secure_hash
      {
        message: @message, # Already sanitized during initialization
        type: @type,
        timestamp: @timestamp.iso8601,
        context: @context # Already sanitized during initialization
      }
    end

    private

    # Sanitize message content to remove PII
    # @param message [String] The original message
    # @return [String] Sanitized message
    def sanitize_message(message)
      return message unless Security::Config.pii_detection_enabled?
      return "" if message.nil?

      Security::Config.sanitizer.sanitize_error(message)
    end

    # Sanitize context data to remove sensitive information
    # @param context [Hash] The original context
    # @return [Hash] Sanitized context
    def sanitize_context(context)
      return context unless Security::Config.pii_detection_enabled?
      return {} if context.nil?

      sanitized = Security::Config.sanitizer.sanitize(context, context: :error)
      # The sanitizer stringifies keys; restore symbol access expected by callers
      sanitized.transform_keys(&:to_sym)
    end
  end
end
