# frozen_string_literal: true

require "securerandom"
require "json"
require_relative "observable"

module Agentic
  # Represents an individual task to be executed by an agent
  # @attr_reader [String] id Unique identifier for the task
  # @attr_reader [String] description Human-readable description of the task
  # @attr_reader [Hash] agent_spec Requirements for the agent that will execute this task
  # @attr_reader [Hash] input Input data for the task
  # @attr_reader [Hash, nil] output Output produced by the task, nil if not yet executed
  # @attr_reader [Symbol] status Current status of the task (:pending, :in_progress, :completed, :failed)
  # @attr_reader [TaskFailure, nil] failure Failure information if the task failed, nil otherwise
  # @attr_reader [Boolean, nil] ready_to_execute Flag indicating if the task is ready to be executed
  # @attr_accessor [Integer, nil] retry_count Number of times the task has been retried
  class Task
    include Agentic::Observable

    attr_reader :id, :description, :agent_spec, :input, :output, :status, :failure, :ready_to_execute
    attr_accessor :retry_count

    # Initializes a new task
    # @param description [String] Human-readable description of the task
    # @param agent_spec [Hash] Requirements for the agent that will execute this task
    # @param input [Hash] Input data for the task
    # @return [Task] A new task instance
    def initialize(description:, agent_spec:, input: {})
      @id = SecureRandom.uuid
      @description = description
      @agent_spec = agent_spec
      @input = input
      @output = nil
      @failure = nil
      @status = :pending
      @ready_to_execute = nil
    end

    # Executes the task using the given agent
    # @param agent [Agent] The agent that will execute this task
    # @return [TaskResult] The result of the task execution
    def perform(agent)
      old_status = @status
      @status = :in_progress

      notify_observers(:status_change, old_status, @status)

      begin
        @output = agent.execute(build_prompt)
        old_status = @status
        @status = :completed

        notify_observers(:status_change, old_status, @status)

        TaskResult.new(
          task_id: @id,
          success: true,
          output: @output
        )
      rescue => e
        @failure = TaskFailure.new(
          message: e.message,
          type: e.class.name,
          context: {
            backtrace: e.backtrace&.first(10),
            agent_id: agent.respond_to?(:id) ? agent.id : nil
          }
        )

        old_status = @status
        @status = :failed

        notify_observers(:status_change, old_status, @status)
        notify_observers(:failure_occurred, @failure)

        Agentic.logger.error("Task execution failed: #{e.message}")

        TaskResult.new(
          task_id: @id,
          success: false,
          failure: @failure
        )
      end
    end

    # Retries a failed task
    # @param agent [Agent] The agent that will execute this task
    # @return [TaskResult] The result of the task execution
    # @raise [StandardError] If the task is not in a failed state
    def retry(agent)
      raise "Cannot retry a task that is not in a failed state" unless @status == :failed

      old_status = @status
      @status = :retrying

      notify_observers(:status_change, old_status, @status)

      perform(agent)
    end

    # Returns a serializable representation of the task
    # @return [Hash] The task as a hash
    def to_h
      {
        id: @id,
        description: @description,
        agent_spec: @agent_spec,
        input: @input,
        output: @output,
        status: @status,
        failure: @failure&.to_h
      }
    end

    private

    # Builds the prompt to be sent to the agent
    # @return [String] The formatted prompt
    def build_prompt
      <<~PROMPT
        [System Instructions]
        #{agent_spec["instructions"]}
        
        [Task Description]
        #{description}
        
        [Input Parameters]
        #{JSON.pretty_generate(input)}
        
        [Output Requirements]
        Please provide your response in JSON format.
      PROMPT
    end
  end
end
