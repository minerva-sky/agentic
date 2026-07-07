# frozen_string_literal: true

# Contract Fixtures: example payloads in docs rot the day the contract
# changes. So don't write them - DERIVE them. This generator reads a
# capability's declarations and produces a minimal fixture (required
# keys only) and a maximal one (everything), then a referee proves
# every generated fixture passes its own contract, and that a mutated
# fixture still fails. Docs that compile, effectively.
#
#   bundle exec ruby examples/contract_fixtures.rb
#
# Runs offline; exits 1 if the generator and validator disagree.

require_relative "../lib/agentic"
require "json"

SPECS = [
  Agentic::CapabilitySpecification.new(
    name: "quote_shipping", description: "Quote a shipment", version: "2.0.0",
    inputs: {
      mode: {type: "string", required: true, enum: %w[air sea road]},
      weight: {type: "number", required: true, min: 1, max: 5_000},
      volume: {type: "number", min: 0, max: 5_000},
      customs_code: {type: "string"},
      express: {type: "boolean"},
      api_key: {type: "string"},
      oauth_token: {type: "string"}
    },
    outputs: {price_cents: {type: "number", required: true}},
    rules: {
      fits: {relation: :sum_lte, fields: [:weight, :volume], limit: 4_000},
      customs: {relation: :requires, fields: [:express, :customs_code]},
      one_auth: {relation: :mutually_exclusive, fields: [:api_key, :oauth_token]}
    }
  ),
  Agentic::CapabilitySpecification.new(
    name: "classify_ticket", description: "Route a support ticket", version: "1.1.0",
    inputs: {
      text: {type: "string", required: true, non_empty: true},
      urgency: {type: "number", min: 0, max: 10}
    },
    outputs: {queue: {type: "string", required: true, enum: %w[billing tech general]}}
  )
].freeze

# One value per declaration, derived - never invented
def value_for(key, decl)
  return decl[:enum].first if decl[:enum]

  case decl[:type]
  when "number"
    low = decl[:min] || 0
    high = decl[:max] || 100
    low + (high - low) / 2
  when "boolean" then true
  else "example-#{key}"
  end
end

# Relation-typed rules are data, so the generator can SATISFY them
# instead of hoping: scale sums under their limit, add what a present
# trigger requires, keep only the first of an exclusive group
def satisfy_relations(fixture, spec)
  spec.rules.each_value do |definition|
    next if definition.respond_to?(:call) || !definition[:relation]

    fields = definition[:fields]
    case definition[:relation]
    when :sum_lte
      given = fields.select { |f| fixture[f].is_a?(Numeric) }
      total = given.sum { |f| fixture[f] }
      if total > definition[:limit]
        given.each { |f| fixture[f] = definition[:limit] / given.size }
      end
    when :requires
      trigger, *needed = fields
      if !fixture[trigger].nil?
        needed.each { |f| fixture[f] ||= value_for(f, spec.inputs[f]) }
      end
    when :mutually_exclusive
      fields.select { |f| fixture.key?(f) }.drop(1).each { |f| fixture.delete(f) }
    end
  end
  fixture
end

def fixtures_for(spec)
  required = spec.inputs.select { |_, decl| decl[:required] }
  {
    "minimal" => satisfy_relations(required.to_h { |key, decl| [key, value_for(key, decl)] }, spec),
    "maximal" => satisfy_relations(spec.inputs.to_h { |key, decl| [key, value_for(key, decl)] }, spec)
  }
end

failures = 0
puts "CONTRACT FIXTURES (derived from declarations, then proved)"

SPECS.each do |spec|
  validator = Agentic::CapabilityValidator.new(spec)
  puts
  puts "  #{spec.name} v#{spec.version}:"

  fixtures_for(spec).each do |flavor, fixture|
    verdict = begin
      validator.validate_inputs!(fixture)
      "valid"
    rescue Agentic::Errors::ValidationError => e
      failures += 1
      "REJECTED BY OWN CONTRACT: #{e.message}"
    end
    puts format("    %-8s %-60s %s", flavor, JSON.generate(fixture), verdict)
  end

  # The referee's teeth: a mutant fixture (first required key removed)
  # must still FAIL - a validator that accepts everything would make
  # the proofs above worthless
  mutant = fixtures_for(spec)["minimal"].dup
  removed = mutant.keys.first
  mutant.delete(removed)
  begin
    validator.validate_inputs!(mutant)
    failures += 1
    puts format("    %-8s dropped :%-20s ACCEPTED - validator has no teeth", "mutant", removed)
  rescue Agentic::Errors::ValidationError
    puts format("    %-8s dropped :%-20s rejected, as it must be", "mutant", removed)
  end
end

puts
if failures.zero?
  puts "  every derived fixture passed its own contract, and every mutant"
  puts "  failed. paste these into your README - when the contract changes,"
  puts "  rerun and they change with it. handwritten examples are promises;"
  puts "  derived ones are consequences."
  puts
  puts "  and the round-9 blind spot has closed for the declarable"
  puts "  majority: relation-typed rules (sum_lte, requires,"
  puts "  mutually_exclusive) are data, so the generator SATISFIED them -"
  puts "  scaled the weights under the limit, added what express required,"
  puts "  kept one credential of the exclusive pair - and the validator,"
  puts "  which now enforces relations too, countersigned the result."
  puts "  lambdas remain for the exotic tail, and remain opaque."
else
  puts "  #{failures} DISAGREEMENT(S) between generator and validator."
end
exit(failures.zero? ? 0 : 1)
