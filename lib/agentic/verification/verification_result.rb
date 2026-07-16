# frozen_string_literal: true

module Agentic
  module Verification
    # Represents the result of a verification process
    class VerificationResult
      # @return [String] The ID of the task that was verified
      attr_reader :task_id

      # @return [Boolean] Whether the verification passed
      attr_reader :verified

      # @return [Float] The confidence score (0.0-1.0) of the verification
      attr_reader :confidence

      # @return [Array<String>] Messages from the verification process
      attr_reader :messages

      # @return [Hash, nil] Structured error context when verification failed
      #   due to an error (e.g. :error_type, :timestamp)
      attr_reader :error_details

      # Initializes a new VerificationResult
      # @param task_id [String] The ID of the task that was verified
      # @param verified [Boolean] Whether the verification passed
      # @param confidence [Float] The confidence score (0.0-1.0) of the verification
      # @param messages [Array<String>] Messages from the verification process
      # @param error_details [Hash, nil] Structured error context for failures
      def initialize(task_id:, verified:, confidence:, messages: [], error_details: nil)
        @task_id = task_id
        @verified = verified
        @confidence = confidence
        @messages = messages
        @error_details = error_details
      end

      # Checks if the verification passed with high confidence
      # @param threshold [Float] The confidence threshold
      # @return [Boolean] Whether verification passed with confidence above the threshold
      def verified_with_confidence?(threshold: 0.8)
        @verified && @confidence >= threshold
      end

      # Converts the verification result to a hash
      # @return [Hash] The verification result as a hash
      def to_h
        {
          task_id: @task_id,
          verified: @verified,
          confidence: @confidence,
          messages: @messages
        }
      end
    end
  end
end
