# frozen_string_literal: true

# The Exquisite Corpse: three artists each draw one part of a creature
# without seeing the others' work; the assembler receives all three
# parts BY NAME and stacks them. The surrealists played this on folded
# paper; we play it on a dependency graph.
#
#   bundle exec ruby examples/exquisite_corpse.rb [seed]
#
# Runs offline. Every seed is a different creature.

require_relative "../lib/agentic"

seed = (ARGV.first || rand(1000)).to_i
rng = Random.new(seed)

PARTS = {
  head: [
    ["   /\\_/\\   ", "  ( o.o )  ", "   > ^ <   "],
    ["   .---.   ", "  ( @ @ )  ", "   \\_-_/   "],
    ["   ,***,   ", "  { > < }  ", "   \"---\"   "]
  ],
  torso: [
    ["  /|___|\\  ", " | (===) | ", "  \\|___|/  "],
    ["  <#####>  ", "  |#####|  ", "  <#####>  "],
    ["   )~~~(   ", "  ( ~~~ )  ", "   )~~~(   "]
  ],
  legs: [
    ["   |   |   ", "   |   |   ", "  _|   |_  "],
    ["   d   b   ", "   |   |   ", "  =$   $=  "],
    ["   \\   /   ", "    \\ /    ", "   _/^\\_   "]
  ]
}.freeze

orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 3)

artists = PARTS.to_h do |part, options|
  task = Agentic::Task.new(
    description: "draw the #{part}",
    agent_spec: {"name" => "Artist of the #{part}", "instructions" => "draw without peeking"},
    payload: options
  )
  orchestrator.add_task(task, agent: ->(t) { t.payload.sample(random: rng) })
  [part, task]
end

reveal = Agentic::Task.new(
  description: "unfold the paper",
  agent_spec: {"name" => "Assembler", "instructions" => "stack the parts"}
)
orchestrator.add_task(reveal, needs: artists, agent: ->(t) {
  t.needs.head + t.needs.torso + t.needs.legs
})

result = orchestrator.execute_plan

puts "EXQUISITE CORPSE (seed #{seed})"
puts
result.results[reveal.id].output.each { |line| puts "    #{line}" }
puts
puts "three artists, no peeking - the assembler read the parts by name:"
puts "  t.needs.head, t.needs.torso, t.needs.legs"
