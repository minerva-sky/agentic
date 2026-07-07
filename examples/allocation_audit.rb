# frozen_string_literal: true

# The Allocation Audit: every object is a promissory note the GC
# collects on later. This audit counts exactly what each framework
# operation allocates (GC.stat's total_allocated_objects is an exact
# counter, not a sample) and where the GC actually runs during a
# plan. Latency spikes that "come from nowhere" come from here.
#
#   bundle exec ruby examples/allocation_audit.rb
#
# Runs offline; counts are exact for this Ruby version.

require_relative "../lib/agentic"

Agentic.logger.level = :fatal

def allocations(iterations = 100)
  yield # warm: first call pays memoization, schema compilation, caches
  GC.start
  before = GC.stat(:total_allocated_objects)
  iterations.times { yield }
  (GC.stat(:total_allocated_objects) - before) / iterations
end

def task_named(name)
  Agentic::Task.new(description: name, agent_spec: {"name" => "w", "instructions" => "work"})
end

SPEC = Agentic::CapabilitySpecification.new(
  name: "audit", description: "x", version: "1.0.0",
  inputs: {mode: {type: "string", required: true, enum: %w[a b]},
           weight: {type: "number", required: true, min: 1, max: 100}},
  rules: {fits: {relation: :sum_lte, fields: [:weight], limit: 100}}
)
VALIDATOR = Agentic::CapabilityValidator.new(SPEC)

def ten_task_orchestrator
  orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 4)
  previous = nil
  10.times do |i|
    task = task_named("t#{i}")
    orchestrator.add_task(task, previous ? [previous] : [], agent: ->(_t) { :ok })
    previous = task
  end
  orchestrator
end

puts "ALLOCATION AUDIT (objects per operation, exact via GC.stat)"
puts

rows = {
  "Task.new" => -> { task_named("x") },
  "validator: happy path" => -> { VALIDATOR.validate_inputs!(mode: "a", weight: 50) },
  "validator: rejection" => -> {
    begin
      VALIDATOR.validate_inputs!(mode: "z", weight: 500)
    rescue Agentic::Errors::ValidationError
      nil
    end
  },
  "graph snapshot (10 tasks)" => -> { ten_task_orchestrator.graph },
  "to_json_schema" => -> { SPEC.to_json_schema }
}

counts = rows.transform_values { |op| allocations(&op) }
counts.each do |label, objects|
  puts format("  %-28s %6d objects   %s", label, objects, "#" * [objects / 50, 40].min)
end

# The graph row includes building the orchestrator - separate the two
build_only = allocations { ten_task_orchestrator }
graph_only = counts["graph snapshot (10 tasks)"] - build_only
puts format("  %-28s %6d objects   (snapshot alone, build subtracted)", "  ...graph, isolated", graph_only)

# --- where the GC actually fires during a plan ---------------------------------
orchestrator = ten_task_orchestrator
GC.start
gc_before = GC.count
allocated_before = GC.stat(:total_allocated_objects)
orchestrator.execute_plan
plan_allocations = GC.stat(:total_allocated_objects) - allocated_before
gc_runs = GC.count - gc_before

puts
puts format("  a full 10-task plan allocates %d objects and triggered %d GC run(s).", plan_allocations, gc_runs)
puts
per_call = counts["validator: happy path"]
puts "  reading the audit like a VM person: the happy-path validation"
puts "  (#{per_call} objects) is what you multiply by requests-per-second -"
puts "  #{per_call} x 1000 rps is #{per_call * 1000} promissory notes a second, and the GC"
puts "  collects on schedule whether you budgeted or not. rejection costs"
puts "  #{counts["validator: rejection"] / per_call}x the happy path in objects (exceptions carry backtraces;"
puts "  error paths are allocation paths), and the graph snapshot's"
puts "  #{graph_only} objects of dup+freeze buy the immutability every round-8"
puts "  tool leans on - that's not waste, that's a purchase. allocation"
puts "  isn't evil; UNBUDGETED allocation is. now there's a budget."
