# frozen_string_literal: true

# Did You Mean, for plans: the kindest thing an error can do is
# finish your sentence. In round 14 this example retrofitted
# suggestions onto three error seams from the outside; the round-15
# release moved them INSIDE - ValidationError diagnoses renamed keys
# and the rewire/remove errors suggest close task names, natively.
# This file now just... triggers the errors, and lets them speak.
#
#   bundle exec ruby examples/did_you_mean.rb
#
# Runs offline; every suggestion below comes from the framework itself.

require_relative "../lib/agentic"

Agentic.logger.level = :fatal

puts "DID YOU MEAN, FOR PLANS (the errors finish your sentence natively now)"
puts

# --- seam 1: a renamed contract field --------------------------------------------
contract = Agentic::CapabilitySpecification.new(
  name: "quote", description: "q", version: "1.0.0",
  inputs: {mode: {type: "string", required: true}, weight_kg: {type: "number", required: true}}
)
begin
  Agentic::CapabilityValidator.new(contract).validate_inputs!(mode: "air", weight_kilo: 50)
rescue Agentic::Errors::ValidationError => e
  puts "  contract violation (sent :weight_kilo for :weight_kg):"
  puts "    #{e.message}"
  puts "    structured too: e.hints => #{e.hints.inspect}"
end
puts

# --- seam 2: a typo'd rewire target ----------------------------------------------
orchestrator = Agentic::PlanOrchestrator.new
tasks = %w[fetch_orders fetch_refunds build_ledger].to_h { |n|
  t = Agentic::Task.new(description: n, agent_spec: {"name" => n, "instructions" => "w"})
  orchestrator.add_task(t)
  [n, t]
}
begin
  orchestrator.rewire_task(tasks["build_ledger"], ["fetch_order"])
rescue ArgumentError => e
  puts "  rewire to a task that doesn't exist:"
  puts "    #{e.message}"
end
puts

# --- seam 3: remove with a misremembered name ------------------------------------
begin
  orchestrator.remove_task("build_ledgr")
rescue ArgumentError => e
  puts "  remove a misremembered task:"
  puts "    #{e.message}"
end
puts

# --- the discipline: no wild guesses ----------------------------------------------
begin
  Agentic::CapabilityValidator.new(contract).validate_inputs!(mode: "air", banana: true)
rescue Agentic::Errors::ValidationError => e
  puts "  and the silence discipline (sent :banana, nothing close):"
  puts "    hints: #{e.hints.inspect} - a wrong suggestion is worse than none"
end
puts
puts "  round 14 built this as a retrofit and filed the ask; round 15"
puts "  delivered it as Agentic::Suggestions plus hints threaded into"
puts "  ValidationError and the rewire/remove errors - the candidate"
puts "  lists were already in scope at every raise site, so the whole"
puts "  feature is one Levenshtein pass and the discipline to stay"
puts "  quiet past the threshold. missing-plus-similar-extra is a"
puts "  typo's signature; now the framework reads signatures. kindness"
puts "  shipped as infrastructure, which is where kindness scales."
