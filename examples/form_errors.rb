# frozen_string_literal: true

# The 422 Generator: turn a ValidationError into the API error document
# your frontend actually wants - message, allowed values, bounds - using
# ONLY what the exception carries (new this round: #expectations). The
# renderer has zero knowledge of the contract; the exception brings the
# contract with it.
#
#   bundle exec ruby examples/form_errors.rb
#
# Runs offline; prints the JSON your form would receive.

require_relative "../lib/agentic"
require "json"

spec = Agentic::CapabilitySpecification.new(
  name: "checkout",
  description: "Process a checkout form",
  version: "1.0.0",
  inputs: {
    email: {type: "string", required: true, non_empty: true},
    plan: {type: "string", required: true, enum: %w[starter team enterprise]},
    seats: {type: "number", required: true, min: 1, max: 500},
    coupon: {type: "string"}
  },
  rules: {
    "starter plan is limited to 5 seats" => ->(i) { i[:plan] != "starter" || i[:seats] <= 5 }
  }
)
Agentic.register_capability(spec, Agentic::CapabilityProvider.new(
  capability: spec, implementation: ->(i) { {order_id: "ord-#{i[:plan]}-#{i[:seats]}"} }
))

# The renderer: exception in, error document out. Note what it does NOT
# have: any reference to the checkout contract.
def error_document(error)
  field_errors = error.violations.filter_map do |field, messages|
    next if field == :base

    declared = error.expectations[field] || {}
    detail = {field: field, messages: Array(messages)}
    detail[:allowed] = declared[:enum] if declared[:enum]
    detail[:minimum] = declared[:min] if declared[:min]
    detail[:maximum] = declared[:max] if declared[:max]
    detail[:type] = declared[:type] if declared[:type]
    detail
  end

  {
    status: 422,
    capability: error.capability,
    errors: field_errors,
    policy_violations: error.violations.fetch(:base, [])
  }
end

checkout = Agentic::AgentCapabilityRegistry.instance.get_provider("checkout")

SUBMISSIONS = [
  {email: "ada@example.com", plan: "team", seats: 12},
  {email: "", plan: "premium", seats: 0},
  {email: "joan@example.com", plan: "starter", seats: 9}
].freeze

SUBMISSIONS.each_with_index do |form, index|
  puts "submission ##{index + 1}: #{form.inspect}"
  begin
    result = checkout.execute(form)
    puts "  201 CREATED #{result[:order_id]}"
  rescue Agentic::Errors::ValidationError => e
    puts JSON.pretty_generate(error_document(e)).gsub(/^/, "  ")
  end
  puts
end

puts "the renderer never saw the checkout contract - 'allowed', 'minimum',"
puts "and 'maximum' all traveled inside the exception. one renderer serves"
puts "every capability in the app, current and future."
