# frozen_string_literal: true

# The RBS Export: a capability contract already knows its types -
# it validates them at runtime on every call. RBS is the same
# knowledge written down for tools that read instead of run: steep,
# IDEs, docs. This generates .rbs signatures from contracts, so the
# type checker and the validator can never disagree - they're
# projections of one declaration.
#
#   bundle exec ruby examples/rbs_export.rb
#
# Runs offline; the signatures are printed and self-checked.

require_relative "../lib/agentic"

# Contract type -> RBS type. Optional inputs may be omitted entirely,
# so they project as optional KEYS (key: ?), while nilability is a
# separate question the contract answers with its type check.
RBS_TYPES = {
  "string" => "String", "number" => "Numeric", "integer" => "Integer",
  "boolean" => "bool", "array" => "Array[untyped]", "object" => "Hash[Symbol, untyped]",
  "hash" => "Hash[Symbol, untyped]", nil => "untyped"
}.freeze

def rbs_record(declared)
  fields = declared.map { |key, decl|
    marker = decl[:required] ? "" : "?"
    "#{marker}#{key}: #{RBS_TYPES.fetch(decl[:type], "untyped")}"
  }
  "{ #{fields.join(", ")} }"
end

def to_rbs(spec)
  method_name = spec.name.gsub(/[^a-z0-9_]/, "_")
  <<~RBS
    # #{spec.description} (v#{spec.version})
    # Enum/bounds/rules are enforced at runtime by CapabilityValidator;
    # RBS carries the SHAPE, the validator carries the LAW.
    class #{method_name.split("_").map(&:capitalize).join}Capability
      def call: (#{rbs_record(spec.inputs)} inputs) -> #{rbs_record(spec.outputs)}
    end
  RBS
end

SPECS = [
  Agentic::CapabilitySpecification.new(
    name: "quote_shipping", description: "Quote a shipment", version: "2.1.0",
    inputs: {
      mode: {type: "string", required: true, enum: %w[air sea road]},
      weight_kg: {type: "number", required: true, min: 1, max: 5_000},
      express: {type: "boolean"},
      customs_code: {type: "string"}
    },
    outputs: {price_cents: {type: "integer", required: true}, carrier: {type: "string", required: true}}
  ),
  Agentic::CapabilitySpecification.new(
    name: "classify_ticket", description: "Route a ticket", version: "1.1.0",
    inputs: {text: {type: "string", required: true, non_empty: true}, urgency: {type: "number"}},
    outputs: {queue: {type: "string", required: true}}
  )
].freeze

puts "THE RBS EXPORT (contracts already know their types; write them down)"
puts
SPECS.each do |spec|
  to_rbs(spec).lines.each { |line| puts "  #{line}" }
  puts
end

# --- the agreement check: what RBS says optional, the validator permits ---------
# (Same discipline as round 10's projection prover: two renderings of
# one declaration must be spot-checked against each other.)
spec = SPECS.first
validator = Agentic::CapabilityValidator.new(spec)
optional_omitted = {mode: "air", weight_kg: 100} # express, customs_code omitted
required_omitted = {mode: "air"}                 # weight_kg missing

validator.validate_inputs!(optional_omitted)
agreement_a = true
agreement_b = begin
  validator.validate_inputs!(required_omitted)
  false # validator allowed what RBS marks required - disagreement!
rescue Agentic::Errors::ValidationError
  true
end

puts "  agreement spot-check against the validator:"
puts "    omitting ?-marked keys (express, customs_code): accepted  #{agreement_a ? "- agrees" : "DISAGREES"}"
puts "    omitting an unmarked key (weight_kg):           rejected  #{agreement_b ? "- agrees" : "DISAGREES"}"
puts
puts "  the division of labor, stated precisely: RBS carries the SHAPE"
puts "  (keys, types, optionality - what steep and your IDE can check"
puts "  before anything runs), and the validator carries the LAW (enums,"
puts "  bounds, cross-field rules - what needs values to judge). neither"
puts "  replaces the other; both project from ONE declaration, which is"
puts "  why they cannot drift the way hand-written sig files against"
puts "  hand-written validations always, always do. gradual typing works"
puts "  when the types come from where the truth already lives."
exit((agreement_a && agreement_b) ? 0 : 1)
