# Task Observable Pattern

## Overview

This document outlines the architectural design for implementing the Observable pattern in the Agentic task system. It leverages Ruby's built-in Observable module to enable loose coupling between tasks and components that need to react to task state changes.

## Design Decision

### Using Ruby's Standard Observable

The Agentic framework will use Ruby's built-in Observable module from the standard library rather than implementing a custom solution. The standard library implementation provides:

1. **Proven Implementation**: Battle-tested code with known behavior
2. **Familiarity**: Recognized pattern that Ruby developers understand
3. **Lightweight**: Minimal overhead for the functionality provided
4. **Maintenance**: Reduces custom code that needs to be maintained

## Implementation Details

### Task Integration

```ruby
require 'observer'

module Agentic
  class Task
    include Observable
    
    # ... other attributes and methods ...
    
    def perform(agent)
      old_status = @status
      @status = :in_progress
      
      # Signal that object state has changed
      changed
      # Notify observers with event type and context
      notify_observers(:status_change, self, old_status, @status)
      
      # ... execution logic ...
      
      # Status transitions with notifications
    end
    
    def retry(agent)
      # Similar pattern with status change notifications
    end
  end
end
```

### Notification Protocol

The Observable pattern requires a clear protocol for notifications:

1. **Event Types**: Symbolized event identifiers (e.g., `:status_change`)
2. **Event Context**: Relevant objects and data for the event
3. **Observer Interface**: Observer must implement `update` method

Observer's `update` method signature:

```ruby
def update(event_type, task, *args)
  # Handle the event based on type and context
end
```

Common event types:

| Event Type | Description | Arguments |
|------------|-------------|-----------|
| `:status_change` | Task status has changed | `task, old_status, new_status` |
| `:output_available` | Task has produced output | `task, output` |
| `:failure_occurred` | Task has failed | `task, failure` |
| `:verification_complete` | Task verification complete | `task, verification_result` |

## Practical Usage Patterns

### 1. Plan Orchestration

```ruby
class PlanOrchestrator
  def initialize(plan_id)
    @plan_id = plan_id
    @tasks_in_progress = 0
    @task_results = {}
    @dependencies = {}
  end
  
  def update(event_type, task, *args)
    case event_type
    when :status_change
      old_status, new_status = args
      handle_status_change(task, old_status, new_status)
    when :failure_occurred
      failure = args.first
      handle_failure(task, failure)
    end
  end
  
  def add_task(task, dependencies = [])
    task.add_observer(self)
    @dependencies[task.id] = dependencies
  end
  
  private
  
  def handle_status_change(task, old_status, new_status)
    # React to status changes
    # Track tasks in progress
    # Execute dependent tasks when appropriate
  end
  
  def handle_failure(task, failure)
    # Apply appropriate failure handling strategy
    # Retry, fallback, or human intervention
  end
  
  def execute_dependent_tasks(completed_task_id)
    # Find and execute tasks that depend on the completed task
  end
end
```

### 2. Metrics Collection

```ruby
class MetricsCollector
  def initialize
    @task_timings = {}
    @status_transitions = {}
  end
  
  def update(event_type, task, *args)
    if event_type == :status_change
      old_status, new_status = args
      
      # Record timestamp of status change
      @status_transitions[task.id] ||= []
      @status_transitions[task.id] << {
        from: old_status,
        to: new_status,
        timestamp: Time.now
      }
      
      # Calculate and record timings for completed tasks
      if new_status == :completed
        start_time = find_start_time(task.id)
        @task_timings[task.id] = Time.now - start_time if start_time
      end
    end
  end
  
  private
  
  def find_start_time(task_id)
    transition = @status_transitions[task_id]&.find { |t| t[:to] == :in_progress }
    transition&.fetch(:timestamp)
  end
end
```

### 3. Human Intervention Portal

```ruby
class HumanInterventionPortal
  def initialize
    @intervention_requests = {}
  end
  
  def update(event_type, task, *args)
    if event_type == :status_change
      old_status, new_status = args
      
      if new_status == :failed
        failure = task.failure
        
        # Check if this failure requires human intervention
        if requires_human_intervention?(failure)
          request_intervention(task, failure)
        end
      end
    end
  end
  
  private
  
  def requires_human_intervention?(failure)
    # Logic to determine if human should intervene
    %w[AuthenticationError PermissionDeniedError UnknownDomainError].include?(failure.type)
  end
  
  def request_intervention(task, failure)
    @intervention_requests[task.id] = {
      task_id: task.id,
      task_description: task.description,
      failure: failure.to_h,
      timestamp: Time.now,
      status: :pending
    }
    
    # Notify human operators
    notify_operators(task)
  end
end
```

