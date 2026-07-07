# frozen_string_literal: true

# The Contract State Machine: each transition is a capability whose
# guard is not an if-statement but an enum predicate on its declared
# contract (new this round). An illegal transition doesn't fail - it
# never types-checks in the first place, and the violation names the
# states that WOULD have been legal.
#
#   bundle exec ruby examples/state_machine.rb
#
# Runs offline. Watch "deliver" bounce off a cart-state order.

require_relative "../lib/agentic"

# from: is the transition guard, expressed as a contract enum
TRANSITIONS = {
  "place" => {from: %w[cart], to: "placed"},
  "ship" => {from: %w[placed], to: "shipped"},
  "deliver" => {from: %w[shipped], to: "delivered"},
  "cancel" => {from: %w[cart placed], to: "canceled"}
}.freeze

TRANSITIONS.each do |event, rule|
  spec = Agentic::CapabilitySpecification.new(
    name: event,
    description: "Transition an order via #{event}",
    version: "1.0.0",
    inputs: {
      order_id: {type: "string", required: true, non_empty: true},
      state: {type: "string", required: true, enum: rule[:from]}
    },
    outputs: {state: {type: "string", required: true, enum: [rule[:to]]}}
  )
  Agentic.register_capability(spec, Agentic::CapabilityProvider.new(
    capability: spec,
    implementation: ->(inputs) { {state: rule[:to]} }
  ))
end

# The machine: current state + registry lookup. No case statement,
# no transition table at runtime - the contracts ARE the table.
class Order
  attr_reader :id, :state, :history

  def initialize(id)
    @id = id
    @state = "cart"
    @history = ["cart"]
  end

  def fire(event)
    provider = Agentic::AgentCapabilityRegistry.instance.get_provider(event) or
      return [:unknown_event, event]

    result = provider.execute(order_id: @id, state: @state)
    @state = result[:state]
    @history << @state
    [:ok, @state]
  rescue Agentic::Errors::ValidationError => e
    allowed = TRANSITIONS.fetch(event)[:from]
    [:illegal, "cannot #{event} from '#{@state}' (legal from: #{allowed.join(", ")}) - #{e.violations.keys.join(", ")} violated"]
  end
end

order = Order.new("ord-7")

SCRIPT = %w[deliver place place ship cancel deliver].freeze

puts "CONTRACT STATE MACHINE: order #{order.id} begins in 'cart'"
puts
SCRIPT.each do |event|
  verdict, detail = order.fire(event)
  case verdict
  when :ok then puts format("  %-8s -> now '%s'", event, detail)
  when :illegal then puts format("  %-8s XX %s", event, detail)
  when :unknown_event then puts format("  %-8s ?? no such transition", event)
  end
end

puts
puts "journey: #{order.history.join(" -> ")}"
puts
puts "the machine has no case statement and no runtime transition table:"
puts "each event's contract declares its legal source states as an enum,"
puts "and the validator enforces the topology. illegal moves are type"
puts "errors with the legal alternatives in the message."
