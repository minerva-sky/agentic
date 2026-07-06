# frozen_string_literal: true

# The Refactoring Dojo: a student submits a method, three critic agents
# review it from three distinct perspectives, and the sensei prescribes
# the ONE smallest next step. Today's student: this gem itself,
# submitting its second-longest method (schedule_task, 90 lines).
#
#   bundle exec ruby examples/refactoring_dojo.rb [file] [method]
#
# Runs offline: the critics measure; they don't guess.

require_relative "../lib/agentic"
require "prism"

file = ARGV[0] || File.expand_path("../lib/agentic/plan_orchestrator.rb", __dir__)
method_name = (ARGV[1] || "schedule_task").to_sym

# Find the student's submission
def find_def(node, name)
  return node if node.is_a?(Prism::DefNode) && node.name == name

  node&.child_nodes&.each do |child|
    found = find_def(child, name)
    return found if found
  end
  nil
end

submission = find_def(Prism.parse_file(file).value, method_name) ||
  abort("no method #{method_name} in #{file}")
source = submission.slice
lines = source.lines

def critic(name, &impl)
  spec = Agentic::CapabilitySpecification.new(
    name: name, description: "The #{name} critic", version: "1.0.0",
    inputs: {source: {type: "string", required: true}},
    outputs: {findings: {type: "array", required: true}}
  )
  Agentic.register_capability(
    spec, Agentic::CapabilityProvider.new(capability: spec, implementation: impl)
  )

  Agentic::Agent.build { |a| a.name = name }.tap { |a| a.add_capability(name) }
end

critics = []

critics << critic("rule_keeper") do |input|
  body = input[:source].lines
  findings = []
  if body.size > 5
    findings << "#{body.size} lines; the rule is five. Every extra line is a place for a bug to live."
  end
  params = body.first[/\((.*)\)/, 1].to_s.split(",").size
  if params > 4
    findings << "#{params} parameters; four is the ceiling before a parameter object is cheaper."
  end
  {findings: findings}
end

critics << critic("squint_tester") do |input|
  body = input[:source].lines
  indents = body.map { |l| l[/\A */].size }.reject(&:zero?)
  depth = (indents.max - indents.min) / 2
  findings = []
  if depth >= 3
    findings << "squinting shows #{depth} levels of shape change - each ridge is a concept asking for its own method."
  end
  branches = body.count { |l| l.strip.start_with?("if ", "elsif ", "unless ", "when ", "rescue") }
  if branches >= 4
    findings << "#{branches} branch points in one method - this method makes decisions AND does work; split the two."
  end
  {findings: findings}
end

critics << critic("name_watcher") do |input|
  body = input[:source]
  findings = []
  vague = body.scan(/\b(data|info|result|temp|obj|thing)\b/).flatten.tally
  vague.each do |word, count|
    findings << "'#{word}' appears #{count}x - a name that could mean anything means nothing. What IS it?"
  end
  if body.match?(/def \w+_and_\w+/)
    findings << "the name contains 'and' - a confession that this is two methods in one costume."
  end
  {findings: findings}
end

# The circle convenes: each critic rides its own task and reviews in parallel
orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 3)
seats = critics.to_h do |c|
  task = Agentic::Task.new(
    description: c.name,
    agent_spec: {"name" => c.name, "instructions" => "Review the submission"},
    payload: c
  )
  orchestrator.add_task(task, agent: ->(t) {
    t.payload.execute_capability(t.payload.name, {source: source})[:findings]
  })
  [c.name, task]
end
run = orchestrator.execute_plan
scrolls = seats.transform_values { |task| run.results[task.id].output }

puts "REFACTORING DOJO"
puts "submission: ##{method_name} (#{lines.size} lines) from #{File.basename(file)}"
puts
scrolls.each do |critic_name, findings|
  puts "#{critic_name.tr("_", " ")} says:"
  findings.each { |f| puts "  - #{f}" }
  puts "  - no complaints. rare." if findings.empty?
  puts
end

total = scrolls.values.sum(&:size)
puts "sensei's prescription:"
if total.zero?
  puts "  ship it, then find a harder kata."
else
  first_move = scrolls["squint_tester"]&.first || scrolls.values.flatten.first
  puts "  #{total} findings, ONE next step - the smallest one:"
  puts "  start where the squint test hurts: #{first_move}"
  puts "  make that change, run the tests, come back. refactoring is many small"
  puts "  safe steps, not one brave rewrite."
end
