# frozen_string_literal: true

module Agentic
  module Observability
    # Local observer for in-process event handling
    #
    # Provides a standardized interface for objects that want to observe
    # events within the same process. This is the foundation for synchronous
    # event handling and immediate response to system state changes.
    #
    # @example Creating a custom observer
    #   class TaskMonitor < LocalObserver
    #     def handle_task_started(event_data)
    #       puts "Task started: #{event_data[:task_id]}"
    #     end
    #
    #     def handle_task_completed(event_data)
    #       puts "Task completed in #{event_data[:duration]}s"
    #     end
    #   end
    #
    # @example Using with ObservabilityEngine
    #   monitor = TaskMonitor.new
    #   Agentic.observability_engine.add_local_observer(monitor)
    class LocalObserver
      # Standard observer interface method
      # Called by ObservabilityEngine when events occur
      #
      # @param event_type [Symbol] Type of event (e.g., :task_started)
      # @param source [Object] Source of the event (usually ObservabilityEngine)
      # @param event_data [Hash] Event payload with data and metadata
      def update(event_type, source, event_data)
        # Try to call specific handler method first
        handler_method = "handle_#{event_type}"

        if respond_to?(handler_method, true)
          send(handler_method, event_data)
        else
          # Fall back to generic handler
          handle_event(event_type, event_data)
        end
      rescue => error
        handle_observer_error(event_type, error)
      end

      protected

      # Generic event handler - override in subclasses for custom behavior
      # @param event_type [Symbol] Type of event
      # @param event_data [Hash] Event data
      def handle_event(event_type, event_data)
        # Default implementation does nothing
        # Subclasses can override for custom handling
      end

      # Error handling for observer errors
      # @param event_type [Symbol] Event type that caused the error
      # @param error [Exception] The error that occurred
      def handle_observer_error(event_type, error)
        Agentic.logger.warn("Observer error for #{event_type}: #{error.message}")
      end

      # Convenience methods for common event type checks

      def task_event?(event_type)
        event_type.to_s.start_with?("task_")
      end

      def agent_event?(event_type)
        event_type.to_s.start_with?("agent_")
      end

      def plan_event?(event_type)
        event_type.to_s.start_with?("plan_")
      end

      def execution_event?(event_type)
        [:task_started, :task_completed, :task_failed, :plan_started, :plan_completed, :plan_failed].include?(event_type)
      end
    end

    # Specialized local observer for execution events (tasks, plans, agents)
    # Provides specific handler methods for common execution lifecycle events
    class ExecutionObserver < LocalObserver
      def initialize
        @execution_stats = {
          tasks_started: 0,
          tasks_completed: 0,
          tasks_failed: 0,
          plans_started: 0,
          plans_completed: 0,
          plans_failed: 0
        }
      end

      attr_reader :execution_stats

      protected

      def handle_task_started(event_data)
        @execution_stats[:tasks_started] += 1
        on_task_started(event_data)
      end

      def handle_task_completed(event_data)
        @execution_stats[:tasks_completed] += 1
        on_task_completed(event_data)
      end

      def handle_task_failed(event_data)
        @execution_stats[:tasks_failed] += 1
        on_task_failed(event_data)
      end

      def handle_plan_started(event_data)
        @execution_stats[:plans_started] += 1
        on_plan_started(event_data)
      end

      def handle_plan_completed(event_data)
        @execution_stats[:plans_completed] += 1
        on_plan_completed(event_data)
      end

      def handle_plan_failed(event_data)
        @execution_stats[:plans_failed] += 1
        on_plan_failed(event_data)
      end

      # Override these methods in subclasses for custom execution monitoring
      def on_task_started(event_data)
      end

      def on_task_completed(event_data)
      end

      def on_task_failed(event_data)
      end

      def on_plan_started(event_data)
      end

      def on_plan_completed(event_data)
      end

      def on_plan_failed(event_data)
      end
    end
  end
end
