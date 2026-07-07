# frozen_string_literal: true

# The Round Trip: serialize a plan's graph to JSON, rebuild a fresh
# orchestrator from the JSON, and prove the rebuilt topology is
# isomorphic to the original - same shape, same labels, new ids. A
# projection you can't invert is a projection you can't trust with
# your plans.
#
#   bundle exec ruby examples/plan_roundtrip.rb
#
# Runs offline; prints the wire format and the verdict.

require_relative "../lib/agentic"
require "json"

def step(name)
  Agentic::Task.new(description: name, agent_spec: {"name" => name, "instructions" => "work"})
end

# --- an original plan with every edge flavor ---------------------------------
original = Agentic::PlanOrchestrator.new
gather = step("gather")
check = step("check")
weave = step("weave")
ship = step("ship")

original.add_task(gather)
original.add_task(check)
original.add_task(weave, [check], needs: {threads: gather})
original.add_task(ship, [weave])

# --- serialize: graph -> wire format (ids replaced by descriptions) ---------
def serialize(graph)
  names = graph[:tasks].transform_values(&:description)
  {
    "tasks" => graph[:order].map { |id| names[id] },
    "edges" => graph[:edges].map { |e|
      {"from" => names[e[:from]], "to" => names[e[:to]], "label" => e[:label]&.to_s}
    }
  }
end

# --- deserialize: wire format -> a fresh orchestrator ------------------------
def deserialize(data)
  orchestrator = Agentic::PlanOrchestrator.new
  tasks = data["tasks"].to_h { |name| [name, step(name)] }

  data["tasks"].each do |name|
    edges_in = data["edges"].select { |e| e["to"] == name }
    plain = edges_in.reject { |e| e["label"] }.map { |e| tasks.fetch(e["from"]) }
    named = edges_in.select { |e| e["label"] }
      .to_h { |e| [e["label"].to_sym, tasks.fetch(e["from"])] }

    orchestrator.add_task(tasks[name], plain, needs: named.empty? ? nil : named)
  end
  orchestrator
end

wire = JSON.pretty_generate(serialize(original.graph))
rebuilt = deserialize(JSON.parse(wire))

puts "THE WIRE FORMAT"
puts wire.gsub(/^/, "  ")
puts

# --- the isomorphism check: compare shapes, not ids --------------------------
def shape(graph)
  names = graph[:tasks].transform_values(&:description)
  {
    order: graph[:order].map { |id| names[id] },
    edges: graph[:edges].map { |e| [names[e[:from]], names[e[:to]], e[:label]] }.sort_by(&:to_s)
  }
end

before = shape(original.graph)
after = shape(rebuilt.graph)

puts "THE VERDICT"
if before == after
  puts "  round trip is faithful: #{before[:edges].size} edges, labels intact,"
  puts "  topological order preserved (#{after[:order].join(" -> ")})"
else
  puts "  DRIFT DETECTED:"
  puts "  before: #{before.inspect}"
  puts "  after:  #{after.inspect}"
  exit 1
end
puts
puts "task ids are per-process and correctly absent from the wire format -"
puts "identity travels as description, structure travels as edges, and"
puts "needs: labels survive because graph[:edges] carries them."
