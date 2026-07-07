# frozen_string_literal: true

# The Graph Critic: reviews a plan's dependency structure BEFORE it
# runs, the way you'd review a class diagram. God tasks, deep chains,
# and orphans are design smells in a graph exactly as they are in
# objects - and they're cheaper to fix before execution than after.
#
#   bundle exec ruby examples/graph_critic.rb
#
# Runs offline; no task is executed. The review IS the program.

require_relative "../lib/agentic"

def task_named(name)
  Agentic::Task.new(
    description: name,
    agent_spec: {"name" => name, "instructions" => "work"}
  )
end

# A plan with three deliberate smells
orchestrator = Agentic::PlanOrchestrator.new
tasks = {}
%w[ingest_a ingest_b ingest_c ingest_d ingest_e clean join report publish lonely].each do |name|
  tasks[name] = task_named(name)
end

orchestrator.add_task(tasks["ingest_a"])
orchestrator.add_task(tasks["ingest_b"])
orchestrator.add_task(tasks["ingest_c"])
orchestrator.add_task(tasks["ingest_d"])
orchestrator.add_task(tasks["ingest_e"])
# the god task: everything funnels through join
orchestrator.add_task(tasks["join"], %w[ingest_a ingest_b ingest_c ingest_d ingest_e].map { |n| tasks[n] })
# a chain hanging off it
orchestrator.add_task(tasks["clean"], [tasks["join"]])
orchestrator.add_task(tasks["report"], [tasks["clean"]])
orchestrator.add_task(tasks["publish"], [tasks["report"]])
# and a task nobody references
orchestrator.add_task(tasks["lonely"])

# --- the critique ----------------------------------------------------------
# This example's original feature request, granted: a read-only view of
# the plan's topology. No more crowbar.
graph = orchestrator.graph
dependencies = graph[:dependencies]
names = graph[:tasks].transform_values(&:description)

dependents = Hash.new { |h, k| h[k] = [] }
dependencies.each { |task_id, deps| deps.each { |dep| dependents[dep] << task_id } }

# Depth now ships precomputed in the snapshot
depth_of = ->(task_id) { graph[:stats][:depth][task_id] }

findings = []

dependencies.each do |task_id, deps|
  if deps.size >= 4
    findings << {smell: "god task", task: names[task_id],
                 note: "gathers #{deps.size} dependencies - does it join, or does it do everything? " \
                   "consider staged joins so each has one reason to wait"}
  end
end

deepest = dependencies.keys.max_by { |task_id| depth_of.call(task_id) }
if depth_of.call(deepest) >= 4
  findings << {smell: "deep chain", task: names[deepest],
               note: "sits #{depth_of.call(deepest)} levels down - every level is latency and a failure " \
                 "domain; could any middle link merge with a neighbor?"}
end

dependencies.each do |task_id, deps|
  if deps.empty? && dependents[task_id].empty? && dependencies.size > 1
    findings << {smell: "orphan", task: names[task_id],
                 note: "no dependencies, no dependents - is it in the wrong plan, or is the " \
                   "connection that justifies it missing?"}
  end
end

puts "GRAPH CRITIC: #{dependencies.size} tasks reviewed before execution"
puts
findings.each do |finding|
  puts "  [#{finding[:smell]}] #{finding[:task]}"
  puts "     #{finding[:note]}"
  puts
end

puts "prescription: fix ONE - start with the god task. five ingests"
puts "joining at once usually means 'join' hides a pipeline: stage the"
puts "joins (a+b, c+d+e, then both) and each join gets one reason to"
puts "change. rerun the critic; the chain may resolve itself."
