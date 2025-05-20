# ADR 002: Plan Orchestrator Implementation with Async

## Status

Proposed

## Context

The Agentic framework requires a component to manage the execution of tasks in a plan, handling dependencies, orchestrating execution flow, and managing task state transitions. Having already implemented the Observable pattern for task state notification, we need to evaluate whether to continue with that approach or to use a more comprehensive concurrency solution for our PlanOrchestrator.

After reviewing the available options, we're considering whether the [socketry/async](https://github.com/socketry/async) gem would provide a better foundation for task orchestration than our current Observable pattern approach.

## Decision Drivers

1. **Execution Flexibility**: Support for various execution patterns (sequential, parallel, conditional)
2. **Dependency Management**: Ability to handle complex task dependencies
3. **Failure Handling**: Graceful management of task failures with appropriate recovery strategies
4. **Extensibility**: Support for custom execution strategies and plugins
5. **Observability**: Comprehensive metrics and visibility into execution state
6. **Human Intervention**: Clear points for human involvement when needed
7. **State Management**: Maintaining consistent state across the execution lifecycle
8. **Concurrency Model**: Efficient and predictable concurrency
9. **Resource Management**: Proper handling of system resources

## Options Considered

### 1. Observer Pattern-Based Orchestrator (Current Approach)

**Description**:
- Continue using our current Observer pattern implementation
- Design PlanOrchestrator as an observer of task state changes
- React to events (task completion, failure) to drive execution

**Pros**:
- Already implemented and tested
- No additional dependencies
- Simple to understand
- Loose coupling between tasks and orchestrator

**Cons**:
- Limited concurrency support - not optimized for parallel execution
- Manual thread management required for true parallelism
- No built-in limiting of concurrency
- Potential for race conditions in concurrent scenarios

### 2. Async Gem-Based Orchestrator

**Description**:
- Use socketry/async as the foundation for task orchestration
- Leverage Async's fiber-based concurrency model
- Use Async barriers and semaphores to manage task completion and concurrency

**Pros**:
- Fiber-based concurrency model is lightweight and efficient
- Built-in mechanisms for limiting concurrency (semaphores)
- Better support for parallel execution
- Task parent-child relationships handle cleanup automatically
- More idiomatic for concurrent Ruby code
- Support for graceful termination

**Cons**:
- Adds an external dependency
- Different mental model than our current implementation
- May require refactoring of existing task code
- Learning curve for developers unfamiliar with Async

## Decision

We will adopt the **Async Gem-Based Orchestrator** approach (Option 2) for our PlanOrchestrator implementation. While the Observer pattern has served us well for simple task state notification, the Async gem provides a more comprehensive solution for managing concurrent task execution with better control over resource usage, concurrency limits, and error handling.

### Implementation Approach

The PlanOrchestrator will leverage Async's capabilities while maintaining our existing task lifecycle and interface. We'll implement it as follows:

```ruby
module Agentic
  class PlanOrchestrator
    attr_reader :plan_id, :tasks, :execution_state, :results

    def initialize(plan_id: SecureRandom.uuid, concurrency_limit: 10)
      @plan_id = plan_id
      @tasks = {}
      @dependencies = {}
      @results = {}
      @execution_state = {
        pending: Set.new,
        in_progress: Set.new,
        completed: Set.new,
        failed: Set.new
      }
      @concurrency_limit = concurrency_limit
    end
    
    def add_task(task, dependencies = [])
      task_id = task.id
      @tasks[task_id] = task
      @dependencies[task_id] = Array(dependencies)
      @execution_state[:pending].add(task_id)
    end
    
    def execute_plan(agent_provider)
      Async do |reactor|
        barrier = Async::Barrier.new
        semaphore = Async::Semaphore.new(@concurrency_limit, parent: barrier)
        
        # Start with tasks that have no dependencies
        eligible_tasks = find_eligible_tasks
        
        # Initial execution of eligible tasks
        eligible_tasks.each do |task_id|
          schedule_task(task_id, agent_provider, semaphore, barrier)
        end
        
        # Wait for all tasks to complete
        barrier.wait
      end
      
      # Return execution results
      {
        plan_id: @plan_id,
        status: overall_status,
        tasks: @tasks.transform_values(&:to_h),
        results: @results
      }
    end
    
    private
    
    def schedule_task(task_id, agent_provider, semaphore, barrier)
      return unless @execution_state[:pending].include?(task_id)
      
      # Move to in_progress state
      @execution_state[:pending].delete(task_id)
      @execution_state[:in_progress].add(task_id)
      task = @tasks[task_id]
      
      # Schedule task execution with the semaphore
      semaphore.async do
        begin
          agent = agent_provider.get_agent_for_task(task)
          result = task.perform(agent)
          
          # Record result and update state
          if result.successful?
            @execution_state[:in_progress].delete(task_id)
            @execution_state[:completed].add(task_id)
            @results[task_id] = { 
              status: :completed,
              output: result.output
            }
            
            # Find and schedule dependent tasks
            schedule_dependent_tasks(task_id, agent_provider, semaphore, barrier)
          else
            @execution_state[:in_progress].delete(task_id)
            @execution_state[:failed].add(task_id)
            @results[task_id] = {
              status: :failed,
              failure: result.failure&.to_h
            }
            
            # Handle failure based on policy
            handle_task_failure(task, result.failure, agent_provider, semaphore, barrier)
          end
        rescue => e
          # Handle unexpected errors
          @execution_state[:in_progress].delete(task_id)
          @execution_state[:failed].add(task_id)
          @results[task_id] = {
            status: :failed,
            failure: TaskFailure.from_exception(e).to_h
          }
          
          Agentic.logger.error("Unexpected error in task #{task_id}: #{e.message}")
        end
      end
    end
    
    def schedule_dependent_tasks(completed_task_id, agent_provider, semaphore, barrier)
      # Find tasks that depend on the completed task
      dependent_tasks = @dependencies.select do |task_id, deps|
        deps.include?(completed_task_id) && @execution_state[:pending].include?(task_id)
      end.keys
      
      # For each dependent task, check if all dependencies are satisfied
      dependent_tasks.each do |task_id|
        deps = @dependencies[task_id]
        all_deps_satisfied = deps.all? do |dep_id|
          @execution_state[:completed].include?(dep_id)
        end
        
        if all_deps_satisfied
          schedule_task(task_id, agent_provider, semaphore, barrier)
        end
      end
    end
    
    def handle_task_failure(task, failure, agent_provider, semaphore, barrier)
      # Implement different strategies based on failure type
      case failure.type
      when "TimeoutError"
        # Maybe retry with extended timeout
        Agentic.logger.info("Task #{task.id} failed with timeout, retrying...")
        retry_task(task, agent_provider, semaphore, barrier)
      when "AuthenticationError"
        # Maybe request new credentials
        Agentic.logger.warn("Task #{task.id} failed with authentication error, intervention required")
        request_human_intervention(task, failure)
      else
        # Apply general failure policy
        Agentic.logger.error("Task #{task.id} failed: #{failure.message}")
      end
    end
    
    def retry_task(task, agent_provider, semaphore, barrier, max_retries = 3)
      # Check if the task can be retried
      return unless task.status == :failed
      return if task.retry_count && task.retry_count >= max_retries
      
      # Increment retry count
      task.retry_count ||= 0
      task.retry_count += 1
      
      # Put task back in pending state
      @execution_state[:failed].delete(task.id)
      @execution_state[:pending].add(task.id)
      
      # Schedule retrying the task
      schedule_task(task.id, agent_provider, semaphore, barrier)
    end
    
    def request_human_intervention(task, failure)
      # This would integrate with the yet-to-be-implemented human intervention system
      Agentic.logger.warn("Human intervention requested for task #{task.id}: #{failure.message}")
    end
    
    def find_eligible_tasks
      @dependencies.select do |task_id, deps|
        deps.empty? && @execution_state[:pending].include?(task_id)
      end.keys
    end
    
    def overall_status
      if @execution_state[:failed].any?
        :partial_failure
      elsif @execution_state[:pending].empty? && @execution_state[:in_progress].empty?
        :completed
      else
        :in_progress
      end
    end
  end
end
```

