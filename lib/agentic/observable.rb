# frozen_string_literal: true

module Agentic
  # Custom implementation of the Observer pattern
  # Provides a thread-safe way for objects to notify observers of state changes
  #
  # Simplified version that works with the unified ObservabilityEngine
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
    def remove_observer(observer)
      @_observers&.delete(observer)
    end

    # Remove all observers from this object
    # @return [void]
    def clear_observers
      @_observers = []
    end

    # Return the number of observers
    # @return [Integer] The number of observers
    def observer_count
      @_observers ? @_observers.size : 0
    end

    # Notify all observers of an event (standardized interface)
    # @param event_type [Symbol] The type of event
    # @param source [Object] Source object (defaults to self)
    # @param args [Array] Arguments to pass to the observers
    # @return [void]
    def notify(event_type, source = nil, *args)
      # Delegate to global observability engine if available
      if defined?(Agentic.observability_engine)
        data = args.first if args.size == 1 && args.first.is_a?(Hash)
        data ||= {args: args} unless args.empty?
        data ||= {}

        Agentic.observability_engine.notify(
          event_type,
          data: data,
          source: source&.class&.name || self.class.name
        )
      end

      # Also notify local observers for backward compatibility
      notify_observers(event_type, source || self, *args)
    end

    # Notify all observers of an event (legacy interface)
    # @param event_type [Symbol] The type of event
    # @param *args Arguments to pass to the observers
    # @return [void]
    def notify_observers(event_type, *args)
      return unless @_observers

      # Make a thread-safe copy of the observers array
      observers = @_observers.dup

      observers.each do |observer|
        if observer.respond_to?(:update)
          # Handle both legacy (event_type, source, *args) and new interface
          if args.empty?
            observer.update(event_type, self)
          else
            observer.update(event_type, self, *args)
          end
        end
      rescue => e
        # Log errors but don't let one bad observer break the whole system
        if defined?(Agentic.logger)
          Agentic.logger.error("Observer notification failed: #{observer.class.name} - #{e.message}")
        else
          warn "Observer notification failed: #{observer.class.name} - #{e.message}"
        end
      end
    end

    # Legacy aliases for backward compatibility
    alias_method :delete_observer, :remove_observer
    alias_method :delete_observers, :clear_observers
    alias_method :count_observers, :observer_count
  end
end
