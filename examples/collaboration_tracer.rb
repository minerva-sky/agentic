# frozen_string_literal: true

# The Collaboration Tracer: lifecycle hooks record every message the
# orchestrator sends and every reply that comes back, then the run is
# drawn as a sequence diagram. Object-oriented programs are
# conversations; this makes the conversation visible.
#
#   bundle exec ruby examples/collaboration_tracer.rb
#
# Runs offline: a three-agent editorial pipeline, traced.

require_relative "../lib/agentic"

PIPELINE = {
  "Researcher" => {work: ->(_prev) { "3 facts about fibers" }},
  "Writer" => {work: ->(prev) { "draft built on: #{prev}" }},
  "Editor" => {work: ->(prev) { "tightened: #{prev.split(":").first}" }}
}.freeze

trace = []
hooks = {
  before_task_execution: ->(task_id:, task:) {
    trace << {from: "Orchestrator", to: task.description, label: "perform(#{task.description.downcase})"}
    unless task.dependency_outputs.empty?
      task.dependency_outputs.each_value do |output|
        trace << {from: "Orchestrator", to: task.description, label: "here's \"#{output.to_s[0, 18]}...\""}
      end
    end
  },
  after_task_success: ->(task_id:, task:, result:, duration:) {
    trace << {from: task.description, to: "Orchestrator", label: "done: \"#{result.output.to_s[0, 18]}...\""}
  }
}

orchestrator = Agentic::PlanOrchestrator.new(lifecycle_hooks: hooks)
previous = nil
PIPELINE.each do |role, spec|
  task = Agentic::Task.new(
    description: role,
    agent_spec: {"name" => role, "instructions" => "collaborate"},
    payload: spec[:work]
  )
  orchestrator.add_task(task, previous ? [previous] : [], agent: ->(t) {
    t.payload.call(t.dependency_outputs.values.first)
  })
  previous = task
end

orchestrator.execute_plan

# --- render the conversation as a sequence diagram --------------------------
actors = ["Orchestrator"] + PIPELINE.keys
width = 16
positions = actors.each_with_index.to_h { |actor, i| [actor, i * width + width / 2] }
line_width = actors.size * width

puts "COLLABORATION TRACE (#{trace.size} messages)"
puts
puts actors.map { |a| a.center(width) }.join
puts positions.values.each_with_object(" " * line_width) { |pos, line|
       line[pos] = "|"
     }

trace.each do |message|
  from_pos = positions[message[:from]]
  to_pos = positions[message[:to]]
  left, right = [from_pos, to_pos].minmax

  # the arrow line, with lifelines drawn through
  line = " " * line_width
  positions.each_value { |pos| line[pos] = "|" }
  (left + 1...right).each { |i| line[i] = "-" }
  line[(from_pos < to_pos) ? right - 1 : left + 1] = (from_pos < to_pos) ? ">" : "<"
  puts line

  # the label line
  label = " " * line_width
  positions.each_value { |pos| label[pos] = "|" }
  text = message[:label][0, right - left - 3]
  label[left + 2, text.length] = text
  puts label
end

puts positions.values.each_with_object(" " * line_width) { |pos, line|
       line[pos] = "|"
     }
puts
puts "read it like a conversation: every arrow is a message, every"
puts "reply flows back before the next collaborator is addressed."
