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
# graph[:edges] arrives pre-merged with labels and graph[:order] gives
# stable, topological node numbering - both were this example's asks.
def to_mermaid(graph)
  names = graph[:tasks].transform_values(&:description)
  ids = graph[:order].each_with_index.to_h { |task_id, i| [task_id, "T#{i}"] }

  lines = ["graph TD"]
  graph[:order].each { |task_id| lines << "  #{ids[task_id]}[\"#{names[task_id]}\"]" }
  graph[:edges].each do |edge|
    arrow = edge[:label] ? "-- #{edge[:label]} -->" : "-->"
    lines << "  #{ids[edge[:from]]} #{arrow} #{ids[edge[:to]]}"
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
