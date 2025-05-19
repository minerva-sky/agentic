# frozen_string_literal: true

module Agentic
  # Custom implementation of the Observer pattern
  # Provides a thread-safe way for objects to notify observers of state changes
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
