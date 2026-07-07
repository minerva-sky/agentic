# frozen_string_literal: true

# Feature Flags for Plans: shipping a new pipeline step shouldn't be
# a deploy decision - it should be a FLAG decision. A tiny Flipper-
# shaped adapter (boolean, actor, percentage gates) decides per run
# whether the experimental step joins the plan, and rewire_task
# splices it in or routes around it. Same code in production for
# everyone; different plans per actor.
#
#   bundle exec ruby examples/feature_flags.rb
#
# Runs offline; three tenants, one flag, three rollout phases.

require_relative "../lib/agentic"

Agentic.logger.level = :fatal

# Flipper's essential shape in 30 lines: gates checked in order
class Flags
  def initialize
    @features = Hash.new { |h, k| h[k] = {boolean: false, actors: [], percentage: 0} }
  end

  def enable(name) = @features[name][:boolean] = true

  def enable_actor(name, actor) = @features[name][:actors] << actor

  def enable_percentage(name, pct) = @features[name][:percentage] = pct

  def enabled?(name, actor = nil)
    f = @features[name]
    return true if f[:boolean]
    return true if actor && f[:actors].include?(actor)
    return true if actor && f[:percentage].positive? &&
      (actor.sum(&:ord) % 100) < f[:percentage] # deterministic bucketing

    false
  end
end

FLAGS = Flags.new

def task_named(name)
  Agentic::Task.new(description: name, agent_spec: {"name" => name, "instructions" => "w"})
end

# One plan definition; the flag decides its SHAPE per actor
def build_plan(tenant)
  o = Agentic::PlanOrchestrator.new
  fetch = task_named("fetch")
  summarize = task_named("summarize")
  publish = task_named("publish")
  o.add_task(fetch, agent: ->(_t) { "articles" })
  o.add_task(summarize, [fetch], agent: ->(_t) { "summary" })
  o.add_task(publish, [summarize], agent: ->(t) { "published: #{t.previous_output}" })

  if FLAGS.enabled?(:fact_check, tenant)
    check = task_named("fact_check")
    o.add_task(check, [summarize], agent: ->(_t) { "checked summary" })
    o.rewire_task(publish, [check]) # splice the new step into the seam
  end
  [o, publish]
end

TENANTS = %w[acme globex umbrella].freeze

def survey(phase)
  puts "  #{phase}:"
  TENANTS.each do |tenant|
    orchestrator, publish = build_plan(tenant)
    shape = orchestrator.graph[:order].map { |id| orchestrator.graph[:tasks][id].description }.join(" -> ")
    result = orchestrator.execute_plan
    puts format("    %-8s %-46s %s", tenant, shape, result.task_result(publish.id).output)
  end
  puts
end

puts "FEATURE FLAGS FOR PLANS (one codebase, per-actor shapes)"
puts
survey("phase 1 - flag off for everyone")

FLAGS.enable_actor(:fact_check, "acme")
survey("phase 2 - enabled for actor acme (the design partner)")

FLAGS.enable_percentage(:fact_check, 50)
survey("phase 3 - 50% rollout (deterministic per-tenant bucketing)")

puts "  the shape of the trick: the experimental step isn't hidden"
puts "  behind an if INSIDE a task - it's a different PLAN, built per"
puts "  run, spliced in with rewire_task at exactly one seam. acme has"
puts "  been running fact-checked for a phase before anyone else, the"
puts "  50% bucket is deterministic (same tenant, same verdict, every"
puts "  run - flapping flags are worse than no flags), and rollback is"
puts "  disable, not deploy. flags decouple SHIPPING code from RUNNING"
puts "  it; plans-as-data means they can decouple shipping a STEP from"
puts "  running it, too."
