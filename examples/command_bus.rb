# frozen_string_literal: true

# The Command Bus: every command is a composed capability with its OWN
# declared contract (new in this round - compositions used to be
# contract-less). The bus is just the registry: dispatching a command
# validates it at the boundary, routes it through its handler pipeline,
# and validates what comes back.
#
#   bundle exec ruby examples/command_bus.rb
#
# Runs offline. Watch PlaceOrder(quantity: "many") bounce off the
# boundary with the violation named.

require_relative "../lib/agentic"

registry = Agentic::AgentCapabilityRegistry.instance

# --- primitive capabilities: small, reusable handler steps -----------------
def capability(name, inputs:, outputs:, &impl)
  spec = Agentic::CapabilitySpecification.new(
    name: name, description: name, version: "1.0.0", inputs: inputs, outputs: outputs
  )
  Agentic.register_capability(
    spec, Agentic::CapabilityProvider.new(capability: spec, implementation: impl)
  )
end

STOCK = Hash.new(10)
LEDGER = []

capability("reserve_stock",
  inputs: {sku: {type: "string", required: true}, quantity: {type: "number", required: true}},
  outputs: {reserved: {type: "boolean", required: true}, remaining: {type: "number", required: true}}) do |input|
  available = STOCK[input[:sku]]
  reserved = available >= input[:quantity]
  STOCK[input[:sku]] -= input[:quantity] if reserved
  {reserved: reserved, remaining: STOCK[input[:sku]]}
end

capability("record_entry",
  inputs: {entry: {type: "string", required: true}},
  outputs: {position: {type: "number", required: true}}) do |input|
  LEDGER << input[:entry]
  {position: LEDGER.size}
end

# --- commands: compositions with their own contracts ------------------------
registry.compose(
  "PlaceOrder", "Place an order for a SKU", "1.0.0",
  [{name: "reserve_stock", version: "1.0.0"}, {name: "record_entry", version: "1.0.0"}],
  lambda do |(reserve, record), command|
    reservation = reserve.execute(sku: command[:sku], quantity: command[:quantity])
    unless reservation[:reserved]
      next {accepted: false, events: ["OrderRejected: insufficient stock for #{command[:sku]}"]}
    end

    entry = record.execute(entry: "order #{command[:sku]} x#{command[:quantity]}")
    {accepted: true, events: ["StockReserved(#{reservation[:remaining]} left)", "OrderPlaced(##{entry[:position]})"]}
  end,
  inputs: {
    sku: {type: "string", required: true},
    quantity: {type: "number", required: true}
  },
  outputs: {
    accepted: {type: "boolean", required: true},
    events: {type: "array", required: true}
  }
)

registry.compose(
  "RestockShelf", "Add stock for a SKU", "1.0.0",
  [{name: "record_entry", version: "1.0.0"}],
  lambda do |(record), command|
    STOCK[command[:sku]] += command[:quantity]
    entry = record.execute(entry: "restock #{command[:sku]} +#{command[:quantity]}")
    {accepted: true, events: ["ShelfRestocked(##{entry[:position]})"]}
  end,
  inputs: {sku: {type: "string", required: true}, quantity: {type: "number", required: true}},
  outputs: {accepted: {type: "boolean", required: true}, events: {type: "array", required: true}}
)

# --- the bus: dispatch is validation + routing, nothing else ----------------
def dispatch(registry, command_name, payload)
  provider = registry.get_provider(command_name) or
    return {accepted: false, events: ["UnknownCommand: #{command_name}"]}
  provider.execute(payload)
rescue Agentic::Errors::ValidationError => e
  {accepted: false,
   events: e.violations.map { |key, msgs| "CommandRejected: #{key} #{Array(msgs).join(", ")}" }}
end

COMMANDS = [
  ["PlaceOrder", {sku: "widget", quantity: 3}],
  ["PlaceOrder", {sku: "widget", quantity: "many"}], # violates the contract
  ["RestockShelf", {sku: "widget", quantity: 5}],
  ["PlaceOrder", {sku: "widget", quantity: 13}], # violates the business rule
  ["ShipRocket", {to: "the moon"}] # nobody handles this
].freeze

puts "COMMAND BUS"
puts
COMMANDS.each do |name, payload|
  result = dispatch(registry, name, payload)
  status = result[:accepted] ? "ACCEPTED" : "REJECTED"
  puts format("  %-8s %s(%s)", status, name, payload.map { |k, v| "#{k}: #{v.inspect}" }.join(", "))
  result[:events].each { |event| puts "           -> #{event}" }
end

puts
puts "ledger: #{LEDGER.size} entries | widget stock: #{STOCK["widget"]}"
puts
puts "note the two different REJECTED shapes: the contract rejected"
puts "'many' before any handler ran; the business rule rejected 13 after"
puts "checking the shelf. types stop nonsense, domains stop mistakes."
