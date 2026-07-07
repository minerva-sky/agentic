# frozen_string_literal: true

# The Graph Invariants Prover: the reflection API makes promises -
# order respects edges, roots have no dependencies, depth is the
# longest path, leaves feed nothing. Documentation asserts these;
# this referee PROVES them, across four plan shapes including a
# deliberate cycle. Exit 0 is a certificate, not a shrug.
#
#   bundle exec ruby examples/graph_invariants.rb
#
# Runs offline; exits 1 if any invariant is violated.

require_relative "../lib/agentic"

def task(name)
  Agentic::Task.new(description: name, agent_spec: {"name" => name, "instructions" => "work"})
end

def chain_plan
  orchestrator = Agentic::PlanOrchestrator.new
  a, b, c, d = %w[a b c d].map { |n| task(n) }
  orchestrator.add_task(a)
  orchestrator.add_task(b, [a])
  orchestrator.add_task(c, [b])
  orchestrator.add_task(d, [c])
  orchestrator
end

def diamond_plan
  orchestrator = Agentic::PlanOrchestrator.new
  top, left, right, bottom = %w[top left right bottom].map { |n| task(n) }
  orchestrator.add_task(top)
  orchestrator.add_task(left, [top])
  orchestrator.add_task(right, [top])
  orchestrator.add_task(bottom, needs: {l: left, r: right})
  orchestrator
end

def forest_plan
  orchestrator = Agentic::PlanOrchestrator.new
  trees = %w[oak elm ash].map { |n| task(n) }
  trees.each { |t| orchestrator.add_task(t) }
  crown = task("crown")
  orchestrator.add_task(crown, trees)
  lone = task("lone")
  orchestrator.add_task(lone)
  orchestrator
end

def cyclic_plan
  orchestrator = Agentic::PlanOrchestrator.new
  x, y = %w[x y].map { |n| task(n) }
  orchestrator.add_task(x, [y.id])
  orchestrator.add_task(y, [x])
  orchestrator
end

# Each invariant is a lambda: graph in, list of violations out
INVARIANTS = {
  "order is a permutation of the task set" => lambda { |g|
    (g[:order].sort == g[:tasks].keys.sort) ? [] : ["order #{g[:order].size} ids, tasks #{g[:tasks].size}"]
  },
  "order respects every edge (acyclic only)" => lambda { |g|
    position = g[:order].each_with_index.to_h
    g[:edges].reject { |e| position[e[:from]] < position[e[:to]] }
      .map { |e| "edge #{e[:from]}->#{e[:to]} out of order" }
  },
  "roots are exactly the tasks with no dependencies" => lambda { |g|
    expected = g[:dependencies].select { |_, deps| deps.empty? }.keys
    (g[:stats][:roots].sort == expected.sort) ? [] : ["roots mismatch"]
  },
  "leaves are exactly the tasks nothing depends on" => lambda { |g|
    fed = g[:dependencies].values.flatten
    expected = g[:tasks].keys - fed
    (g[:stats][:leaves].sort == expected.sort) ? [] : ["leaves mismatch"]
  },
  "depth is 1 + max dependency depth (acyclic only)" => lambda { |g|
    g[:tasks].keys.filter_map { |id|
      deps = g[:dependencies][id]
      expected = deps.empty? ? 1 : 1 + deps.map { |d| g[:stats][:depth][d] || 0 }.max
      "depth[#{id}] = #{g[:stats][:depth][id]}, expected #{expected}" if g[:stats][:depth][id] != expected
    }
  },
  "max_depth and max_fan_in agree with their sources" => lambda { |g|
    violations = []
    violations << "max_depth" if g[:stats][:max_depth] != (g[:stats][:depth].values.max || 0)
    violations << "max_fan_in" if g[:stats][:max_fan_in] != (g[:dependencies].values.map(&:size).max || 0)
    violations
  },
  "every needs: label appears on its edge" => lambda { |g|
    g[:needs].flat_map { |task_id, named|
      named.filter_map { |label, dep_id|
        edge = g[:edges].find { |e| e[:from] == dep_id && e[:to] == task_id }
        "label #{label} missing on #{dep_id}->#{task_id}" if edge.nil? || edge[:label] != label
      }
    }
  }
}.freeze

PLANS = {
  "chain (a->b->c->d)" => chain_plan,
  "diamond (labeled join)" => diamond_plan,
  "forest (3 trees + orphan)" => forest_plan,
  "cycle (x<->y)" => cyclic_plan
}.freeze

puts "GRAPH INVARIANTS PROVER (#{INVARIANTS.size} invariants x #{PLANS.size} plan shapes)"
puts
failures = 0
PLANS.each do |plan_name, orchestrator|
  graph = orchestrator.graph
  cyclic = plan_name.include?("cycle")
  puts "  #{plan_name}:"
  INVARIANTS.each do |invariant_name, check|
    next if cyclic && invariant_name.include?("acyclic only")

    violations = check.call(graph)
    failures += violations.size
    status = violations.empty? ? "proved" : "VIOLATED: #{violations.join("; ")}"
    puts format("    %-52s %s", invariant_name, status)
  end
  puts
end

if failures.zero?
  puts "  #{INVARIANTS.size * PLANS.size - 2} proofs, 0 violations. two invariants excuse themselves"
  puts "  on the cycle - and finding THAT was the prover's first catch: depth"
  puts "  means \"longest path from a root\", and cyclic graphs have no such"
  puts "  number, so the promise is scoped, not broken. these are the promises"
  puts "  every graph tool built in rounds 5-8 leans on - the forest drawing, the"
  puts "  spec generator, the merge, the diff. a reflection API that ships"
  puts "  without its invariants proved is asking consumers to prove them"
  puts "  one production incident at a time."
else
  puts "  #{failures} VIOLATION(S) - the reflection API broke a promise."
end
exit(failures.zero? ? 0 : 1)
