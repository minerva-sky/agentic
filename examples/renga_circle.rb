# frozen_string_literal: true

# A renga circle: three poet agents compose a linked-verse poem, each
# verse responding to the one before it. The dependency graph IS the
# poem's form - verse 2 cannot begin until verse 1 exists, and the
# orchestrator pipes each verse into the poet who answers it.
#
#   bundle exec ruby examples/renga_circle.rb
#
# Runs offline: each poet's craft is a lambda-backed capability.

require_relative "../lib/agentic"

STYLES = {
  "Basho" => ->(theme, previous) {
    previous ? "#{previous.split.last} lingers -\n#{theme} on the temple bell\na crow shakes off rain" : "first light, #{theme} -\nthe pond remembers\nlast night's moon"
  },
  "Buson" => ->(theme, previous) {
    "answering #{previous.split.first}:\n#{theme} paints the hillside\nin a brush of geese"
  },
  "Issa" => ->(theme, previous) {
    "yes, #{previous.split.last} - and yet\neven this #{theme}\nis home to someone small"
  }
}.freeze

# Each poet is an agent with a single "verse" capability
poets = STYLES.to_h do |name, craft|
  spec = Agentic::CapabilitySpecification.new(
    name: "verse_#{name.downcase}",
    description: "Compose a linked verse in #{name}'s voice",
    version: "1.0.0",
    inputs: {
      theme: {type: "string", required: true},
      previous: {type: "string", description: "The verse being answered"}
    },
    outputs: {verse: {type: "string", required: true}}
  )

  provider = Agentic::CapabilityProvider.new(
    capability: spec,
    implementation: ->(inputs) { {verse: craft.call(inputs[:theme], inputs[:previous])} }
  )
  Agentic.register_capability(spec, provider)

  poet = Agentic::Agent.build do |a|
    a.name = name
    a.role = "Renga poet"
  end
  poet.add_capability("verse_#{name.downcase}")

  [name, poet]
end

theme = ARGV.first || "autumn wind"
orchestrator = Agentic::PlanOrchestrator.new

# The circle: each poet's task depends on the previous poet's, and the
# previous verse arrives through the dependency pipe - no shared state
tasks = []
%w[Basho Buson Issa].each do |name|
  task = Agentic::Task.new(
    description: name,
    agent_spec: Agentic::AgentSpecification.new(
      name: name, description: "Renga poet", instructions: "Compose one linked verse"
    ),
    payload: theme
  )

  orchestrator.add_task(task, tasks.empty? ? [] : [tasks.last], agent: ->(t) {
    previous = t.dependency_outputs.values.first
    poets[t.description].execute_capability(
      "verse_#{t.description.downcase}",
      {theme: t.payload, previous: previous}.compact
    )[:verse]
  })
  tasks << task
end

result = orchestrator.execute_plan

puts "  ~ a renga on \"#{theme}\" ~"
puts
tasks.each do |task|
  puts result.results[task.id].output.split("\n").map { |line| "  #{line}" }
  puts
end
puts "  (#{result.status} in #{(result.execution_time * 1000).round}ms)"
