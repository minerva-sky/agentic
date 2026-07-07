# frozen_string_literal: true

# Refactor Receipts: the god-join plan from the graph critic, improved
# in two small steps - with a receipt after each one. Every step shows
# the smells found, the structure numbers, and the measured wall time,
# because "I made it better" is a claim and receipts are evidence.
#
#   bundle exec ruby examples/refactor_receipts.rb
#
# Runs offline; each task is 30ms of simulated IO.

require_relative "../lib/agentic"

UNIT = 0.03

# Three versions of the same pipeline: five ingests feeding a report
SHAPES = {
  "before: the god join" => {
    "join" => %w[ingest_a ingest_b ingest_c ingest_d ingest_e],
    "report" => %w[join]
  },
  "step 1: stage the pairs" => {
    "join_ab" => %w[ingest_a ingest_b],
    "join_cde" => %w[ingest_c ingest_d ingest_e],
    "join" => %w[join_ab join_cde],
    "report" => %w[join]
  },
  "step 2: report reads the stages" => {
    "join_ab" => %w[ingest_a ingest_b],
    "join_cde" => %w[ingest_c ingest_d ingest_e],
    "report" => %w[join_ab join_cde]
  }
}.freeze

def build(deps)
  orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 4)
  names = (%w[ingest_a ingest_b ingest_c ingest_d ingest_e] + deps.keys).uniq
  tasks = names.to_h { |n| [n, Agentic::Task.new(description: n, agent_spec: {"name" => n, "instructions" => "work"})] }
  names.each do |name|
    orchestrator.add_task(tasks[name], (deps[name] || []).map { |d| tasks.fetch(d) },
      agent: ->(_t) { sleep(UNIT) || :ok })
  end
  orchestrator
end

def critique(graph)
  dependencies = graph[:dependencies]
  smells = []
  dependencies.each do |id, deps|
    smells << "god task (#{deps.size} deps)" if deps.size >= 4
  end
  depth = {}
  measure = ->(id) { depth[id] ||= 1 + (dependencies[id].map { |d| measure.call(d) }.max || 0) }
  max_depth = dependencies.keys.map { |id| measure.call(id) }.max
  smells << "deep chain (#{max_depth} levels)" if max_depth >= 5
  [smells, max_depth, dependencies.values.map(&:size).max]
end

puts "REFACTOR RECEIPTS (five ingests -> report, 30ms per task)"
puts

SHAPES.each do |label, deps|
  orchestrator = build(deps)
  smells, depth, fan_in = critique(orchestrator.graph)
  result = orchestrator.execute_plan

  puts "  #{label}"
  puts format("    wall %3dms | depth %d | max fan-in %d | tasks %d",
    result.execution_time * 1000, depth, fan_in, orchestrator.graph[:tasks].size)
  if smells.empty?
    puts "    critic: no complaints"
  else
    smells.each { |smell| puts "    critic: #{smell}" }
  end
  puts
end

puts "read the receipts honestly: step 1 removed the smell but COST 30ms"
puts "(the extra join level) - a receipt you'd never notice without the"
puts "measurement. step 2 pays it back by letting the report read the"
puts "stages directly. intermediate steps may cost; receipts price them,"
puts "and every step was still a shippable state."
