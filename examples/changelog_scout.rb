# frozen_string_literal: true

# The Changelog Scout: reads real git history, classifies every commit
# through a contract-checked capability, and drafts the release notes -
# features first, fixes second, docs summarized in one line.
#
#   bundle exec ruby examples/changelog_scout.rb [commit_count]
#
# Runs offline against the current repo. Swap the classifier lambda for
# an LLM client when you want prose instead of parsing - the contract
# stays identical.

require_relative "../lib/agentic"

ROOT = File.expand_path("..", __dir__)
count = (ARGV.first || 40).to_i

# --- the classifier: one commit in, one classified entry out ---------------
spec = Agentic::CapabilitySpecification.new(
  name: "classify_commit",
  description: "Classify one commit subject for release notes",
  version: "1.0.0",
  inputs: {subject: {type: "string", required: true}},
  outputs: {
    kind: {type: "string", required: true},
    note: {type: "string", required: true},
    breaking: {type: "boolean", required: true}
  }
)
Agentic.register_capability(spec, Agentic::CapabilityProvider.new(
  capability: spec,
  implementation: ->(inputs) {
    subject = inputs[:subject]
    kind = subject[/\A(feat|fix|docs|refactor|test|chore)/, 1] || "other"
    note = subject.sub(/\A\w+(\([^)]*\))?!?:\s*/, "").sub(/\A(.)/) { $1.upcase }
    {kind: kind, note: note, breaking: subject.include?("!:")}
  }
))

scribe = Agentic::Agent.build { |a| a.name = "Scribe" }
scribe.add_capability("classify_commit")

# --- the plan: classify commits in parallel, then one writer fans in --------
subjects = `git -C #{ROOT} log -#{count} --pretty=format:%s`.lines.map(&:strip)

orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 8)
classifications = subjects.map.with_index do |subject, i|
  task = Agentic::Task.new(
    description: "commit #{i + 1}",
    agent_spec: {"name" => "Scribe", "instructions" => "classify"},
    payload: subject
  )
  orchestrator.add_task(task, agent: ->(t) {
    scribe.execute_capability("classify_commit", {subject: t.payload})
  })
  task
end

notes = Agentic::Task.new(
  description: "release notes",
  agent_spec: {"name" => "Editor", "instructions" => "draft the notes"}
)
orchestrator.add_task(notes, classifications, agent: ->(t) {
  entries = classifications.map { |c| t.output_of(c) }
  grouped = entries.group_by { |e| e[:kind] }

  sections = []
  sections << "## Breaking\n" + entries.select { |e| e[:breaking] }.map { |e| "- #{e[:note]}" }.join("\n") if entries.any? { |e| e[:breaking] }
  {"feat" => "## Features", "fix" => "## Fixes", "refactor" => "## Internals"}.each do |kind, heading|
    items = grouped[kind] or next
    sections << "#{heading}\n#{items.map { |e| "- #{e[:note]}" }.join("\n")}"
  end
  quiet = grouped.slice("docs", "test", "chore", "other").values.flatten.size
  sections << "_...plus #{quiet} documentation, test, and housekeeping commits._" if quiet.positive?
  sections.join("\n\n")
})

result = orchestrator.execute_plan

puts "RELEASE NOTES (last #{subjects.size} commits, drafted in #{(result.execution_time * 1000).round}ms)"
puts "=" * 60
puts result.results[notes.id].output
