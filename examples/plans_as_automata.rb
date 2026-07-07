# frozen_string_literal: true

# Plans as Automata: strip away the agents and the LLMs and a plan is
# a transition system - states are sets of completed tasks, and each
# step completes one task whose dependencies are satisfied. Which
# means questions about plans ("can it finish?", "must it finish?",
# "what can run together?") aren't matters of testing or opinion:
# they're REACHABILITY, and small plans let us compute the entire
# state space and simply look.
#
#   bundle exec ruby examples/plans_as_automata.rb
#
# Runs offline; the whole state machine is enumerated, then judged.

require_relative "../lib/agentic"
require "set"

def task_named(name)
  Agentic::Task.new(description: name, agent_spec: {"name" => name, "instructions" => "w"})
end

def diamond
  o = Agentic::PlanOrchestrator.new
  a, b, c, d = %w[a b c d].map { |n| task_named(n) }
  o.add_task(a)
  o.add_task(b, [a])
  o.add_task(c, [a])
  o.add_task(d, [b, c])
  o
end

def cyclic
  o = Agentic::PlanOrchestrator.new
  x = task_named("x")
  y = task_named("y")
  o.add_task(x, [y.id])
  o.add_task(y, [x])
  o
end

# The operational semantics, in one method: from a state (set of done
# tasks), any task whose deps are all done may fire next
def steps(graph, done)
  graph[:tasks].keys.reject { |t| done.include?(t) }
    .select { |t| graph[:dependencies][t].all? { |d| done.include?(d) } }
end

# Enumerate the full transition system by breadth-first search
def state_space(graph)
  names = graph[:tasks].transform_values(&:description)
  initial = Set.new
  seen = {initial => []}
  frontier = [initial]
  until frontier.empty?
    state = frontier.shift
    steps(graph, state).each do |task|
      next_state = state | [task]
      unless seen.key?(next_state)
        seen[next_state] = []
        frontier << next_state
      end
      seen[state] << names[task]
    end
  end
  seen
end

def judge(title, orchestrator)
  graph = orchestrator.graph
  space = state_space(graph)
  all = graph[:tasks].keys.to_set
  final = space.keys.select { |s| steps(graph, s).empty? }
  complete = final.select { |s| s == all }
  stuck = final - complete

  puts "  #{title}:"
  puts "    reachable states: #{space.size} (of #{2**all.size} conceivable subsets)"
  puts "    terminal states:  #{final.size} -> #{complete.size} complete, #{stuck.size} stuck"
  if stuck.any?
    names = graph[:tasks].transform_values(&:description)
    stuck.each { |s| puts "    STUCK at {#{s.map { |t| names[t] }.sort.join(", ")}} - no task can ever fire" }
  end
  widest = space.keys.max_by { |s| steps(graph, s).size }
  puts "    max choice: #{steps(graph, widest).size} tasks ready at once from one state"
  puts
  [space, complete, stuck]
end

puts "PLANS AS AUTOMATA (the whole state space, enumerated)"
puts
space, complete, = judge("the diamond (a -> b,c -> d)", diamond)
_, complete2, stuck2 = judge("the cycle (x <-> y)", cyclic)

puts "  what enumeration buys that testing cannot: the diamond's #{space.size}"
puts "  reachable states include EVERY execution order the scheduler"
puts "  could ever choose - both b-then-c and c-then-b paths converge,"
puts "  so completion isn't 'observed in CI', it's TOTAL: all runs"
puts "  reach {a,b,c,d}, by exhaustion of a 6-state space rather than"
puts "  by sampling it. the cycle tells the opposite story with the"
puts "  same rigor: its only terminal state is the empty set - not one"
puts "  task can EVER fire - which is why round 9's depth invariant"
puts "  had to excuse itself on cycles: there is no altitude in a"
puts "  building with no floors. plans are small automata; for small"
puts "  automata, don't argue about behavior - enumerate it. (at 40"
puts "  tasks the state space outgrows the universe; that's what the"
puts "  invariant provers are for. know which regime you're in.)"

exit((complete.any? && stuck2.any? && complete2.empty?) ? 0 : 1)
