# frozen_string_literal: true

# The Projection Agreement Prover: relation rules now render twice -
# the validator enforces them in Ruby, and to_json_schema projects
# them into draft-07 keywords (dependencies, not-required). Two
# renderings of one law can drift, so this prover evaluates BOTH
# against every presence combination and demands they agree. It also
# walks to the exact frontier where they don't: JSON's null.
#
#   bundle exec ruby examples/projection_agreement.rb
#
# Runs offline; exits 1 if the projections disagree on the nil-free plane.

require_relative "../lib/agentic"

SPEC = Agentic::CapabilitySpecification.new(
  name: "connect", description: "Connect an integration", version: "1.0.0",
  inputs: {
    express: {type: "boolean"},
    customs_code: {type: "string"},
    api_key: {type: "string"},
    oauth_token: {type: "string"}
  },
  rules: {
    customs: {relation: :requires, fields: [:express, :customs_code]},
    one_auth: {relation: :mutually_exclusive, fields: [:api_key, :oauth_token]}
  }
)

VALUES = {express: true, customs_code: "HS-1", api_key: "k", oauth_token: "t"}.freeze

# A four-line draft-07 evaluator for exactly the projected keywords
def schema_allows?(schema, payload)
  keys = payload.keys.map(&:to_s)
  (schema["dependencies"] || {}).each do |trigger, needed|
    return false if keys.include?(trigger) && !(needed - keys).empty?
  end
  (schema["allOf"] || []).each do |clause|
    required = clause.dig("not", "required")
    return false if required && (required - keys).empty?
  end
  true
end

def validator_allows?(validator, payload)
  validator.validate_inputs!(payload)
  true
rescue Agentic::Errors::ValidationError
  false
end

schema = SPEC.to_json_schema
validator = Agentic::CapabilityValidator.new(SPEC)
fields = VALUES.keys

puts "PROJECTION AGREEMENT PROVER (#{fields.size} fields -> #{2**fields.size} presence combinations)"
puts

disagreements = 0
(0...2**fields.size).each do |mask|
  payload = fields.each_with_index.select { |_, i| mask[i] == 1 }.to_h { |f, _| [f, VALUES[f]] }
  ruby = validator_allows?(validator, payload)
  json = schema_allows?(schema, payload)
  disagreements += 1 if ruby != json

  next unless ruby != json || !ruby # print the interesting rows only

  puts format("  {%-40s} validator: %-6s schema: %-6s %s",
    payload.keys.join(", "), ruby ? "allow" : "reject", json ? "allow" : "reject",
    (ruby == json) ? "agree" : "DISAGREE")
end

puts
puts "  #{2**fields.size} combinations, #{disagreements} disagreement(s) - the dependencies and"
puts "  not-required clauses say exactly what the validator enforces,"
puts "  proven point by point rather than asserted."
puts

# --- the frontier: explicit nulls ---------------------------------------------
# Ruby's relation presence is "given and non-nil"; JSON Schema's
# dependencies trigger on the PROPERTY existing, null or not. Two
# metaphysics of absence - walk to the exact spot where they part.
#
# First discovery: for TYPED fields the frontier is guarded. An
# explicit nil never reaches the relation check, because per-key
# typing rejects it first ("must be boolean"), and the schema rejects
# it too (dependencies fire) - agreement, but for different reasons.
frontier = {express: nil}
puts "  the frontier: {express: nil}"
puts format("    typed field:   validator %-7s (per-key: nil isn't a boolean)", validator_allows?(validator, frontier) ? "allows" : "rejects")
puts format("                   schema    %-7s (the property EXISTS - dependencies fire)", schema_allows?(schema, frontier) ? "allows" : "rejects")

# The TRUE divergence needs an untyped field, where nil sails past
# per-key checks and the two presence semantics finally face off
untyped = Agentic::CapabilitySpecification.new(
  name: "connect", description: "x", version: "1.0.0",
  inputs: {express: {}, customs_code: {type: "string"}},
  rules: {customs: {relation: :requires, fields: [:express, :customs_code]}}
)
ruby = validator_allows?(Agentic::CapabilityValidator.new(untyped), frontier)
json = schema_allows?(untyped.to_json_schema, frontier)
puts format("    untyped field: validator %-7s (nil is ABSENT - rule not triggered)", ruby ? "allows" : "rejects")
puts format("                   schema    %-7s (null is PRESENT - rule fires)", json ? "allows" : "rejects")
puts
puts "  on the nil-free plane the projection is faithful, point by point."
puts "  explicit null is where Ruby's nil and JSON's null part ways - but"
puts "  only for UNTYPED fields, because typing guards the frontier."
puts "  senders: omit keys, don't null them. (filed as the round-11 ask:"
puts "  align or officially document presence semantics at the boundary.)"

exit(disagreements.zero? ? 0 : 1)
