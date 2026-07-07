# frozen_string_literal: true

# The Plan Tour: hand any orchestrator to the guide and it narrates the
# plan as prose - first this, then that, meanwhile the other - read
# straight from graph[:order] and graph[:edges]. If the prose sounds
# wrong, your plan IS wrong, and you found out before running it.
#
#   bundle exec ruby examples/plan_tour.rb
#
# Runs offline; narration only, no execution.

require_relative "../lib/agentic"

# A breakfast, planned properly
orchestrator = Agentic::PlanOrchestrator.new

def step(name)
  Agentic::Task.new(description: name, agent_spec: {"name" => name, "instructions" => "cook"})
end

kettle = step("boil the kettle")
eggs = step("soft-boil the eggs")
bread = step("slice the bread")
toast = step("toast the bread")
tea = step("steep the tea")
plate = step("plate everything")

orchestrator.add_task(kettle)
orchestrator.add_task(bread)
orchestrator.add_task(eggs, [kettle])
orchestrator.add_task(tea, [kettle])
orchestrator.add_task(toast, [bread])
orchestrator.add_task(plate, needs: {protein: eggs, crunch: toast, comfort: tea})

# --- the guide: graph in, prose out ------------------------------------------
def narrate(graph)
  names = graph[:tasks].transform_values(&:description)
  incoming = graph[:edges].group_by { |e| e[:to] }
  narrated = []
  sentences = []

  graph[:order].each do |task_id|
    edges_in = incoming[task_id] || []
    sentence =
      if edges_in.empty?
        opener = narrated.empty? ? "First" : "Meanwhile"
        "#{opener}, #{names[task_id]}."
      else
        reasons = edges_in.map { |e|
          e[:label] ? "\"#{names[e[:from]]}\" (your #{e[:label]})" : "\"#{names[e[:from]]}\""
        }
        joined = (reasons.size > 1) ? reasons[0..-2].join(", ") + " and #{reasons.last}" : reasons.first
        "After #{joined}: #{names[task_id]}."
      end
    sentences << sentence
    narrated << task_id
  end

  sentences
end

puts "THE PLAN, AS PROSE (nobody has cooked anything yet)"
puts
narrate(orchestrator.graph).each { |sentence| puts "  #{sentence}" }
puts
puts "the narration is generated from graph[:order] and graph[:edges] -"
puts "the same topology the scheduler will execute. read your plan aloud"
puts "before you run it; ears catch what eyes skim."