## Integration with Existing Task System

To integrate with the Async-based PlanOrchestrator, we'll need to make the following adjustments to our Task implementation:

1. **Minimal Interface Changes**: We'll maintain the current Task interface while ensuring it's compatible with Async's concurrency model.

2. **Task Result Handling**: We'll continue using our TaskResult approach for communicating execution outcomes.

3. **Observer Pattern Coexistence**: We'll maintain the Observer pattern for task state notification, which can coexist with the Async-based execution model, allowing components that don't need concurrent execution to still observe task state.

## Consequences

### Positive

1. **Better Concurrency**: Fiber-based concurrency offers a more efficient and scalable model for task execution.
2. **Resource Management**: Built-in semaphores prevent resource exhaustion by limiting concurrent tasks.
3. **Task Lifecycle**: Parent-child relationships in Async tasks handle cleanup and termination automatically.
4. **Simplified Orchestration**: The complexity of managing concurrent execution is largely handled by the Async gem.
5. **Graceful Termination**: Better support for stopping and cleaning up tasks during termination.

### Negative

1. **New Dependency**: Adds a dependency on the Async gem.
2. **Learning Curve**: Team members will need to understand Async's concurrency model.
3. **Integration Effort**: Requires careful integration with our existing Observer pattern.

### Neutral

1. **Performance Characteristics**: While expected to be better, actual performance improvements need to be measured.
2. **API Evolution**: The Async gem is actively developed, which may introduce API changes over time.

## Implementation Notes

1. **Gradual Transition**:
   - Start by making the PlanOrchestrator Async-based without requiring tasks to change
   - Later, consider deeper integration where tasks themselves leverage Async

2. **Testing Strategy**:
   - Create dedicated tests for the Async-based PlanOrchestrator
   - Ensure existing tests still pass with the new implementation
   - Test concurrency limits and behavior under high load

3. **Monitoring and Metrics**:
   - Add instrumentation for tracking task execution performance
   - Measure and compare against the previous Observer-based approach

4. **Error Handling**:
   - Ensure proper propagation of errors from Async tasks
   - Maintain our existing error context information

## Alternative Paths

If the Async approach proves problematic, we can:

1. Revert to our Observer pattern implementation
2. Consider other concurrency frameworks like concurrent-ruby
3. Implement a hybrid approach that uses Observer pattern for state notification and a simpler execution model

## References

- [Socketry Async GitHub Repository](https://github.com/socketry/async)
- [Async Best Practices](https://socketry.github.io/async/guides/best-practices/index)
- [Asynchronous Tasks Guide](https://socketry.github.io/async/guides/asynchronous-tasks/index.html)
- [Observer Pattern Implementation (ADR-001)](file:///Users/valentinostoll/src/agentic/.architecture-review/adr_001_observer_pattern_implementation.md)
- [Task Failure Handling Architecture](file:///Users/valentinostoll/src/agentic/.architecture-review/task_failure_handling.md)