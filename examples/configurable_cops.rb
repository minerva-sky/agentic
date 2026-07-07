# frozen_string_literal: true

# Configurable Cops: a style guide nobody can configure is a style
# FIGHT on a delay timer. RuboCop's deepest lesson isn't any single
# cop - it's the .yml: enable/disable per cop, parameters instead of
# hardcoded taste, and (the policy that saved a thousand upgrades)
# NEW COPS ARRIVE PENDING - they never fire until the team opts in,
# so a linter update can't turn a green build red by surprise.
#
#   bundle exec ruby examples/configurable_cops.rb
#
# Runs offline; one contract, two teams, two verdicts, zero fights.

require_relative "../lib/agentic"
require "yaml"

# The defendant, unchanged between teams
CONTRACT = {
  name: "quote_shipping", description: "", version: "1.0.0",
  inputs: {
    mode: {type: "string", required: true, enum: %w[sea air road]},
    weight_kg: {type: "number", required: true, min: 0, max: 5_000},
    a: {type: "string", required: true}, b: {type: "string", required: true},
    c: {type: "string", required: true}, d: {type: "string", required: true},
    ref: {}
  }
}.freeze

# Cops carry status (:stable or :pending) and read their params from config
COPS = {
  "Documentation/Description" => {
    status: :stable,
    check: ->(s, _p) { s[:description].to_s.empty? ? ["capability has no description"] : [] }
  },
  "Style/EnumOrder" => {
    status: :stable,
    check: ->(s, _p) { s[:inputs].select { |_, d| d[:enum] && d[:enum] != d[:enum].sort }.map { |k, _| "input :#{k} enum is not sorted" } }
  },
  "Metrics/RequiredInputCount" => {
    status: :stable, defaults: {"Max" => 5},
    check: ->(s, p) {
      required = s[:inputs].count { |_, d| d[:required] }
      (required > p["Max"]) ? ["#{required} required inputs (Max: #{p["Max"]})"] : []
    }
  },
  "Lint/UntypedField" => {
    status: :pending, # arrived in this release: fires ONLY if the team opts in
    check: ->(s, _p) { s[:inputs].select { |_, d| d[:type].nil? }.map { |k, _| "input :#{k} has no type" } }
  }
}.freeze

def inspect_with(config_yaml, spec)
  config = YAML.safe_load(config_yaml) || {}
  COPS.flat_map do |name, cop|
    cop_config = config.fetch(name, {})
    enabled = cop_config.fetch("Enabled", cop[:status] == :stable)
    next [] unless enabled

    params = (cop[:defaults] || {}).merge(cop_config.except("Enabled"))
    cop[:check].call(spec, params).map { |offense| [name, offense] }
  end
end

TEAM_A = <<~YAML
  # team A: defaults, plus we opted into the new pending cop
  Lint/UntypedField:
    Enabled: true
YAML

TEAM_B = <<~YAML
  # team B: we have seven required inputs and we've MET our capability;
  # raising Max is a decision, recorded here, reviewable in git blame
  Metrics/RequiredInputCount:
    Max: 8
  Style/EnumOrder:
    Enabled: false   # our enums are ordered by freight class, not alphabet
YAML

puts "CONFIGURABLE COPS (same contract, two teams, two configs)"
puts
[["team A (defaults + opted into pending cop)", TEAM_A],
  ["team B (raised Max, disabled EnumOrder, pending cop stays off)", TEAM_B]].each do |team, config|
  offenses = inspect_with(config, CONTRACT)
  puts "  #{team}: #{offenses.size} offense(s)"
  offenses.each { |cop, offense| puts format("    %-30s %s", cop, offense) }
  puts
end

puts "  the pending status is the load-bearing idea: Lint/UntypedField"
puts "  shipped in this release, and for team B it fired ZERO times -"
puts "  not because it's wrong but because a linter update must never"
puts "  turn a green build red without the team's signature. team A"
puts "  signed. and look at what team B's config really is: a RECORD OF"
puts "  DECISIONS - 'Max: 8' with a comment, blame-able to a person and"
puts "  a date, instead of the same argument re-fought in every review."
puts "  hardcoded taste creates rebels; configurable taste creates a"
puts "  paper trail. the style guide is the conversation; the config"
puts "  file is its minutes."
