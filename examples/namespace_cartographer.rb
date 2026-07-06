# frozen_string_literal: true

# The Namespace Cartographer: maps a gem's constant tree and audits
# every file against the constant Zeitwerk expects it to define.
# One orchestrator task per file; Prism reads the actual definitions.
#
#   bundle exec ruby examples/namespace_cartographer.rb [lib_dir]
#
# Defaults to surveying this gem. A conforming codebase produces a map
# with no annotations; every deviation is listed with what was expected
# and what was found.

require_relative "../lib/agentic"
require "prism"

LIB = File.expand_path(ARGV.first || "#{__dir__}/../lib")
INFLECTIONS = {"cli" => "CLI", "ui" => "UI"}.freeze

def camelize(segment)
  INFLECTIONS.fetch(segment) { segment.split("_").map(&:capitalize).join }
end

# The constant Zeitwerk expects lib/foo/bar_baz.rb to define.
# Zeitwerk::GemInflector special-cases the gem's version.rb: it expects
# Foo::VERSION, not Foo::Version - a lesson this cartographer learned
# by first drawing the deviation on its own map.
def expected_constant(relative_path)
  segments = relative_path.delete_suffix(".rb").split("/")
  return "#{camelize(segments.first)}::VERSION" if segments.length == 2 && segments.last == "version"

  segments.map { |seg| camelize(seg) }.join("::")
end

# Collects every module/class defined in a parse tree, as full paths
def collect_definitions(node, namespace, found)
  return unless node

  case node
  when Prism::ModuleNode, Prism::ClassNode
    name = node.constant_path.slice
    full = [namespace, name].reject(&:empty?).join("::")
    found << full
    node.child_nodes.each { |child| collect_definitions(child, full, found) }
  when Prism::ConstantWriteNode
    found << [namespace, node.name.to_s].reject(&:empty?).join("::")
  else
    node.child_nodes.each { |child| collect_definitions(child, namespace, found) }
  end
end

spec = Agentic::CapabilitySpecification.new(
  name: "survey_file",
  description: "Chart the constants a Ruby file defines",
  version: "1.0.0",
  inputs: {path: {type: "string", required: true}},
  outputs: {defined: {type: "array", required: true}}
)
Agentic.register_capability(spec, Agentic::CapabilityProvider.new(
  capability: spec,
  implementation: ->(inputs) {
    found = []
    collect_definitions(Prism.parse_file(inputs[:path]).value, "", found)
    {defined: found}
  }
))

surveyor = Agentic::Agent.build { |a| a.name = "Cartographer" }
surveyor.add_capability("survey_file")

Expedition = Struct.new(:agent, :charts) do
  def get_agent_for_task(task)
    expedition = self
    Object.new.tap do |scout|
      scout.define_singleton_method(:execute) do |_prompt|
        expedition.charts[task.description] =
          expedition.agent.execute_capability("survey_file", {path: task.description})[:defined]
        "charted"
      end
    end
  end
end

files = Dir[File.join(LIB, "**", "*.rb")].sort
charts = {}
orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 8)
files.each do |path|
  orchestrator.add_task(Agentic::Task.new(
    description: path,
    agent_spec: {"name" => "Cartographer", "instructions" => "Survey the file"},
    input: {}
  ))
end
result = orchestrator.execute_plan(Expedition.new(surveyor, charts))

# Compare the map against the territory
deviations = []
tree = Hash.new(0)
files.each do |path|
  relative = path.delete_prefix("#{LIB}/")
  expected = expected_constant(relative)
  defined = charts.fetch(path, [])

  tree[relative.split("/").first(2).join("/").delete_suffix(".rb")] += 1
  unless defined.include?(expected)
    deviations << {file: relative, expected: expected, found: defined.first(3)}
  end
end

puts "NAMESPACE MAP of #{LIB}"
puts "(#{files.size} files surveyed, #{result.status} in #{(result.execution_time * 1000).round}ms)"
puts
tree.sort.each { |region, count| puts format("  %-46s %3d file(s)", region, count) }
puts
if deviations.empty?
  puts "Every file defines the constant its path promises. The map IS the territory."
else
  puts "DEVIATIONS (#{deviations.size}):"
  deviations.each do |d|
    puts "  #{d[:file]}"
    puts "    expected #{d[:expected]}, defines #{d[:found].join(", ")}"
  end
end
