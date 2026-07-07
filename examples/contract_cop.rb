# frozen_string_literal: true

# The Contract Cop: RuboCop for capability specs. Contracts are the
# most-read documents in this framework - six tools consume them -
# so they deserve a style guide with teeth: named cops, an offense
# report, and autocorrection for everything mechanical. Style is not
# vanity; it's the cost of reading, paid down in advance.
#
#   bundle exec ruby examples/contract_cop.rb
#
# Runs offline; a messy contract walks in, autocorrect walks it out.

require_relative "../lib/agentic"

# The defendant: a contract written at 6pm on a Friday
MESSY = {
  name: "QuoteShipping", description: "", version: "1.0.0",
  inputs: {
    Mode: {type: "string", required: true, enum: %w[sea air road]},
    weightKg: {type: "number", required: true, min: 0, max: 5_000},
    customs_code: {type: "string"},
    ref: {},
    a: {type: "string", required: true},
    b: {type: "string", required: true},
    c: {type: "string", required: true},
    d: {type: "string", required: true},
    e: {type: "string", required: true}
  },
  rules: {
    check1: {fields: [:weightKg], check: ->(i) { i[:weightKg] < 5_000 }}
  }
}.freeze

# Each cop: name, check (spec-hash in, offenses out), correctable?
COPS = {
  "Naming/SnakeCaseName" => {
    check: ->(s) { (s[:name] =~ /\A[a-z][a-z0-9_]*\z/) ? [] : ["capability name '#{s[:name]}' is not snake_case"] },
    correct: ->(s) { s[:name] = s[:name].gsub(/([a-z])([A-Z])/, '\1_\2').downcase }
  },
  "Naming/SnakeCaseFields" => {
    check: ->(s) { s[:inputs].keys.reject { |k| k =~ /\A[a-z][a-z0-9_]*\z/ }.map { |k| "input :#{k} is not snake_case" } },
    correct: ->(s) { s[:inputs].transform_keys! { |k| k.to_s.gsub(/([a-z])([A-Z])/, '\1_\2').downcase.to_sym } }
  },
  "Documentation/Description" => {
    check: ->(s) { s[:description].to_s.empty? ? ["capability has no description"] : [] },
    correct: nil # a human must actually say what it does
  },
  "Style/EnumOrder" => {
    check: ->(s) { s[:inputs].select { |_, d| d[:enum] && d[:enum] != d[:enum].sort }.map { |k, _| "input :#{k} enum is not sorted" } },
    correct: ->(s) { s[:inputs].each_value { |d| d[:enum] = d[:enum].sort if d[:enum] } }
  },
  "Lint/UntypedField" => {
    check: ->(s) { s[:inputs].select { |_, d| d[:type].nil? }.map { |k, _| "input :#{k} has no type (and won't project into schemas)" } },
    correct: nil # guessing a type is how bugs get typed
  },
  "Lint/OpaqueRuleWithoutMessage" => {
    check: ->(s) {
      s[:rules].select { |_, d| d.respond_to?(:call) || (d[:check] && !d[:message]) }
        .map { |k, _| "rule :#{k} is opaque AND messageless - violations will say nothing" }
    },
    correct: nil # the message is the author's testimony; can't forge it
  },
  "Metrics/RequiredInputCount" => {
    check: ->(s) {
      required = s[:inputs].count { |_, d| d[:required] }
      (required > 5) ? ["#{required} required inputs (max 5) - is this one capability or three?"] : []
    },
    correct: nil
  }
}.freeze

def inspect_spec(spec_hash)
  COPS.flat_map { |cop, definition| definition[:check].call(spec_hash).map { |offense| [cop, offense] } }
end

puts "CONTRACT COP (#{COPS.size} cops on the beat)"
puts
offenses = inspect_spec(MESSY)
puts "  inspecting quote_shipping... #{offenses.size} offenses:"
offenses.each { |cop, offense| puts format("    %-33s %s", cop, offense) }
puts

# --- autocorrect what's mechanical ----------------------------------------------
corrected = {name: MESSY[:name].dup, description: MESSY[:description].dup, version: MESSY[:version],
             inputs: MESSY[:inputs].transform_values(&:dup).dup, rules: MESSY[:rules].dup}
corrected[:inputs].each_value { |d| d[:enum] = d[:enum].dup if d[:enum] }
COPS.each_value { |definition| definition[:correct]&.call(corrected) }

remaining = inspect_spec(corrected)
puts "  after autocorrect (#{offenses.size - remaining.size} offenses fixed mechanically):"
remaining.each { |cop, offense| puts format("    %-33s %s", cop, offense) }
puts
puts "  what autocorrect fixed, it fixed safely: names snake_cased,"
puts "  enums sorted - transformations with exactly one right answer."
puts "  what remains is the honest residue: a missing description"
puts "  (only the author knows what it does), an untyped field"
puts "  (guessing types is how bugs get typed), an opaque messageless"
puts "  rule, and seven required inputs' worth of scope creep. a linter's"
puts "  job splits exactly there - automate the mechanical, and make"
puts "  the judgment calls impossible to not-see. style is applied"
puts "  empathy for the next reader, and contracts have six readers."
