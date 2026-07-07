# frozen_string_literal: true

# The Confident Pipeline: timid code checks nil at every step because
# it trusts nothing, including itself. Confident code validates once,
# at the barricade, and then speaks in declarative sentences. Same
# pipeline, written both ways - and then both are made to face the
# same malformed input, so the difference is behavior, not taste.
#
#   bundle exec ruby examples/confident_pipeline.rb
#
# Runs offline; the conditional count is computed from this file.

require_relative "../lib/agentic"

Agentic.logger.level = :fatal

# --- the timid version ----------------------------------------------------------
# Every method distrusts its caller, so every method re-litigates
# reality. Read it aloud: it's all subordinate clauses.
module Timid
  def self.process(order)
    return nil if order.nil?

    items = order[:items]
    return nil if items.nil? || !items.is_a?(Array) || items.empty?

    total = 0
    items.each do |item|
      next if item.nil?

      price = item[:price_cents]
      qty = item[:qty] || 1
      total += price * qty if !price.nil? && price.is_a?(Numeric) && price >= 0
    end

    email = order[:email]
    receipt = if email && !email.empty?
      "receipt to #{email}"
    end

    {total_cents: total, delivery: receipt || "no receipt"}
  end
end

# --- the confident version -------------------------------------------------------
# One barricade at the boundary. Inside it, every sentence is
# indicative mood: the data IS shaped; the contract said so.
ORDER_CONTRACT = Agentic::CapabilitySpecification.new(
  name: "process_order", description: "Price an order", version: "1.0.0",
  inputs: {
    items: {type: "array", required: true, non_empty: true},
    email: {type: "string", required: true, non_empty: true}
  },
  outputs: {total_cents: {type: "number", required: true}, delivery: {type: "string", required: true}}
)
BARRICADE = Agentic::CapabilityValidator.new(ORDER_CONTRACT)

module Confident
  def self.process(order)
    BARRICADE.validate_inputs!(order)
    total = order[:items].sum { |item| item.fetch(:price_cents) * item.fetch(:qty, 1) }
    output = {total_cents: total, delivery: "receipt to #{order[:email]}"}
    BARRICADE.validate_outputs!(output)
    output
  end
end

GOOD = {items: [{price_cents: 1200, qty: 2}, {price_cents: 350}], email: "a@b.co"}.freeze
BAD = {items: [{price_cents: nil, qty: 3}], email: ""}.freeze

puts "THE CONFIDENT PIPELINE (same job, two postures)"
puts

source = File.read(__FILE__, encoding: "UTF-8")
timid_src = source[/module Timid.*?\n  end\nend/m]
confident_src = source[/module Confident.*?\n  end\nend/m]
count = ->(src) { src.scan(/\b(?:if|unless|return nil|next if|\|\|)\s/).size + src.scan("&&").size }

puts format("  %-12s %2d conditionals, %2d lines", "timid:", count.call(timid_src), timid_src.lines.size)
puts format("  %-12s %2d conditionals, %2d lines", "confident:", count.call(confident_src), confident_src.lines.size)
puts

puts "  good input:"
puts "    timid:     #{Timid.process(GOOD)}"
puts "    confident: #{Confident.process(GOOD)}"
puts
puts "  malformed input (an item with a nil price, email: \"\"):"
puts "    timid:     #{Timid.process(BAD).inspect}"
begin
  Confident.process(BAD)
rescue Agentic::Errors::ValidationError => e
  puts "    confident: raises ValidationError - #{e.violations.keys.join(", ")} rejected AT THE DOOR"
end
puts
puts "  look at what the timid version returned for garbage: a polite,"
puts "  well-formed, WRONG answer - zero dollars, \"no receipt\", no error."
puts "  that nil-tolerance didn't handle the bad input, it LAUNDERED it;"
puts "  some downstream ledger now owes a customer an explanation. the"
puts "  confident version has one conditional posture: a barricade at"
puts "  each door (inputs validated once, outputs too - honesty is also"
puts "  a promise about what you return). inside, every line is a"
puts "  declarative sentence about data that is KNOWN to be shaped."
puts "  confidence isn't optimism - it's pushing all the doubt to the"
puts "  boundary, where it can say no out loud."
