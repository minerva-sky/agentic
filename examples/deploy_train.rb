# frozen_string_literal: true

# The Deploy Train: lint -> test -> build -> canary -> ship, where a
# red gate stops the train and everything behind it reports CANCELED,
# not skipped-and-shrugged. Run it twice: healthy train, then a canary
# failure. The second run is why deploy pipelines exist.
#
#   bundle exec ruby examples/deploy_train.rb
#
# Runs offline; the canary's health is scripted.

require_relative "../lib/agentic"

Agentic.logger.level = :fatal # the failure is the demo, not news

STATIONS = %w[lint test build canary ship announce].freeze

def run_train(canary_healthy:)
  orchestrator = nil
  hooks = {
    after_task_failure: ->(task_id:, task:, failure:, duration:) {
      # A red gate stops the whole train - no half-shipped releases
      orchestrator.cancel_plan
    }
  }
  orchestrator = Agentic::PlanOrchestrator.new(
    concurrency_limit: 1,
    lifecycle_hooks: hooks,
    retry_policy: {max_retries: 0, retryable_errors: []}
  )

  previous = nil
  tasks = STATIONS.to_h do |station|
    task = Agentic::Task.new(
      description: station,
      agent_spec: {"name" => station, "instructions" => "run the gate"}
    )
    orchestrator.add_task(task, previous ? [previous] : [], agent: ->(t) {
      sleep(0.01)
      if t.description == "canary" && !canary_healthy
        raise "error rate 4.2% exceeds 1% threshold"
      end

      :green
    })
    previous = task
    [station, task]
  end

  result = orchestrator.execute_plan
  [result, tasks]
end

def print_train(label, result, tasks)
  puts label
  tasks.each do |station, task|
    task_result = result.results[task.id]
    status = if task_result.nil?
      "CANCELED (never left the yard)"
    elsif task_result.successful?
      "green"
    elsif task_result.canceled?
      "CANCELED"
    else
      "RED - #{task_result.failure.message}"
    end
    puts format("  %-9s %s", station, status)
  end
  puts format("  train status: %s", result.status)
  puts
end

healthy, healthy_tasks = run_train(canary_healthy: true)
print_train("monday's deploy:", healthy, healthy_tasks)

broken, broken_tasks = run_train(canary_healthy: false)
print_train("friday's deploy:", broken, broken_tasks)

puts "friday's verdict is precise: the train is :partial_failure (a gate"
puts "went RED), and the cars behind it are CANCELED, not silently"
puts "skipped. failure outranks cancellation in the status - the headline"
puts "is WHY the train stopped, the manifest shows what never shipped."
