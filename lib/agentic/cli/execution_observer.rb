# frozen_string_literal: true

module Agentic
  class CLI < Thor
    # Observer that provides real-time feedback during plan execution
    class ExecutionObserver
      # Initialize a new execution observer
      # @param options [Hash] CLI options
      def initialize(options = {})
        @options = options
        @start_time = Time.now
        @completed_tasks = 0
        @failed_tasks = 0
        @total_tasks = 0
        @task_spinners = {}
      end

      # Builds lifecycle hooks for the plan orchestrator
      # @return [Hash] The lifecycle hooks
      def lifecycle_hooks
        {
          before_task_execution: method(:before_task_execution),
          after_task_success: method(:after_task_success),
          after_task_failure: method(:after_task_failure),
          plan_completed: method(:plan_completed)
        }
      end

      # Called before a task is executed
      # @param task_id [String] The ID of the task
      # @param task [Task] The task to execute
      def before_task_execution(task_id:, task:)
        return if @options[:quiet]

        @total_tasks += 1 unless @task_spinners.key?(task_id)

        # Create a spinner for the task
        spinner = TTY::Spinner.new(
          "[:spinner] #{UI.colorize("⋯", :blue)} Task: #{task.description}",
          format: :dots
        )

        @task_spinners[task_id] = {
          spinner: spinner,
          task: task,
          start_time: Time.now
        }

        spinner.auto_spin
      end

      # Called after a task is successfully executed
      # @param task_id [String] The ID of the task
      # @param task [Task] The task that was executed
      # @param result [TaskResult] The result of the task
      # @param duration [Float] The duration of the task execution
      def after_task_success(task_id:, task:, result:, duration:)
        return if @options[:quiet]

        @completed_tasks += 1

        if @task_spinners[task_id]
          spinner = @task_spinners[task_id][:spinner]
          spinner.success(
            "#{UI.colorize("✓", :green)} Task: #{task.description} " \
            "(#{UI.format_duration(duration)})"
          )
        end

        # Display progress
        display_progress
      end

      # Called after a task fails
      # @param task_id [String] The ID of the task
      # @param task [Task] The task that failed
      # @param failure [TaskFailure] The failure details
      # @param duration [Float] The duration of the task execution
      def after_task_failure(task_id:, task:, failure:, duration:)
        return if @options[:quiet]

        @failed_tasks += 1

        if @task_spinners[task_id]
          spinner = @task_spinners[task_id][:spinner]
          spinner.error(
            "#{UI.colorize("✗", :red)} Task: #{task.description} - " \
            "#{failure.message} (#{UI.format_duration(duration)})"
          )
        end

        # Display progress
        display_progress
      end

      # Called when the plan execution is completed
      # @param plan_id [String] The ID of the plan
      # @param status [Symbol] The status of the plan execution
      # @param execution_time [Float] The execution time in seconds
      # @param tasks [Hash] The tasks that were executed
      # @param results [Hash] The results of the task executions
      def plan_completed(plan_id:, status:, execution_time:, tasks:, results:)
        return if @options[:quiet]

        # Display a summary
        total_time = UI.format_duration(execution_time)

        result_color = case status
        when :completed
          :green
        when :partial_failure
          :yellow
        else
          :red
        end

        summary = UI.box(
          "Execution Results",
          [
            "Status: #{UI.status_text(status, status)}",
            "Tasks: #{@total_tasks} total, " \
            "#{UI.colorize(@completed_tasks.to_s, :green)} completed, " \
            "#{UI.colorize(@failed_tasks.to_s, :red)} failed",
            "Time: #{total_time}"
          ].join("\n"),
          style: {border: {fg: result_color}}
        )

        puts "\n#{summary}"
      end

      private

      # Displays progress information
      def display_progress
        return if @options[:quiet]

        total = @completed_tasks + @failed_tasks
        elapsed = Time.now - @start_time

        if @total_tasks > 0
          progress = (total / @total_tasks.to_f * 100).round
          if total > 0 && total < @total_tasks
            puts UI.colorize(
              "Progress: #{progress}% (#{total}/#{@total_tasks}) - " \
              "Elapsed: #{UI.format_duration(elapsed)}",
              :blue
            )
          end
        end
      end
    end
  end
end
