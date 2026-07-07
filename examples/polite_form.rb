# frozen_string_literal: true

# The Polite Form: a contract usually speaks AFTER you fail - a 422,
# a stack of violations. This assistant makes it speak FIRST, turning
# every declaration into a question: required keys become requests,
# bounds become gentle corrections, and relation rules become the
# follow-ups a good clerk asks ("express? then I'll need a customs
# code"). Zero errors are ever shown; the contract is the script.
#
#   bundle exec ruby examples/polite_form.rb
#
# Runs offline; the "user" answers from a queue.

require_relative "../lib/agentic"
require "json"

SPEC = Agentic::CapabilitySpecification.new(
  name: "quote_shipping", description: "Quote a shipment", version: "2.1.0",
  inputs: {
    mode: {type: "string", required: true, enum: %w[air sea road]},
    weight: {type: "number", required: true, min: 1, max: 5_000},
    volume: {type: "number", min: 0},
    express: {type: "boolean"},
    customs_code: {type: "string"},
    api_key: {type: "string"},
    oauth_token: {type: "string"}
  },
  rules: {
    fits: {relation: :sum_lte, fields: [:weight, :volume], limit: 6_000},
    customs: {relation: :requires, fields: [:express, :customs_code]},
    one_auth: {relation: :mutually_exclusive, fields: [:api_key, :oauth_token]}
  }
)

# The half-filled form the user pasted in
answers = {express: true, api_key: "k-123", oauth_token: "t-456", volume: 2_500}

# What the user will say when asked (a queue per field)
REPLIES = {
  mode: ["air"],
  weight: [6_000, 4_500], # first too heavy, then adjusted
  volume: [1_500],        # reduced when the total is too much
  customs_code: ["HS-42"],
  keep: [:api_key]
}.transform_values(&:dup)

def say(role, line)
  puts format("  %-10s %s", "#{role}:", line)
end

def ask(field, question, answers)
  say("assistant", question)
  reply = REPLIES.fetch(field).shift
  say("user", reply.inspect)
  answers[field] = reply
end

validator = Agentic::CapabilityValidator.new(SPEC)
puts "THE POLITE FORM (#{SPEC.name} v#{SPEC.version})"
puts
say("user", "here's what I have: #{JSON.generate(answers)}")

10.times do
  validator.validate_inputs!(answers)
  break
rescue Agentic::Errors::ValidationError => e
  if e.rule_violations.any?
    violation = e.rule_violations.first
    rule = SPEC.rules[violation[:rule]]
    case rule[:relation]
    when :requires
      needed = rule[:fields].drop(1).find { |f| answers[f].nil? }
      ask(needed, "since you chose #{rule[:fields].first}, I'll also need your #{needed} - what is it?", answers)
    when :sum_lte
      total = rule[:fields].sum { |f| answers[f] || 0 }
      target = rule[:fields].last
      ask(target, "together #{rule[:fields].join(" and ")} come to #{total}, and #{rule[:limit]} is our limit - could we lower the #{target}?", answers)
    when :mutually_exclusive
      say("assistant", "you've given me #{violation[:fields].join(" and ")} - I only need one; which shall we keep?")
      keep = REPLIES.fetch(:keep).shift
      say("user", keep.inspect)
      (violation[:fields] - [keep]).each { |f| answers.delete(f) }
    end
  else
    field, messages = e.violations.first
    if messages.first.include?("missing")
      ask(field, "may I have your #{field}? (#{SPEC.inputs[field][:enum]&.join(", ") || SPEC.inputs[field][:type]})", answers)
    else
      ask(field, "ah - #{field} #{messages.first}. shall we adjust it?", answers)
    end
  end
end

puts
say("assistant", "all set. here's your form: #{JSON.generate(answers)}")
validator.validate_inputs!(answers) # the countersignature
puts
puts "  the same contract that would have stacked up 422s asked six"
puts "  questions instead. nothing here was written twice: the"
puts "  requests came from required:, the correction from max:, and"
puts "  the follow-ups from the relations - requires became \"then I'll"
puts "  also need\", sum_lte became \"could we lower it\", and"
puts "  mutually_exclusive became \"which shall we keep?\". an error"
puts "  message is just a question you asked too late."
