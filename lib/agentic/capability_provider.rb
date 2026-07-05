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
      @validator = CapabilityValidator.new(capability)
    end

    # Execute the capability, enforcing its declared input/output contract
    # @param inputs [Hash] The inputs for the capability
    # @return [Hash] The outputs from the capability
    # @raise [Errors::ValidationError] when inputs or outputs violate the specification
    def execute(inputs = {})
      @validator.validate_inputs!(inputs)

      result = case @implementation
      when Proc
        @implementation.call(inputs)
      when Class
        instance = @implementation.new
        instance.execute(inputs)
      else
        raise ArgumentError, "Invalid implementation type: #{@implementation.class}"
      end

      @validator.validate_outputs!(result)

      result
    end
  end
end
