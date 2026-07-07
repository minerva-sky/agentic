# frozen_string_literal: true

# Graph to Specs: the plan's structure dictates its test plan - roots
# need fixture cases, joins need one case per missing tributary,
# leaves need output assertions. This generates the RSpec skeleton
# from the graph, so "what should we test?" stops being a staring
# contest with a blank file.
#
#   bundle exec ruby examples/graph_to_specs.rb
#
# Runs offline; prints a runnable-shaped spec skeleton.

require_relative "../lib/agentic"

def step(name)
  Agentic::Task.new(description: name, agent_spec: {"name" => name, "instructions" => "work"})
end

orchestrator = Agentic::PlanOrchestrator.new
orders = step("fetch orders")
refunds = step("fetch refunds")
ledger = step("build ledger")
report = step("render report")

orchestrator.add_task(orders)
orchestrator.add_task(refunds)
orchestrator.add_task(ledger, needs: {sales: orders, credits: refunds})
orchestrator.add_task(report, [ledger])

graph = orchestrator.graph
stats = graph[:stats]
names = graph[:tasks].transform_values(&:description)

puts "# generated from the plan's graph - one describe per task,"
puts "# examples dictated by each task's structural role"
puts
puts "RSpec.describe \"the pipeline\" do"

graph[:order].each do |id|
  name = names[id]
  deps = graph[:dependencies][id]
  labeled = graph[:edges].select { |e| e[:to] == id && e[:label] }
  role = []
  role << "root" if stats[:roots].include?(id)
  role << "join" if deps.size >= 2
  role << "leaf" if stats[:leaves].include?(id)

  puts "  describe \"#{name}\" do  # #{role.join(", ")}"

  if stats[:roots].include?(id)
    puts "    it \"produces output from fixture input\"  # roots own the boundary with the world"
    puts "    it \"raises a named error when the source is unreachable\""
  end

  if deps.size >= 2
    puts "    context \"with all #{deps.size} inputs present\" do"
    puts "      it \"combines #{labeled.map { |e| e[:label] }.join(" and ")}\""
    puts "    end"
    labeled.each do |edge|
      puts "    context \"when #{edge[:label]} is missing\" do  # joins fail per-tributary, not vaguely"
      puts "      it \"reports which input was absent\""
      puts "    end"
    end
  elsif deps.size == 1
    puts "    it \"transforms its upstream's output\"  # assert on previous_output's shape"
  end

  if stats[:leaves].include?(id)
    puts "    it \"produces the artifact consumers read\"  # leaves are promises to the outside"
  end

  puts "  end"
  puts
end
puts "end"
puts
puts "# #{graph[:tasks].size} tasks -> #{stats[:roots].size} boundary suites, " \
  "#{graph[:dependencies].count { |_, d| d.size >= 2 }} join suites with " \
  "per-tributary absence cases, #{stats[:leaves].size} artifact suites."
puts "# the graph decided what deserves a test; you decide what passes one."
