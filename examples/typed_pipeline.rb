# frozen_string_literal: true

# A typed ETL pipeline: extract -> transform -> load, each stage a
# capability with a declared contract, composed into one capability via
# the registry. Bad data doesn't flow downstream - it's stopped at the
# boundary that first notices, with every violation named.
#
#   bundle exec ruby examples/typed_pipeline.rb
#
# Runs offline. The interesting output is the FAILED record: watch
# where it stops and what the error says.

require_relative "../lib/agentic"

registry = Agentic::AgentCapabilityRegistry.instance

RAW_EVENTS = [
  %(id=ev-1|user=ada@example.com|amount_cents=4200|currency=USD),
  %(id=ev-2|user=grace@example.com|amount_cents=1850|currency=EUR),
  %(id=ev-3|user=|amount_cents=not-a-number|currency=USD),
  %(id=ev-4|user=joan@example.com|amount_cents=99900|currency=USD)
].freeze

def capability(name, inputs:, outputs:, &impl)
  spec = Agentic::CapabilitySpecification.new(
    name: name, description: name, version: "1.0.0",
    inputs: inputs, outputs: outputs
  )
  Agentic.register_capability(
    spec, Agentic::CapabilityProvider.new(capability: spec, implementation: impl)
  )
end

# Extract: raw line in, loosely-typed fields out. Extraction is
# forgiving - its job is parsing, not judgment.
capability("extract",
  inputs: {raw: {type: "string", required: true}},
  outputs: {fields: {type: "object", required: true}}) do |input|
  fields = input[:raw].split("|").to_h { |pair| pair.split("=", 2) }
  {fields: fields}
end

# Transform: loose fields in, STRICT record out. This is the boundary
# where "data" becomes "facts" - the contract insists amount is a
# number and user is present.
capability("transform",
  inputs: {fields: {type: "object", required: true}},
  outputs: {
    id: {type: "string", required: true},
    user: {type: "string", required: true},
    amount_cents: {type: "number", required: true},
    currency: {type: "string", required: true}
  }) do |input|
  fields = input[:fields]
  amount = begin
    Integer(fields["amount_cents"])
  rescue ArgumentError, TypeError
    fields["amount_cents"] # let the output contract catch it, by name
  end
  user = fields["user"].to_s.empty? ? nil : fields["user"]
  {id: fields["id"], user: user, amount_cents: amount, currency: fields["currency"]}.compact
end

# Load: strict record in, ledger entry out
LEDGER = Hash.new(0)
capability("load",
  inputs: {
    id: {type: "string", required: true},
    user: {type: "string", required: true},
    amount_cents: {type: "number", required: true},
    currency: {type: "string", required: true}
  },
  outputs: {posted: {type: "string", required: true}}) do |record|
  LEDGER[record[:currency]] += record[:amount_cents]
  {posted: record[:id]}
end

# Compose the three stages into one pipeline capability
registry.compose(
  "etl_pipeline",
  "Extract, transform, and load one raw event",
  "1.0.0",
  [{name: "extract", version: "1.0.0"},
    {name: "transform", version: "1.0.0"},
    {name: "load", version: "1.0.0"}],
  lambda do |providers, inputs|
    extract, transform, load = providers
    record = transform.execute(extract.execute(raw: inputs[:raw]))
    load.execute(record)
  end
)

pipeline = registry.get_provider("etl_pipeline")

puts "PIPELINE RUN (#{RAW_EVENTS.size} raw events)"
puts
RAW_EVENTS.each do |raw|
  posted = pipeline.execute(raw: raw)
  puts "  POSTED   #{posted[:posted]}"
rescue Agentic::Errors::ValidationError => e
  puts "  REJECTED #{raw[/id=([^|]+)/, 1]} at the '#{e.capability}' #{e.kind} boundary:"
  e.violations.each { |key, messages| puts "             #{key}: #{Array(messages).join(", ")}" }
end

puts
puts "LEDGER (only facts made it this far):"
LEDGER.each { |currency, cents| puts format("  %s %10.2f", currency, cents / 100.0) }
