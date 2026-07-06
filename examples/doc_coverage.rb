# frozen_string_literal: true

# The Documentation Surveyor: measures YARD comment coverage for every
# public method in a lib/ tree. One survey task per file fans out; a
# single report task fans all the surveys in through the dependency
# pipe and renders the coverage table.
#
#   bundle exec ruby examples/doc_coverage.rb [lib_dir]
#
# Runs offline; Prism reads the definitions, the comments speak for
# themselves.

require_relative "../lib/agentic"
require "prism"

LIB = File.expand_path(ARGV.first || "#{__dir__}/../lib")

# Walks a parse tree counting public defs and whether a comment
# immediately precedes each one
def survey(parsed)
  comment_lines = parsed.comments.map { |c| c.location.start_line }.to_set
  stats = {documented: 0, undocumented: [], private_from: nil}

  # Track `private` markers statement-by-statement within class bodies
  walk = lambda do |node, private_scope|
    return unless node

    if node.is_a?(Prism::ClassNode) || node.is_a?(Prism::ModuleNode)
      inner = false
      node.child_nodes.each { |child| inner = walk.call(child, inner) || inner }
      private_scope
    elsif node.is_a?(Prism::StatementsNode)
      scope = private_scope
      node.child_nodes.each { |child| scope = walk.call(child, scope) || scope }
      scope
    elsif node.is_a?(Prism::CallNode) && node.name == :private && node.receiver.nil? && node.arguments.nil?
      true
    elsif node.is_a?(Prism::DefNode)
      unless private_scope
        if comment_lines.include?(node.location.start_line - 1)
          stats[:documented] += 1
        else
          stats[:undocumented] << {name: node.name.to_s, line: node.location.start_line}
        end
      end
      false
    else
      node.child_nodes.each { |child| walk.call(child, private_scope) }
      false
    end
  end

  walk.call(parsed.value, false)
  stats
end

orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 8)
files = Dir[File.join(LIB, "**", "*.rb")].sort

surveys = files.map do |path|
  task = Agentic::Task.new(
    description: path.delete_prefix("#{LIB}/"),
    agent_spec: {"name" => "Surveyor", "instructions" => "Survey documentation"},
    payload: path
  )
  orchestrator.add_task(task, agent: ->(t) { survey(Prism.parse_file(t.payload)) })
  task
end

report = Agentic::Task.new(
  description: "coverage report",
  agent_spec: {"name" => "Reporter", "instructions" => "Aggregate"}
)
orchestrator.add_task(report, surveys, agent: ->(t) {
  rows = surveys.map { |s|
    stats = t.output_of(s)
    total = stats[:documented] + stats[:undocumented].size
    {file: s.description, documented: stats[:documented], total: total,
     missing: stats[:undocumented]}
  }
  covered = rows.sum { |r| r[:documented] }
  total = rows.sum { |r| r[:total] }
  {rows: rows, covered: covered, total: total}
})

result = orchestrator.execute_plan
data = result.results[report.id].output

puts "DOCUMENTATION SURVEY of #{LIB}"
puts format("  %d/%d public methods documented (%.1f%%)",
  data[:covered], data[:total], 100.0 * data[:covered] / data[:total])
puts
worst = data[:rows].select { |r| r[:total] > 0 }
  .sort_by { |r| [Float(r[:documented]) / r[:total], -r[:total]] }.first(5)
puts "least documented files:"
worst.each do |row|
  puts format("  %5.1f%%  %-46s (%d/%d)",
    100.0 * row[:documented] / row[:total], row[:file], row[:documented], row[:total])
  row[:missing].first(2).each { |m| puts "           missing: ##{m[:name]} (line #{m[:line]})" }
end
