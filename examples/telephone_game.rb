# frozen_string_literal: true

# The telephone game: a rumor passes through five villagers, each of
# whom hears the previous version through the orchestrator's dependency
# pipe and repeats it... imperfectly. No shared state, no scroll passed
# around - the framework itself carries the whisper.
#
#   bundle exec ruby examples/telephone_game.rb ["a rumor"]
#
# Runs offline. The bug is the feature.

require_relative "../lib/agentic"

QUIRKS = {
  "the miller" => ->(s) { s.sub(/\bsaw\b/, "wrestled") },
  "the baker" => ->(s) { s.sub(/\ba (\w+)/, 'an enormous \1') },
  "the fisherman" => ->(s) { "#{s.chomp(".")}, down by the river" },
  "the innkeeper" => ->(s) { s.gsub(/\btwo\b/i, "twelve").gsub(/\bmice\b/, "wolves") },
  "the town crier" => ->(s) { "HEAR YE: #{s.upcase}!!" }
}.freeze

rumor = ARGV.first || "Old Tom saw a cat chase two mice."

orchestrator = Agentic::PlanOrchestrator.new
tasks = []
QUIRKS.each_key do |villager|
  task = Agentic::Task.new(
    description: villager,
    agent_spec: {"name" => villager, "instructions" => "Repeat what you heard"},
    payload: rumor
  )
  orchestrator.add_task(task, tasks.empty? ? [] : [tasks.last], agent: ->(t) {
    heard = t.dependency_outputs.values.first || t.payload
    QUIRKS.fetch(t.description).call(heard)
  })
  tasks << task
end

result = orchestrator.execute_plan

puts "the rumor: \"#{rumor}\""
puts
tasks.each do |task|
  puts format("%-14s heard it as: %s", task.description, result.results[task.id].output)
end
puts
puts "(#{result.status} in #{(result.execution_time * 1000).round}ms - " \
  "the whisper traveled through #{tasks.size} villagers)"
