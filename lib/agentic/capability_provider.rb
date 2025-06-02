# frozen_string_literal: true

module Agentic
  # Provider for a capability implementation
  # @attr_reader [CapabilitySpecification] capability The capability specification
  # @attr_reader [Proc, Class] implementation The implementation of the capability
  class CapabilityProvider
    attr_reader :capability, :implementation

    # Initialize a new capability provider
    # @param capability [CapabilitySpecification] The capability specification
    # @param implementation [Proc, Class] The implementation of the capability
    def initialize(capability:, implementation:)
      @capability = capability
      @implementation = implementation
    end

    # Execute the capability
    # @param inputs [Hash] The inputs for the capability
    # @return [Hash] The outputs from the capability
    def execute(inputs = {})
      # Validate inputs against capability specification
      validate_inputs!(inputs)

      # Execute the implementation
      result = case @implementation
      when Proc
        @implementation.call(inputs)
      when Class
        instance = @implementation.new
        instance.execute(inputs)
      else
        raise "Invalid implementation type: #{@implementation.class}"
      end

      # Validate outputs against capability specification
      validate_outputs!(result)

      result
    end

    private

    def validate_inputs!(inputs)
      # Skip validation if there are no input specifications
      return unless @capability.inputs && !@capability.inputs.empty?

      # Check for required inputs
      @capability.inputs.each do |name, spec|
        if spec[:required] && !inputs.key?(name.to_sym) && !inputs.key?(name.to_s)
          raise "Missing required input: #{name}"
        end
      end

      # Validate input types (if specified)
      inputs.each do |name, value|
        name_sym = name.to_sym
        name_str = name.to_s

        # Skip inputs that aren't in the specification
        next unless @capability.inputs.key?(name_sym) || @capability.inputs.key?(name_str)

        # Get the spec for this input
        input_spec = @capability.inputs[name_sym] || @capability.inputs[name_str]

        # Skip if no type is specified
        next unless input_spec[:type]

        # Check type
        case input_spec[:type]
        when "string"
          unless value.is_a?(String)
            raise "Input #{name} must be a string"
          end
        when "number", "integer"
          unless value.is_a?(Numeric)
            raise "Input #{name} must be a number"
          end
        when "boolean"
          unless value == true || value == false
            raise "Input #{name} must be a boolean"
          end
        when "array"
          unless value.is_a?(Array)
            raise "Input #{name} must be an array"
          end
        when "object", "hash"
          unless value.is_a?(Hash)
            raise "Input #{name} must be an object/hash"
          end
        end
      end
    end

    def validate_outputs!(outputs)
      # Skip validation if there are no output specifications or the output is nil
      return unless @capability.outputs && !@capability.outputs.empty? && outputs

      # Check for required outputs
      @capability.outputs.each do |name, spec|
        if spec[:required] && !outputs.key?(name.to_sym) && !outputs.key?(name.to_s)
          raise "Missing required output: #{name}"
        end
      end

      # Validate output types (if specified)
      outputs.each do |name, value|
        name_sym = name.to_sym
        name_str = name.to_s

        # Skip outputs that aren't in the specification
        next unless @capability.outputs.key?(name_sym) || @capability.outputs.key?(name_str)

        # Get the spec for this output
        output_spec = @capability.outputs[name_sym] || @capability.outputs[name_str]

        # Skip if no type is specified
        next unless output_spec[:type]

        # Check type
        case output_spec[:type]
        when "string"
          unless value.is_a?(String)
            raise "Output #{name} must be a string"
          end
        when "number", "integer"
          unless value.is_a?(Numeric)
            raise "Output #{name} must be a number"
          end
        when "boolean"
          unless value == true || value == false
            raise "Output #{name} must be a boolean"
          end
        when "array"
          unless value.is_a?(Array)
            raise "Output #{name} must be an array"
          end
        when "object", "hash"
          unless value.is_a?(Hash)
            raise "Output #{name} must be an object/hash"
          end
        end
      end
    end
  end
end
