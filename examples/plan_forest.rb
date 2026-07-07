# frozen_string_literal: true

# The Plan Forest: your graph drawn as a forest - roots at the soil,
# leaves in the canopy, every task planted at its depth. stats[:roots]
# and stats[:leaves] (new this round) do the gardening.
#
#   bundle exec ruby examples/plan_forest.rb
#
# Runs offline; no photosynthesis required.

require_relative "../lib/agentic"

def step(name)
  Agentic::Task.new(description: name, agent_spec: {"name" => name, "instructions" => "grow"})
end

orchestrator = Agentic::PlanOrchestrator.new
seeds = step("gather seeds")
till = step("till the soil")
plant = step("plant rows")
water = step("water daily")
weed = step("pull weeds")
harvest = step("harvest")
preserve = step("preserve jars")
feast = step("feast")

orchestrator.add_task(seeds)
orchestrator.add_task(till)
orchestrator.add_task(plant, needs: {seed_stock: seeds, bed: till})
orchestrator.add_task(water, [plant])
orchestrator.add_task(weed, [plant])
orchestrator.add_task(harvest, needs: {growth: water, clear_rows: weed})
orchestrator.add_task(preserve, [harvest])
orchestrator.add_task(feast, [harvest])

graph = orchestrator.graph
stats = graph[:stats]
names = graph[:tasks].transform_values(&:description)

# --- the forest: depth becomes altitude ---------------------------------------
canopy = stats[:depth].values.max
rows = (2..canopy).map { |level| stats[:depth].select { |_, d| d == level }.keys }

puts "THE PLAN FOREST"
puts
rows.reverse_each.with_index do |ids, i|
  level = canopy - i
  ids.each do |id|
    leaf = stats[:leaves].include?(id)
    indent = "    " * (level - 1)
    puts format("  %s%s %-16s %s", indent, leaf ? "(@)" : " | ", names[id],
      leaf ? "<- canopy" : "")
  end
end
stats[:roots].each do |id|
  puts format("  \\_/ %-16s <- root", names[id])
end
puts "  #{"~" * 40} soil"
puts
puts format("  %d trees from %d roots to %d leaves, canopy %d high",
  graph[:tasks].size, stats[:roots].size, stats[:leaves].size, canopy)
puts
puts "  the shape at a glance: two roots feed one trunk (plant rows),"
puts "  the trunk splits to water and weeds, rejoins at harvest, and"
puts "  the canopy bears two fruits. stats[:roots] and stats[:leaves]"
puts "  told the gardener where the soil and sunlight are."
