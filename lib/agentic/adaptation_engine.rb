# frozen_string_literal: true

module Agentic
  # The AdaptationEngine enables feedback-driven adjustments to agents and tasks.
  # It is part of the Verification Layer and focuses on applying learned improvements
  # based on feedback, outcomes, and performance metrics.
  class AdaptationEngine
    # Initialize a new AdaptationEngine.
    #
    # @param [Hash] options Configuration options for the adaptation engine
    # @option options [Logger] :logger Custom logger instance
    # @option options [Integer] :adaptation_threshold Minimum confidence score to trigger adaptation (0-100)
    # @option options [Boolean] :auto_adapt Whether to automatically apply adaptations
    def initialize(options = {})
      @logger = options[:logger] || Agentic.logger
      @adaptation_threshold = options[:adaptation_threshold] || 75
      @auto_adapt = options.fetch(:auto_adapt, false)
      @adaptation_registry = {}
      @feedback_history = []
    end

    # Register an adaptation strategy for a specific component/context
    #
    # @param [Symbol] component The component or context to adapt (e.g., :agent, :task, :prompt)
    # @param [Proc] strategy A callable that implements the adaptation logic
    # @return [Boolean] True if registration was successful
    def register_adaptation_strategy(component, strategy)
      return false unless strategy.respond_to?(:call)

      @adaptation_registry[component] = strategy
      true
    end

    # Process feedback and determine if adaptation is needed
    #
    # @param [Hash] feedback The feedback data to process
    # @option feedback [Symbol] :component The component receiving feedback
    # @option feedback [Object] :target The specific instance to adapt
    # @option feedback [Hash] :metrics Performance metrics
    # @option feedback [String, Symbol] :outcome Success/failure indicator
    # @option feedback [String] :suggestion Suggested improvement
    # @return [Hash] Result of the adaptation process
    def process_feedback(feedback)
      record_feedback(feedback)
      
      adaptation_needed = determine_if_adaptation_needed(feedback)
      return {adapted: false, reason: "Adaptation threshold not met"} unless adaptation_needed
      
      if @auto_adapt
        apply_adaptation(feedback)
      else
        {
          adapted: false,
          adaptation_suggested: true,
          suggestion: feedback[:suggestion]
        }
      end
    end

    # Apply an adaptation based on feedback
    #
    # @param [Hash] feedback The feedback data to use for adaptation
    # @return [Hash] Result of the adaptation attempt
    def apply_adaptation(feedback)
      component = feedback[:component]
      
      unless @adaptation_registry.key?(component)
        return {adapted: false, reason: "No adaptation strategy registered for #{component}"}
      end
      
      strategy = @adaptation_registry[component]
      
      begin
        result = strategy.call(feedback)
        {
          adapted: true,
          component: component,
          target: feedback[:target],
          result: result
        }
      rescue StandardError => e
        @logger.error("Adaptation failed: #{e.message}")
        {
          adapted: false,
          error: e.message,
          component: component
        }
      end
    end

    # Retrieve adaptation history for a specific component
    #
    # @param [Symbol] component The component to get history for
    # @return [Array<Hash>] History of adaptations for the component
    def adaptation_history(component = nil)
      if component
        @feedback_history.select { |f| f[:component] == component }
      else
        @feedback_history
      end
    end

    private

    # Record feedback in the history
    #
    # @param [Hash] feedback The feedback to record
    def record_feedback(feedback)
      @feedback_history << feedback.merge(timestamp: Time.now)
    end

    # Determine if adaptation is needed based on feedback
    #
    # @param [Hash] feedback The feedback to analyze
    # @return [Boolean] True if adaptation is needed
    def determine_if_adaptation_needed(feedback)
      # Simple implementation - can be expanded with more sophisticated logic
      return false unless feedback[:metrics] && feedback[:metrics][:confidence]
      
      confidence_score = feedback[:metrics][:confidence]
      confidence_score < @adaptation_threshold
    end
  end
end