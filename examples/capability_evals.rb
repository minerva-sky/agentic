# frozen_string_literal: true

# Capability Evals: golden test cases run against registered
# capabilities, scored, and gated. When you swap a lambda for an LLM
# (or one model for another), the eval suite is what tells you whether
# quality moved - contracts check shape, evals check SUBSTANCE.
#
#   bundle exec ruby examples/capability_evals.rb
#
# Runs offline; one capability has a bug the evals catch.

require_relative "../lib/agentic"

def capability(name, inputs:, outputs:, &impl)
  spec = Agentic::CapabilitySpecification.new(
    name: name, description: name, version: "1.0.0", inputs: inputs, outputs: outputs
  )
  Agentic.register_capability(
    spec, Agentic::CapabilityProvider.new(capability: spec, implementation: impl)
  )
end

capability("classify_sentiment",
  inputs: {text: {type: "string", required: true}},
  outputs: {label: {type: "string", required: true, enum: %w[positive negative neutral]}}) do |i|
  text = i[:text].downcase
  label = if text.match?(/love|great|excellent|happy/)
    "positive"
  elsif text.match?(/hate|terrible|awful|angry/)
    "negative"
  else
    "neutral"
  end
  {label: label}
end

capability("extract_amount",
  inputs: {text: {type: "string", required: true}},
  outputs: {cents: {type: "number", required: true}}) do |i|
  # The bug: parses dollars but drops the cents
  dollars = i[:text][/\$(\d+)/, 1].to_i
  {cents: dollars * 100}
end

EVALS = {
  "classify_sentiment" => [
    {input: {text: "I love this gem"}, expect: {label: "positive"}},
    {input: {text: "This is terrible"}, expect: {label: "negative"}},
    {input: {text: "It runs on Ruby 3.3"}, expect: {label: "neutral"}},
    {input: {text: "absolutely EXCELLENT work"}, expect: {label: "positive"}}
  ],
  "extract_amount" => [
    {input: {text: "invoice total $45"}, expect: {cents: 4500}},
    {input: {text: "you owe $12.50 by friday"}, expect: {cents: 1250}},
    {input: {text: "refund of $0.99 issued"}, expect: {cents: 99}}
  ]
}.freeze

registry = Agentic::AgentCapabilityRegistry.instance
THRESHOLD = 0.9

puts "CAPABILITY EVALS (pass threshold #{(THRESHOLD * 100).round}%)"
puts

overall = []
EVALS.each do |name, cases|
  provider = registry.get_provider(name)
  results = cases.map do |eval_case|
    actual = provider.execute(eval_case[:input])
    passed = eval_case[:expect].all? { |key, expected| actual[key] == expected }
    [eval_case, actual, passed]
  end

  passed = results.count { |_, _, ok| ok }
  rate = passed.to_f / cases.size
  overall << rate
  puts format("  %-20s %d/%d (%3.0f%%) %s", name, passed, cases.size, rate * 100,
    (rate >= THRESHOLD) ? "" : "BELOW THRESHOLD")

  results.reject { |_, _, ok| ok }.each do |eval_case, actual, _|
    puts "    FAIL #{eval_case[:input][:text].inspect}"
    puts "         expected #{eval_case[:expect].inspect}, got #{actual.inspect}"
  end
end

puts
score = overall.sum / overall.size
puts format("  suite score: %.0f%%", score * 100)
if score < THRESHOLD
  puts "  the gate holds: extract_amount drops cents - a shape-valid,"
  puts "  substance-wrong answer that no contract could catch. contracts"
  puts "  check types; evals check truth. you need both."
  exit 1
end
