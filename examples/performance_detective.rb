# frozen_string_literal: true

# The Performance Detective: one task per Ruby file in lib/, fanned out
# through the orchestrator, each dissecting a file for long methods.
# The victim is this very gem. The report names names.
#
#   bundle exec ruby examples/performance_detective.rb [concurrency]
#
# Runs offline - the "agent" here is Prism, Ruby's own parser, because
# the best LLM for counting your method lengths is the actual grammar.

require_relative "../lib/agentic"
require "prism"

LIB = File.expand_path("../lib", __dir__)

# Walks a parsed tree collecting every def with its measured length
def collect_defs(node, found)
  return unless node

  if node.is_a?(Prism::DefNode)
    found << {
      name: node.receiver ? "self.#{node.name}" : node.name.to_s,
      line: node.location.start_line,
      lines: node.location.end_line - node.location.start_line + 1
    }
  end
  node.child_nodes.each { |child| collect_defs(child, found) }
end

# A capability that dissects one file: every def, with its length
spec = Agentic::CapabilitySpecification.new(
  name: "dissect_file",
  description: "Measure the methods in one Ruby file",
  version: "1.0.0",
  inputs: {path: {type: "string", required: true}},
  outputs: {methods: {type: "array", required: true}, lines: {type: "number", required: true}}
)
provider = Agentic::CapabilityProvider.new(
  capability: spec,
  implementation: ->(inputs) {
    parsed = Prism.parse_file(inputs[:path])
    methods = []
    collect_defs(parsed.value, methods)

    {methods: methods, lines: parsed.source.source.count("\n")}
  }
)
Agentic.register_capability(spec, provider)

detective = Agentic::Agent.build { |a| a.name = "Detective" }
detective.add_capability("dissect_file")

# Every file is a lead; every lead gets a task
Casefile = Struct.new(:agent, :evidence) do
  def get_agent_for_task(task)
    casefile = self
    Object.new.tap do |gumshoe|
      gumshoe.define_singleton_method(:execute) do |_prompt|
        report = casefile.agent.execute_capability("dissect_file", {path: task.description})
        casefile.evidence[task.description] = report
        "#{report[:methods].size} methods"
      end
    end
  end
end

concurrency = (ARGV.first || 16).to_i
files = Dir[File.join(LIB, "**", "*.rb")].sort

evidence = {}
orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: concurrency)
files.each do |path|
  orchestrator.add_task(Agentic::Task.new(
    description: path,
    agent_spec: {"name" => "Detective", "instructions" => "Dissect the file"},
    input: {}
  ))
end

started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
result = orchestrator.execute_plan(Casefile.new(detective, evidence))
elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round

all_methods = evidence.flat_map do |path, report|
  report[:methods].map { |m| m.merge(file: path.delete_prefix("#{LIB}/")) }
end

puts "CASE FILE: #{files.size} files, #{all_methods.size} methods, " \
  "#{evidence.values.sum { |r| r[:lines] }} lines"
puts "(#{result.status} in #{elapsed_ms}ms at concurrency #{concurrency})"
puts
puts "THE USUAL SUSPECTS (longest methods):"
all_methods.sort_by { |m| -m[:lines] }.first(7).each do |m|
  puts format("  %3d lines  %s  (%s:%d)", m[:lines], m[:name], m[:file], m[:line])
end
puts
puts "DENSEST NEIGHBORHOODS (methods per file):"
evidence.sort_by { |_, r| -r[:methods].size }.first(5).each do |path, r|
  puts format("  %3d methods  %s", r[:methods].size, path.delete_prefix("#{LIB}/"))
end
