# frozen_string_literal: true

# Plan Flog: flog gives every Ruby method a pain score; this gives
# every plan one. Fan-in hurts (joins hide coupling), depth hurts
# (chains hide latency), unlabeled edges hurt (anonymous data flow),
# and orphans hurt (dead code that runs). One number per task, one
# number per plan, and a threshold that means "refactor me". Yes,
# it's opinionated. So is flog. That's the point.
#
#   bundle exec ruby examples/plan_flog.rb
#
# Runs offline; three plans walk in, one gets told the truth.

require_relative "../lib/agentic"

def task_named(name)
  Agentic::Task.new(description: name, agent_spec: {"name" => name, "instructions" => "w"})
end

def tidy_pipeline
  o = Agentic::PlanOrchestrator.new
  fetch, clean, render = %w[fetch clean render].map { |n| task_named(n) }
  o.add_task(fetch)
  o.add_task(clean, [fetch])
  o.add_task(render, [clean])
  o
end

def labeled_diamond
  o = Agentic::PlanOrchestrator.new
  orders, refunds, ledger, report = %w[orders refunds ledger report].map { |n| task_named(n) }
  o.add_task(orders)
  o.add_task(refunds)
  o.add_task(ledger, needs: {sales: orders, credits: refunds})
  o.add_task(report, [ledger])
  o
end

def the_monster
  o = Agentic::PlanOrchestrator.new
  sources = 6.times.map { |i| task_named("src#{i}") }
  sources.each { |s| o.add_task(s) }
  god = task_named("do_everything")
  o.add_task(god, sources) # six unlabeled inputs
  chain = god
  4.times do |i|
    step = task_named("then#{i}")
    o.add_task(step, [chain])
    chain = step
  end
  o.add_task(task_named("orphan")) # added in a refactor, feeds nothing... but runs
  o
end

# The scoring, flog-style: pain per structural sin
def flog(graph)
  stats = graph[:stats]
  labeled = graph[:edges].count { |e| e[:label] }
  scores = graph[:tasks].keys.to_h do |id|
    fan_in = graph[:dependencies][id].size
    fan_out = graph[:edges].count { |e| e[:from] == id }
    unlabeled_in = (fan_in >= 2) ? graph[:edges].count { |e| e[:to] == id && !e[:label] } : 0
    orphan = (stats[:roots].include?(id) && stats[:leaves].include?(id) && graph[:tasks].size > 1) ? 5.0 : 0
    score = [fan_in - 1, 0].max * 1.5 +         # a pipe is free; every EXTRA join input is coupling
      [fan_out - 2, 0].max * 1.0 +              # fan-out past 2 spreads blame
      (stats[:depth][id] - 3).clamp(0, 99) * 0.8 + # depth past 3 hides latency
      unlabeled_in * 1.2 +                      # anonymous inputs, where they can be confused
      orphan                                    # runs, feeds nothing: pay attention
    [id, score]
  end
  [scores, labeled]
end

PLANS = {
  "tidy pipeline" => tidy_pipeline,
  "labeled diamond" => labeled_diamond,
  "the monster" => the_monster
}.freeze

puts "PLAN FLOG (pain points per plan; > 12 total means refactor me)"
puts
PLANS.each do |name, orchestrator|
  graph = orchestrator.graph
  scores, = flog(graph)
  total = scores.values.sum
  names = graph[:tasks].transform_values(&:description)
  worst = scores.max_by(2) { |_, s| s }.select { |_, s| s > 0 }

  verdict = if total > 12
    "REFACTOR ME"
  else
    ((total > 6) ? "watch it" : "fine")
  end
  puts format("  %-18s %5.1f  %-12s %s", name, total, verdict,
    worst.map { |id, s| "#{names[id]}=#{s.round(1)}" }.join("  "))
end

puts
monster = the_monster.graph
scores, = flog(monster)
names = monster[:tasks].transform_values(&:description)
top = scores.max_by { |_, s| s }
total = scores.values.sum
puts "  the monster's breakdown, because a score you can't argue with"
puts "  is a score you can't learn from: #{names[top[0]]} costs #{top[1].round(1)} - five"
puts "  EXTRA join inputs at 1.5 coupling each, plus six anonymous ones"
puts "  at 1.2. the orphan costs 5.0 flat: it runs on every execution"
puts "  and feeds nothing, which is either a bug or a billing strategy."
puts "  and the tidy pipeline scores 0.0, because a pipe is free and"
puts "  boring plans should be."
puts
puts "  numbers don't refactor code and they don't refactor plans -"
puts "  but they end the meeting about whether the monster is fine."
puts "  it's a #{total.round}. it's not fine."
