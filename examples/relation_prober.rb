# frozen_string_literal: true

# The Relation Prober: relation-typed rules are new, and new
# predicates deserve hostility. Each relation is probed with edge
# inputs - zeros, negatives, floats, missing keys, nils - and every
# verdict is checked against an independent hand-written oracle.
# The prober also walks off the paved road on purpose: in round 10
# a rule referencing an undeclared field met a string and escaped as
# a raw TypeError; the round-11 release files that edge down, and
# this prober is the acceptance test that proves it stays down.
#
#   bundle exec ruby examples/relation_prober.rb
#
# Runs offline; exits 1 if any probe draws blood again.

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
# In round 10, a rule referencing an undeclared field let a string
# reach sum_lte's arithmetic: raw TypeError, a 422 path turned 500
# path. The round-11 fix refuses at CONSTRUCTION - the typo fails at
# boot, where it names itself, before any request can find it.
edges = {
  "sum_lte over an UNDECLARED field" =>
    [{r: {relation: :sum_lte, fields: [:a, :undeclared], limit: 10}}, {a: {type: "number"}}],
  "sum_lte over a declared STRING" =>
    [{r: {relation: :sum_lte, fields: [:a, :b], limit: 10}}, {a: {type: "number"}, b: {type: "string"}}],
  "requires with a typo'd field (fail-open)" =>
    [{r: {relation: :requires, fields: [:a, :customs_kode]}}, {a: {type: "number"}, customs_code: {type: "string"}}]
}

blood = 0
puts "  off the paved road: rules that must refuse to construct"
edges.each do |name, (rules, inputs)|
  Agentic::CapabilityValidator.new(spec_for(rules, inputs))
  blood += 1
  puts format("    %-42s CONSTRUCTED - the edge is back", name)
rescue ArgumentError => e
  puts format("    %-42s refused at boot: %s", name, e.message[0, 40] + "...")
rescue => e
  blood += 1
  puts format("    %-42s wrong uniform: %s", name, e.class)
end

puts
if divergences.zero? && blood.zero?
  puts "  the paved road holds and the roadside refuses construction."
  puts "  note the third edge: a typo'd field in requires used to fail"
  puts "  OPEN - the rule just never fired, which no test of valid inputs"
  puts "  would ever notice. now the typo can't boot. a validator's"
  puts "  errors must wear its uniform, and its typos must not compile."
else
  puts "  BLOOD DRAWN: #{divergences} divergence(s), #{blood} escaped edge(s)."
end
exit((divergences + blood).zero? ? 0 : 1)
