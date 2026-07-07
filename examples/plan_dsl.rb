# frozen_string_literal: true

# The Plan DSL: Sinatra's whole argument was that an API is a user
# interface, and a user interface should read like what it means.
# The orchestrator's API is honest but administrative - ids, task
# objects, add_task bookkeeping. Thirty lines of DSL later, a plan
# reads like a plan. No engine changes: sugar OVER the API, never
# reaching into it.
#
#   bundle exec ruby examples/plan_dsl.rb
#
# Runs offline; the DSL builds a real orchestrator underneath.

require_relative "../lib/agentic"

Agentic.logger.level = :fatal

# The whole DSL. Symbols in, wiring out; the block IS the agent.
module Plan
  def self.define(&block)
    builder = Builder.new
    builder.instance_eval(&block)
    builder
  end

  class Builder
    attr_reader :orchestrator

    def initialize
      @orchestrator = Agentic::PlanOrchestrator.new
      @tasks = {}
    end

    def step(name, after: [], needs: nil, &work)
      task = Agentic::Task.new(description: name.to_s, agent_spec: {"name" => name.to_s, "instructions" => name.to_s})
      @tasks[name] = task
      deps = Array(after).map { |n| @tasks.fetch(n) }
      named = needs&.transform_values { |n| @tasks.fetch(n) }
      @orchestrator.add_task(task, deps, needs: named, agent: ->(t) { work&.call(t) })
      self
    end

    def run
      @orchestrator.execute_plan
    end

    def output_of(name, result)
      result.task_result(@tasks.fetch(name).id).output
    end
  end
end

# --- a plan that reads like a plan ----------------------------------------------
plan = Plan.define do
  step :fetch_orders do
    [{id: 1, total: 120}, {id: 2, total: 80}]
  end

  step :fetch_refunds do
    [{order_id: 2, amount: 80}]
  end

  step :ledger, needs: {orders: :fetch_orders, refunds: :fetch_refunds} do |t|
    t.needs[:orders].sum { |o| o[:total] } - t.needs[:refunds].sum { |r| r[:amount] }
  end

  step :report, after: :ledger do |t|
    "net revenue: $#{t.previous_output}"
  end
end

result = plan.run
puts "THE PLAN DSL (thirty lines of sugar over the real API)"
puts
puts "  #{plan.output_of(:report, result)}"
puts

graph = plan.orchestrator.graph
puts "  and it's all real underneath: #{graph[:tasks].size} tasks, labeled edges"
puts "  (#{graph[:edges].filter_map { |e| e[:label] }.join(", ")}), same graph every round-5-to-11 tool consumes."
puts
puts "  what the sugar buys: names instead of ids (symbols resolve to"
puts "  tasks at definition time, so a typo'd :fetch_order fails at"
puts "  DEFINE, not at run); the block IS the agent (the work sits"
puts "  inside the step that owns it); and after:/needs: read as"
puts "  English. what the sugar refuses: reaching into the engine."
puts "  every line delegates to public API - add_task, execute_plan,"
puts "  graph - so the DSL can never drift ahead of what the engine"
puts "  supports, and anything the DSL can't express, you drop down"
puts "  one layer without rewriting. Sinatra's rule: the frontend"
puts "  should be a pleasure and the escape hatch should be a door,"
puts "  not a wall."
