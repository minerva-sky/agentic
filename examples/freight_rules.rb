# frozen_string_literal: true

# The Freight Desk: a quoting capability whose tariff book is written
# as cross-field contract rules (new this round). Per-key checks catch
# nonsense; rules: catch the LEGAL-LOOKING orders that violate policy -
# and every broken rule is reported at once, because a shipper fixing
# their manifest deserves the whole list, not a scavenger hunt.
#
#   bundle exec ruby examples/freight_rules.rb
#
# Runs offline and deterministically.

require_relative "../lib/agentic"

spec = Agentic::CapabilitySpecification.new(
  name: "quote_freight",
  description: "Quote a freight shipment",
  version: "1.0.0",
  inputs: {
    mode: {type: "string", required: true, enum: %w[air sea road]},
    weight_kg: {type: "number", required: true, min: 1, max: 30_000},
    hazardous: {type: "boolean", required: true},
    insured_value: {type: "number", required: true, min: 0},
    destination: {type: "string", required: true, non_empty: true}
  },
  rules: {
    "air freight is limited to 500kg" =>
      ->(i) { i[:mode] != "air" || i[:weight_kg] <= 500 },
    "hazardous cargo may not fly" =>
      ->(i) { !(i[:mode] == "air" && i[:hazardous]) },
    "insured value over 100k requires sea mode" =>
      ->(i) { i[:insured_value] <= 100_000 || i[:mode] == "sea" },
    "road freight only reaches domestic destinations" =>
      ->(i) { i[:mode] != "road" || i[:destination].start_with?("domestic:") }
  }
)

RATES = {"air" => 4.20, "sea" => 0.30, "road" => 1.10}.freeze
Agentic.register_capability(spec, Agentic::CapabilityProvider.new(
  capability: spec,
  implementation: ->(i) { {quote: (i[:weight_kg] * RATES.fetch(i[:mode])).round(2)} }
))

desk = Agentic::AgentCapabilityRegistry.instance.get_provider("quote_freight")

MANIFESTS = [
  {mode: "sea", weight_kg: 12_000, hazardous: true, insured_value: 250_000, destination: "port of rotterdam"},
  {mode: "air", weight_kg: 480, hazardous: false, insured_value: 20_000, destination: "berlin"},
  {mode: "air", weight_kg: 900, hazardous: true, insured_value: 150_000, destination: "tokyo"},
  {mode: "road", weight_kg: 2_000, hazardous: false, insured_value: 5_000, destination: "domestic:austin"},
  {mode: "teleport", weight_kg: -5, hazardous: false, insured_value: 10, destination: ""}
].freeze

puts "THE FREIGHT DESK (#{spec.rules.size} tariff rules on the contract)"
puts
MANIFESTS.each_with_index do |manifest, index|
  quote = desk.execute(manifest)
  puts format("  #%d QUOTED  $%.2f  (%s, %dkg)", index + 1, quote[:quote], manifest[:mode], manifest[:weight_kg])
rescue Agentic::Errors::ValidationError => e
  if e.violations.key?(:base)
    puts "  ##{index + 1} REFUSED - #{e.violations[:base].size} rule(s) broken:"
    e.violations[:base].each { |rule| puts "       - #{rule}" }
  else
    puts "  ##{index + 1} MALFORMED - #{e.violations.keys.join(", ")} invalid " \
      "(never reached the tariff book)"
  end
end

puts
puts "manifest #3 broke THREE rules and heard about all three at once."
puts "manifest #5 never reached the tariff book: per-key validation"
puts "rejects nonsense before cross-field rules spend time on it."
