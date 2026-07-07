# frozen_string_literal: true

# The Structural Diff: two versions of a plan's wire format, diffed as
# TOPOLOGY - tasks added and removed, edges rewired, labels renamed.
# A line diff of plan JSON tells you bytes changed; this tells you what
# changed about the plan.
#
#   bundle exec ruby examples/plan_structural_diff.rb
#
# Runs offline; v1 and v2 are built in-process via the round-trip wire
# format, as they would be loaded from two commits of plan.json.

require_relative "../lib/agentic"

def step(name)
  Agentic::Task.new(description: name, agent_spec: {"name" => name, "instructions" => "work"})
end

def wire(orchestrator)
  graph = orchestrator.graph
  names = graph[:tasks].transform_values(&:description)
  {
    "tasks" => graph[:order].map { |id| names[id] },
    "edges" => graph[:edges].map { |e|
      {"from" => names[e[:from]], "to" => names[e[:to]], "label" => e[:label]&.to_s}
    }
  }
end

# --- version 1: last sprint's pipeline ---------------------------------------
v1 = Agentic::PlanOrchestrator.new
fetch = step("fetch feed")
parse = step("parse entries")
rank = step("rank entries")
publish = step("publish digest")
v1.add_task(fetch)
v1.add_task(parse, [fetch])
v1.add_task(rank, needs: {entries: parse})
v1.add_task(publish, [rank])

# --- version 2: this sprint's - dedupe added, ranking rewired ----------------
v2 = Agentic::PlanOrchestrator.new
fetch2 = step("fetch feed")
parse2 = step("parse entries")
dedupe2 = step("dedupe entries")
rank2 = step("rank entries")
publish2 = step("publish digest")
v2.add_task(fetch2)
v2.add_task(parse2, [fetch2])
v2.add_task(dedupe2, needs: {entries: parse2})
v2.add_task(rank2, needs: {candidates: dedupe2})
v2.add_task(publish2, [rank2])

# --- the diff: sets of names and labeled edges --------------------------------
def structural_diff(before, after)
  edge_key = ->(e) { [e["from"], e["to"]] }

  before_edges = before["edges"].to_h { |e| [edge_key.call(e), e["label"]] }
  after_edges = after["edges"].to_h { |e| [edge_key.call(e), e["label"]] }

  {
    tasks_added: after["tasks"] - before["tasks"],
    tasks_removed: before["tasks"] - after["tasks"],
    edges_added: (after_edges.keys - before_edges.keys),
    edges_removed: (before_edges.keys - after_edges.keys),
    labels_changed: before_edges.keys.intersection(after_edges.keys)
      .reject { |k| before_edges[k] == after_edges[k] }
      .map { |k| [k, before_edges[k], after_edges[k]] }
  }
end

diff = structural_diff(wire(v1), wire(v2))

puts "PLAN STRUCTURAL DIFF (v1 -> v2)"
puts
diff[:tasks_added].each { |t| puts "  + task  #{t}" }
diff[:tasks_removed].each { |t| puts "  - task  #{t}" }
diff[:edges_added].each { |(from, to)| puts "  + edge  #{from} -> #{to}" }
diff[:edges_removed].each { |(from, to)| puts "  - edge  #{from} -> #{to}" }
diff[:labels_changed].each { |(from, to), old, new| puts "  ~ label #{from} -> #{to}: #{old.inspect} => #{new.inspect}" }

puts
total = diff.values.sum(&:size)
puts "  #{total} structural changes. the review question is no longer"
puts "  'what do these 40 changed JSON lines mean' but 'should ranking"
puts "  consume deduped candidates instead of raw entries' - which is"
puts "  a question a human can actually answer."
