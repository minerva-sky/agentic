# frozen_string_literal: true

# The Plan Kata: red, green, refactor - for a plan. The "tests" are
# assertions about the graph (one root, one leaf, labeled joins,
# nothing too deep), written BEFORE any tasks exist. Each step adds
# the smallest thing that moves a red line green, and the refactor
# step changes structure with the assertions standing guard. You've
# TDD'd methods; plans deserve the same discipline.
#
#   bundle exec ruby examples/plan_kata.rb
#
# Runs offline; exits 1 if the kata ends with a red assertion.

require_relative "../lib/agentic"

def task_named(name)
  Agentic::Task.new(description: name, agent_spec: {"name" => name, "instructions" => "w"})
end

# The test list, written first - what a GOOD ingest plan looks like,
# structurally, before we know what the tasks are
ASSERTIONS = {
  "has exactly one entry point" => ->(g) { g[:stats][:roots].size == 1 },
  "has exactly one deliverable" => ->(g) { g[:stats][:leaves].size == 1 },
  "every join names its inputs" => ->(g) {
    g[:dependencies].select { |_, d| d.size >= 2 }.keys.all? { |id|
      g[:edges].select { |e| e[:to] == id }.all? { |e| e[:label] }
    }
  },
  "no deeper than four stages" => ->(g) { g[:stats][:max_depth] <= 4 },
  "no orphan tasks" => ->(g) {
    g[:tasks].size < 2 || (g[:stats][:roots] & g[:stats][:leaves]).empty?
  }
}.freeze

def check(orchestrator)
  graph = orchestrator.graph
  ASSERTIONS.transform_values { |assertion| assertion.call(graph) }
end

def report(step, results)
  reds = results.count { |_, ok| !ok }
  puts "  step: #{step}"
  results.each { |name, ok| puts format("    %-32s %s", name, ok ? "green" : "RED") }
  puts format("    -> %d red", reds)
  puts
end

puts "THE PLAN KATA (assertions first, tasks second)"
puts

# RED: no tasks at all - most assertions can't hold on emptiness
o = Agentic::PlanOrchestrator.new
report("empty plan (the honest starting point)", check(o))

# GREEN, smallest step: one task satisfies one-root-one-leaf trivially
ingest = task_named("ingest")
o.add_task(ingest)
report("add the entry point", check(o))

# Grow: parse feeds off ingest; deliverable moves - still green
parse = task_named("parse")
o.add_task(parse, [ingest])
report("add parse", check(o))

# RED on purpose: a second source creates a second root, and an
# unlabeled join - two assertions object, and they name the problem
prices = task_named("prices")
merge = task_named("merge")
o.add_task(prices)
o.add_task(merge, [parse, prices])
report("bolt on a price feed (two sins)", check(o))

# GREEN again: rebuild the seam properly. A plan can't remove tasks
# (round-12 ask!), so the kata rebuilds - which is itself the lesson:
# keep plans cheap to rebuild
o = Agentic::PlanOrchestrator.new
ingest = task_named("ingest")
parse = task_named("parse")
prices = task_named("prices")
merge = task_named("merge")
report_task = task_named("report")
o.add_task(ingest)
o.add_task(parse, [ingest])
o.add_task(prices, [ingest]) # both feeds enter through ONE door
o.add_task(merge, needs: {parsed: parse, prices: prices})
o.add_task(report_task, [merge])
final = check(o)
report("rebuild: one entry, labeled merge", final)

reds = final.count { |_, ok| !ok }
puts "  the kata's shape is the point: the assertions existed before"
puts "  the plan did, every addition was the smallest thing that moved"
puts "  a line, and the two deliberate sins were CAUGHT and NAMED by"
puts "  tests written when nobody was defensive about the design yet."
puts "  notice the refactor step required rebuilding the orchestrator -"
puts "  plans are add-only today. filed as the round-12 ask: remove_task"
puts "  (or a rewire seam), so refactoring a plan doesn't mean"
puts "  reconstructing it. #{(reds == 0) ? "kata complete, all green." : "KATA INCOMPLETE."}"
exit((reds == 0) ? 0 : 1)
