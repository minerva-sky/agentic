# frozen_string_literal: true

# The Escalation Ladder: the pattern under every AI product that
# survives contact with customers. The machine does the whole job it
# can PROVE it can do, and hands the rest up a ladder - tier 0
# auto-resolves from playbooks, tier 1 drafts for known-but-nuanced
# intents, and the human queue takes the rest. Two rules make it a
# product instead of a demo: confidence thresholds are BUSINESS
# POLICY as data (not vibes in a prompt), and sensitivity TRUMPS
# confidence - the machine can be 95% sure about a legal threat and
# 100% wrong to touch it. Escalation hands over a dossier, never a
# shrug.
#
#   bundle exec ruby examples/support_escalation.rb
#
# Runs offline; six tickets ride the ladder, exit 1 if any lands
# on the wrong rung.

require_relative "../lib/agentic"
require "tmpdir"

Agentic.logger.level = :fatal

POLICY = {auto_resolve_at: 0.8, draft_at: 0.5}.freeze

TICKETS = [
  {id: "T-1", text: "I forgot my password and the reset email never arrives"},
  {id: "T-2", text: "I was charged twice this month, please refund the duplicate"},
  {id: "T-3", text: "Refund me today or my lawyer files the chargeback and we sue"},
  {id: "T-4", text: "Would love a dark mode! Any plans?"},
  {id: "T-5", text: "The export finished but the CSV opens garbled in Excel"},
  {id: "T-6", text: "it just doesnt work anymore??? nothing loads. fix it"}
].freeze

# Offline stand-in for the triage LLM: keyword scoring with an
# honest confidence and a sensitivity flag (money+threats, legal)
TRIAGE = ->(text) {
  signals = {
    password_reset: ["password", "reset"], refund: ["charged", "refund", "chargeback"],
    feature_request: ["love", "plans", "mode"], data_export: ["export", "csv", "garbled"]
  }
  scores = signals.transform_values { |words| words.count { |w| text.downcase.include?(w) } }
  intent, hits = scores.max_by { |_, v| v }
  {intent: (hits.zero? ? :unknown : intent),
   confidence: [hits * 0.45, 0.95].min.round(2),
   sensitive: text.match?(/lawyer|sue|legal|lawsuit/i)}
}

PLAYBOOKS = {
  password_reset: "Sent manual reset link; advised checking spam filters.",
  feature_request: "Logged +1 for the feature; shared the public roadmap."
}.freeze

SPECIALIST = ->(ticket, triage) {
  case triage[:intent]
  when :refund then "Drafted refund of the duplicate charge pending payment-ops review."
  when :data_export then "Reproduced: BOM missing for Excel; sent UTF-8 BOM re-export steps."
  end
}

journal = Agentic::ExecutionJournal.new(path: File.join(Dir.tmpdir, "agentic_ladder.jsonl"))
File.delete(journal.path) if File.exist?(journal.path)
orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 6, lifecycle_hooks: journal.lifecycle_hooks)

routed = {}
TICKETS.each do |ticket|
  triage = Agentic::Task.new(description: "triage #{ticket[:id]}", agent_spec: {"name" => "t", "instructions" => "w"}, payload: ticket)
  resolve = Agentic::Task.new(description: "resolve #{ticket[:id]}", agent_spec: {"name" => "r", "instructions" => "w"})
  orchestrator.add_task(triage, agent: ->(t) { {ticket: t.payload, triage: TRIAGE.call(t.payload[:text])} })
  orchestrator.add_task(resolve, [triage], agent: ->(t) {
    dossier = t.previous_output
    verdict = dossier[:triage]
    tier, outcome =
      if verdict[:sensitive]
        # sensitivity trumps confidence, always - this branch is FIRST
        [:human, "sensitive (#{verdict[:confidence]} confident, and it does not matter)"]
      elsif verdict[:confidence] >= POLICY[:auto_resolve_at] && PLAYBOOKS[verdict[:intent]]
        [:auto, PLAYBOOKS[verdict[:intent]]]
      elsif verdict[:confidence] >= POLICY[:draft_at] && (draft = SPECIALIST.call(dossier[:ticket], verdict))
        [:specialist, draft]
      else
        [:human, "low confidence (#{verdict[:confidence]})"]
      end
    dossier.merge(tier: tier, outcome: outcome)
  })
  routed[ticket[:id]] = resolve
end

result = orchestrator.execute_plan
resolutions = routed.transform_values { |task| result.task_result(task.id).output }

puts "THE ESCALATION LADDER (do what you can prove; hand up the rest with a dossier)"
puts
[[:auto, "tier 0 - auto-resolved from playbooks"], [:specialist, "tier 1 - specialist drafts"], [:human, "the human queue"]].each do |tier, label|
  puts "  #{label}:"
  resolutions.select { |_, r| r[:tier] == tier }.each do |id, r|
    puts "    #{id} (#{r[:triage][:intent]}, conf #{r[:triage][:confidence]}): #{r[:outcome]}"
    if tier == :human
      puts "         dossier: #{r[:ticket][:text][0, 44].inspect}... triage + attempts attached"
    end
  end
  puts
end

failures = []
failures << "the legal threat was touched by a machine" unless resolutions["T-3"][:tier] == :human
failures << "gibberish was not sent to a human" unless resolutions["T-6"][:tier] == :human
failures << "the password reset should have auto-resolved" unless resolutions["T-1"][:tier] == :auto
failures << "a ticket fell off the ladder" unless resolutions.values.all? { |r| r[:tier] }
failures << "a human item arrived without a dossier" if resolutions.values.any? { |r| r[:tier] == :human && !(r[:ticket] && r[:triage]) }

puts "  the two load-bearing rules: thresholds are DATA (0.8 and 0.5 live"
puts "  in a POLICY hash a product manager can read, diff, and A/B), and"
puts "  the sensitivity check outranks the confidence check in the"
puts "  routing order itself - T-3 scored confident-refund and still went"
puts "  human, because being sure is not the same as being allowed."
puts "  escalation is not failure; it's the product working as designed -"
puts "  and every handoff carries the full dossier, so the human starts"
puts "  from everything the machine learned instead of a blank screen."
exit(failures.empty? ? 0 : 1)
