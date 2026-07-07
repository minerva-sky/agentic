# frozen_string_literal: true

# The TTY Status Board: terminal output is a UI, and UIs are built
# from COMPONENTS - a tree for structure, gauges for progress, badges
# for state - not from puts sprinkled where the mood struck. This
# renders a plan's live state as composed components, three frames of
# it, driven entirely by lifecycle hooks. No curses, no deps: the
# component discipline is the point, not the escape codes.
#
#   bundle exec ruby examples/tty_status.rb
#
# Runs offline; frames are captured at plan milestones.

require_relative "../lib/agentic"

Agentic.logger.level = :fatal

# --- tiny components, each one testable alone -----------------------------------
module UI
  BADGES = {pending: "[ ]", running: "[~]", done: "[x]", failed: "[!]"}.freeze

  def self.badge(state) = BADGES.fetch(state)

  def self.gauge(done, total, width: 24)
    filled = (total.zero? ? 0 : done * width / total)
    "|#{"=" * filled}#{" " * (width - filled)}| #{done}/#{total}"
  end

  def self.tree(rows)
    rows.map.with_index { |(depth, text), i|
      glyph = (i == rows.size - 1) ? "`-- " : "|-- "
      (depth == 1) ? text : "#{"    " * (depth - 2)}#{glyph}#{text}"
    }
  end

  def self.frame(title, lines)
    width = ([title.size] + lines.map(&:size)).max + 2
    ["+#{"-" * width}+", "| #{title.ljust(width - 1)}|", "+#{"-" * width}+"] +
      lines.map { |l| "| #{l.ljust(width - 1)}|" } + ["+#{"-" * width}+"]
  end
end

# --- the board: hook events in, frames out ---------------------------------------
class StatusBoard
  def initialize(graph)
    @graph = graph
    @states = graph[:tasks].keys.to_h { |id| [id, :pending] }
    @frames = []
  end

  attr_reader :frames

  def hooks
    {
      before_task_execution: ->(task_id:, task:) { @states[task_id] = :running },
      after_task_success: ->(task_id:, task:, result:, duration:) {
        @states[task_id] = :done
        snapshot("after #{task.description}")
      },
      after_task_failure: ->(task_id:, task:, failure:, duration:) {
        @states[task_id] = :failed
        snapshot("after #{task.description} FAILED")
      }
    }
  end

  def snapshot(caption)
    rows = @graph[:order].map { |id|
      [@graph[:stats][:depth][id], "#{UI.badge(@states[id])} #{@graph[:tasks][id].description}"]
    }
    done = @states.values.count(:done)
    @frames << UI.frame(caption, UI.tree(rows) + ["", UI.gauge(done, @states.size)])
  end
end

orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 2)
fetch = Agentic::Task.new(description: "fetch feeds", agent_spec: {"name" => "f", "instructions" => "w"})
parse = Agentic::Task.new(description: "parse entries", agent_spec: {"name" => "p", "instructions" => "w"})
rank = Agentic::Task.new(description: "rank stories", agent_spec: {"name" => "r", "instructions" => "w"})
publish = Agentic::Task.new(description: "publish digest", agent_spec: {"name" => "d", "instructions" => "w"})
orchestrator.add_task(fetch, agent: ->(_t) { sleep(0.01) })
orchestrator.add_task(parse, [fetch], agent: ->(_t) { sleep(0.01) })
orchestrator.add_task(rank, [parse], agent: ->(_t) { sleep(0.01) })
orchestrator.add_task(publish, [rank], agent: ->(_t) { sleep(0.01) })

board = StatusBoard.new(orchestrator.graph)
orchestrator2 = Agentic::PlanOrchestrator.new(concurrency_limit: 2, lifecycle_hooks: board.hooks)
[fetch, parse, rank, publish].each_with_index do |task, i|
  deps = i.zero? ? [] : [[fetch, parse, rank][i - 1]]
  orchestrator2.add_task(task, deps, agent: ->(_t) { sleep(0.005) })
end
orchestrator2.execute_plan

puts "THE TTY STATUS BOARD (three frames from one run)"
puts
[0, 1, 3].each do |index|
  board.frames[index].each { |line| puts "  #{line}" }
  puts
end
puts "  each piece is a component with one job: badge (state to glyph),"
puts "  gauge (counts to bar), tree (depth to indent), frame (lines to"
puts "  box) - and the board only composes them. that separation is the"
puts "  whole tty-* toolbox philosophy: when the spinner needs to become"
puts "  a progress bar, you swap ONE component and no rendering code"
puts "  learns about it. the hooks hand over exactly what a UI needs"
puts "  (state transitions with names), the graph hands over structure"
puts "  (depth, order), and the terminal gets what every user deserves:"
puts "  an interface that was designed, not accreted."
