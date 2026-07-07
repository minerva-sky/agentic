# frozen_string_literal: true

# The Graph Style Guide: RuboCop for plans. Cops with thresholds run
# against any orchestrator's graph - depth, fan-in, orphans, and the
# style rule I care most about: fan-ins of two or more should NAME
# their dependencies, because a join you can't name is a join you
# don't understand.
#
#   bundle exec ruby examples/graph_style.rb
#
# Runs offline; lints a tidy plan and a messy one.

require_relative "../lib/agentic"

STYLE = {
  "Graph/MaxDepth" => {limit: 4, why: "every level is latency and a failure domain"},
  "Graph/MaxFanIn" => {limit: 3, why: "wide joins own too many failure modes"},
  "Graph/NoOrphans" => {why: "unconnected tasks are in the wrong plan or missing an edge"},
  "Graph/NamedFanIns" => {min_to_name: 2, why: "a join you can't name is a join you don't understand"}
}.freeze

def lint(graph, style)
  names = graph[:tasks].transform_values(&:description)
  stats = graph[:stats]
  offenses = []

  if stats[:max_depth] > style["Graph/MaxDepth"][:limit]
    deepest = stats[:depth].max_by { |_, d| d }.first
    offenses << ["Graph/MaxDepth", "#{names[deepest]} sits #{stats[:max_depth]} deep (limit #{style["Graph/MaxDepth"][:limit]})"]
  end

  graph[:dependencies].each do |id, deps|
    if deps.size > style["Graph/MaxFanIn"][:limit]
      offenses << ["Graph/MaxFanIn", "#{names[id]} joins #{deps.size} (limit #{style["Graph/MaxFanIn"][:limit]})"]
    end
  end

  graph[:dependencies].each do |id, deps|
    if deps.empty? && graph[:edges].none? { |e| e[:from] == id } && graph[:tasks].size > 1
      offenses << ["Graph/NoOrphans", "#{names[id]} touches nothing and is touched by nothing"]
    end
  end

  graph[:dependencies].each do |id, deps|
    next if deps.size < style["Graph/NamedFanIns"][:min_to_name]

    unnamed = graph[:edges].count { |e| e[:to] == id && e[:label].nil? }
    if unnamed.positive?
      offenses << ["Graph/NamedFanIns", "#{names[id]} joins #{deps.size} but #{unnamed} edge(s) are unnamed - use needs:"]
    end
  end

  offenses
end

def step(name)
  Agentic::Task.new(description: name, agent_spec: {"name" => name, "instructions" => "work"})
end

# --- a tidy plan ------------------------------------------------------------
tidy = Agentic::PlanOrchestrator.new
a = step("fetch users")
b = step("fetch orders")
c = step("merge report")
tidy.add_task(a)
tidy.add_task(b)
tidy.add_task(c, needs: {users: a, orders: b})

# --- a messy one --------------------------------------------------------------
messy = Agentic::PlanOrchestrator.new
sources = 4.times.map { |i| step("source-#{i}") }
funnel = step("funnel")
steps = %w[polish buff shine present].map { |n| step(n) }
stray = step("stray")
sources.each { |t| messy.add_task(t) }
messy.add_task(funnel, sources)
previous = funnel
steps.each { |t| messy.add_task(t, [previous]) && (previous = t) }
messy.add_task(stray)

puts "GRAPH STYLE GUIDE (#{STYLE.size} cops)"
{"tidy plan" => tidy, "messy plan" => messy}.each do |label, orchestrator|
  offenses = lint(orchestrator.graph, STYLE)
  puts
  puts "  #{label}: #{offenses.empty? ? "no offenses" : "#{offenses.size} offense(s)"}"
  offenses.each do |cop, message|
    puts "    #{cop}: #{message}"
    puts "      (#{STYLE[cop][:why]})"
  end
end

puts
puts "style guides work because they argue once, in a config file,"
puts "instead of every review. these thresholds are this team's taste -"
puts "yours may differ. that they're WRITTEN DOWN is the feature."
