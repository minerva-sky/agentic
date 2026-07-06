# frozen_string_literal: true

# The Coupling Cartographer: which files lean on which? Every file is
# surveyed for the constants it DEFINES and the constants it REFERENCES;
# a fan-in task joins the two into a dependency graph and reports the
# load-bearing walls and the heaviest leaners.
#
#   bundle exec ruby examples/coupling_cartographer.rb [lib_dir]
#
# Runs offline; Prism supplies both sides of every edge.

require_relative "../lib/agentic"
require "prism"

LIB = File.expand_path(ARGV.first || "#{__dir__}/../lib")

# Collects constants defined and referenced in one parse tree
def survey_constants(node, namespace, defined, referenced)
  return unless node

  case node
  when Prism::ModuleNode, Prism::ClassNode
    name = node.constant_path.slice
    full = [namespace, name].reject(&:empty?).join("::")
    defined << full
    node.child_nodes.each { |child| survey_constants(child, full, defined, referenced) }
    return
  when Prism::ConstantReadNode
    referenced << node.name.to_s
  when Prism::ConstantPathNode
    referenced << node.slice
  end

  node.child_nodes.each { |child| survey_constants(child, namespace, defined, referenced) }
end

orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 8)
files = Dir[File.join(LIB, "**", "*.rb")].sort

surveys = files.map do |path|
  task = Agentic::Task.new(
    description: path.delete_prefix("#{LIB}/"),
    agent_spec: {"name" => "Surveyor", "instructions" => "chart the constants"},
    payload: path
  )
  orchestrator.add_task(task, agent: ->(t) {
    defined = []
    referenced = []
    survey_constants(Prism.parse_file(t.payload).value, "", defined, referenced)
    {defined: defined, referenced: referenced.uniq - defined}
  })
  task
end

atlas = Agentic::Task.new(
  description: "the atlas",
  agent_spec: {"name" => "Cartographer", "instructions" => "join the maps"}
)
orchestrator.add_task(atlas, surveys, agent: ->(t) {
  charts = surveys.to_h { |s| [s.description, t.output_of(s)] }

  # Who owns each constant (by trailing segment, since references are
  # often relative: LlmClient rather than Agentic::LlmClient)
  owners = {}
  charts.each do |file, chart|
    chart[:defined].each { |const| owners[const.split("::").last] = file }
  end

  edges = Hash.new { |h, k| h[k] = [] }
  charts.each do |file, chart|
    chart[:referenced].each do |ref|
      owner = owners[ref.split("::").last]
      edges[file] << owner if owner && owner != file
    end
  end
  # Copy without the default proc: a Hash.new {} that leaks to readers
  # invents keys on every miss - including during iteration
  edges = edges.transform_values(&:uniq)

  inbound = Hash.new(0)
  edges.each_value { |targets| targets.each { |target| inbound[target] += 1 } }

  {edges: edges, inbound: inbound}
})

result = orchestrator.execute_plan
atlas_data = result.results[atlas.id].output

puts "COUPLING ATLAS of #{LIB} (#{files.size} files)"
puts
puts "load-bearing walls (most depended-upon):"
atlas_data[:inbound].sort_by { |_, count| -count }.first(6).each do |file, count|
  puts format("  %2d files lean on  %s", count, file)
end
puts
puts "heaviest leaners (most dependencies out):"
atlas_data[:edges].sort_by { |_, targets| -targets.size }.first(6).each do |file, targets|
  puts format("  %-40s leans on %2d files", file, targets.size)
end

mutual = atlas_data[:edges].flat_map { |file, targets|
  targets.filter_map { |target| [file, target].sort if atlas_data[:edges][target]&.include?(file) }
}.uniq
puts
if mutual.empty?
  puts "no mutual dependencies - every edge points one way. rare, and good."
else
  puts "mutual dependencies (each file references the other):"
  mutual.each { |a, b| puts "  #{a} <-> #{b}" }
end
