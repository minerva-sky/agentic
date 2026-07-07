# frozen_string_literal: true

require "securerandom"
require "set"
require "async"
require "async/barrier"
require "async/semaphore"

module Agentic
  # Orchestrates the execution of tasks in a plan, handling dependencies and concurrency
  # @attr_reader [String] plan_id Unique identifier for the plan
  # @attr_reader [Hash] tasks Map of task ids to Task objects
  # @attr_reader [Hash] execution_state Current state of all tasks in the plan
  # @attr_reader [Hash] results Results of task execution
  class PlanOrchestrator
    attr_reader :plan_id, :tasks, :execution_state, :results, :retry_policy, :lifecycle_hooks

    # Initializes a new plan orchestrator
    # @param plan_id [String] Optional plan id, will be generated if not provided
    # @param concurrency_limit [Integer] Maximum number of tasks to execute concurrently
    # @param retry_policy [Hash] Configuration for retry behavior
    # @param lifecycle_hooks [Hash] Configuration for execution lifecycle hooks
    # @return [PlanOrchestrator] A new plan orchestrator instance
    def initialize(plan_id: SecureRandom.uuid, concurrency_limit: 10, retry_policy: {}, lifecycle_hooks: {})
      @plan_id = plan_id
      @tasks = {}
      @dependencies = {}
      @results = {}
      @execution_state = {
        pending: Set.new,
        in_progress: Set.new,
        completed: Set.new,
        failed: Set.new,
        canceled: Set.new
      }
      @concurrency_limit = concurrency_limit
      @async_tasks = {}
      @task_agents = {}
      @task_needs = {}

      # Configure retry policy with defaults. Jitter defaults ON: a fleet
      # retrying an upstream on the same schedule is a synchronized
      # stampede; pass backoff_jitter: false to opt out (e.g. in tests
      # that assert exact delays)
      @retry_policy = {
        max_retries: 3,
        retryable_errors: ["TimeoutError"],
        backoff_strategy: :constant,
        backoff_jitter: true
      }.merge(retry_policy)

      # Configure lifecycle hooks with callable defaults (no-ops).
      # Hooks run inline on the task's fiber - anything slower than a hash
      # insert should hand off (e.g. enqueue onto an Async::Queue).
      @lifecycle_hooks = {
        before_agent_build: ->(task_id:, task:) {},          # Called before an agent is built
        after_agent_build: ->(task_id:, task:, agent:, build_duration:) {}, # Called after an agent is built
        before_task_execution: ->(task_id:, task:) {},        # Called when the task is scheduled (may still queue)
        task_slot_acquired: ->(task_id:, task:, waited:) {},  # Called when a concurrency slot is acquired
        after_task_success: ->(task_id:, task:, result:, duration:) {}, # Called after a task succeeds
        after_task_failure: ->(task_id:, task:, failure:, duration:) {}, # Called after a task fails
        plan_completed: ->(plan_id:, status:, execution_time:, tasks:, results:) {} # Called when plan completes
      }.merge(lifecycle_hooks)
    end

    # Adds a task to the plan with optional dependencies
    #
    # Dependencies may be task ids or Task objects. An agent (anything
    # responding to #execute) or a bare callable (receives the task,
    # returns the output) can be attached directly, making a plan-wide
    # agent provider optional. Named dependencies declared via needs: are
    # dependencies whose outputs arrive addressable by name:
    #
    #   orchestrator.add_task(digest, needs: {shipped: commits, owed: debt})
    #   # in the agent: task.needs.shipped
    #
    # @param task [Task] The task to add
    # @param dependencies [Array<String, Task>] Tasks (or ids) this task depends on
    # @param agent [#execute, #call, nil] The agent or callable to execute this task
    # @param needs [Hash{Symbol=>Task,String}, nil] Named dependencies
    # @return [void]
    def add_task(task, dependencies = [], agent: nil, needs: nil)
      task_id = task.id
      @tasks[task_id] = task
      deps = Array(dependencies).map { |dep| dep.respond_to?(:id) ? dep.id : dep }

      if needs
        @task_needs[task_id] = needs.transform_values { |dep| dep.respond_to?(:id) ? dep.id : dep }
        deps |= @task_needs[task_id].values
      end

      @dependencies[task_id] = deps
      @task_agents[task_id] = agent if agent
      @execution_state[:pending].add(task_id)
    end

    # A read-only snapshot of the plan's topology, for tools that render,
    # review, or analyze the graph without executing it
    # @return [Hash] :tasks (id => Task), :dependencies (id => [ids]),
    #   :needs (id => {name => id}), :order (task ids, topologically
    #   sorted), :edges ([{from:, to:, label:}] with labels from needs:)
    def graph
      labels = @task_needs.each_with_object({}) do |(task_id, named), acc|
        named.each { |name, dep_id| acc[[dep_id, task_id]] = name }
      end
      edges = @dependencies.flat_map { |task_id, deps|
        deps.map { |dep_id| {from: dep_id, to: task_id, label: labels[[dep_id, task_id]]}.freeze }
      }.freeze

      order = topological_order

      # Structural stats, computed once so every graph tool stops
      # hand-rolling the same walk: per-task depth (1 = root), the
      # longest chain, and the widest fan-in
      depth = {}
      order.each do |task_id|
        depth[task_id] = 1 + (@dependencies[task_id].map { |dep| depth[dep] || 0 }.max || 0)
      end

      {
        tasks: @tasks.dup.freeze,
        dependencies: @dependencies.transform_values { |deps| deps.dup.freeze }.freeze,
        needs: @task_needs.transform_values { |named| named.dup.freeze }.freeze,
        order: order.freeze,
        edges: edges,
        stats: {
          depth: depth.freeze,
          max_depth: depth.values.max || 0,
          max_fan_in: @dependencies.values.map(&:size).max || 0
        }.freeze
      }.freeze
    end

    # Executes the plan, respecting task dependencies and concurrency limits
    #
    # Composes with structured concurrency: when called inside a running
    # Async reactor (e.g. under Falcon or within another task) it joins the
    # current reactor instead of nesting a new event loop; standalone calls
    # still create their own reactor and block until the plan completes.
    #
    # @param agent_provider [Object, nil] An object that provides agents for
    #   task execution (responds to #get_agent_for_task), or a callable
    #   factory (receives the task, returns an agent). Optional when every
    #   task was added with its own agent:, or when a block is given.
    # @yield [task] Optional agent factory - called per task, returns an agent
    # @return [PlanExecutionResult] The structured execution results
    def execute_plan(agent_provider = nil, &agent_factory)
      agent_provider ||= agent_factory
      ensure_agents_resolvable!(agent_provider)

      @reactor = Sync do |reactor|
        @barrier = Async::Barrier.new
        @semaphore = Async::Semaphore.new(@concurrency_limit, parent: @barrier)

        # Track execution start time
        @execution_start_time = Time.now

        # Start with tasks that have no dependencies
        eligible_tasks = find_eligible_tasks

        # Initial execution of eligible tasks
        eligible_tasks.each do |task_id|
          schedule_task(task_id, agent_provider, @semaphore, @barrier)
        end

        # Wait for all tasks to complete
        @barrier.wait

        # Track execution completion time
        @execution_end_time = Time.now

        # Call plan completion hook
        @lifecycle_hooks[:plan_completed].call(
          plan_id: @plan_id,
          status: overall_status,
          execution_time: @execution_end_time - @execution_start_time,
          tasks: @tasks.transform_values(&:to_h),
          results: @results
        )
      ensure
        @barrier&.stop
        # Ensure execution_end_time is set even if an exception occurred
        @execution_end_time ||= Time.now
      end

      # Create and return a PlanExecutionResult
      PlanExecutionResult.new(
        plan_id: @plan_id,
        status: overall_status,
        execution_time: @execution_end_time - @execution_start_time,
        tasks: @tasks.transform_values(&:to_h),
        results: @results
      )
    end

    # Cancels execution of a specific task
    # @param task_id [String] ID of the task to cancel
    # @return [Boolean] True if the task was canceled, false otherwise
    def cancel_task(task_id)
      # Can only cancel pending or in_progress tasks
      return false unless @execution_state[:pending].include?(task_id) ||
        @execution_state[:in_progress].include?(task_id)

      # If the task is pending, simply move it to canceled state
      if @execution_state[:pending].include?(task_id)
        transition_task_state(task_id, from: :pending, to: :canceled)
        return true
      end

      # If the task is in progress, cancel its Async task
      if @execution_state[:in_progress].include?(task_id) && @async_tasks[task_id]
        @async_tasks[task_id].stop
        transition_task_state(task_id, from: :in_progress, to: :canceled)
        return true
      end

      false
    end

    # Cancels execution of the entire plan
    # @return [void]
    def cancel_plan
      # Stop the reactor to cancel all async tasks
      @reactor&.stop

      # Move all pending and in_progress tasks to canceled state
      @execution_state[:pending].each do |task_id|
        transition_task_state(task_id, from: :pending, to: :canceled)
      end

      @execution_state[:in_progress].each do |task_id|
        transition_task_state(task_id, from: :in_progress, to: :canceled)
      end
    end

    # Determines if a task failure is retryable based on retry policy
    # @param task [Task] The failed task
    # @param failure [TaskFailure] The failure details
    # @return [Boolean] True if the task failure is retryable
    def retry?(task:, failure:)
      # Check if we've reached max retries
      task.retry_count ||= 0
      return false if task.retry_count >= @retry_policy[:max_retries]

      # An error's own retryability verdict outranks the type list -
      # Errors::LlmRateLimitError knows it's retryable, an
      # authentication error knows it isn't
      verdict = failure.respond_to?(:retryable?) ? failure.retryable? : nil
      return verdict unless verdict.nil?

      # Check if error type is in retryable_errors list
      @retry_policy[:retryable_errors].include?(failure.type)
    end

    # Determines if a failure requires human intervention
    # @param failure [TaskFailure] The failure details
    # @return [Boolean] True if human intervention is required
    def requires_intervention?(failure:)
      # For now, we only identify a few error types that need human help
      %w[AuthenticationError PermissionDeniedError ConfigurationError].include?(failure.type)
    end

    # Applies a delay based on the backoff strategy before retrying
    # @param task [Task] The task being retried
    # @return [void]
    def apply_retry_backoff(task:)
      return if @retry_policy[:backoff_strategy] == :none

      delay = case @retry_policy[:backoff_strategy]
      when :constant
        # Constant delay (default 1 second)
        @retry_policy[:backoff_constant] || 1
      when :linear
        # Linear backoff (retry_count * base_delay)
        base_delay = @retry_policy[:backoff_base] || 1
        task.retry_count * base_delay
      when :exponential
        # Exponential backoff (base_delay * 2^retry_count)
        base_delay = @retry_policy[:backoff_base] || 1
        base_delay * (2**(task.retry_count - 1))
      else
        0
      end

      # Apply jitter (on by default) so fleets don't retry in lockstep.
      # true = equal jitter (+/-25%); :full = full jitter (uniform over
      # [0, delay]), which flattens synchronized herds much harder.
      # An injected rng: (any object with #rand) makes timing testable.
      rng = @retry_policy[:rng]
      case @retry_policy[:backoff_jitter]
      when :full
        delay = rng ? rng.rand(0.0..delay) : rand(0.0..delay)
      when true
        jitter_factor = 0.25 # Default 25% jitter
        band = -delay * jitter_factor..delay * jitter_factor
        jitter = rng ? rng.rand(band) : rand(band)
        delay = [delay + jitter, 0].max
      end

      # Sleep in the current task so the retry actually waits; the async
      # fiber scheduler keeps this non-blocking for sibling tasks. The old
      # `Async { sleep }` spawned a detached task and returned immediately,
      # so retries never observed their backoff delay.
      sleep(delay) if delay > 0
    end

    # Checks if all dependencies for a task are met
    # @param task_id [String] ID of the task to check
    # @return [Boolean] True if all dependencies are met, false otherwise
    def all_dependencies_met?(task_id)
      deps = @dependencies[task_id] || []
      deps.all? do |dep_id|
        @execution_state[:completed].include?(dep_id)
      end
    end

    # Finds tasks that are eligible for execution (have no dependencies)
    # @return [Array<String>] IDs of eligible tasks
    def find_eligible_tasks
      @dependencies.select do |task_id, deps|
        deps.empty? && @execution_state[:pending].include?(task_id)
      end.keys
    end

    # Determines the overall status of the plan
    # @return [Symbol] The overall status (:completed, :in_progress, or :partial_failure)
    def overall_status
      if @execution_state[:failed].any?
        :partial_failure
      elsif @execution_state[:canceled].any?
        # A plan with canceled tasks did not complete, even if every task
        # that ran succeeded
        :canceled
      elsif @execution_state[:pending].empty? && @execution_state[:in_progress].empty?
        :completed
      else
        :in_progress
      end
    end

    private

    # Kahn's algorithm over the declared dependencies. Tasks caught in a
    # dependency cycle are appended (in insertion order) after the sorted
    # portion rather than silently dropped.
    # @return [Array<String>] Task ids, dependencies before dependents
    def topological_order
      remaining_deps = @dependencies.transform_values(&:dup)
      order = []
      ready = remaining_deps.select { |_, deps| deps.empty? }.keys

      until ready.empty?
        task_id = ready.shift
        order << task_id
        remaining_deps.each do |candidate, deps|
          next unless deps.delete(task_id)

          ready << candidate if deps.empty? && !order.include?(candidate)
        end
      end

      order + (@dependencies.keys - order)
    end

    # Schedules a task for execution using the semaphore to limit concurrency
    # @param task_id [String] ID of the task to schedule
    # @param agent_provider [Object] Provides agents for task execution
    # @param semaphore [Async::Semaphore] Controls concurrency
    # @param barrier [Async::Barrier] Tracks task completion
    # @return [void]
    def schedule_task(task_id, agent_provider, semaphore, barrier)
      return unless @execution_state[:pending].include?(task_id)

      # Move to in_progress state
      task = @tasks[task_id]
      transition_task_state(task_id, from: :pending, to: :in_progress)

      # Pipe completed dependency outputs into the task before it runs
      @dependencies[task_id].each do |dependency_id|
        dependency_result = @results[dependency_id]
        if dependency_result&.successful?
          task.record_dependency_output(dependency_id, dependency_result.output)
        end
      end

      # Named dependencies arrive addressable by the caller's chosen name
      @task_needs[task_id]&.each do |name, dependency_id|
        dependency_result = @results[dependency_id]
        task.needs[name] = dependency_result.output if dependency_result&.successful?
      end

      # Call before_task_execution hook
      @lifecycle_hooks[:before_task_execution].call(
        task_id: task_id,
        task: task
      )

      # Spawn through the barrier and acquire the semaphore INSIDE the
      # spawned fiber. Spawning with semaphore.async here would block the
      # caller when the semaphore is full - and completing tasks schedule
      # their dependents from within their own slot, so two slot-holders
      # spawning dependents at a tight concurrency limit would deadlock
      # waiting for each other's slots.
      scheduled_at = Time.now
      async_task = barrier.async do
        semaphore.acquire do
          @lifecycle_hooks[:task_slot_acquired].call(
            task_id: task_id,
            task: task,
            waited: Time.now - scheduled_at
          )
          execute_task_in_slot(task_id, task, agent_provider, semaphore, barrier)
        end
      end

      # Store the async task for potential cancellation
      @async_tasks[task_id] = async_task
    end

    # Runs one task inside an acquired concurrency slot: builds the agent,
    # performs the task, records the outcome, and fans out to dependents
    # @param task_id [String] ID of the task
    # @param task [Task] The task to run
    # @param agent_provider [Object, nil] Provides agents for task execution
    # @param semaphore [Async::Semaphore] Controls concurrency
    # @param barrier [Async::Barrier] Tracks task completion
    # @return [void]
    def execute_task_in_slot(task_id, task, agent_provider, semaphore, barrier)
      task_start_time = Time.now

      # Call before_agent_build hook
      @lifecycle_hooks[:before_agent_build].call(
        task_id: task_id,
        task: task
      )

      agent_build_start = Time.now
      agent = resolve_agent(task, agent_provider)
      agent_build_duration = Time.now - agent_build_start

      # Call after_agent_build hook
      @lifecycle_hooks[:after_agent_build].call(
        task_id: task_id,
        task: task,
        agent: agent,
        build_duration: agent_build_duration
      )

      result = task.perform(agent)
      task_duration = Time.now - task_start_time

      # Record result and update state
      if result.successful?
        record_task_success(task_id, result.output)

        # Call after_task_success hook
        @lifecycle_hooks[:after_task_success].call(
          task_id: task_id,
          task: task,
          result: result,
          duration: task_duration
        )

        # Find and schedule dependent tasks
        schedule_dependent_tasks(task_id, agent_provider, semaphore, barrier)
      else
        record_task_failure(task_id, result.failure)

        # Call after_task_failure hook
        @lifecycle_hooks[:after_task_failure].call(
          task_id: task_id,
          task: task,
          failure: result.failure,
          duration: task_duration
        )

        # Handle failure based on policy
        handle_task_failure(task, result.failure, agent_provider, semaphore, barrier)
      end
    rescue => e
      # Handle unexpected errors
      failure = TaskFailure.from_exception(e, {
        task_id: task_id,
        context_type: "unexpected_error"
      })

      record_task_failure(task_id, failure)

      # Call after_task_failure hook for unexpected errors
      @lifecycle_hooks[:after_task_failure].call(
        task_id: task_id,
        task: task,
        failure: failure,
        duration: Time.now - task_start_time
      )

      Agentic.logger.error("Unexpected error in task #{task_id}: #{e.message}")
    end

    # Schedules tasks that depend on a completed task
    # @param completed_task_id [String] ID of the completed task
    # @param agent_provider [Object] Provides agents for task execution
    # @param semaphore [Async::Semaphore] Controls concurrency
    # @param barrier [Async::Barrier] Tracks task completion
    # @return [void]
    def schedule_dependent_tasks(completed_task_id, agent_provider, semaphore, barrier)
      # Find tasks that depend on the completed task
      dependent_tasks = @dependencies.select do |task_id, deps|
        deps.include?(completed_task_id) && @execution_state[:pending].include?(task_id)
      end.keys

      # For each dependent task, check if all dependencies are satisfied
      dependent_tasks.each do |task_id|
        @dependencies[task_id]
        all_deps_satisfied = all_dependencies_met?(task_id)

        if all_deps_satisfied
          schedule_task(task_id, agent_provider, semaphore, barrier)
        end
      end
    end

    # Handles a task failure according to policy
    # @param task [Task] The failed task
    # @param failure [TaskFailure] The failure details
    # @param agent_provider [Object] Provides agents for task execution
    # @param semaphore [Async::Semaphore] Controls concurrency
    # @param barrier [Async::Barrier] Tracks task completion
    # @return [void]
    def handle_task_failure(task, failure, agent_provider, semaphore, barrier)
      # Check if this error type is retryable according to policy
      if retry?(task: task, failure: failure)
        Agentic.logger.info("Task #{task.id} failed with #{failure.type}, retrying...")
        retry_task(task, agent_provider, semaphore, barrier)
      elsif requires_intervention?(failure: failure)
        Agentic.logger.warn("Task #{task.id} failed with #{failure.type}, intervention required")
        request_human_intervention(task, failure)
      else
        # Apply general failure policy
        Agentic.logger.error("Task #{task.id} failed: #{failure.message}")
      end
    end

    # Retries a failed task
    # @param task [Task] The failed task
    # @param agent_provider [Object] Provides agents for task execution
    # @param semaphore [Async::Semaphore] Controls concurrency
    # @param barrier [Async::Barrier] Tracks task completion
    # @return [void]
    def retry_task(task, agent_provider, semaphore, barrier)
      # Check if the task can be retried
      return unless task.status == :failed

      # Initialize retry count if not already set
      task.retry_count ||= 0

      # Check if max retries reached
      max_retries = @retry_policy[:max_retries]
      if task.retry_count >= max_retries
        Agentic.logger.warn("Max retries reached for task #{task.id}")
        return
      end

      # Increment retry count
      task.retry_count += 1
      Agentic.logger.info("Retrying task #{task.id} (attempt #{task.retry_count} of #{max_retries})")

      # Apply backoff delay if specified
      apply_retry_backoff(task: task)

      # Reset task state for retry
      transition_task_state(task.id, from: :failed, to: :pending)

      # Schedule retrying the task
      schedule_task(task.id, agent_provider, semaphore, barrier)
    end

    # Requests human intervention for a failed task
    # @param task [Task] The failed task
    # @param failure [TaskFailure] The failure details
    # @return [void]
    def request_human_intervention(task, failure)
      # This would integrate with the yet-to-be-implemented human intervention system
      Agentic.logger.warn("Human intervention requested for task #{task.id}: #{failure.message}")
    end

    # Records a successful task completion with proper state transition and result storage
    # @param task_id [String] ID of the completed task
    # @param output [Hash] The task output
    # @return [void]
    def record_task_success(task_id, output)
      transition_task_state(task_id, from: :in_progress, to: :completed)
      @results[task_id] = TaskExecutionResult.success(output)
    end

    # Resolves the agent for a task: per-task agent first, then the
    # plan-wide provider or factory
    # @param task [Task] The task needing an agent
    # @param agent_provider [Object, nil] Plan-wide provider or factory
    # @return [Object] An agent responding to #execute
    def resolve_agent(task, agent_provider)
      per_task = @task_agents[task.id]
      if per_task
        # A per-task callable IS the work; wrap it so it receives the task
        return per_task.respond_to?(:execute) ? per_task : CallableAgent.new(per_task, task)
      end

      if agent_provider.respond_to?(:get_agent_for_task)
        agent_provider.get_agent_for_task(task)
      else
        # A plan-wide callable is a factory: task in, agent out
        agent_provider.call(task)
      end
    end

    # Fails fast when execute_plan is called with no way to obtain agents
    # @param agent_provider [Object, nil] Plan-wide provider or factory
    # @return [void]
    def ensure_agents_resolvable!(agent_provider)
      return if agent_provider

      missing = @tasks.keys.reject { |task_id| @task_agents.key?(task_id) }
      return if missing.empty?

      raise ArgumentError,
        "#{missing.size} task(s) have no agent. Pass an agent provider (or block) " \
        "to execute_plan, or add each task with add_task(task, agent: ...)"
    end

    # Records a task failure with proper state transition and result storage
    # @param task_id [String] ID of the failed task
    # @param failure [TaskFailure] The failure details
    # @return [void]
    def record_task_failure(task_id, failure)
      transition_task_state(task_id, from: :in_progress, to: :failed)
      @results[task_id] = TaskExecutionResult.failure(failure)
    end

    # Transitions a task from one state to another
    # @param task_id [String] ID of the task to transition
    # @param from: [Symbol] Current state of the task
    # @param to: [Symbol] Target state for the task
    # @return [void]
    def transition_task_state(task_id, from:, to:)
      return unless @execution_state[from].include?(task_id)

      @execution_state[from].delete(task_id)
      @execution_state[to].add(task_id)
    end
  end
end