## Benefits of Observable Pattern

### 1. Loose Coupling

The Observable pattern decouples tasks from components that need to react to task state:

```
                      ┌─────────────────┐
                      │MetricsCollector │
                      └────────┬────────┘
                               │
┌─────┐   notify    ┌──────┐   │   update
│Agent│───────────▶ │ Task │◀──┘
└─────┘             └──────┘
                        │
                        │
                    ┌───┴────────────┐
                    │PlanOrchestrator│
                    └────────────────┘
```

This enables:
- Independent development of components
- Pluggable monitoring and orchestration
- Testing in isolation

### 2. Flexible Execution Models

The Observer pattern supports both:
- **Synchronous Execution**: Direct response to events
- **Asynchronous Execution**: Event queues with background processing

This enables evolution of the execution model without changing the Task interface.

### 3. Simplified Extensibility

New functionality can be added by implementing new observers:

```ruby
# Add execution logging without modifying Task
class TaskLogger
  def update(event_type, task, *args)
    if event_type == :status_change
      old_status, new_status = args
      Agentic.logger.info("Task #{task.id} transitioned from #{old_status} to #{new_status}")
    end
  end
end

# Usage:
task = Task.new(...)
task.add_observer(TaskLogger.new)
```

### 4. Enhanced Parallelism

Observable pattern enables:
- Multiple observers processing events in parallel
- Observer-specific thread pools
- Backpressure handling per observer

## Implementation Considerations

### 1. Thread Safety

Ruby's Observable implementation is not thread-safe by default. In multi-threaded environments:

- Consider using a thread-safe observer collection
- Use synchronization when notifying observers
- Consider thread-local changed flag

Example enhancement:

```ruby
module ThreadSafeObservable
  include Observable
  
  def notify_observers(*args)
    observers = @observer_peers.dup
    observers.each do |observer|
      observer.update(*args)
    end
  end
end
```

### 2. Memory Management

Observers create references to the observed objects which may lead to memory leaks:

- Ensure observers are properly removed when no longer needed
- Consider using weak references for long-lived tasks
- Implement cleanup methods for completed tasks

### 3. Error Handling

Observer errors should not affect the observed object:

```ruby
def notify_observers(*args)
  observers = @observer_peers.dup
  observers.each do |observer|
    begin
      observer.update(*args)
    rescue => e
      Agentic.logger.error("Observer error: #{e.message}")
    end
  end
end
```

## Integration with Larger Architecture

### 1. PlanOrchestrator

The PlanOrchestrator becomes an observer of all tasks it manages:

```ruby
def execute_plan(tasks)
  tasks.each do |task|
    task.add_observer(self)
    # Add other observers as needed
    task.add_observer(MetricsCollector.instance)
    task.add_observer(HumanInterventionPortal.instance)
  end
  
  # Start eligible tasks
  start_eligible_tasks(tasks)
end
```

### 2. Verification System

Verification can be triggered by task status changes:

```ruby
class VerificationHub
  def update(event_type, task, *args)
    if event_type == :status_change
      old_status, new_status = args
      
      if new_status == :completed
        # Perform verification
        verification_result = verify(task)
        
        # Notify observers of verification result
        task.changed
        task.notify_observers(:verification_complete, task, verification_result)
      end
    end
  end
end
```

### 3. Learning System

The learning system can observe tasks to gather training data:

```ruby
class ExecutionHistoryStore
  def update(event_type, task, *args)
    case event_type
    when :status_change
      record_status_change(task, *args)
    when :failure_occurred
      record_failure(task, *args.first)
    when :verification_complete
      record_verification(task, *args.first)
    end
  end
end
```

## Conclusion

The Observable pattern provides a robust, flexible foundation for task state management in the Agentic framework. By leveraging Ruby's built-in Observable module, we achieve loose coupling between tasks and the components that react to them, enabling a more extensible and maintainable architecture.

This design supports our core architectural goals of:
- Separation of concerns
- Extensibility
- Resilience to failures
- Flexible execution models

The Observable pattern will be particularly valuable as the system grows in complexity, allowing new monitoring, orchestration, and intervention components to be added without modifying the core Task implementation.