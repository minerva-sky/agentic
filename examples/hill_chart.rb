# frozen_string_literal: true

# The Hill Chart: Basecamp's answer to "how's it going?" - work climbs
# the hill while it's still uncertain (queued, waiting on dependencies)
# and rolls down once it's just execution. Three live snapshots of a
# running plan, drawn from lifecycle hooks. No status meeting convened.
#
#   bundle exec ruby examples/hill_chart.rb
#
# Runs offline; watch the letters roll downhill.

require_relative "../lib/agentic"

WORK = {
  "A: audit copy" => {sleep: 0.05, deps: []},
  "B: build hero" => {sleep: 0.09, deps: []},
  "C: cut video" => {sleep: 0.12, deps: []},
  "D: draft email" => {sleep: 0.06, deps: ["A: audit copy"]},
  "E: embed video" => {sleep: 0.05, deps: ["B: build hero", "C: cut video"]},
  "F: final review" => {sleep: 0.04, deps: ["D: draft email", "E: embed video"]}
}.freeze

# Position on the hill, 0.0 (left base) to 1.0 (right base)
POSITIONS = {pending: 0.15, queued: 0.35, running: 0.55, done: 0.9}.freeze

states = WORK.keys.to_h { |name| [name, :pending] }
snapshots = []

take_snapshot = -> { snapshots << states.dup }

hooks = {
  before_task_execution: ->(task_id:, task:) { states[task.description] = :queued },
  task_slot_acquired: ->(task_id:, task:, waited:) {
    states[task.description] = :running
    take_snapshot.call
  },
  after_task_success: ->(task_id:, task:, result:, duration:) {
    states[task.description] = :done
  }
}

orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 2, lifecycle_hooks: hooks)
tasks = {}
WORK.each do |name, spec|
  tasks[name] = Agentic::Task.new(description: name,
    agent_spec: {"name" => name, "instructions" => "work"}, payload: spec[:sleep])
  orchestrator.add_task(tasks[name], spec[:deps].map { |d| tasks.fetch(d) },
    agent: ->(t) { sleep(t.payload) || :ok })
end
orchestrator.execute_plan
take_snapshot.call # the finished hill

# --- draw the hill -------------------------------------------------------------
HILL = [
  "                    ___________                    ",
  "               ____/           \\____               ",
  "          ____/                     \\____          ",
  "     ____/                               \\____     ",
  "____/                                         \\____"
].freeze

def draw_hill(states)
  width = HILL.first.length
  rows = HILL.map(&:dup)

  # Height of the hill surface at each column, from the art itself
  surface = (0...width).map { |col| rows.index { |row| row[col] != " " } || rows.size - 1 }

  states.each do |name, state|
    col = (POSITIONS.fetch(state) * (width - 1)).round
    row = [surface[col] - 1, 0].max
    letter = name[0]
    col += 1 while rows[row][col] != " " && col < width - 1
    rows[row][col] = letter
  end
  rows.each { |row| puts "    #{row}" }
end

puts "THE HILL CHART (uphill = still uncertain, downhill = just execution)"
[0, snapshots.size / 2, snapshots.size - 1].uniq.each_with_index do |index, i|
  snap = snapshots[index]
  puts
  puts "  #{["early:", "mid-flight:", "at the end:"][i]}"
  draw_hill(snap)
end

puts
puts "    legend: #{WORK.keys.map { |n| n.split(":").first + "=" + n.split(": ").last }.join(", ")}"
puts
puts "the crest is the honest divider: left of it, tasks are waiting on"
puts "dependencies or a slot (uncertainty you can't schedule away);"
puts "right of it, it's just execution. the chart never asks anyone"
puts "'percent complete?' - the states are facts from hooks."
