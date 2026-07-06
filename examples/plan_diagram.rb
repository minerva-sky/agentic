# frozen_string_literal: true

# The Plan Diagrammer: any orchestrator's graph, emitted as Mermaid -
# paste it into a README, GitHub renders it, and the diagram can never
# drift from the plan because it is generated FROM the plan.
#
#   bundle exec ruby examples/plan_diagram.rb
#
# Runs offline; prints Mermaid source. Named dependencies become
# labeled edges; plain dependencies become arrows.

require_relative "../lib/agentic"

# A representative plan: the editorial pipeline with a named fan-in
orchestrator = Agentic::PlanOrchestrator.new

def step(name)
  Agentic::Task.new(description: name, agent_spec: {"name" => name, "instructions" => "work"})
end

research = step("research topic")
outline = step("draft outline")
sources = step("verify sources")
draft = step("write draft")
publish = step("publish")

orchestrator.add_task(research)
orchestrator.add_task(outline, [research])
orchestrator.add_task(sources, [research])
orchestrator.add_task(draft, needs: {skeleton: outline, citations: sources})
orchestrator.add_task(publish, [draft])

# --- the diagrammer: graph in, mermaid out -----------------------------------
def to_mermaid(graph)
  names = graph[:tasks].transform_values(&:description)
  ids = names.keys.each_with_index.to_h { |task_id, i| [task_id, "T#{i}"] }

  named_edges = graph[:needs].flat_map { |task_id, needs|
    needs.map { |label, dep_id| [dep_id, task_id, label] }
  }
  labeled = named_edges.to_h { |from, to, _| [[from, to], true] }

  lines = ["graph TD"]
  names.each { |task_id, name| lines << "  #{ids[task_id]}[\"#{name}\"]" }
  graph[:dependencies].each do |task_id, deps|
    deps.each do |dep_id|
      next if labeled[[dep_id, task_id]] # named edges are drawn with labels below

      lines << "  #{ids[dep_id]} --> #{ids[task_id]}"
    end
  end
  named_edges.each do |from, to, label|
    lines << "  #{ids[from]} -- #{label} --> #{ids[to]}"
  end
  lines.join("\n")
end

mermaid = to_mermaid(orchestrator.graph)

puts "```mermaid"
puts mermaid
puts "```"
puts
puts "paste the block above into any GitHub markdown file. the arrows"
puts "labeled 'skeleton' and 'citations' are the named dependencies -"
puts "the diagram documents not just THAT draft waits, but WHY."
