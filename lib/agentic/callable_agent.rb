# frozen_string_literal: true

module Agentic
  # Adapts a bare callable into the agent interface the orchestrator
  # expects. The callable receives the Task itself - payload, input,
  # dependency outputs and all - and its return value becomes the task's
  # output:
  #
  #   orchestrator.add_task(task, agent: ->(t) { process(t.payload) })
  class CallableAgent
    # @param callable [#call] The work, called with the task
    # @param task [Task] The task this agent executes
    def initialize(callable, task)
      @callable = callable
      @task = task
    end

    # Executes the callable with the task (the prompt is derivable from
    # the task, so callables receive the richer object)
    # @param _prompt [String] Ignored - the callable gets the task
    # @return [Object] The callable's return value, as task output
    def execute(_prompt)
      @callable.call(@task)
    end
  end
end
