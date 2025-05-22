# Task Failure Handling Architecture

## Overview

This document outlines the architectural design decision for handling task failures within the Agentic framework. It addresses limitations of exception-based failure handling and proposes a more robust approach compatible with complex execution scenarios.

## Context

Tasks in Agentic represent discrete units of work executed by agents. The initial design considered raising exceptions when task execution fails, which presents several challenges:

- **Orchestration Complexity**: In multi-step or parallel execution scenarios, exceptions disrupt the entire orchestration flow
- **Recovery Difficulty**: Exception-based approaches complicate retry mechanisms and graceful degradation
- **Workflow Continuity**: Dependent tasks may be able to proceed with partial results or alternative paths
- **Failure Analysis**: Immediate exception propagation may limit comprehensive failure tracking and analysis

## Design Decision

### Result-Oriented Failure Handling

Rather than raising exceptions, task execution will use a result-oriented approach:

1. **Task Result Object**: Introduce a TaskResult class to encapsulate execution outcomes
2. **Status-Based Flow Control**: Use task status to indicate completion state
3. **Error Preservation**: Store error details in the task object itself
4. **Observable Failure**: Implement event-based notification for status changes

### TaskResult Structure

```ruby
class TaskResult
  attr_reader :success, :output, :error, :task_id
  
  def initialize(task_id:, success:, output: nil, error: nil)
    @task_id = task_id
    @success = success
    @output = output
    @error = error
  end
  
  def successful?
    @success
  end
  
  def failed?
    !@success
  end
end
```

### Task Status Lifecycle

```
  ┌─────────┐     ┌─────────────┐     ┌───────────┐
  │ pending ├────►│ in_progress ├────►│ completed │
  └─────────┘     └──────┬──────┘     └───────────┘
                         │
                         ▼
                    ┌─────────┐      ┌──────────┐
                    │ failed  ├─────►│ retrying │
                    └─────┬───┘      └───┬──────┘
                          │              │
                          └──────────────┘
```

### Task Error Representation

```ruby
class TaskError
  attr_reader :message, :type, :timestamp, :context
  
  def initialize(message:, type:, context: {})
    @message = message
    @type = type
    @timestamp = Time.now
    @context = context
  end
  
  def to_h
    {
      message: @message,
      type: @type,
      timestamp: @timestamp.iso8601,
      context: @context
    }
  end
end
```

### Observable Failure Pattern

```ruby
module TaskObservable
  def add_observer(observer)
    @observers ||= []
    @observers << observer
  end
  
  def notify_status_change(old_status, new_status)
    return unless @observers
    
    @observers.each do |observer|
      observer.on_task_status_change(self, old_status, new_status)
    end
  end
end
```

## Implementation Details

### Task Class Modifications

```ruby
class Task
  include TaskObservable
  
  attr_reader :id, :description, :agent_spec, :input, :output, :status, :error
  
  # ... existing initialization ...
  
  def perform(agent)
    old_status = @status
    @status = :in_progress
    notify_status_change(old_status, @status)
    
    begin
      @output = agent.execute(build_prompt)
      old_status = @status
      @status = :completed
      notify_status_change(old_status, @status)
      
      TaskResult.new(
        task_id: @id,
        success: true,
        output: @output
      )
    rescue StandardError => e
      @error = TaskError.new(
        message: e.message,
        type: e.class.name,
        context: {
          backtrace: e.backtrace&.first(10),
          agent_id: agent.id
        }
      )
      
      old_status = @status
      @status = :failed
      notify_status_change(old_status, @status)
      
      Agentic.logger.error("Task execution failed: #{e.message}")
      
      TaskResult.new(
        task_id: @id,
        success: false,
        error: @error
      )
    end
  end
  
  def retry(agent)
    return unless @status == :failed
    
    old_status = @status
    @status = :retrying
    notify_status_change(old_status, @status)
    
    perform(agent)
  end
  
  # ... other methods ...
end
```

### PlanOrchestrator Usage

