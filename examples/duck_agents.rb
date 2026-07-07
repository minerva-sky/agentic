# frozen_string_literal: true

# Duck Agents: the agent: seam asks one question - "can you be called
# with a task?" - and five differently-shaped objects all answer yes:
# a lambda, an instance, a Method, a curried proc, and a decorator
# wrapping any of the others. Nobody was asked what class they are.
# Ask for what you need, not for who someone is.
#
#   bundle exec ruby examples/duck_agents.rb
#
# Runs offline; one plan, five ducks, one timing decorator.

require_relative "../lib/agentic"

Agentic.logger.level = :fatal

# Duck 1: a lambda - the shape you reach for first
fetch = ->(task) { {records: 12, source: task.description} }

# Duck 2: a plain object with #call - state and a real home for logic
class Deduper
  def initialize
    @seen = 0
  end

  def call(_task)
    @seen += 1
    {unique: 9, dropped: 3, pass: @seen}
  end
end

# Duck 3: a Method object - module functions join the plan unwrapped
module Stats
  def self.summarize(_task)
    {mean: 4.2, max: 9}
  end
end

# Duck 4: a curried proc - configuration applied ahead of time,
# leaving exactly the one-argument shape the seam asks for
render = lambda { |format, _task| {rendered: true, format: format} }
render_html = render.curry["html"]

# Duck 5: a decorator - wraps ANY of the above, because it only
# relies on the same one-message contract it provides
class Timed
  def initialize(inner)
    @inner = inner
  end

  def call(task)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    @inner.call(task).merge(
      timed_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(2)
    )
  end
end

def task(name)
  Agentic::Task.new(description: name, agent_spec: {"name" => name, "instructions" => "work"})
end

orchestrator = Agentic::PlanOrchestrator.new
fetch_task = task("fetch")
dedupe_task = task("dedupe")
stats_task = task("stats")
render_task = task("render")
audit_task = task("audit")

orchestrator.add_task(fetch_task, agent: fetch)
orchestrator.add_task(dedupe_task, [fetch_task], agent: Deduper.new)
orchestrator.add_task(stats_task, [dedupe_task], agent: Stats.method(:summarize))
orchestrator.add_task(render_task, [stats_task], agent: render_html)
orchestrator.add_task(audit_task, [render_task], agent: Timed.new(->(_t) { {audited: true} }))

result = orchestrator.execute_plan

DUCKS = {
  "fetch" => "lambda",
  "dedupe" => "instance with #call",
  "stats" => "Method object",
  "render" => "curried proc",
  "audit" => "decorator around a lambda"
}.freeze

puts "DUCK AGENTS (one seam, five shapes)"
puts
[fetch_task, dedupe_task, stats_task, render_task, audit_task].each do |t|
  output = result.task_result(t.id).output
  puts format("  %-8s %-26s -> %s", t.description, DUCKS[t.description], output)
end

puts
puts "  the seam asked one question: respond to call (or execute) with a"
puts "  task. it never asked anyone's class, so anything shaped right"
puts "  walks in: closures for the quick cases, instances when logic"
puts "  deserves a home, Method objects when it already has one, curry"
puts "  for pre-applied config, and decorators that stack because they"
puts "  honor the same contract they consume. depend on messages and"
puts "  every object ever written - and not yet written - is a plugin."
