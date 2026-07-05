# frozen_string_literal: true

# The three-line agent. Run me with no API key at all:
#
#   bundle exec ruby examples/haiku_agent.rb
#
# An agent, a capability, a result - each expressed the way Ruby wants
# to express it: a block, a lambda, a hash. Nothing here talks to a
# network; capabilities are just callables, so the whole plan-and-execute
# idea is graspable in one screen.

require_relative "../lib/agentic"

# 1. An agent in three lines
poet = Agentic::Agent.build do |a|
  a.name = "Basho"
  a.role = "Haiku poet"
end

# 2. A capability is a specification plus any callable
haiku = Agentic::CapabilitySpecification.new(
  name: "haiku",
  description: "Compose a haiku about a topic",
  version: "1.0.0",
  inputs: {topic: {type: "string", required: true}},
  outputs: {poem: {type: "string"}}
)

brush = Agentic::CapabilityProvider.new(
  capability: haiku,
  implementation: ->(inputs) {
    {poem: [
      "#{inputs[:topic].capitalize} at first light",
      "an old pond holds the whole sky",
      "ruby leaves drift down"
    ].join("\n")}
  }
)

Agentic.register_capability(haiku, brush)
poet.add_capability("haiku")

# 3. Ask the poet for a poem
puts poet.execute_capability("haiku", {topic: "autumn"})[:poem]

# And when you do have an API key, the same agent, the same message,
# a real LLM - only the provider changes:
#
#   Agentic.configure { |c| c.access_token = ENV["OPENAI_ACCESS_TOKEN"] }
#   plan = Agentic::TaskPlanner.new("Write a haiku about autumn").plan
#   puts plan.to_s
