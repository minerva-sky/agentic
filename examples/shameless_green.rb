# frozen_string_literal: true

# Shameless Green: the 99 Bottles discipline applied to a plan. Step
# zero is one god task that does everything - and it's GREEN, and we
# are not ashamed, because green output pinned as a golden master is
# what buys every move after it. Then the refactoring loop: extract
# ONE responsibility per step, re-run the whole plan, and compare
# output byte-for-byte. A step that "improves the design" while
# changing the answer is not a refactoring - it's a bug with good
# posture, and the referee rejects it. Design metrics (tasks, max
# responsibilities per task, graph depth) are computed, not asserted.
#
#   bundle exec ruby examples/shameless_green.rb
#
# Runs offline; one extraction is deliberately botched to prove the
# rope holds. Exit 1 unless the final shape is single-responsibility
# AND the output never changed.

require_relative "../lib/agentic"

Agentic.logger.level = :fatal

TICKETS = [
  {id: 1, kind: :bug, day: "wed"}, {id: 2, kind: :feature, day: "mon"},
  {id: 3, kind: :bug, day: "wed"}, {id: 4, kind: :chore, day: "fri"},
  {id: 5, kind: :bug, day: "wed"}, {id: 6, kind: :feature, day: "tue"},
  {id: 7, kind: :chore, day: "wed"}
].freeze

# The four responsibilities, as sharable lambdas - each version of
# the plan differs only in how many live in one task
FETCH = ->(_) { TICKETS }
COUNT = ->(tickets) { {total: tickets.size, bugs: tickets.count { |t| t[:kind] == :bug }, busiest: tickets.group_by { |t| t[:day] }.max_by { |_, v| v.size }.first} }
BUGGY_COUNT = ->(tickets) { {total: tickets.size, bugs: tickets.count { |t| t[:kind] == :bug } - 1, busiest: "wed"} } # the botched extraction
FORMAT = ->(stats) { "#{stats[:total]} tickets, #{stats[:bugs]} bugs, busiest: #{stats[:busiest]}" }
RENDER = ->(line) { "== WEEKLY REPORT ==\n#{line}" }

# Each step: stages, where a stage is {name:, ops: [lambdas]} - a
# task per stage, responsibilities per task COUNTED from the data
STEPS = [
  {label: "step 0  shameless green", stages: [{name: "do everything", ops: [FETCH, COUNT, FORMAT, RENDER]}]},
  {label: "step 1  extract the I/O edge", stages: [{name: "fetch", ops: [FETCH]}, {name: "the rest", ops: [COUNT, FORMAT, RENDER]}]},
  {label: "step 2  extract calculation", stages: [{name: "fetch", ops: [FETCH]}, {name: "count", ops: [BUGGY_COUNT]}, {name: "present", ops: [FORMAT, RENDER]}]},
  {label: "step 2' extract calculation", stages: [{name: "fetch", ops: [FETCH]}, {name: "count", ops: [COUNT]}, {name: "present", ops: [FORMAT, RENDER]}]},
  {label: "step 3  one job per task", stages: [{name: "fetch", ops: [FETCH]}, {name: "count", ops: [COUNT]}, {name: "format", ops: [FORMAT]}, {name: "render", ops: [RENDER]}]}
].freeze

def run_shape(stages)
  orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 2)
  previous = nil
  last = nil
  stages.each do |stage|
    task = Agentic::Task.new(description: stage[:name], agent_spec: {"name" => stage[:name], "instructions" => "w"})
    orchestrator.add_task(task, previous ? [previous] : [], agent: ->(t) {
      stage[:ops].inject(t.previous_output) { |acc, op| op.call(acc) }
    })
    previous = task
    last = task
  end
  result = orchestrator.execute_plan
  [result.task_result(last.id).output, orchestrator.graph[:stats]]
end

puts "SHAMELESS GREEN (first make it work, then make it right - PROVABLY right)"
puts
puts format("  %-30s %-7s %-14s %-7s %s", "", "tasks", "max ops/task", "depth", "referee")

golden = nil
rejected = 0
final_output = nil
final_max_ops = nil

STEPS.each do |step|
  output, stats = run_shape(step[:stages])
  max_ops = step[:stages].map { |s| s[:ops].size }.max
  verdict =
    if golden.nil?
      golden = output
      "output pinned as GOLDEN"
    elsif output == golden
      final_output = output
      final_max_ops = max_ops
      "identical output - refactoring, certified"
    else
      rejected += 1
      "REJECTED: output changed (#{output.lines.last.strip.inspect}) - rolled back"
    end
  puts format("  %-30s %-7d %-14d %-7d %s", step[:label], step[:stages].size, max_ops, stats[:max_depth] + 1, verdict)
end

puts
puts "  the arc is 99 Bottles, one abstraction up: step 0 is unashamed -"
puts "  a god task, but GREEN, and pinned as the golden master that funds"
puts "  every later move. each extraction removes exactly one"
puts "  responsibility (watch max ops/task fall 4, 3, 2, 1 while depth"
puts "  grows - the design metrics are computed from the shape, not"
puts "  asserted by the author). and step 2 is the whole sermon: an"
puts "  extraction that 'cleaned up' the counting changed the bug count,"
puts "  the golden master caught it, the step was rejected, the rope"
puts "  held. refactoring is changing the arrangement of code while"
puts "  PROVING the behavior stands still; without the proof it's just"
puts "  editing with confidence."
exit((final_output == golden && final_max_ops == 1 && rejected == 1) ? 0 : 1)
