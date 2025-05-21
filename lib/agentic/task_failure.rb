# frozen_string_literal: true

module Agentic
  # Represents a failure that occurred during task execution
  # @attr_reader [String] message The failure message
  # @attr_reader [String] type The type of failure
  # @attr_reader [Time] timestamp When the failure occurred
  # @attr_reader [Hash] context Additional context about the failure
  class TaskFailure
    attr_reader :message, :type, :timestamp, :context

    # Initializes a new task failure
    # @param message [String] The failure message
    # @param type [String] The type of failure
    # @param context [Hash] Additional context about the failure
    # @return [TaskFailure] A new task failure instance
    def initialize(message:, type:, context: {})
      @message = message
      @type = type
      @timestamp = Time.now
      @context = context
    end

    # Returns a serializable representation of the failure
    # @return [Hash] The failure as a hash
    def to_h
      {
        message: @message,
        type: @type,
        timestamp: @timestamp.iso8601,
        context: @context
      }
    end

    # Creates a task failure from an exception
    # @param exception [Exception] The exception
    # @param context [Hash] Additional context about the failure
    # @return [TaskFailure] A new task failure instance
    def self.from_exception(exception, context = {})
      new(
        message: exception.message,
        type: exception.class.name,
        context: context.merge(
          backtrace: exception.backtrace&.first(10)
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
  end
end
