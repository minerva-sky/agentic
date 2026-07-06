# frozen_string_literal: true

# A renga circle: three poet agents compose a linked-verse poem, each
# verse responding to the one before it. The dependency graph IS the
# poem's form - verse 2 cannot begin until verse 1 exists.
#
#   bundle exec ruby examples/renga_circle.rb
#
# Runs offline: each poet's craft is a lambda-backed capability.

require_relative "../lib/agentic"

# The scroll is passed hand to hand; each poet reads what came before
scroll = []

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

# A poet-agent adapter: when the orchestrator hands it a prompt, it
# reads the scroll, composes, and appends
PoetAtTheTable = Struct.new(:poet, :capability, :theme, :scroll) do
  def execute(_prompt)
    verse = poet.execute_capability(capability, {
      theme: theme,
      previous: scroll.last
    }.compact)[:verse]
    scroll << verse
    verse
  end
end

class RengaProvider
  def initialize(seats)
    @seats = seats
  end

  def get_agent_for_task(task)
    @seats.fetch(task.description)
  end
end

theme = ARGV.first || "autumn wind"
orchestrator = Agentic::PlanOrchestrator.new

seats = {}
previous_task = nil
%w[Basho Buson Issa].each do |name|
  task = Agentic::Task.new(
    description: name,
    agent_spec: Agentic::AgentSpecification.new(
      name: name, description: "Renga poet", instructions: "Compose one linked verse"
    ),
    input: {}
  )
  seats[name] = PoetAtTheTable.new(poets[name], "verse_#{name.downcase}", theme, scroll)
  orchestrator.add_task(task, previous_task ? [previous_task.id] : [])
  previous_task = task
end

result = orchestrator.execute_plan(RengaProvider.new(seats))

puts "  ~ a renga on \"#{theme}\" ~"
puts
scroll.each_with_index do |verse, i|
  puts verse.split("\n").map { |line| "  #{line}" }
  puts
end
puts "  (#{result.status} in #{(result.execution_time * 1000).round}ms)"
