# frozen_string_literal: true

require "tempfile"

# Test observer for recording events
class TestObserver
  attr_reader :received_events

  def initialize
    @received_events = []
  end

  def update(event_type, source, data)
    @received_events << {event_type: event_type, source: source, data: data}
  end

  def event_count
    @received_events.size
  end

  def last_event
    @received_events.last
  end
end

# Observer that crashes for testing error handling
class CrashingObserver
  def update(event_type, source, data)
    raise StandardError, "Observer crashed!"
  end
end

RSpec.describe "ObservabilityEngine Integration", type: :integration do
  let(:observability_engine) { Agentic::ObservabilityEngine.new }

  before do
    # Reset global state
    Agentic.instance_variable_set(:@observability_engine, nil)
  end

  after do
    # Clean up after each test
    observability_engine.shutdown
  end

  describe "Event Notification Method Signature" do
    let(:observer) { TestObserver.new }

    before do
      observability_engine.add_local_observer(observer)
    end

    it "accepts event_type and data (2 parameters)" do
      expect {
        observability_engine.notify(:test_event, data: {message: "test"})
      }.not_to raise_error

      expect(observer.event_count).to eq(1)
      last_event = observer.last_event

      expect(last_event[:event_type]).to eq(:test_event)
      expect(last_event[:source]).to eq(observability_engine)
      expect(last_event[:data]).to include(
        type: :test_event,
        data: {message: "test"},
        source: "unknown"
      )
    end

    it "accepts event_type, source, and data (3 parameters)" do
      source_object = "test_source"

      expect {
        observability_engine.notify(:test_event, data: {message: "test"}, source: source_object)
      }.not_to raise_error

      expect(observer.event_count).to eq(1)
      last_event = observer.last_event

      expect(last_event[:event_type]).to eq(:test_event)
      expect(last_event[:source]).to eq(source_object)
      expect(last_event[:data]).to include(
        type: :test_event,
        data: {message: "test"},
        source: "String"
      )
    end

    it "handles nil source parameter correctly" do
      observability_engine.notify(:test_event, data: {message: "test"}, source: nil)

      expect(observer.event_count).to eq(1)
      last_event = observer.last_event

      expect(last_event[:event_type]).to eq(:test_event)
      expect(last_event[:source]).to eq(observability_engine)
      expect(last_event[:data]).to include(
        type: :test_event,
        data: {message: "test"},
        source: "unknown"
      )
    end
  end

  describe "Local Observer Management" do
    let(:observer1) { TestObserver.new }
    let(:observer2) { TestObserver.new }

    it "adds and removes local observers correctly" do
      expect(observability_engine.local_observers.size).to eq(0)

      observability_engine.add_local_observer(observer1)
      observability_engine.add_local_observer(observer2)
      expect(observability_engine.local_observers.size).to eq(2)

      observability_engine.notify(:test_event, data: {message: "broadcast"})

      expect(observer1.event_count).to eq(1)
      expect(observer2.event_count).to eq(1)

      observability_engine.remove_local_observer(observer1)
      expect(observability_engine.local_observers.size).to eq(1)

      observability_engine.notify(:second_event, data: {message: "after removal"})
      expect(observer1.event_count).to eq(1) # No new events
      expect(observer2.event_count).to eq(2) # Received new event
    end

    it "handles observer errors gracefully" do
      # Create an observer that will crash
      crashing_observer = CrashingObserver.new
      good_observer = TestObserver.new

      observability_engine.add_local_observer(good_observer)
      observability_engine.add_local_observer(crashing_observer)

      expect {
        observability_engine.notify(:error_test, data: {message: "test"})
      }.not_to raise_error

      # Good observer should still receive the event
      expect(good_observer.event_count).to eq(1)
    end
  end

  describe "Event Payload Structure" do
    let(:observer) { TestObserver.new }

    before do
      observability_engine.add_local_observer(observer)
    end

    it "creates properly structured event payloads" do
      test_data = {task_id: "test-123", status: "completed"}

      observability_engine.notify(:task_completed, data: test_data, source: "test_source")

      expect(observer.event_count).to eq(1)
      received_payload = observer.last_event[:data]

      expect(received_payload).to include(
        type: :task_completed,
        timestamp: match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/), # ISO8601 format
        source: "String",
        data: test_data
      )
    end

    it "passes complex nested data through to observers intact" do
      timestamp = Time.now
      complex_data = {
        timestamp: timestamp,
        symbols: [:success, :completed],
        nested: {level: 1, items: [1, 2, 3]}
      }

      observability_engine.notify(:complex_event, data: complex_data)

      expect(observer.event_count).to eq(1)
      received_payload = observer.last_event[:data]

      # The local observer path delivers event data unchanged (no lossy
      # serialization), preserving value types and nested structure.
      expect(received_payload[:data]).to eq(complex_data)
      expect(received_payload[:data][:symbols]).to eq([:success, :completed])
      expect(received_payload[:data][:timestamp]).to eq(timestamp)
      expect(received_payload[:data][:nested]).to eq({level: 1, items: [1, 2, 3]})
    end
  end

  describe "Statistics Tracking" do
    let(:observer) { TestObserver.new }

    it "tracks event processing statistics" do
      initial_stats = observability_engine.statistics

      observability_engine.notify(:stat_test_1, data: {message: "test 1"})
      observability_engine.notify(:stat_test_2, data: {message: "test 2"})

      updated_stats = observability_engine.statistics

      expect(updated_stats[:events_processed]).to eq(initial_stats[:events_processed] + 2)
      expect(updated_stats[:last_event_at]).not_to be_nil
      if initial_stats[:last_event_at]
        expect(updated_stats[:last_event_at]).to be > initial_stats[:last_event_at]
      end
    end

    it "tracks local notification statistics" do
      observability_engine.add_local_observer(observer)
      initial_stats = observability_engine.statistics

      observability_engine.notify(:local_stat_test, data: {message: "test"})

      updated_stats = observability_engine.statistics
      expect(updated_stats[:local_notifications]).to eq(initial_stats[:local_notifications] + 1)
      expect(observer.event_count).to eq(1)
    end
  end

  describe "Activity Status" do
    let(:observer) { TestObserver.new }

    it "reports inactive when no observers or adapters" do
      expect(observability_engine.active?).to be false
    end

    it "reports active with local observers" do
      observability_engine.add_local_observer(observer)

      expect(observability_engine.active?).to be true
    end
  end

  describe "Global Observability Engine" do
    let(:observer) { TestObserver.new }

    it "provides global singleton access" do
      engine1 = Agentic.observability_engine
      engine2 = Agentic.observability_engine

      expect(engine1).to be_a(Agentic::ObservabilityEngine)
      expect(engine1).to eq(engine2)
    end

    it "allows global event notification" do
      Agentic.observability_engine.add_local_observer(observer)
      Agentic.observability_engine.notify(:global_test, data: {message: "global event"})

      expect(observer.event_count).to eq(1)
      expect(observer.last_event[:event_type]).to eq(:global_test)
      expect(observer.last_event[:data][:data]).to eq({message: "global event"})
    end
  end

  describe "Error Handling and Resilience" do
    let(:good_observer) { TestObserver.new }

    it "continues processing when local observers fail" do
      bad_observer = CrashingObserver.new

      observability_engine.add_local_observer(good_observer)
      observability_engine.add_local_observer(bad_observer)

      expect {
        observability_engine.notify(:error_test, data: {message: "resilience test"})
      }.not_to raise_error

      expect(good_observer.event_count).to eq(1)
    end
  end

  describe "Shutdown and Cleanup" do
    let(:observer) { TestObserver.new }
    let(:temp_file) { Tempfile.new(["shutdown_events", ".jsonl"]) }
    let(:file_adapter) { Agentic::Observability::FileAdapter.new(log_path: temp_file.path) }

    after do
      temp_file.close
      temp_file.unlink
    end

    it "properly shuts down all components" do
      observability_engine.add_local_observer(observer)
      observability_engine.add_adapter(file_adapter)

      expect(observability_engine.active?).to be true

      observability_engine.shutdown

      expect(observability_engine.local_observers).to be_empty
      expect(observability_engine.all_adapters).to be_empty
      expect(observability_engine.active?).to be false
    end
  end

  describe "Integration with Real Components" do
    let(:observer) { TestObserver.new }
    let(:temp_file) { Tempfile.new(["integration_events", ".jsonl"]) }
    let(:file_adapter) { Agentic::Observability::FileAdapter.new(log_path: temp_file.path) }

    after do
      temp_file.close
      temp_file.unlink
    end

    it "coordinates local observers and adapters together" do
      # Set up full observability stack: in-process observer + file adapter
      observability_engine.add_local_observer(observer)
      observability_engine.add_adapter(file_adapter)

      # Send events
      observability_engine.notify(:task_started, data: {task_id: "task-123"}, source: "test_task")
      observability_engine.notify(:task_progress, data: {progress: 50}, source: "test_task")
      observability_engine.notify(:task_completed, data: {result: "success"}, source: "test_task")

      # Verify local observer received all events
      expect(observer.event_count).to eq(3)

      # Verify event types
      event_types = observer.received_events.map { |e| e[:event_type] }
      expect(event_types).to eq([:task_started, :task_progress, :task_completed])

      # Verify the file adapter persisted the events
      expect(file_adapter.file_statistics[:total_events]).to eq(3)

      # Verify statistics
      stats = observability_engine.statistics
      expect(stats[:events_processed]).to eq(3)
      expect(stats[:local_notifications]).to eq(3)
    end
  end
end
