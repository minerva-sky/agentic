# frozen_string_literal: true

module Agentic
  # Represents the result of a task execution
  # @attr_reader [String] task_id The ID of the task that produced this result
  # @attr_reader [Boolean] success Whether the task execution was successful
  # @attr_reader [Hash, nil] output The output produced by the task, nil if unsuccessful
  # @attr_reader [TaskFailure, nil] failure The failure information, nil if successful
  class TaskResult
    attr_reader :task_id, :success, :output, :failure

    # Initializes a new task result
    # @param task_id [String] The ID of the task that produced this result
    # @param success [Boolean] Whether the task execution was successful
    # @param output [Hash, nil] The output produced by the task
    # @param failure [TaskFailure, nil] The failure information
    # @return [TaskResult] A new task result instance
    def initialize(task_id:, success:, output: nil, failure: nil)
      @task_id = task_id
      @success = success
      @output = output
      @failure = failure
    end

    # Checks if the task execution was successful
    # @return [Boolean] True if successful, false otherwise
    def successful?
      @success
    end

    # Checks if the task execution failed
    # @return [Boolean] True if failed, false otherwise
    def failed?
      !@success
    end

    # Returns a serializable representation of the result
    # @return [Hash] The result as a hash
    def to_h
      {
        task_id: @task_id,
        success: @success,
        output: @output,
        failure: @failure&.to_h
      }
    end
  end
end
