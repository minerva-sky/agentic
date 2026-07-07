# frozen_string_literal: true

# The Dungeon Crawl: a quest is a plan, rooms are tasks, and doors are
# dependencies. The map is drawn from the orchestrator's own graph
# BEFORE the run - then the party delves, and the treasure fans in.
#
#   bundle exec ruby examples/dungeon_crawl.rb [seed]
#
# Runs offline. The dungeon is the dependency graph; there is no
# second map to fall out of date.

require_relative "../lib/agentic"

seed = (ARGV.first || 4).to_i
rng = Random.new(seed)

LOOT = {
  "Entrance Hall" => ["a rusty key", "a torch stub", "an ominous note"],
  "Spider Nest" => ["silk rope", "a shed fang", "someone's boot"],
  "Flooded Crypt" => ["a waterlogged tome", "a silver coin", "an eyeless fish"],
  "Treasury" => ["the Amulet of Yendor", "a chest of coppers", "a suspicious goose"]
}.freeze

orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 2)

rooms = {}
delve = ->(t) {
  sleep(0.02) # every room takes delving
  LOOT.fetch(t.description).sample(random: rng)
}

def room(name)
  Agentic::Task.new(description: name, agent_spec: {"name" => name, "instructions" => "delve"})
end

rooms["Entrance Hall"] = room("Entrance Hall")
rooms["Spider Nest"] = room("Spider Nest")
rooms["Flooded Crypt"] = room("Flooded Crypt")
rooms["Treasury"] = room("Treasury")

orchestrator.add_task(rooms["Entrance Hall"], agent: delve)
orchestrator.add_task(rooms["Spider Nest"], [rooms["Entrance Hall"]], agent: delve)
orchestrator.add_task(rooms["Flooded Crypt"], [rooms["Entrance Hall"]], agent: delve)
orchestrator.add_task(rooms["Treasury"],
  needs: {web: rooms["Spider Nest"], depths: rooms["Flooded Crypt"]},
  agent: ->(t) {
    "#{LOOT.fetch(t.description).sample(random: rng)} (unlocked with #{t.needs.web} and #{t.needs.depths})"
  })

# --- the map, drawn from the plan itself ------------------------------------
graph = orchestrator.graph
names = graph[:tasks].transform_values(&:description)

puts "THE MAP (drawn from orchestrator.graph, in delving order)"
puts
graph[:order].each do |room_id|
  door_ids = graph[:dependencies][room_id]
  if door_ids.empty?
    puts "  [#{names[room_id]}]  <- you are here"
  else
    puts "  [#{names[room_id]}]  doors from: #{door_ids.map { |d| names[d] }.join(", ")}"
  end
end

# --- the delve ---------------------------------------------------------------
result = orchestrator.execute_plan

puts
puts "THE DELVE (seed #{seed})"
rooms.each do |name, task|
  puts "  #{name}: found #{result.results[task.id].output}"
end
puts
puts "(#{result.status} in #{(result.execution_time * 1000).round}ms - the nest and"
puts " the crypt were delved in parallel; the treasury needed both keys)"
