# frozen_string_literal: true

module Agentic
  module Verification
    # Base class for verification strategies
    class VerificationStrategy
      # @return [Hash] Configuration options for the strategy
      attr_reader :config

      # Initializes a new VerificationStrategy
      # @param config [Hash] Configuration options for the strategy
      def initialize(config = {})
        @config = config
      end

      # Verifies a task result
      # @param task [Task] The task to verify
      # @param result [TaskResult] The result to verify
      # @return [VerificationResult] The verification result
      # @raise [NotImplementedError] This method must be implemented by subclasses
      def verify(task, result)
        raise NotImplementedError, "Subclasses must implement verify"
      end
    end
  end
end
