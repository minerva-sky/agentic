# frozen_string_literal: true

module Agentic
  # Registry for managing task output schemas
  # Provides a centralized location for defining and accessing
  # structured output schemas used by tasks
  class TaskOutputSchemas
    @schemas = {}

    class << self
      # Registers a new output schema
      # @param name [Symbol] The schema name/identifier
      # @param schema [Agentic::StructuredOutputs::Schema] The schema definition
      def register(name, schema)
        @schemas[name] = schema
      end

      # Retrieves a registered schema
      # @param name [Symbol] The schema name/identifier
      # @return [Agentic::StructuredOutputs::Schema, nil] The schema or nil if not found
      def get(name)
        @schemas[name] || ((name == :default) ? default_task_schema : nil)
      end

      # Lists all registered schema names
      # @return [Array<Symbol>] Array of schema names
      def list_schemas
        (@schemas.keys + [:default]).uniq
      end

      # Checks if a schema is registered
      # @param name [Symbol] The schema name/identifier
      # @return [Boolean] True if schema exists
      def exists?(name)
        @schemas.key?(name) || name == :default
      end

      # Returns the default task output schema for general task responses
      # @return [Agentic::StructuredOutputs::Schema] Default schema for task outputs
      def default_task_schema
        @default_schema ||= StructuredOutputs::Schema.new("task_output") do |schema|
          # Simple, flexible schema for task results
          schema.string(:status, enum: ["completed", "partial", "failed"])
          schema.object(:result) do |result_schema|
            result_schema.string(:summary)
            # Additional properties will be allowed for flexible task outputs
          end
          schema.array(:steps, items: {type: "string"})
        end
      end

      # Returns a simple object schema for maximum flexibility
      # @return [Agentic::StructuredOutputs::Schema] Simple object schema
      def simple_object_schema
        @simple_object_schema ||= StructuredOutputs::Schema.new("simple_object") do |schema|
          # Minimal schema that accepts any structured JSON object
          # This is useful when we want structured JSON but maximum flexibility
          schema.string(:type)
          schema.object(:data) do
            # Flexible data structure
          end
        end
      end

      # Returns a schema for code generation tasks
      # @return [Agentic::StructuredOutputs::Schema] Code generation schema
      def code_generation_schema
        @code_generation_schema ||= StructuredOutputs::Schema.new("code_generation") do |schema|
          schema.string(:language)
          schema.string(:filename)
          schema.string(:code)
          schema.string(:description)
          schema.array(:dependencies, items: {type: "string"})
        end
      end

      # Returns a schema for analysis/research tasks
      # @return [Agentic::StructuredOutputs::Schema] Analysis task schema
      def analysis_schema
        @analysis_schema ||= StructuredOutputs::Schema.new("analysis_result") do |schema|
          schema.string(:summary)
          schema.array(:key_findings, items: {type: "string"})
          schema.object(:data) do
            # Flexible analysis data
          end
          schema.array(:recommendations, items: {type: "string"})
          schema.string(:confidence_level, enum: ["high", "medium", "low"])
        end
      end

      # Resets all registered schemas (useful for testing)
      def reset!
        @schemas = {}
        @default_schema = nil
        @simple_object_schema = nil
        @code_generation_schema = nil
        @analysis_schema = nil
      end

      # Registers default schemas
      def register_defaults!
        register(:default, default_task_schema)
        register(:simple_object, simple_object_schema)
        register(:code_generation, code_generation_schema)
        register(:analysis, analysis_schema)
      end
    end

    # Register defaults when the class is loaded
    register_defaults!
  end
end
