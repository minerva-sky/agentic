# frozen_string_literal: true

require "spec_helper"

class ObservableTest
  include Agentic::Observable

  attr_reader :value

  def initialize
    @value = 0
  end

  def increment
    old_value = @value
    @value += 1
    notify_observers(:value_changed, old_value, @value)
  end
end

class TestObserver
  attr_reader :events

  def initialize
    @events = []
  end

  def update(event_type, observable, *args)
    @events << {
      type: event_type,
      observable: observable,
      args: args
    }
  end
end

RSpec.describe Agentic::Observable do
  let(:observable) { ObservableTest.new }
  let(:observer) { TestObserver.new }

  describe "#add_observer" do
    it "adds an observer" do
      observable.add_observer(observer)
      expect(observable.count_observers).to eq(1)
    end

    it "doesn't add the same observer twice" do
      observable.add_observer(observer)
      observable.add_observer(observer)
      expect(observable.count_observers).to eq(1)
    end
  end

  describe "#delete_observer" do
    it "removes an observer" do
      observable.add_observer(observer)
      observable.delete_observer(observer)
      expect(observable.count_observers).to eq(0)
    end

    it "doesn't raise an error when observer is not present" do
      expect { observable.delete_observer(observer) }.not_to raise_error
    end
  end

  describe "#delete_observers" do
    it "removes all observers" do
      observable.add_observer(observer)
      observable.add_observer(TestObserver.new)
      observable.delete_observers
      expect(observable.count_observers).to eq(0)
    end
  end

  describe "#notify_observers" do
    before do
      observable.add_observer(observer)
    end

    it "notifies observers with event and arguments" do
      observable.increment

      expect(observer.events.size).to eq(1)
      expect(observer.events.first[:type]).to eq(:value_changed)
      expect(observer.events.first[:observable]).to eq(observable)
      expect(observer.events.first[:args]).to eq([0, 1])
    end

    it "handles multiple observers" do
      second_observer = TestObserver.new
      observable.add_observer(second_observer)

      observable.increment

      expect(observer.events.size).to eq(1)
      expect(second_observer.events.size).to eq(1)
    end

    it "doesn't call observers that don't implement update" do
      non_conforming_observer = Object.new
      observable.add_observer(non_conforming_observer)

      expect { observable.increment }.not_to raise_error
    end

    it "is thread-safe when observers are added/removed during notification" do
      # Observer that removes itself during notification
      self_removing_observer = Class.new do
        def initialize(observable)
          @observable = observable
        end

        def update(*)
          @observable.delete_observer(self)
        end
      end.new(observable)

      # Observer that adds a new observer during notification
      observer_adding_observer = Class.new do
        def initialize(observable, new_observer)
          @observable = observable
          @new_observer = new_observer
        end

        def update(*)
          @observable.add_observer(@new_observer)
        end
      end.new(observable, TestObserver.new)

      observable.add_observer(self_removing_observer)
      observable.add_observer(observer_adding_observer)

      # This should not raise errors even though observers are modified during notification
      expect { observable.increment }.not_to raise_error
    end
  end
end
