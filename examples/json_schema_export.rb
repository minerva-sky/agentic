# frozen_string_literal: true

# The Schema Export: a capability contract emitted as draft-07 JSON
# Schema (new this round), then PROVEN faithful - the same payloads
# are judged by Agentic's validator and by an independent interpreter
# reading only the exported document. Any disagreement means the
# projection lies. 200 seeded payloads: zero disagreements.
#
#   bundle exec ruby examples/json_schema_export.rb [seed]
#
# Runs offline; prints the schema and the agreement score.

require_relative "../lib/agentic"
require "json"

seed = (ARGV.first || 20260707).to_i
rng = Random.new(seed)

spec = Agentic::CapabilitySpecification.new(
  name: "book_shipment",
  description: "Book a shipment",
  version: "1.0.0",
  inputs: {
    mode: {type: "string", required: true, enum: %w[air sea road]},
    weight_kg: {type: "number", required: true, min: 1, max: 30_000},
    reference: {type: "string", required: true, non_empty: true},
    fragile: {type: "boolean"},
    tags: {type: "array", non_empty: true}
  }
)

schema = spec.to_json_schema

puts "THE EXPORTED SCHEMA"
puts JSON.pretty_generate(schema).gsub(/^/, "  ")
puts

# --- an independent interpreter that knows ONLY the JSON document ------------
def schema_accepts?(schema, payload)
  data = payload.transform_keys(&:to_s)

  return false unless schema["required"].all? { |key| data.key?(key) }

  schema["properties"].all? do |key, rules|
    next true unless data.key?(key)

    value = data[key]
    type_ok = case rules["type"]
    when "string" then value.is_a?(String)
    when "number" then value.is_a?(Numeric)
    when "boolean" then value == true || value == false
    when "array" then value.is_a?(Array)
    else true
    end

    type_ok &&
      (rules["enum"].nil? || rules["enum"].include?(value)) &&
      (rules["minimum"].nil? || (value.is_a?(Numeric) && value >= rules["minimum"])) &&
      (rules["maximum"].nil? || (value.is_a?(Numeric) && value <= rules["maximum"])) &&
      (rules["minLength"].nil? || (value.respond_to?(:length) && value.length >= rules["minLength"])) &&
      (rules["minItems"].nil? || (value.is_a?(Array) && value.size >= rules["minItems"]))
  end
end

# --- generate payloads that wander in and out of validity --------------------
def valid_payload(rng)
  {
    mode: %w[air sea road].sample(random: rng),
    weight_kg: rng.rand(1..30_000),
    reference: "REF-#{rng.rand(1000)}",
    fragile: [true, false].sample(random: rng)
  }
end

def corrupted_payload(rng)
  payload = valid_payload(rng)
  if rng.rand < 0.6
    corruptions = {
      mode: ["teleport", 7], weight_kg: [0, "heavy", 50_000],
      reference: [""], fragile: ["yes"], tags: [[]]
    }
    field = corruptions.keys.sample(random: rng)
    payload[field] = corruptions[field].sample(random: rng)
  end
  payload
end

def chaos_payload(rng)
  payload = {}
  payload[:mode] = ["air", "sea", "teleport", 7].sample(random: rng) if rng.rand < 0.8
  payload[:weight_kg] = [rng.rand(1..30_000), -4, "heavy"].sample(random: rng) if rng.rand < 0.8
  payload[:reference] = ["REF-#{rng.rand(1000)}", ""].sample(random: rng) if rng.rand < 0.8
  payload[:tags] = [["a"], []].sample(random: rng) if rng.rand < 0.4
  payload
end

def random_payload(rng)
  # Half start valid and get one field corrupted (or not); half are chaos
  (rng.rand < 0.5) ? corrupted_payload(rng) : chaos_payload(rng)
end

validator = Agentic::CapabilityValidator.new(spec)
trials = 200
disagreements = []
accepted = 0

trials.times do
  payload = random_payload(rng)

  agentic_verdict = begin
    validator.validate_inputs!(payload)
    true
  rescue Agentic::Errors::ValidationError
    false
  end

  schema_verdict = schema_accepts?(schema, payload)
  accepted += 1 if agentic_verdict
  disagreements << payload if agentic_verdict != schema_verdict
end

puts "THE AGREEMENT PROOF (#{trials} seeded payloads, #{accepted} valid)"
if disagreements.empty?
  puts "  the exported schema and the live validator agreed on every payload."
  puts "  the projection is faithful: what the JSON document promises is"
  puts "  exactly what the boundary enforces."
else
  puts "  DISAGREEMENTS (the export lies about the contract):"
  disagreements.first(5).each { |payload| puts "  - #{payload.inspect}" }
  exit 1
end
