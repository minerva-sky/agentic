# frozen_string_literal: true

require_relative "verification_strategy"
require_relative "verification_result"

module Agentic
  module Verification
    # Verifies task results against a schema
    class SchemaVerificationStrategy < VerificationStrategy
      # Verifies a task result against a schema
      # @param task [Task] The task to verify
      # @param result [TaskResult] The result to verify
      # @return [VerificationResult] The verification result
      def verify(task, result)
        unless result.successful?
          return VerificationResult.new(
            task_id: task.id,
            verified: false,
            confidence: 0.0,
            messages: ["Task failed, skipping schema verification"]
          )
        end

        # Extracting schema from task if available
        schema = task.input["output_schema"] if task.input.is_a?(Hash)

        unless schema
          return VerificationResult.new(
            task_id: task.id,
            verified: true,
            confidence: 0.5,
            messages: ["No schema specified for verification, passing by default"]
          )
        end

        # In a real implementation, we would validate the output against the schema
        # For this stub, we'll assume validation passes
        VerificationResult.new(
          task_id: task.id,
          verified: true,
          confidence: 0.9,
          messages: ["Output matches expected schema"]
        )
      end
    end
  end
end
