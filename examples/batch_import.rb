# frozen_string_literal: true

# The Batch Import: 500 rows of the kind of data people actually
# upload - typos, header drift, impossible combinations - run through
# one contract. Good rows proceed; bad rows land in a REJECT FILE
# with the field, the reason, and the rule that caught them. An
# importer that raises on row 37 is a tool for importing 36 rows.
#
#   bundle exec ruby examples/batch_import.rb
#
# Runs offline; the dirty data is seeded and repeatable.

require_relative "../lib/agentic"
require "json"

CONTRACT = Agentic::CapabilitySpecification.new(
  name: "import_shipment", description: "One row of the shipments upload", version: "1.0.0",
  inputs: {
    mode: {type: "string", required: true, enum: %w[air sea road]},
    weight: {type: "number", required: true, min: 1, max: 5_000},
    volume: {type: "number", min: 0},
    express: {type: "boolean"},
    customs_code: {type: "string"}
  },
  rules: {
    fits: {relation: :sum_lte, fields: [:weight, :volume], limit: 6_000},
    customs: {relation: :requires, fields: [:express, :customs_code]}
  }
)

# 500 rows, seeded: roughly three-quarters clean, the rest wrong in
# the ways uploads actually are
rng = Random.new(20_260_707)
ROWS = 500.times.map do |i|
  row = {
    mode: %w[air sea road].sample(random: rng),
    weight: rng.rand(1..4_000),
    volume: rng.rand(0..1_500)
  }
  row[:express] = true if rng.rand < 0.25
  row[:customs_code] = "HS-#{rng.rand(100)}" if row[:express] && rng.rand < 0.7
  case rng.rand
  when 0..0.03 then row[:mode] = "trian"            # typo
  when 0.03..0.06 then row[:weight] = 0             # zero weight
  when 0.06..0.09 then row[:weight] = rng.rand(5_001..9_000) # too heavy
  when 0.09..0.12 then row[:volume] = rng.rand(4_000..8_000) # breaks the sum rule
  when 0.12..0.14 then row.delete(:mode)            # header drift
  end
  row
end

validator = Agentic::CapabilityValidator.new(CONTRACT)
accepted = []
rejects = []

started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
ROWS.each_with_index do |row, index|
  validator.validate_inputs!(row)
  accepted << row
rescue Agentic::Errors::ValidationError => e
  reasons = e.violations.except(:base).map { |field, msgs| "#{field}: #{msgs.first}" }
  reasons += e.rule_violations.map { |v| "#{v[:rule]}: #{v[:message]}" }
  rejects << {line: index + 2, reasons: reasons} # +2: 1-based plus header row
end
elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

puts "BATCH IMPORT (#{ROWS.size} rows through one contract in #{(elapsed * 1000).round}ms)"
puts
puts "  accepted: #{accepted.size}   rejected: #{rejects.size}"
puts

by_reason = rejects.flat_map { |r| r[:reasons].map { |reason| reason[/\A[^:]+/] } }.tally
puts "  reject file, summarized by cause:"
by_reason.sort_by { |_, count| -count }.each do |cause, count|
  puts format("    %-14s %-3d %s", cause, count, "#" * count)
end
puts
puts "  first three lines of the reject file (the thing support actually opens):"
rejects.first(3).each do |reject|
  puts "    line #{reject[:line]}: #{reject[:reasons].join("; ")}"
end
puts
puts "  #{ROWS.size} rows cost #{(elapsed * 1000).round}ms of validation - #{format("%.2f", elapsed / ROWS.size * 1_000_000)}us a row - and"
puts "  every rejection names its line, its field, and its rule, including"
puts "  the cross-field ones (\"fits\", \"customs\") no per-column check"
puts "  catches. two design rules for importers: never raise on row 37"
puts "  (collect, don't crash), and never write \"invalid row\" (a reject"
puts "  file without reasons is a support ticket generator). the contract"
puts "  supplied both for free."
