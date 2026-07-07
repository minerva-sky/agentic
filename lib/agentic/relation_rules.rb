# frozen_string_literal: true

module Agentic
  # Relation-typed cross-field rules: predicates declared as data.
  #
  # A structured rule with a relation: key names its predicate instead
  # of hiding it in a lambda, so validators can enforce it, generators
  # can satisfy it, schema exports can project it, and diff tools can
  # compare two versions of it:
  #
  #   rules: {
  #     fits: {relation: :sum_lte, fields: [:cpu, :memory], limit: 100},
  #     customs: {relation: :requires, fields: [:express, :customs_code]},
  #     one_auth: {relation: :mutually_exclusive, fields: [:api_key, :oauth_token]}
  #   }
  #
  # "Present" means the key is given with a non-nil value - the same
  # presence JSON Schema's dependencies keyword speaks about.
  module RelationRules
    SUPPORTED = %i[sum_lte requires mutually_exclusive].freeze

    module_function

    # Builds the predicate a relation declaration describes
    # @param definition [Hash] The rule definition ({relation:, fields:, ...})
    # @return [Proc] inputs -> Boolean
    # @raise [ArgumentError] For an unknown relation
    def check(definition)
      fields = definition.fetch(:fields)
      case definition[:relation]
      when :sum_lte
        limit = definition.fetch(:limit)
        ->(inputs) { fields.sum { |field| inputs[field] || 0 } <= limit }
      when :requires
        trigger, *needed = fields
        ->(inputs) { !present?(inputs, trigger) || needed.all? { |field| present?(inputs, field) } }
      when :mutually_exclusive
        ->(inputs) { fields.count { |field| present?(inputs, field) } <= 1 }
      else
        raise ArgumentError, "unknown rule relation #{definition[:relation].inspect} " \
          "(supported: #{SUPPORTED.map(&:inspect).join(", ")})"
      end
    end

    # A human message derived from the declaration itself, used when the
    # rule doesn't supply one
    # @param definition [Hash] The rule definition
    # @return [String]
    def message(definition)
      fields = definition.fetch(:fields)
      case definition[:relation]
      when :sum_lte then "#{fields.join(" + ")} must total at most #{definition[:limit]}"
      when :requires then "#{fields.first} requires #{fields.drop(1).join(", ")}"
      when :mutually_exclusive then "at most one of #{fields.join(", ")} may be given"
      end
    end

    # @param inputs [Hash] Symbolized inputs
    # @param field [Symbol] The field to test
    # @return [Boolean] True when the key is given with a non-nil value
    def present?(inputs, field)
      inputs.key?(field) && !inputs[field].nil?
    end
  end
end
