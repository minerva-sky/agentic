# frozen_string_literal: true

# The Critical Path: after a run, combine the graph topology with
# measured durations to find the chain of tasks that determined the
# wall clock. Optimizing anything OFF that path is charity work -
# and this proves it by making a non-critical task instant and
# re-running.
#
#   bundle exec ruby examples/critical_path.rb
#
# Runs offline; durations are simulated IO.

require_relative "../lib/agentic"

WORK = {
  "pull:catalog" => {sleep: 0.05, deps: []},
  "pull:orders" => {sleep: 0.18, deps: []},
  "pull:reviews" => {sleep: 0.06, deps: []},
  "score:products" => {sleep: 0.09, deps: ["pull:catalog", "pull:reviews"]},
  "invoice:month" => {sleep: 0.12, deps: ["pull:orders"]},
  "report:board" => {sleep: 0.04, deps: ["score:products", "invoice:month"]}
}.freeze

def run(work, concurrency: 6)
  durations = {}
  hooks = {
    after_task_success: ->(task_id:, task:, result:, duration:) { durations[task_id] = duration }
  }
  orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: concurrency, lifecycle_hooks: hooks)
  tasks = {}
  work.each do |name, spec|
    tasks[name] = Agentic::Task.new(
      description: name,
      agent_spec: {"name" => name, "instructions" => "simulate"},
      payload: spec[:sleep]
    )
    orchestrator.add_task(tasks[name], spec[:deps].map { |d| tasks.fetch(d) },
      agent: ->(t) { sleep(t.payload) || :ok })
  end
  result = orchestrator.execute_plan
  [orchestrator.graph, durations, result.execution_time]
end

# Longest-duration path to each node, computed over the real topology
def critical_path(graph, durations)
  names = graph[:tasks].transform_values(&:description)
  memo = {}
  walk = lambda do |task_id|
    memo[task_id] ||= begin
      deps = graph[:dependencies][task_id]
      best = deps.map { |dep| walk.call(dep) }.max_by { |p| p[:cost] } || {cost: 0.0, path: []}
      {cost: best[:cost] + durations[task_id], path: best[:path] + [names[task_id]]}
    end
  end
  graph[:dependencies].keys.map { |id| walk.call(id) }.max_by { |p| p[:cost] }
end

graph, durations, wall = run(WORK)
path = critical_path(graph, durations)

puts "CRITICAL PATH ANALYSIS"
puts
puts format("  wall clock:      %dms", wall * 1000)
puts format("  critical path:   %dms  =  %s", path[:cost] * 1000, path[:path].join(" -> "))
puts format("  (path explains %.0f%% of the wall clock - the rest is scheduling noise)",
  100 * path[:cost] / wall)
puts

# The proof: optimize a NON-critical task to zero... nothing happens
off_path = WORK.keys.find { |name| !path[:path].include?(name) }
faster = WORK.merge(off_path => WORK[off_path].merge(sleep: 0.0))
_, _, wall_after_wrong = run(faster)

# Now halve the SLOWEST task on the path... everything happens
bottleneck = path[:path].max_by { |name| WORK[name][:sleep] }
righter = WORK.merge(bottleneck => WORK[bottleneck].merge(sleep: WORK[bottleneck][:sleep] / 2))
_, _, wall_after_right = run(righter)

puts "the experiment:"
puts format("  make '%s' (off-path) instant:   %3dms -> %3dms  (nothing. told you.)",
  off_path, wall * 1000, wall_after_wrong * 1000)
puts format("  halve '%s' (on-path):     %3dms -> %3dms  (there it is)",
  bottleneck, wall * 1000, wall_after_right * 1000)
puts
puts "profile the path, not the plan. optimizing off the critical path"
puts "is how teams burn a sprint making the fast part faster."
