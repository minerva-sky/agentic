# frozen_string_literal: true

# The Railway Plan: dry-monads taught Ruby that failure handling is
# COMPOSITION, not rescue blocks - a pipeline of steps where success
# rides the happy track and the first failure switches every later
# step onto the bypass, carrying WHY. TaskResult/TaskFailure are
# already Result values in street clothes; this gives them bind, so
# a plan's outcome composes like a railway instead of nesting like
# an if-tree.
#
#   bundle exec ruby examples/railway_plan.rb
#
# Runs offline; one train arrives, one is politely diverted.

require_relative "../lib/agentic"

Agentic.logger.level = :fatal

# The whole monad: Success carries a value through bind; Failure
# short-circuits, carrying the failure to the end of the line
module Railway
  Success = Struct.new(:value) do
    def bind = yield(value)

    def success? = true
  end

  Failure = Struct.new(:failure) do
    def bind = self # the bypass track: later steps never run

    def success? = false
  end

  # Lift a plan's task outcome onto the railway
  def self.from(result, task)
    task_result = result.task_result(task.id)
    task_result.successful? ? Success.new(task_result.output) : Failure.new(task_result.failure)
  end
end

def run_task(description, payload, &work)
  orchestrator = Agentic::PlanOrchestrator.new(retry_policy: {max_retries: 0, retryable_errors: []})
  task = Agentic::Task.new(description: description, agent_spec: {"name" => description, "instructions" => "w"}, payload: payload)
  orchestrator.add_task(task, agent: ->(t) { work.call(t.payload) })
  Railway.from(orchestrator.execute_plan, task)
end

# Three steps of a checkout, each a real journaled-able plan task,
# composed with bind - read it top to bottom, that IS the control flow
def checkout(order)
  run_task("validate", order) { |o|
    raise Agentic::Errors::LlmInvalidRequestError, "cart is empty" if o[:items].empty?

    o
  }.bind { |o|
    run_task("price", o) { |ord| ord.merge(total_cents: ord[:items].sum { |i| i[:cents] }) }
  }.bind { |o|
    run_task("invoice", o) { |ord| "invoice ##{ord[:id]}: #{ord[:total_cents]} cents" }
  }
end

puts "THE RAILWAY PLAN (bind, not rescue)"
puts

happy = checkout({id: 41, items: [{cents: 1200}, {cents: 350}]})
puts "  a full cart:"
puts "    -> #{happy.success? ? happy.value : happy.failure.message}"
puts

sad = checkout({id: 42, items: []})
puts "  an empty cart:"
puts "    -> diverted at: #{sad.failure.type.split("::").last} - #{sad.failure.message}"
puts "    (price and invoice never ran - no nil checks asked, none needed)"
puts

puts "  what the railway buys, precisely: the checkout reads as three"
puts "  binds top to bottom, and that reading IS the control flow - no"
puts "  rescue pyramid, no `return unless`, no nil creeping past step"
puts "  two. the diverted train still carries a first-class TaskFailure"
puts "  (type, message, timestamp, retryable verdict), because the"
puts "  framework already models failure as data; the monad is just"
puts "  fourteen lines acknowledging it. Success/Failure with bind is"
puts "  all you need for the pattern - do-notation is nicer, but the"
puts "  discipline (failures COMPOSE, they don't interrupt) is the part"
puts "  that survives translation into any codebase."
