# frozen_string_literal: true

# Did You Mean, for plans: the kindest thing an error can do is
# finish your sentence. A typo'd capability name, contract field, or
# task reference is ALWAYS one of three or four nearby strings - the
# framework knows every valid name at the moment of failure, so the
# error should spend one Levenshtein pass and hand you the fix.
#
#   bundle exec ruby examples/did_you_mean.rb
#
# Runs offline; every suggestion is computed, none are hardcoded.

require_relative "../lib/agentic"

Agentic.logger.level = :fatal

# The whole engine: edit distance + a threshold that scales with length
module DidYouMean2
  def self.distance(a, b)
    rows = (0..b.size).to_a
    a.each_char.with_index(1) do |ca, i|
      prev = rows[0]
      rows[0] = i
      b.each_char.with_index(1) do |cb, j|
        cur = rows[j]
        rows[j] = [rows[j] + 1, rows[j - 1] + 1, prev + ((ca == cb) ? 0 : 1)].min
        prev = cur
      end
    end
    rows[b.size]
  end

  def self.suggest(typo, candidates)
    scored = candidates.map { |c| [c, distance(typo.to_s, c.to_s)] }
    threshold = [typo.to_s.size / 2, 3].min.clamp(1, 3)
    scored.select { |_, d| d <= threshold }.min_by { |_, d| d }&.first
  end

  def self.phrase(typo, candidates)
    hit = suggest(typo, candidates)
    hit ? "Did you mean? #{hit}" : "(no close match; valid: #{candidates.take(4).join(", ")})"
  end
end

puts "DID YOU MEAN, FOR PLANS (the error finishes your sentence)"
puts

# --- scene 1: a typo'd capability lookup -----------------------------------------
%w[summarize_ticket classify_ticket route_escalation].each do |name|
  spec = Agentic::CapabilitySpecification.new(name: name, description: name, version: "1.0.0")
  Agentic.register_capability(spec, Agentic::CapabilityProvider.new(capability: spec, implementation: ->(i) { i }))
end
registry = Agentic::AgentCapabilityRegistry.instance
typo = "sumarize_ticket"
if registry.get_provider(typo).nil?
  known = %w[summarize_ticket classify_ticket route_escalation]
  puts "  capability lookup:"
  puts "    get_provider(#{typo.inspect}) -> nil"
  puts "    with suggestions: unknown capability '#{typo}'. #{DidYouMean2.phrase(typo, known)}"
end
puts

# --- scene 2: a typo'd contract field --------------------------------------------
contract = Agentic::CapabilitySpecification.new(
  name: "quote", description: "q", version: "1.0.0",
  inputs: {mode: {type: "string", required: true}, weight_kg: {type: "number", required: true}}
)
begin
  Agentic::CapabilityValidator.new(contract).validate_inputs!(mode: "air", weight_kilo: 50)
rescue Agentic::Errors::ValidationError => e
  missing = e.violations.keys.first
  sent = [:mode, :weight_kilo]
  puts "  contract violation:"
  puts "    today:  #{missing}: #{e.violations[missing].first}"
  extra = (sent - contract.inputs.keys)
  puts "    with suggestions: you sent :#{extra.first} - #{DidYouMean2.phrase(extra.first, contract.inputs.keys)}"
end
puts

# --- scene 3: a typo'd rewire target ---------------------------------------------
orchestrator = Agentic::PlanOrchestrator.new
tasks = %w[fetch_orders fetch_refunds build_ledger].to_h { |n|
  t = Agentic::Task.new(description: n, agent_spec: {"name" => n, "instructions" => "w"})
  orchestrator.add_task(t)
  [n, t]
}
begin
  orchestrator.rewire_task(tasks["build_ledger"], ["fetch_order"]) # singular typo
rescue ArgumentError => e
  puts "  rewire to a task id that doesn't exist:"
  puts "    today:  #{e.message}"
  puts "    with suggestions: #{DidYouMean2.phrase("fetch_order", tasks.keys)}"
end
puts

puts "  three seams, one pattern: at the moment each error is raised,"
puts "  the framework is HOLDING the list of every valid name - the"
puts "  registry knows its capabilities, the contract knows its fields,"
puts "  the plan knows its tasks. did_you_mean taught ruby core that"
puts "  spending 40 lines of Levenshtein there converts a stack trace"
puts "  into a one-keystroke fix, and the lesson ports to every layer"
puts "  above the VM. the suggestion engine is generic; only the"
puts "  candidate list changes. filed as the round-15 ask: thread"
puts "  suggestions into ValidationError (unknown-key hints when a sent"
puts "  key is close to a declared one) and rewire/remove errors -"
puts "  kindness is a Levenshtein pass away."
