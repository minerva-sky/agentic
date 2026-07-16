# frozen_string_literal: true

module Agentic
  module Configuration
    # Comprehensive schema validation system for all Agentic configurations
    #
    # Provides type checking, constraint validation, and extensible schema definitions
    # for configuration objects throughout the framework.
    #
    # Design Goals:
    # 1. Type-safe configuration validation with clear error messages
    # 2. Extensible schema system for plugins and domain adapters
    # 3. Performance-optimized validation with caching
    # 4. Support for nested configurations and complex data structures
    # 5. Migration support for configuration evolution
    #
    # Architect Team Guidance:
    # - Taylor Kim (Agent Systems Engineer): Plugin architecture integration
    # - Riley Park (Ruby Ecosystem Expert): Ruby-idiomatic design patterns
    class Schema
      # Schema validation errors
      class ValidationError < StandardError
        attr_reader :field, :value, :constraint

        def initialize(message, field: nil, value: nil, constraint: nil)
          super(message)
          @field = field
          @value = value
          @constraint = constraint
        end
      end

      # Supported field types for validation
      FIELD_TYPES = {
        string: String,
        integer: Integer,
        float: Float,
        boolean: ->(v) { [true, false].include?(v) },
        array: Array,
        hash: Hash,
        symbol: Symbol,
        time: Time,
        regexp: Regexp,
        any: ->(v) { true }
      }.freeze

      attr_reader :fields, :name, :version

      def initialize(name, version: "1.0.0")
        @name = name
        @version = version
        @fields = {}
        @validations = {}
        @defaults = {}
        @computed_fields = {}
        @nested_schemas = {}
      end

      # Define a field in the schema
      # @param field_name [Symbol] Name of the field
      # @param type [Symbol, Class, Proc] Type constraint for the field
      # @param required [Boolean] Whether the field is required
      # @param default [Object, Proc] Default value or callable
      # @param constraints [Array<Proc>] Additional validation constraints
      # @param description [String] Human-readable description
      # @param example [Object] Example value for documentation
      def field(field_name, type:, required: false, default: nil, constraints: [], description: nil, example: nil)
        field_name = field_name.to_sym

        @fields[field_name] = {
          type: type,
          required: required,
          constraints: Array(constraints),
          description: description,
          example: example
        }

        @defaults[field_name] = default if default

        self
      end

      # Define a nested schema field
      # @param field_name [Symbol] Name of the nested field
      # @param schema [Schema] The nested schema
      # @param required [Boolean] Whether the field is required
      # @param array [Boolean] Whether this is an array of the schema type
      def nested(field_name, schema, required: false, array: false)
        field_name = field_name.to_sym

        @nested_schemas[field_name] = {
          schema: schema,
          array: array
        }

        # Type/required checks live on the field; the detailed per-item
        # validation (with contextual error messages) is handled by
        # #validate_nested_field! so no boolean constraint is added here.
        field(
          field_name,
          type: array ? Array : Hash,
          required: required
        )

        self
      end

      # Define a computed field based on other fields
      # @param field_name [Symbol] Name of the computed field
      # @param dependencies [Array<Symbol>] Fields this computation depends on
      # @param block [Proc] Computation logic
      def computed(field_name, dependencies: [], &block)
        field_name = field_name.to_sym

        @computed_fields[field_name] = {
          dependencies: dependencies,
          compute: block
        }

        self
      end

      # Add a cross-field validation
      # @param message [String] Error message for validation failure
      # @param block [Proc] Validation logic that receives the full config hash
      def validate(message, &block)
        @validations[message] = block
        self
      end

      # Validate a configuration hash against this schema
      # @param config [Hash] The configuration to validate
      # @param strict [Boolean] Whether to reject unknown fields
      # @return [Boolean] True if valid
      # @raise [ValidationError] If validation fails
      def validate!(config, strict: false)
        config = symbolize_keys(config)

        # Check for unknown fields in strict mode
        if strict
          unknown_fields = config.keys - @fields.keys - @computed_fields.keys
          unless unknown_fields.empty?
            raise ValidationError.new("Unknown fields: #{unknown_fields.join(", ")}")
          end
        end

        # Check required fields
        missing_required = @fields.select { |name, opts| opts[:required] }.keys - config.keys
        unless missing_required.empty?
          raise ValidationError.new("Missing required fields: #{missing_required.join(", ")}")
        end

        # Validate individual fields
        @fields.each do |field_name, field_spec|
          next unless config.key?(field_name)

          value = config[field_name]
          validate_field!(field_name, value, field_spec)
        end

        # Validate nested schemas
        @nested_schemas.each do |field_name, nested_spec|
          next unless config.key?(field_name)

          value = config[field_name]
          validate_nested_field!(field_name, value, nested_spec)
        end

        # Run cross-field validations
        @validations.each do |message, validation_proc|
          unless validation_proc.call(config)
            raise ValidationError.new(message)
          end
        end

        true
      end

      # Check if a configuration is valid
      # @param config [Hash] The configuration to check
      # @param strict [Boolean] Whether to reject unknown fields
      # @return [Boolean] True if valid, false otherwise
      def valid?(config, strict: false)
        validate!(config, strict: strict)
        true
      rescue ValidationError
        false
      end

      # Apply defaults and compute derived values
      # @param config [Hash] The base configuration
      # @return [Hash] Configuration with defaults and computed values
      def apply_defaults(config)
        config = symbolize_keys(config)
        result = config.dup

        # Apply default values
        @defaults.each do |field_name, default_value|
          unless result.key?(field_name)
            result[field_name] = default_value.respond_to?(:call) ? default_value.call : default_value
          end
        end

        # Compute derived fields
        @computed_fields.each do |field_name, computation|
          # Check if all dependencies are available
          missing_deps = computation[:dependencies] - result.keys
          unless missing_deps.empty?
            raise ValidationError.new(
              "Cannot compute #{field_name}: missing dependencies #{missing_deps.join(", ")}"
            )
          end

          # Compute the value
          dependency_values = computation[:dependencies].map { |dep| result[dep] }
          result[field_name] = computation[:compute].call(result, *dependency_values)
        end

        result
      end

      # Get schema documentation
      # @return [Hash] Human-readable schema documentation
      def documentation
        {
          name: @name,
          version: @version,
          fields: @fields.transform_values do |field_spec|
            {
              type: field_spec[:type],
              required: field_spec[:required],
              description: field_spec[:description],
              example: field_spec[:example]
            }.compact
          end,
          nested_schemas: @nested_schemas.transform_values do |nested_spec|
            {
              schema_name: nested_spec[:schema].name,
              array: nested_spec[:array]
            }
          end,
          computed_fields: @computed_fields.keys,
          validations: @validations.keys
        }
      end

      # Create a configuration instance with validation and defaults
      # @param config [Hash] Raw configuration data
      # @param strict [Boolean] Whether to reject unknown fields
      # @return [ConfigurationInstance] Validated and processed configuration
      def create(config = {}, strict: false)
        processed_config = apply_defaults(config)
        validate!(processed_config, strict: strict)

        ConfigurationInstance.new(processed_config, self)
      end

      private

      # Validate individual field against its specification
      def validate_field!(field_name, value, field_spec)
        type_constraint = field_spec[:type]

        # Type validation
        unless type_valid?(value, type_constraint)
          expected_type = case type_constraint
          when Symbol then type_constraint
          when Class then type_constraint.name
          else "custom"
          end
          raise ValidationError.new(
            "Field #{field_name} must be of type #{expected_type}, got #{value.class.name}",
            field: field_name,
            value: value,
            constraint: :type
          )
        end

        # Additional constraint validation
        field_spec[:constraints].each_with_index do |constraint, index|
          unless constraint.call(value)
            raise ValidationError.new(
              "Field #{field_name} failed validation constraint #{index + 1}",
              field: field_name,
              value: value,
              constraint: constraint
            )
          end
        end
      end

      # Validate nested schema field
      def validate_nested_field!(field_name, value, nested_spec)
        schema = nested_spec[:schema]
        is_array = nested_spec[:array]

        if is_array
          unless value.is_a?(Array)
            raise ValidationError.new(
              "Field #{field_name} must be an array",
              field: field_name,
              value: value
            )
          end

          value.each_with_index do |item, index|
            schema.validate!(schema.apply_defaults(item))
          rescue ValidationError => e
            raise ValidationError.new(
              "Field #{field_name}[#{index}]: #{e.message}",
              field: field_name,
              value: item
            )
          end
        else
          begin
            schema.validate!(schema.apply_defaults(value))
          rescue ValidationError => e
            raise ValidationError.new(
              "Field #{field_name}: #{e.message}",
              field: field_name,
              value: value
            )
          end
        end
      end

      # Check if value matches type constraint
      def type_valid?(value, type_constraint)
        case type_constraint
        when Symbol
          validator = FIELD_TYPES[type_constraint]
          return false unless validator

          if validator.respond_to?(:call)
            validator.call(value)
          else
            value.is_a?(validator)
          end
        when Class
          value.is_a?(type_constraint)
        when Proc
          type_constraint.call(value)
        else
          false
        end
      end

      # Convert string keys to symbols recursively
      def symbolize_keys(hash)
        return hash unless hash.is_a?(Hash)

        hash.transform_keys(&:to_sym).transform_values do |value|
          if value.is_a?(Hash)
            symbolize_keys(value)
          elsif value.is_a?(Array)
            value.map { |item| item.is_a?(Hash) ? symbolize_keys(item) : item }
          else
            value
          end
        end
      end
    end

    # Configuration instance with validated data and schema reference
    class ConfigurationInstance
      attr_reader :data, :schema

      def initialize(data, schema)
        @data = data.freeze
        @schema = schema
      end

      # Access configuration values
      def [](key)
        @data[key.to_sym]
      end

      # Get configuration value with default
      def get(key, default = nil)
        @data.fetch(key.to_sym, default)
      end

      # Check if configuration has a key
      def key?(key)
        @data.key?(key.to_sym)
      end

      # Get all configuration keys
      def keys
        @data.keys
      end

      # Get all configuration values
      def values
        @data.values
      end

      # Convert to hash
      def to_h
        @data.dup
      end

      # Convert to JSON
      def to_json(**args)
        @data.to_json(**args)
      end

      # Create a new instance with merged configuration
      def merge(other_config)
        new_data = @data.merge(symbolize_keys(other_config))
        @schema.create(new_data)
      end

      # Validate current configuration
      def valid?
        @schema.valid?(@data)
      end

      private

      def symbolize_keys(hash)
        return hash unless hash.is_a?(Hash)
        hash.transform_keys(&:to_sym)
      end
    end
  end
end
