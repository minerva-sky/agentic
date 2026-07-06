# frozen_string_literal: true

# The Kanban Board: a plan rendered as the three columns everyone
# actually understands - To Do, Doing, Done - reprinted at every state
# change while the plan runs. No standup, no sync meeting, no PM tool
# subscription: the orchestrator IS the board.
#
#   bundle exec ruby examples/kanban_board.rb
#
# Runs offline; watch the cards move.

require_relative "../lib/agentic"

CARDS = {
  "write copy" => 0.06,
  "shoot photos" => 0.10,
  "edit photos" => 0.05,
  "layout page" => 0.08,
  "review" => 0.04,
  "publish" => 0.03
}.freeze

DEPS = {
  "edit photos" => ["shoot photos"],
  "layout page" => ["write copy", "edit photos"],
  "review" => ["layout page"],
  "publish" => ["review"]
}.freeze

board = {todo: CARDS.keys.dup, doing: [], done: []}
frames = []

move = lambda do |card, from, to|
  board[from].delete(card)
  board[to] << card
  columns = [:todo, :doing, :done].map { |col| board[col] }
  height = columns.map(&:size).max
  frame = +"  %-16s %-16s %-16s\n" % ["TO DO", "DOING", "DONE"]
  frame << "  #{"-" * 14}   #{"-" * 14}   #{"-" * 14}\n"
  height.times do |i|
    frame << ("  %-16s %-16s %-16s\n" % columns.map { |col| col[i] || "" })
  end
  frames << frame
end

hooks = {
  task_slot_acquired: ->(task_id:, task:, waited:) { move.call(task.description, :todo, :doing) },
  after_task_success: ->(task_id:, task:, result:, duration:) { move.call(task.description, :doing, :done) }
}

orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 2, lifecycle_hooks: hooks)
tasks = {}
CARDS.each do |name, duration|
  tasks[name] = Agentic::Task.new(
    description: name,
    agent_spec: {"name" => name, "instructions" => "do the work"},
    payload: duration
  )
  orchestrator.add_task(tasks[name], (DEPS[name] || []).map { |d| tasks.fetch(d) },
    agent: ->(t) { sleep(t.payload) || :done })
end

result = orchestrator.execute_plan

puts "KANBAN (#{frames.size} board states, #{(result.execution_time * 1000).round}ms wall, 2 people on the team)"
puts
# Show the opening, one mid-flight frame, and the final board
[frames.first, frames[frames.size / 2], frames.last].each_with_index do |frame, i|
  puts ["at the start:", "mid-flight:", "at the end:"][i]
  puts frame
end
puts "every frame above was captured live from lifecycle hooks - the"
puts "board is the plan's actual state, not somebody's memory of it."
