# frozen_string_literal: true

# The Contract Fuzzer: for every registered capability, generate inputs
# that SHOULD pass its declared contract and mutations that SHOULD fail
# it, then check the validator agrees. A contract that accepts garbage
# or rejects conforming data is a bug in the boundary - the worst place
# to have one.
#
#   bundle exec ruby examples/contract_fuzzer.rb [seed]
#
# Runs offline and deterministically: same seed, same verdicts.

require_relative "../lib/agentic"

seed = (ARGV.first || 20260706).to_i
rng = Random.new(seed)

Agentic::Capabilities.register_standard_capabilities
registry = Agentic::AgentCapabilityRegistry.instance

# Generates a value conforming to a declared type
def conforming_value(type, rng)
  case type
  when "string" then %w[alpha beta gamma delta].sample(random: rng)
  when "number", "integer" then rng.rand(1..100)
  when "boolean" then [true, false].sample(random: rng)
  when "array" then Array.new(rng.rand(1..3)) { rng.rand(10) }
  when "object", "hash" then {key: rng.rand(10)}
  else "anything"
  end
end

# Generates a value that VIOLATES a declared type
def violating_value(type, rng)
  case type
  when "string" then rng.rand(1..100)
  when "number", "integer" then "not a number"
  when "boolean" then "yes"
  when "array" then "not an array"
  when "object", "hash" then 42
  end
end

def conforming_inputs(spec, rng)
  spec.inputs.to_h { |name, decl| [name, conforming_value(decl[:type], rng)] }
end

verdicts = []
trials = 0

registry.list.each_key do |name|
  spec = registry.get(name)
  validator = Agentic::CapabilityValidator.new(spec)
  next if spec.inputs.empty?

  # Trial 1: conforming inputs must pass
  trials += 1
  begin
    validator.validate_inputs!(conforming_inputs(spec, rng))
  rescue Agentic::Errors::ValidationError => e
    verdicts << "#{name}: REJECTED conforming inputs (#{e.message})"
  end

  # Trial 2: each required key, dropped, must fail
  spec.inputs.select { |_, decl| decl[:required] }.each_key do |required|
    trials += 1
    inputs = conforming_inputs(spec, rng)
    inputs.delete(required)
    begin
      validator.validate_inputs!(inputs)
      verdicts << "#{name}: ACCEPTED inputs missing required :#{required}"
    rescue Agentic::Errors::ValidationError
      # correct rejection
    end
  end

  # Trial 3: each typed key, corrupted, must fail
  spec.inputs.each do |key, decl|
    corrupted = violating_value(decl[:type], rng)
    next if corrupted.nil?

    trials += 1
    inputs = conforming_inputs(spec, rng).merge(key => corrupted)
    begin
      validator.validate_inputs!(inputs)
      verdicts << "#{name}: ACCEPTED #{decl[:type]} key :#{key} holding #{corrupted.inspect}"
    rescue Agentic::Errors::ValidationError
      # correct rejection
    end
  end
end

puts "CONTRACT FUZZ (seed #{seed})"
puts "  #{registry.list.size} capabilities, #{trials} trials"
puts
if verdicts.empty?
  puts "  every contract accepted what it promised and rejected what it should."
  puts "  the boundary holds."
else
  puts "  BOUNDARY DEFECTS (#{verdicts.size}):"
  verdicts.each { |v| puts "  - #{v}" }
  exit 1
end
