# frozen_string_literal: true

# The Gentle Deadline: most deadline code is violent - a timeout
# fires, everything dies, the user gets an error page at 30.0
# seconds that could have been a good-enough answer at 29. This plan
# knows which of its tasks are ESSENTIAL and which are garnish, and
# when the time budget runs low it starts declining the garnish -
# politely, by name, with the meal still served on time.
#
#   bundle exec ruby examples/gentle_deadline.rb
#
# Runs offline; the same dinner is cooked twice, hurried once.

require_relative "../lib/agentic"

Agentic.logger.level = :fatal

# Course list: essential tasks make the meal; optional ones make it lovely
COURSES = [
  {name: "stock: fetch data", essential: true, cost: 0.04},
  {name: "main: analyze", essential: true, cost: 0.06},
  {name: "garnish: related links", essential: false, cost: 0.05},
  {name: "garnish: pull quotes", essential: false, cost: 0.05},
  {name: "dessert: summary haiku", essential: false, cost: 0.03},
  {name: "serve: render answer", essential: true, cost: 0.02}
].freeze

def cook(budget_seconds)
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + budget_seconds
  orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 1)
  declined = []
  previous = nil

  COURSES.each do |course|
    task = Agentic::Task.new(description: course[:name], agent_spec: {"name" => course[:name], "instructions" => "cook"})
    orchestrator.add_task(task, previous ? [previous] : [], agent: ->(_t) {
      remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
      # The gentle part: an optional course checks whether there is
      # comfortably time for it AND the essentials still to come, and
      # bows out by name instead of being murdered mid-simmer
      essentials_owed = COURSES.drop(COURSES.index(course) + 1).select { |c| c[:essential] }.sum { |c| c[:cost] }
      if !course[:essential] && remaining < course[:cost] + essentials_owed + 0.01
        declined << course[:name]
        next :declined_with_regrets
      end

      sleep(course[:cost])
      "#{course[:name]} ready"
    })
    previous = task
  end

  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  result = orchestrator.execute_plan
  [result, Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, declined]
end

puts "THE GENTLE DEADLINE (essential courses always; garnish as time allows)"
puts

[["a leisurely evening", 0.5], ["a hurried lunch", 0.16]].each do |occasion, budget|
  result, elapsed, declined = cook(budget)
  served = result.results.values.count { |r| r.successful? && r.output != :declined_with_regrets }
  puts "  #{occasion} (budget #{(budget * 1000).round}ms):"
  puts format("    served %d courses in %dms - status: %s", served, (elapsed * 1000).round, result.status)
  if declined.any?
    puts "    declined with regrets: #{declined.join("; ")}"
    puts "    (the meal was still served - nobody saw an error page)"
  else
    puts "    everything made it, garnish and all"
  end
  puts
end

puts "  the design is one question asked politely: before an OPTIONAL"
puts "  task starts, is there comfortably time for it AND the essentials"
puts "  still owed? if not, it declines BY NAME and the plan flows on."
puts "  compare the violent alternative - a global timeout that kills"
puts "  the render step because the pull quotes ran long, serving the"
puts "  user an error instead of a plainer dinner. deadlines are not"
puts "  the enemy of graciousness; treating every task as equally"
puts "  essential is. mark the garnish as garnish, and lateness becomes"
puts "  a menu decision instead of an outage."
