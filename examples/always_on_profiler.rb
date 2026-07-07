# frozen_string_literal: true

# The Always-On Profiler: the mini-profiler heresy is that profiling
# belongs in PRODUCTION, on EVERY request, visible to the people who
# wrote the slow code - not in a lab you visit twice a year. Every
# plan gets a badge line; plans over their latency budget get named,
# with the top offender attached; and the profiler measures its own
# overhead, because always-on is only defensible when it's near-free.
#
#   bundle exec ruby examples/always_on_profiler.rb
#
# Runs offline; three plans run, one blows its budget.

require_relative "../lib/agentic"

Agentic.logger.level = :fatal

# The whole profiler: hooks in, one badge line out per plan
class AlwaysOn
  def initialize(budget_ms:)
    @budget_ms = budget_ms
    @timings = []
  end

  def hooks
    {
      after_task_success: ->(task_id:, task:, result:, duration:) {
        @timings << [task.description, duration * 1000]
      },
      plan_completed: ->(plan_id:, status:, execution_time:, tasks:, results:) {
        badge(plan_id, status, execution_time * 1000)
        @timings.clear
      }
    }
  end

  def badge(plan_id, status, total_ms)
    top = @timings.max_by(&:last)
    line = format("[prof] %-10s %5.0fms  %d tasks  top: %s (%.0fms)",
      status, total_ms, @timings.size, top[0], top[1])
    if total_ms > @budget_ms
      puts "  #{line}  OVER BUDGET (#{@budget_ms}ms) <- fix #{top[0]} first"
    else
      puts "  #{line}  within budget"
    end
  end
end

def run_plan(name, workloads, hooks: {})
  orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 2, lifecycle_hooks: hooks)
  previous = nil
  workloads.each do |task_name, ms|
    task = Agentic::Task.new(description: task_name, agent_spec: {"name" => task_name, "instructions" => "w"})
    orchestrator.add_task(task, previous ? [previous] : [], agent: ->(_t) {
      sleep(ms / 1000.0)
      :ok
    })
    previous = task
  end
  orchestrator.execute_plan
end

puts "THE ALWAYS-ON PROFILER (a badge on every plan, budgets with teeth)"
puts
profiler = AlwaysOn.new(budget_ms: 120)
run_plan("morning digest", {"fetch" => 20, "rank" => 30, "render" => 15}, hooks: profiler.hooks)
run_plan("weekly report", {"gather" => 25, "summarize" => 95, "publish" => 20}, hooks: profiler.hooks)
run_plan("tiny ping", {"check" => 5}, hooks: profiler.hooks)
puts

# --- the overhead audit: always-on must be near-free -----------------------------
runs = 30
bare = ->(hooks) {
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  runs.times { run_plan("bench", {"a" => 1, "b" => 1}, hooks: hooks) }
  (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) / runs * 1000
}
silent = Class.new(AlwaysOn) {
  def badge(*)
  end
}.new(budget_ms: 999)
without = bare.call({})
with = bare.call(silent.hooks)

puts format("  overhead audit: %.2fms/plan without hooks, %.2fms with - the", without, with)
puts format("  profiler costs %.0f microseconds per plan, which is the entire", (with - without).abs * 1000)
puts "  argument for leaving it on. the lab-visit model of profiling"
puts "  finds the regressions you already shipped; the badge model"
puts "  finds them in the PR preview, because the person who made"
puts "  summarize slow SAW the badge go red before they merged. three"
puts "  rules made mini-profiler work and they all transplant: always"
puts "  on (sampling is for whales; plans can afford everything),"
puts "  visible to the AUTHOR (not a grafana nobody opens), and"
puts "  budgets with a named offender - 'over budget, fix summarize"
puts "  first' is an assignment; a p95 chart is a vibe."
