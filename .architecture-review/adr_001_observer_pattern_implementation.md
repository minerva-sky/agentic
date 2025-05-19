# ADR 001: Observer Pattern Implementation

## Status

Proposed

## Context

The Agentic framework requires an event notification system to enable components to react to changes in Task state. We've designed the architecture to use the Observer pattern, initially intending to use Ruby's built-in `Observable` module from the standard library.

However, as of Ruby 3.0, the `Observable` module has been extracted from the standard library into a separate gem: [observer](https://github.com/ruby/observer). This change necessitates a decision on how to implement the Observer pattern in our framework.

## Decision Drivers

1. **Dependency Management**: Minimizing unnecessary external dependencies
2. **API Stability**: Ensuring a stable interface for observers
3. **Performance**: Efficient notification for potentially large numbers of observers
4. **Thread Safety**: Support for concurrent task execution
5. **Maintainability**: Ease of understanding and maintaining the code
6. **Flexibility**: Ability to extend or customize behavior as needed

## Options Considered

### 1. Use the 'observer' gem

**Description**:
- Add the 'observer' gem as a dependency
- Continue using the `Observable` module as originally planned

**Pros**:
- Maintains compatibility with standard Ruby practices
- Minimal implementation effort
- Well-understood behavior
- Maintained by the Ruby core team

**Cons**:
- Adds an external dependency to the project
- Limited control over implementation details
- Not thread-safe by default
- Slightly less performance than a custom solution

### 2. Implement a minimal custom observer pattern

**Description**:
- Create our own simple observer implementation within the framework
- Focus on just the functionality we need

**Pros**:
- No external dependency
- Complete control over implementation
- Can be optimized for our specific use case
- Can be made thread-safe from the start

**Cons**:
- Requires maintaining custom code
- Need to ensure compatibility with standard observer patterns
- Potential for bugs in our implementation

### 3. Use the Wisper gem

**Description**:
- Add the 'wisper' gem as a dependency
- Use its pub/sub implementation for event notifications

**Pros**:
- More modern pub/sub implementation
- Additional features like global listeners, temporary subscriptions
- Well maintained and widely used
- Better separation between publishers and subscribers

**Cons**:
- More complex API than basic Observer pattern
- Adds an external dependency
- Potentially more than we need for our use case

### 4. Event-driven architecture with custom dispatcher

**Description**:
- Implement a centralized event dispatcher system
- Components register callbacks for specific event types

**Pros**:
- More flexible than traditional Observer pattern
- Can support multiple event types and filtering
- Centralized control over event propagation
- Potentially better performance for many observers

**Cons**:
- More complex implementation
- Different mental model than traditional Observer pattern
- Requires more coordination between components

## Decision

We will implement a minimal custom observer pattern (Option 2) that closely mirrors the API of Ruby's Observable module. This decision balances our need to minimize dependencies while maintaining a familiar and straightforward API.

The implementation will:

1. Be thread-safe by default
2. Support the familiar add_observer/delete_observer methods
3. Use a more explicit notification mechanism with event types
4. Include only what we need, no unnecessary features

### Implementation

```ruby
module Agentic
  module Observable
    # Add an observer to this object
    # @param observer [Object] The observer object
    # @return [void]
    def add_observer(observer)
      @_observers ||= []
      @_observers << observer unless @_observers.include?(observer)
    end
    
    # Remove an observer from this object
    # @param observer [Object] The observer object
    # @return [void]
    def delete_observer(observer)
      @_observers&.delete(observer)
    end
    
    # Remove all observers from this object
    # @return [void]
    def delete_observers
      @_observers = []
    end
    
    # Return the number of observers
    # @return [Integer] The number of observers
    def count_observers
      @_observers ? @_observers.size : 0
    end
    
    # Notify all observers of an event
    # @param event_type [Symbol] The type of event
    # @param *args Arguments to pass to the observers
    # @return [void]
    def notify_observers(event_type, *args)
      return unless @_observers
      
      # Make a thread-safe copy of the observers array
      observers = @_observers.dup
      
      observers.each do |observer|
        if observer.respond_to?(:update)
          observer.update(event_type, self, *args)
        end
      end
    end
  end
end
```

## Consequences

### Positive

1. **No External Dependencies**: The framework will not require the 'observer' gem or any other external dependency for event notification.
2. **Thread Safety**: The implementation will be thread-safe by default, better supporting concurrent task execution.
3. **Explicit Event Types**: Using explicit event types in notifications provides more clarity than the generic notification in the standard Observable.
4. **Familiar API**: Developers familiar with Ruby's Observable will find our API intuitive and easy to use.
5. **Custom Control**: We have complete control over the implementation and can optimize or extend it as needed.

### Negative

1. **Custom Code Maintenance**: We'll need to maintain our own implementation, including testing and bug fixes.
2. **Slight Deviation**: Our API will slightly deviate from the standard Observable module (explicit event types).
3. **Potential Future Changes**: If Ruby's Observer gem becomes significantly more advanced, we might miss out on those improvements.

### Neutral

1. **Migration Path**: If needed, we can easily migrate to using the observer gem or another solution in the future with minimal changes to client code.
2. **Documentation**: We'll need to clearly document our Observable module, but this is standard practice regardless of implementation choice.

## Implementation Notes

1. The Observable module should be included in the Agentic namespace to avoid conflicts.
2. Thread safety is achieved by creating a copy of the observers array before iteration.
3. The implementation should be tested for both single-threaded and multi-threaded scenarios.
4. Documentation should clarify the slight differences from Ruby's standard Observable.

## Alternative Paths

If this implementation proves problematic in the future, we can:

1. Switch to using the 'observer' gem with minimal code changes
2. Adopt Wisper or another pub/sub gem if we need more advanced features
3. Develop a more comprehensive event system if our needs become more complex

## References

- [Ruby Observer gem](https://github.com/ruby/observer)
- [Wisper gem](https://github.com/krisleech/wisper)
- [Observer Pattern on Wikipedia](https://en.wikipedia.org/wiki/Observer_pattern)