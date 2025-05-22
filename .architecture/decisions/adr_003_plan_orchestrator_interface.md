# ADR 003: Plan Orchestrator Interface Design

## Status

Proposed

## Context

The `PlanOrchestrator` class in the Agentic framework is responsible for managing the execution of tasks, handling dependencies, and tracking task state throughout the execution lifecycle. During testing, we encountered a tension between proper encapsulation of implementation details and the need for effective testing.

Prior to this change, several methods were marked as `private` but were being accessed in tests using `send(:method_name)`. This approach is generally considered a testing anti-pattern as it couples tests to implementation details rather than observable behavior. To address this issue, we needed to decide whether to make these methods public or restructure our testing approach.

The methods in question were:
1. `all_dependencies_met?` - Checks if dependencies for a task are satisfied
2. `find_eligible_tasks` - Identifies tasks eligible for execution 
3. `overall_status` - Determines the current status of the plan

## Decision Drivers

1. **Encapsulation**: Maintaining a clean separation between public interface and implementation details
2. **Testability**: Enabling effective testing without violating encapsulation principles
3. **API Design**: Creating a coherent and intuitive public API
4. **Future Compatibility**: Ensuring changes don't restrict future refactoring options
5. **Code Clarity**: Providing clear boundaries between public and private concerns

## Options Considered

### 1. Make the methods public

**Description**:
- Move the three methods from the private section to the public interface
- Update tests to use direct calls instead of `send(:method_name)`

**Pros**:
- Immediately solves the testing issue
- Simple change with minimal code modification
- No additional dependencies or structures required

**Cons**:
- Exposes implementation details that may not belong in the public API
- Could lead to inappropriate coupling to these methods by client code
- May restrict future refactoring by creating contract obligations
- Violates the principle of minimizing public interfaces

### 2. Create test-specific interfaces or subclasses

**Description**:
- Create testing-specific subclasses that expose private methods for testing
- Keep production code properly encapsulated

**Pros**:
- Maintains encapsulation in production code
- Explicitly separates test-specific access from production interfaces
- Preserves future refactoring flexibility

**Cons**:
- Introduces additional complexity and indirection
- Requires maintaining test-specific classes
- May still lead to tests that are coupled to implementation details

### 3. Refactor to introduce proper abstractions

**Description**:
- Identify the underlying architectural concerns represented by these methods
- Extract these concerns into appropriate abstractions (e.g., a dependency resolver, eligibility provider, status reporter)
- Make these new abstractions testable components in their own right

**Pros**:
- Results in better separation of concerns and cohesion
- Creates properly designed abstractions rather than exposing implementation details
- Improves overall system architecture
- Provides truly unit-testable components

**Cons**:
- Requires significant refactoring
- More time-consuming implementation
- May require changes to multiple components and tests

### 4. Use alternative testing approaches

**Description**:
- Instead of testing these methods directly, test their observable effects
- Focus on behavior verification rather than state verification
- Use integration tests rather than unit tests for orchestration logic

**Pros**:
- Avoids coupling tests to implementation details
- Tests what matters: the observable behavior
- More resilient to refactoring

**Cons**:
- May require more complex test setups
- Could be more difficult to diagnose test failures
- Might not provide sufficient test coverage for complex logic

## Decision

For immediate pragmatic reasons, we have chosen **Option 1: Make the methods public**. However, we acknowledge that this is a compromise that introduces architectural debt, and we should plan to implement **Option 3: Refactor to introduce proper abstractions** in the future.

This decision takes into account the immediate need to fix the testing approach while balancing architectural concerns. By making these methods public now, we allow tests to function correctly without using `send(:method_name)`, but we recognize the need for a better long-term solution.

## Consequences

### Positive

1. **Improved Testability**: Tests no longer need to use `send(:method_name)`, making them more straightforward and less brittle.
2. **Explicit Contract**: The contract of these methods is now explicitly part of the public interface, providing clarity on their expected behavior.
3. **Documentation Visibility**: The methods now have yard-doc comments visible in the public API documentation, making their purpose clear.

### Negative

1. **Expanded Public Interface**: The public API surface is now larger, potentially making the class harder to understand and use correctly.
2. **Exposed Implementation Details**: Internal orchestration concepts are now exposed, potentially creating inappropriate dependencies.
3. **Future Constraints**: These methods must now be maintained as part of the public contract, limiting future refactoring options.
4. **Design Tension**: The current design violates the principle of minimal public interfaces and proper encapsulation.

### Neutral

1. **Method Semantics**: The methods themselves are well-named and their behavior is clear, so even as public methods they are unlikely to cause confusion.
2. **Documentation**: The methods already had good documentation, so making them public required no additional documentation effort.

## Implementation Notes

1. These methods were moved from the private section to the public section:

```ruby
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
  elsif @execution_state[:pending].empty? && @execution_state[:in_progress].empty?
    :completed
  else
    :in_progress
  end
end
```

2. Tests were updated to access these methods directly rather than using `send(:method_name)`.

3. Care was taken to ensure all tests still pass with this change.

## Future Work

While this change resolves the immediate issue, several architectural improvements should be considered for future work:

1. **Task Dependency Resolution**: Extract dependency management into a dedicated component that manages the relationships between tasks and determines eligibility.

2. **Plan Status Management**: Create a dedicated component for tracking and reporting on plan status, allowing for more sophisticated status reporting.

3. **Execution State Management**: Consider extracting the state transition logic into a dedicated state management component.

4. **Test Strategy Review**: Review and potentially revise the testing strategy to focus more on behavior verification rather than state verification.

## References

- [Tell Don't Ask Principle](https://martinfowler.com/bliki/TellDontAsk.html)
- [Law of Demeter](https://en.wikipedia.org/wiki/Law_of_Demeter)
- [Testing Anti-Patterns: Reaching into Private State](https://blog.thecodewhisperer.com/permalink/getting-your-tests-to-tell-you-when-theyre-asking-for-too-much)
- [ADR 002: Plan Orchestrator Implementation with Async](file:///Users/valentinostoll/src/agentic/.architecture-review/adr_002_plan_orchestrator.md)