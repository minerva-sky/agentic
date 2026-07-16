# frozen_string_literal: true

module Agentic
  module Verification
    # Verifies task results against a schema
    class SchemaVerificationStrategy < VerificationStrategy
      # Default configuration for schema verification
      DEFAULT_CONFIG = {
        strict_mode: false,
        allow_additional_properties: true,
        confidence_on_match: 0.95,
        confidence_on_no_schema: 0.5
      }.freeze

      # Initializes a new SchemaVerificationStrategy
      # @param config [Hash] Configuration options for the strategy
      def initialize(config = {})
        merged_config = DEFAULT_CONFIG.merge(config)
        super(merged_config)
      end

      # Verifies a task result against a schema
      # @param task [Task] The task to verify
      # @param result [TaskResult] The result to verify
      # @return [VerificationResult] The verification result
      def verify(task, result)
        return failed_task_result(task) unless result.successful?

        begin
          schema = extract_schema(task)

          unless schema
            return no_schema_result(task)
          end

          perform_schema_validation(task, result, schema)
        rescue => e
          Agentic.logger.error("Schema verification error: #{e.message}")
          error_result(task, e)
        end
      end

      private

      def failed_task_result(task)
        VerificationResult.new(
          task_id: task.id,
          verified: false,
          confidence: 0.0,
          messages: ["Task failed, skipping schema verification"]
        )
      end

      def no_schema_result(task)
        VerificationResult.new(
          task_id: task.id,
          verified: true,
          confidence: config[:confidence_on_no_schema],
          messages: ["No schema specified for verification, passing by default"]
        )
      end

      def error_result(task, error)
        VerificationResult.new(
          task_id: task.id,
          verified: false,
          confidence: 0.0,
          messages: ["Schema verification error: #{error.message}"]
        )
      end

      def extract_schema(task)
        # Try multiple places to find schema
        return task.input["output_schema"] if task.input.is_a?(Hash) && task.input["output_schema"]
        return task.input[:output_schema] if task.input.is_a?(Hash) && task.input[:output_schema]

        # Check if task has schema metadata
        return task.metadata[:output_schema] if task.respond_to?(:metadata) && task.metadata&.dig(:output_schema)

        nil
      end

      def perform_schema_validation(task, result, schema)
        # In a real implementation, we would validate the output against the schema
        # using a JSON Schema validator like the `json-schema` gem
        # For this stub, we'll simulate validation with configurable behavior

        # TODO: Implement actual schema validation using a JSON Schema library
        # Example implementation:
        #   require 'json-schema'
        #   validation_errors = JSON::Validator.fully_validate(schema, result.output)
        #
        #   if validation_errors.empty?
        #     verified = true
        #     messages = ["Output matches expected schema"]
        #   else
        #     verified = config[:strict_mode] ? false : true
        #     messages = validation_errors
        #   end

        # For this stub, we'll assume validation passes
        verified = true
        confidence = config[:confidence_on_match]
        messages = ["Output matches expected schema (simulated)"]

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
