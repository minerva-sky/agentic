# frozen_string_literal: true

module Agentic
  module Verification
    # Coordinates verification strategies and manages the verification process
    class VerificationHub
      # @return [Array<VerificationStrategy>] The registered verification strategies
      attr_reader :strategies

      # @return [Hash] Configuration options for the verification hub
      attr_reader :config

      # Initializes a new VerificationHub
      # @param strategies [Array<VerificationStrategy>] The verification strategies to use
      # @param config [Hash] Configuration options for the verification hub
      def initialize(strategies: [], config: {})
        @strategies = strategies
        @config = config
      end

      # Adds a verification strategy
      # @param strategy [VerificationStrategy] The strategy to add
      # @return [void]
      def add_strategy(strategy)
        @strategies << strategy
      end

      # Verifies a task result using the registered strategies
      # @param task [Task] The task to verify
      # @param result [TaskResult] The result to verify
      # @return [VerificationResult] The verification result
      def verify(task, result)
        # Skip verification for failed tasks
        if result.failed?
          return VerificationResult.new(
            task_id: task.id,
            verified: false,
            confidence: 0.0,
            messages: ["Task failed, skipping verification"]
          )
        end

        # Apply all strategies
        strategy_results = @strategies.map do |strategy|
          strategy.verify(task, result)
        end

        # Combine results
        verified = strategy_results.all?(&:verified)
        confidence = strategy_results.map(&:confidence).sum / strategy_results.size.to_f
        messages = strategy_results.flat_map(&:messages)

        VerificationResult.new(
          task_id: task.id,
          verified: verified,
          confidence: confidence,
          messages: messages
        )
      end
    end
  end
end
