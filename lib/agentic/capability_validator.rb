# frozen_string_literal: true

require "dry/schema"

module Agentic
  # Enforces a capability's declared input/output contract using dry-schema.
  #
  # A CapabilitySpecification declares its boundary as data:
  #
  #   inputs: {prompt: {type: "string", required: true}}
  #
  # This class turns that declaration into a real schema, so the types
  # written in a specification are checked rather than decorative. Unknown
  # keys are permitted - a capability may accept more than it declares -
  # but every declared key must honor its declared type, and required keys
  # must be present.
  class CapabilityValidator
    # @param specification [CapabilitySpecification] The capability specification
    def initialize(specification)
      @specification = specification
      @schemas = {}
    end

    # Validates inputs against the capability's declared inputs
    # @param inputs [Hash] The inputs to validate
    # @return [void]
    # @raise [Errors::ValidationError] listing every violation
    def validate_inputs!(inputs)
      validate!(:inputs, @specification.inputs, inputs)
    end

    # Validates outputs against the capability's declared outputs
    # @param outputs [Hash, nil] The outputs to validate (nil is skipped)
    # @return [void]
    # @raise [Errors::ValidationError] listing every violation
    def validate_outputs!(outputs)
      return if outputs.nil?

      validate!(:outputs, @specification.outputs, outputs)
    end

    private

    def validate!(kind, declared, values)
      return if declared.nil? || declared.empty?

      result = schema_for(kind, declared).call(symbolize_keys(values))
      return if result.success?

      raise Errors::ValidationError.new(
        capability: @specification.name,
        kind: kind,
        violations: result.errors.to_h
      )
    end

    def schema_for(kind, declared)
      @schemas[kind] ||= Dry::Schema.define do
        declared.each do |name, definition|
          definition ||= {}
          key = definition[:required] ? required(name.to_sym) : optional(name.to_sym)

          # Beyond type and presence, declarations may constrain values:
          #   enum: [...]      - value must be one of these
          #   min:/max:        - numeric bounds (inclusive)
          #   non_empty: true  - strings/arrays must not be empty
          predicates = {}
          predicates[:included_in?] = definition[:enum] if definition[:enum]
          predicates[:gteq?] = definition[:min] if definition[:min]
          predicates[:lteq?] = definition[:max] if definition[:max]
          predicates[:min_size?] = 1 if definition[:non_empty]

          case definition[:type]
          when "string" then key.value(:string, **predicates)
          when "number", "integer" then key.value(type?: Numeric, **predicates)
          when "boolean" then key.value(:bool, **predicates)
          when "array" then key.value(:array, **predicates)
          when "object", "hash" then key.value(:hash, **predicates)
          else key.value(type?: Object, **predicates)
          end
        end
      end
    end

    def symbolize_keys(values)
      values.to_h { |key, value| [key.to_sym, value] }
    end
  end
end
