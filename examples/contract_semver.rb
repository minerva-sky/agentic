# frozen_string_literal: true

# The Contract Semver Advisor: two versions of a capability's contract,
# every change classified as breaking or compatible - FROM THE CALLER'S
# and THE CONSUMER'S seats, which disagree about what "breaking" means.
# The verdict is the version bump you owe your users.
#
#   bundle exec ruby examples/contract_semver.rb
#
# Runs offline; v2 contains one of every interesting change.

require_relative "../lib/agentic"

V1 = Agentic::CapabilitySpecification.new(
  name: "quote_shipping", description: "Quote a shipment", version: "1.4.0",
  inputs: {
    mode: {type: "string", required: true, enum: %w[air sea]},
    weight: {type: "number", required: true, min: 1, max: 10_000},
    notes: {type: "string"}
  },
  outputs: {
    price_cents: {type: "number", required: true},
    carrier: {type: "string", required: true}
  }
)

V2 = Agentic::CapabilitySpecification.new(
  name: "quote_shipping", description: "Quote a shipment", version: "?",
  inputs: {
    mode: {type: "string", required: true, enum: %w[air sea road]}, # enum widened
    weight: {type: "number", required: true, min: 1, max: 5_000},   # max tightened
    customs_code: {type: "string", required: true},                 # new required input
    notes: {type: "string"}
  },
  outputs: {
    price_cents: {type: "number", required: true},
    eta_days: {type: "number", required: true}                      # new output
    # carrier: removed
  }
)

def classify_inputs(v1, v2)
  changes = []
  v2.inputs.each do |key, decl|
    old = v1.inputs[key]
    if old.nil?
      changes << [decl[:required] ? :breaking : :compatible,
        "input :#{key} added#{decl[:required] ? " as REQUIRED - existing callers don't send it" : " (optional)"}"]
      next
    end
    changes << [:breaking, "input :#{key} type changed #{old[:type]} -> #{decl[:type]}"] if old[:type] != decl[:type]
    changes << [:breaking, "input :#{key} became required"] if decl[:required] && !old[:required]
    if old[:enum] && decl[:enum]
      changes << [:compatible, "input :#{key} enum widened (#{(decl[:enum] - old[:enum]).join(", ")})"] if (old[:enum] - decl[:enum]).empty? && decl[:enum] != old[:enum]
      changes << [:breaking, "input :#{key} enum narrowed (removed #{(old[:enum] - decl[:enum]).join(", ")})"] unless (old[:enum] - decl[:enum]).empty?
    end
    changes << [:breaking, "input :#{key} max tightened #{old[:max]} -> #{decl[:max]} - previously legal calls now rejected"] if old[:max] && decl[:max] && decl[:max] < old[:max]
    changes << [:breaking, "input :#{key} min tightened #{old[:min]} -> #{decl[:min]}"] if old[:min] && decl[:min] && decl[:min] > old[:min]
  end
  (v1.inputs.keys - v2.inputs.keys).each do |key|
    changes << [:compatible, "input :#{key} no longer declared (extra keys were always permitted)"]
  end
  changes
end

def classify_outputs(v1, v2)
  changes = []
  (v1.outputs.keys - v2.outputs.keys).each do |key|
    changes << [:breaking, "output :#{key} removed - consumers reading it get nil"]
  end
  (v2.outputs.keys - v1.outputs.keys).each do |key|
    changes << [:compatible, "output :#{key} added (consumers ignore unknown keys)"]
  end
  changes
end

changes = classify_inputs(V1, V2) + classify_outputs(V1, V2)
breaking = changes.count { |kind, _| kind == :breaking }

puts "CONTRACT SEMVER ADVISOR: #{V1.name} v#{V1.version} -> v?"
puts
changes.sort_by { |kind, _| (kind == :breaking) ? 0 : 1 }.each do |kind, message|
  puts format("  %-10s %s", kind.to_s.upcase, message)
end

major, minor, = V1.version.split(".").map(&:to_i)
suggested = breaking.positive? ? "#{major + 1}.0.0" : "#{major}.#{minor + 1}.0"
puts
puts "  verdict: #{breaking} breaking change(s) -> ship as v#{suggested}"
puts
puts "  note the asymmetry: INPUTS break when tightened (callers rejected),"
puts "  OUTPUTS break when narrowed (consumers starved). the same edit is"
puts "  breaking on one side and compatible on the other - semver for"
puts "  contracts is a two-seat calculation, and both seats are customers."
