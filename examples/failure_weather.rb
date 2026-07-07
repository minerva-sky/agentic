# frozen_string_literal: true

# The Failure Weather Report: a journal of three days, read as a
# forecast. Retryable failures are WEATHER - showers that pass on
# their own or with an umbrella. Non-retryable failures are CLIMATE -
# no amount of waiting fixes a drought; someone must dig a well.
# The journal now records which is which at the moment it rains.
#
#   bundle exec ruby examples/failure_weather.rb
#
# Runs offline; three scripted days of mixed conditions.

require_relative "../lib/agentic"
require "tmpdir"

Agentic.logger.level = :fatal

JOURNAL = File.join(Dir.tmpdir, "agentic_weather.journal.jsonl")
File.delete(JOURNAL) if File.exist?(JOURNAL)
journal = Agentic::ExecutionJournal.new(path: JOURNAL)

DAYS = [
  {name: "Monday",
   jobs: {"digest" => Agentic::Errors::LlmRateLimitError.new("429"),
          "backup" => Agentic::Errors::LlmTimeoutError.new("slow disk"),
          "invoice" => Agentic::Errors::LlmAuthenticationError.new("401 key expired"),
          "greet" => nil}},
  {name: "Tuesday",
   jobs: {"digest" => nil, # the shower passed
          "backup" => Agentic::Errors::LlmTimeoutError.new("slow disk again"),
          "invoice" => Agentic::Errors::LlmAuthenticationError.new("401 key expired"),
          "greet" => nil}},
  {name: "Wednesday",
   jobs: {"digest" => nil,
          "backup" => nil, # cleared overnight
          "invoice" => Agentic::Errors::LlmAuthenticationError.new("401 key expired"),
          "greet" => nil}}
].freeze

DAYS.each do |day|
  orchestrator = Agentic::PlanOrchestrator.new(
    lifecycle_hooks: journal.lifecycle_hooks,
    retry_policy: {max_retries: 0, retryable_errors: []}
  )
  day[:jobs].each do |name, error|
    orchestrator.add_task(Agentic::Task.new(
      description: name, agent_spec: {"name" => name, "instructions" => "run"},
      payload: error
    ), agent: ->(t) {
      raise t.payload if t.payload

      :ok
    })
  end
  orchestrator.execute_plan
end

# --- the forecast desk ---------------------------------------------------------
state = Agentic::ExecutionJournal.replay(path: JOURNAL)
day_events = state.events.slice_when { |a, b|
  a[:event] == "plan_completed" && b[:event] != "plan_completed"
}.to_a

def sky(failed)
  weather = failed.count { |e| e[:retryable] }
  climate = failed.count { |e| e[:retryable] == false }
  return "clear skies" if failed.empty?
  return "storm damage (#{climate} structural)" if climate.positive? && weather.positive?
  return "drought continues" if climate.positive?

  "passing showers (#{weather})"
end

puts "FAILURE WEATHER REPORT (#{DAYS.size} journaled days)"
puts
day_events.each_with_index do |events, index|
  failed = events.select { |e| e[:event] == "task_failed" }
  puts format("  %-10s %-28s %s", DAYS[index][:name], sky(failed),
    failed.map { |e| e[:description] }.join(", "))
end
puts

# Weather clears; climate persists. The distinction IS the journal's
# retryable verdict, recorded when each drop fell.
latest = {}
state.events.each do |e|
  latest[e[:description]] = e if %w[task_failed task_succeeded].include?(e[:event])
end
weather_jobs = latest.values.select { |e| e[:event] == "task_failed" && e[:retryable] }
climate_jobs = latest.values.select { |e| e[:event] == "task_failed" && e[:retryable] == false }
cleared = state.events.select { |e| e[:event] == "task_failed" }.map { |e| e[:description] }.uniq
  .select { |d| latest[d][:event] == "task_succeeded" }

puts "  extended forecast:"
cleared.each { |d| puts "    #{d}: rained earlier this week, clear now - weather does that" }
weather_jobs.each { |e| puts "    #{e[:description]}: still raining, but it is rain - bring retries" }
climate_jobs.each { |e| puts "    #{e[:description]}: this is not weather, it is climate - #{e[:error]}" }
puts
rain = state.events.select { |e| e[:event] == "task_failed" }
puts "  #{rain.size} rainy events this week: #{rain.count { |e| e[:retryable] }} were weather (they passed, or will),"
puts "  and #{rain.count { |e| e[:retryable] == false }} were the same drought, reported daily."
puts "  no forecast fixes a drought: invoice's 401 has held for three days"
puts "  and will hold forever, because keys do not expire back. the journal"
puts "  told us which failures to wait out and which to dig a well for."
