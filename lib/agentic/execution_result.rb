# frozen_string_literal: true

module Agentic
  # Value object representing the results of plan execution
  class ExecutionResult
    # @return [String] The ID of the plan
    attr_reader :plan_id

    # @return [Symbol] The status of the execution (:completed, :partial_failure, :failed)
    attr_reader :status

    # @return [Float] The total execution time in seconds
    attr_reader :execution_time

    # @return [Hash] The tasks that were executed, keyed by ID
    attr_reader :tasks

    # @return [Hash] The results of the tasks, keyed by task ID
    attr_reader :results

    # Initializes a new execution result
    # @param plan_id [String] The ID of the plan
    # @param status [Symbol] The status of the execution
    # @param execution_time [Float] The total execution time in seconds
    # @param tasks [Hash] The tasks that were executed, keyed by ID
    # @param results [Hash] The results of the tasks, keyed by task ID
    def initialize(plan_id:, status:, execution_time:, tasks:, results:)
      @plan_id = plan_id
      @status = status
      @execution_time = execution_time
      @tasks = tasks
      @results = results
    end

    # Returns the result for a specific task
    # @param task_id [String] The ID of the task
    # @return [TaskResult, nil] The result of the task, or nil if not found
    def task_result(task_id)
      @results[task_id]
    end

    # Checks if the execution was fully successful
    # @return [Boolean] True if all tasks succeeded
    def successful?
      @status == :completed
    end

    # Checks if the execution partially failed
    # @return [Boolean] True if some tasks failed but the plan completed
    def partial_failure?
      @status == :partial_failure
    end

    # Checks if the execution completely failed
    # @return [Boolean] True if the plan failed to complete
    def failed?
      @status == :failed
    end

    # Returns a hash representation of the execution result
    # @return [Hash] The execution result as a hash
    def to_h
      {
        plan_id: @plan_id,
        status: @status,
        execution_time: @execution_time,
        tasks: @tasks.transform_values { |task| task.is_a?(Task) ? task.to_h : task },
        results: @results.transform_values { |result| result.is_a?(TaskResult) ? result.to_h : result }
      }
    end

    # Returns a summary of the execution result
    # @return [Hash] A summary of the execution result
    def summary
      total_tasks = @tasks.size
      successful_tasks = @results.count { |_, result| result.successful? }
      failed_tasks = @results.count { |_, result| result.failed? }

      {
        plan_id: @plan_id,
        status: @status,
        execution_time: @execution_time,
        task_counts: {
          total: total_tasks,
          successful: successful_tasks,
          failed: failed_tasks
        }
      }
    end
  end
end
