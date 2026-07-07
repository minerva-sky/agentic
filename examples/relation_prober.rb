# frozen_string_literal: true

# The Relation Prober: relation-typed rules are new, and new
# predicates deserve hostility. Each relation is probed with edge
# inputs - zeros, negatives, floats, missing keys, nils - and every
# verdict is checked against an independent hand-written oracle.
# The prober also walks off the paved road on purpose: a rule that
# references an undeclared field meets a string, and the resulting
# TypeError escapes raw. Exit 1 by design - the sharp edge is real.
#
#   bundle exec ruby examples/relation_prober.rb
#
# Runs offline; exits 1 because the last probe draws blood.

require_relative "../lib/agentic"

def spec_for(rules, inputs)
  Agentic::CapabilitySpecification.new(
    name: "probe", description: "probe", version: "1.0.0", inputs: inputs, rules: rules
  )
end

def verdict(spec, payload)
  Agentic::CapabilityValidator.new(spec).validate_inputs!(payload)
  :allow
rescue Agentic::Errors::ValidationError
  :reject
end

NUMERIC = {a: {type: "number"}, b: {type: "number"}}.freeze
STRINGS = {x: {type: "string"}, y: {type: "string"}}.freeze

# Each probe: [description, spec, payload, oracle verdict]
PROBES = [
  ["sum_lte: both at zero", spec_for({r: {relation: :sum_lte, fields: [:a, :b], limit: 0}}, NUMERIC),
    {a: 0, b: 0}, :allow],
  ["sum_lte: exactly at the limit", spec_for({r: {relation: :sum_lte, fields: [:a, :b], limit: 10}}, NUMERIC),
    {a: 4, b: 6}, :allow],
  ["sum_lte: one over, via floats", spec_for({r: {relation: :sum_lte, fields: [:a, :b], limit: 10}}, NUMERIC),
    {a: 4.5, b: 5.6}, :reject],
  ["sum_lte: negative rescues the sum", spec_for({r: {relation: :sum_lte, fields: [:a, :b], limit: 10}}, NUMERIC),
    {a: 15, b: -6}, :allow],
  ["sum_lte: missing field counts as 0", spec_for({r: {relation: :sum_lte, fields: [:a, :b], limit: 10}}, NUMERIC),
    {a: 7}, :allow],
  ["requires: trigger absent", spec_for({r: {relation: :requires, fields: [:x, :y]}}, STRINGS),
    {y: "alone is fine"}, :allow],
  ["requires: trigger present, need met", spec_for({r: {relation: :requires, fields: [:x, :y]}}, STRINGS),
    {x: "t", y: "met"}, :allow],
  ["requires: trigger present, need missing", spec_for({r: {relation: :requires, fields: [:x, :y]}}, STRINGS),
    {x: "t"}, :reject],
  ["requires: three-field chain broken", spec_for({r: {relation: :requires, fields: [:x, :y, :z]}}, STRINGS.merge(z: {type: "string"})),
    {x: "t", y: "met"}, :reject],
  ["mutually_exclusive: neither", spec_for({r: {relation: :mutually_exclusive, fields: [:x, :y]}}, STRINGS),
    {}, :allow],
  ["mutually_exclusive: one", spec_for({r: {relation: :mutually_exclusive, fields: [:x, :y]}}, STRINGS),
    {x: "only"}, :allow],
  ["mutually_exclusive: both", spec_for({r: {relation: :mutually_exclusive, fields: [:x, :y]}}, STRINGS),
    {x: "one", y: "two"}, :reject],
  ["mutually_exclusive: empty string is present", spec_for({r: {relation: :mutually_exclusive, fields: [:x, :y]}}, STRINGS),
    {x: "", y: "two"}, :reject]
].freeze

puts "RELATION PROBER (#{PROBES.size} probes against a hand-written oracle)"
puts
divergences = 0
PROBES.each do |description, spec, payload, oracle|
  actual = verdict(spec, payload)
  divergences += 1 if actual != oracle
  puts format("  %-42s oracle: %-7s got: %-7s %s",
    description, oracle, actual, (actual == oracle) ? "ok" : "DIVERGED")
end

puts
puts "  #{PROBES.size} probes, #{divergences} divergence(s) on the paved road."
puts

# --- off the paved road ---------------------------------------------------------
# A rule may reference a field the contract never declared. Per-key
# validation can't type-check what isn't declared, so a string sails
# through to sum_lte's arithmetic - and the failure is a raw
# TypeError, not a ValidationError. Callers rescuing the documented
# error class will not catch this.
sharp = spec_for(
  {r: {relation: :sum_lte, fields: [:a, :undeclared], limit: 10}},
  {a: {type: "number"}}
)
puts "  off the road: sum_lte over an UNDECLARED field, fed a string"
begin
  Agentic::CapabilityValidator.new(sharp).validate_inputs!(a: 5, undeclared: "5")
  puts "    ...allowed?! the prober expected blood and found none"
  exit(divergences.zero? ? 0 : 1)
rescue Agentic::Errors::ValidationError
  puts "    rejected with ValidationError - the edge has been filed down"
  exit(divergences.zero? ? 0 : 1)
rescue TypeError => e
  puts "    RAW #{e.class}: #{e.message.inspect}"
  puts
  puts "    a validator's one job is to convert bad input into its OWN"
  puts "    error type. here, bad input crashes the validator instead -"
  puts "    rescue Agentic::Errors::ValidationError won't catch it, so"
  puts "    the 422 path becomes a 500 path. filed as the round-11 ask:"
  puts "    relation rules must either type-check their fields at"
  puts "    declaration time or wrap evaluation failures. exit 1 until."
  exit(1)
end
