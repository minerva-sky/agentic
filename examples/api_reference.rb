# frozen_string_literal: true

# The API Reference Generator: walk the registry, emit reference docs
# for every capability - types, enums, bounds, policies - straight from
# the contracts that VALIDATE the calls. Documentation that enforces
# itself cannot lie about what it accepts.
#
#   bundle exec ruby examples/api_reference.rb
#
# Runs offline; prints markdown.

require_relative "../lib/agentic"

registry = Agentic::AgentCapabilityRegistry.instance

# Two capabilities as the "app": a transfer and a payout
transfer = Agentic::CapabilitySpecification.new(
  name: "transfer_funds",
  description: "Move money between accounts",
  version: "1.2.0",
  inputs: {
    from_account: {type: "string", required: true, non_empty: true, description: "Source account id"},
    to_account: {type: "string", required: true, non_empty: true, description: "Destination account id"},
    amount_cents: {type: "number", required: true, min: 1, max: 10_000_000, description: "Amount in cents"},
    memo: {type: "string", description: "Optional statement memo"}
  },
  outputs: {
    transfer_id: {type: "string", required: true},
    settled: {type: "boolean", required: true}
  },
  rules: {
    no_self_transfer: {
      message: "source and destination must differ",
      fields: [:from_account, :to_account],
      check: ->(i) { i[:from_account] != i[:to_account] }
    }
  }
)

payout = Agentic::CapabilitySpecification.new(
  name: "schedule_payout",
  description: "Schedule a payout to a bank account",
  version: "2.0.0",
  inputs: {
    amount_cents: {type: "number", required: true, min: 100},
    speed: {type: "string", required: true, enum: %w[standard instant]},
    currency: {type: "string", required: true, enum: %w[usd eur gbp]}
  },
  outputs: {payout_id: {type: "string", required: true}},
  rules: {
    instant_is_domestic: {
      message: "instant payouts support usd only",
      fields: [:speed, :currency],
      check: ->(i) { i[:speed] != "instant" || i[:currency] == "usd" }
    }
  }
)

[transfer, payout].each do |spec|
  Agentic.register_capability(spec, Agentic::CapabilityProvider.new(
    capability: spec, implementation: ->(_i) { {} }
  ))
end

# --- the generator: registry in, markdown out --------------------------------
def constraint_notes(declaration)
  notes = []
  notes << "one of: #{declaration[:enum].join(", ")}" if declaration[:enum]
  notes << ">= #{declaration[:min]}" if declaration[:min]
  notes << "<= #{declaration[:max]}" if declaration[:max]
  notes << "non-empty" if declaration[:non_empty]
  notes.join("; ")
end

def field_table(declared)
  rows = declared.map { |name, decl|
    required = decl[:required] ? "yes" : "no"
    format("| `%s` | %s | %s | %s | %s |",
      name, decl[:type], required, constraint_notes(decl), decl[:description] || "")
  }
  ["| Field | Type | Required | Constraints | Description |",
    "|-------|------|----------|-------------|-------------|"] + rows
end

def reference_for(spec)
  doc = ["## `#{spec.name}` v#{spec.version}", "", spec.description, ""]
  doc << "### Inputs"
  doc += field_table(spec.inputs)
  unless spec.rules.empty?
    doc << ""
    doc << "### Policies"
    spec.rules.each do |rule_id, rule|
      doc << "- **#{rule_id}** (checks #{rule[:fields].map { |f| "`#{f}`" }.join(", ")}): #{rule[:message]}"
    end
  end
  unless spec.outputs.empty?
    doc << ""
    doc << "### Outputs"
    doc += field_table(spec.outputs)
  end
  doc.join("\n")
end

puts "# API Reference"
puts
puts "_Generated from the same contracts that validate every call._"
puts
%w[transfer_funds schedule_payout].each do |name|
  puts reference_for(registry.get(name))
  puts
end