```ruby
class PlanOrchestrator
  def execute_task(task, agent)
    result = task.perform(agent)
    
    if result.successful?
      # Process successful outcome
      process_output(task, result.output)
    else
      # Handle failure based on policy
      handle_task_failure(task, result.error)
    end
    
    result
  end
  
  def handle_task_failure(task, error)
    case error.type
    when "TimeoutError"
      # Maybe retry with longer timeout
      retry_with_extended_timeout(task)
    when "AuthenticationError"
      # Maybe request new credentials
      request_authentication_update(task)
    else
      # Apply general failure policy
      apply_failure_policy(task)
    end
  end
  
  # ... other methods ...
end
```

## Failure Handling Strategies

### Retry with Backoff

For transient failures, implement exponential backoff:

```ruby
def retry_with_backoff(task, agent, max_attempts = 3)
  attempts = 0
  
  while attempts < max_attempts
    sleep_duration = 2 ** attempts
    sleep(sleep_duration)
    
    attempts += 1
    result = task.retry(agent)
    
    return result if result.successful?
  end
  
  # Max retries exceeded
  TaskResult.new(
    task_id: task.id,
    success: false,
    error: TaskError.new(
      message: "Max retry attempts exceeded",
      type: "MaxRetriesExceededError",
      context: { attempts: attempts }
    )
  )
end
```

### Alternative Task Path

When a task fails, try an alternative approach:

```ruby
def execute_with_fallback(primary_task, fallback_task, agent)
  result = primary_task.perform(agent)
  
  if result.successful?
    return result
  end
  
  # Try fallback task instead
  fallback_result = fallback_task.perform(agent)
  
  # Record relationship between tasks
  primary_task.add_related_task(fallback_task.id, "fallback")
  
  fallback_result
end
```

### Human Intervention

For critical failures, request human assistance:

```ruby
def request_human_intervention(task, error)
  intervention_request = HumanInterventionRequest.new(
    task_id: task.id,
    error: error,
    suggested_actions: generate_intervention_suggestions(error),
    priority: calculate_intervention_priority(task, error)
  )
  
  InterventionPortal.instance.submit(intervention_request)
  
  # Return a pending result while waiting for human input
  TaskResult.new(
    task_id: task.id,
    success: false,
    error: TaskError.new(
      message: "Awaiting human intervention",
      type: "HumanInterventionRequiredError",
      context: { intervention_id: intervention_request.id }
    )
  )
end
```

## Benefits of This Approach

1. **Enhanced Resilience**: System continues functioning despite individual task failures
2. **Execution Flexibility**: Supports parallel, sequential, and conditional execution patterns
3. **Better Diagnostics**: Comprehensive error context enables more effective debugging
4. **Adaptable Recovery**: Multiple recovery strategies can be applied based on failure context
5. **Operational Visibility**: Failure patterns can be analyzed across executions
6. **Status Observability**: Other components can react to status changes through the observer pattern

## Drawbacks and Mitigations

1. **Increased Complexity**: More complex than simple exceptions
   - Mitigation: Provide helper methods and clear documentation

2. **Error Propagation**: May mask serious errors that should halt execution
   - Mitigation: Include critical error classification with different handling

3. **Memory Usage**: Storing error details consumes more memory
   - Mitigation: Implement configurable error detail retention policies

## Integration with Other Components

### Verification Layer

Task failure information feeds into verification:

```ruby
def verify_with_failure_awareness(task)
  # Include failure history in verification context
  verification_context = {
    failure_history: task.failure_history,
    current_error: task.error
  }
  
  VerificationHub.instance.verify(task, verification_context)
end
```

### Learning System

Failures contribute to system learning:

```ruby
def record_failure_patterns(task, error)
  ExecutionHistoryStore.instance.record_failure(
    task_type: task.type,
    error_type: error.type,
    context: error.context,
    resolution_strategy: task.resolution_strategy
  )
  
  # Analyze failure patterns periodically
  PatternRecognizer.instance.analyze_failures if should_analyze_patterns?
end
```

## Conclusion

This result-oriented approach to task failure handling offers significant advantages over exception-based designs, particularly for complex orchestration scenarios. It enables more resilient execution flows, flexible recovery strategies, and comprehensive failure analysis while maintaining system stability.

By storing error information within the task and using status-based flow control, the system can better handle parallel execution, support sophisticated retry mechanisms, and provide rich diagnostics for both automated and human-assisted recovery.