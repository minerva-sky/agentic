# frozen_string_literal: true

module Agentic
  module Errors
    # Raised when a capability's inputs or outputs violate its declared
    # specification. Collects every violation instead of failing on the
    # first, so callers can fix a bad payload in one round trip.
    class ValidationError < StandardError
      # @return [String] The capability whose contract was violated
      attr_reader :capability

      # @return [Symbol] Which side of the contract failed (:inputs or :outputs)
      attr_reader :kind

      # @return [Hash{Symbol=>Array<String>}] Violation messages keyed by attribute
      attr_reader :violations

      # @param capability [String] The capability name
      # @param kind [Symbol] :inputs or :outputs
      # @param violations [Hash{Symbol=>Array<String>}] Messages keyed by attribute
      def initialize(capability:, kind:, violations:)
        @capability = capability
        @kind = kind
        @violations = violations

        details = violations.map { |key, messages| "#{key} #{Array(messages).join(", ")}" }.join("; ")
        super("Invalid #{kind} for capability '#{capability}': #{details}")
      end
    end
  end
end
