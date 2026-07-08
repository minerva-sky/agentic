# frozen_string_literal: true

# The Supervision Tree: "let it crash" for plans. The agents in this
# file contain NO rescue clauses - error handling is not the worker's
# job. Recovery is a POLICY, and policies live one level up, in a
# supervisor that knows three strategies from OTP: one_for_one
# (restart the crashed child, keep everyone else's work),
# rest_for_one (restart the crashed child and every child started
# after it - their state may derive from its world), one_for_all
# (restart everything). And because a supervisor that restarts
# forever is just a slow crash, restart INTENSITY is bounded: exceed
# it and the failure escalates up the tree, loudly.
#
#   bundle exec ruby examples/supervision_tree.rb
#
# Runs offline; the same crash is supervised three ways, then a
# hopeless child exhausts its restart budget.

require_relative "../lib/agentic"

Agentic.logger.level = :fatal

class Supervisor
  def initialize(strategy:, max_restarts: 3)
    @strategy = strategy
    @max_restarts = max_restarts
  end

  # children: [{name:, after: [names], agent: ->(deps_hash) {}}] in START ORDER
  def run(children)
    completed = {}
    restarts = 0

    loop do
      failed = execute_round(children, completed)
      return {status: :completed, outputs: completed, restarts: restarts} unless failed
      restarts += 1
      if restarts > @max_restarts
        return {status: :escalated, restarts: restarts - 1,
                reason: "child #{failed.inspect} reached maximum restart intensity (#{@max_restarts}); escalating"}
      end
      invalidated(children, failed).each { |name| completed.delete(name) }
    end
  end

  private

  # One plan run over the not-yet-completed children; finished
  # dependencies are injected so survivors never re-run just to feed
  # their dependents. Returns the first crashed child, or nil.
  def execute_round(children, completed)
    orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 4, retry_policy: {max_retries: 0, retryable_errors: []})
    tasks = {}
    pending = children.reject { |c| completed.key?(c[:name]) }
    pending.each do |child|
      task = Agentic::Task.new(description: child[:name].to_s, agent_spec: {"name" => child[:name].to_s, "instructions" => "work"})
      deps = child[:after].filter_map { |d| tasks[d] } # only edges into this round
      orchestrator.add_task(task, deps, agent: ->(t) {
        inputs = child[:after].to_h { |d| [d, completed[d] || t.output_of(tasks[d])] }
        child[:agent].call(inputs)
      })
      tasks[child[:name]] = task
    end
    result = orchestrator.execute_plan
    pending.each do |child|
      task_result = result.task_result(tasks[child[:name]].id)
      completed[child[:name]] = task_result.output if task_result&.successful?
    end
    pending.find { |c| !completed.key?(c[:name]) }&.fetch(:name)
  end

  def invalidated(children, failed)
    names = children.map { |c| c[:name] }
    case @strategy
    when :one_for_one then [failed]
    when :rest_for_one then names.drop(names.index(failed))
    when :one_for_all then names
    end
  end
end

# The same tree for every scenario: a crash in :fetch on its first
# run, while :heartbeat (started after fetch) has already finished
def tree(runs)
  make = ->(name) {
    ->(_deps) {
      runs[name] += 1
      "#{name} ok"
    }
  }
  [
    {name: :connect, after: [], agent: make.call(:connect)},
    {name: :fetch, after: [:connect], agent: ->(_deps) {
      runs[:fetch] += 1
      raise Agentic::Errors::LlmRateLimitError, "upstream flapped" if runs[:fetch] == 1
      "fetch ok"
    }},
    {name: :heartbeat, after: [:connect], agent: make.call(:heartbeat)},
    {name: :serve, after: [:fetch], agent: make.call(:serve)}
  ]
end

puts "THE SUPERVISION TREE (recovery is a policy, and policies live one level up)"
puts
puts format("  %-14s %-11s %-28s %s", "strategy", "restarts", "runs per child (c/f/h/s)", "who re-ran, and why")

expectations = {one_for_one: [1, 2, 1, 1], rest_for_one: [1, 2, 2, 1], one_for_all: [2, 2, 2, 1]}
failures = []
notes = {
  one_for_one: "only fetch - its crash is its own",
  rest_for_one: "fetch AND heartbeat - started after fetch, state suspect",
  one_for_all: "everyone - the world is rebuilt"
}

expectations.each_key do |strategy|
  runs = Hash.new(0)
  outcome = Supervisor.new(strategy: strategy).run(tree(runs))
  counts = [:connect, :fetch, :heartbeat, :serve].map { |n| runs[n] }
  failures << "#{strategy} ran #{counts.inspect}, expected #{expectations[strategy].inspect}" unless counts == expectations[strategy] && outcome[:status] == :completed
  puts format("  %-14s %-11d %-28s %s", strategy, outcome[:restarts], counts.join("/"), notes[strategy])
end

# The hopeless child: restart budgets exist because a supervisor that
# restarts forever is a crash loop with better manners
runs = Hash.new(0)
doomed = [{name: :flaky_disk, after: [], agent: ->(_d) {
  runs[:flaky_disk] += 1
  raise Agentic::Errors::LlmRateLimitError, "io error"
}}]
outcome = Supervisor.new(strategy: :one_for_one, max_restarts: 3).run(doomed)
puts
puts "  the hopeless child: #{outcome[:reason]}"
puts "    (ran #{runs[:flaky_disk]} times: 1 start + 3 restarts, then UP the tree it goes)"
failures << "escalation broke" unless outcome[:status] == :escalated && runs[:flaky_disk] == 4

puts
puts "  the agents in this file contain zero rescue clauses - that's the"
puts "  design, not an omission. \"let it crash\" splits every system into"
puts "  workers that do the happy path and supervisors that own recovery"
puts "  POLICY: whom to restart (the strategies differ exactly in their"
puts "  blast radius: 1, downstream, all) and how often (intensity, so a"
puts "  permanent failure escalates instead of looping). completed work"
puts "  is state the supervisor protects: heartbeat's result survived"
puts "  one_for_one, was rebuilt under rest_for_one - both on purpose."
exit(failures.empty? ? 0 : 1)
