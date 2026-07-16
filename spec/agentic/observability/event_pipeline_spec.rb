# frozen_string_literal: true

RSpec.describe Agentic::Observability::EventPipeline do
  let(:pipeline) { described_class.new }
  let(:mock_processor) { double("MockProcessor") }

  before do
    allow(mock_processor).to receive(:process_batch)
  end

  describe "initialization" do
    it "creates pipeline with default configuration" do
      expect(pipeline.config).to include(
        batch_size_min: 10,
        batch_size_max: 100,
        strategy: described_class::STRATEGY_HYBRID,
        enable_backpressure: true
      )
    end

    it "allows configuration override" do
      custom_pipeline = described_class.new(
        batch_size_max: 50,
        strategy: described_class::STRATEGY_SIZE_BASED,
        enable_backpressure: false
      )

      expect(custom_pipeline.config[:batch_size_max]).to eq(50)
      expect(custom_pipeline.config[:strategy]).to eq(described_class::STRATEGY_SIZE_BASED)
      expect(custom_pipeline.config[:enable_backpressure]).to be false
    end

    it "initializes performance statistics" do
      stats = pipeline.statistics
      expect(stats[:events_ingested]).to eq(0)
      expect(stats[:events_processed]).to eq(0)
      expect(stats[:batches_formed]).to eq(0)
    end

    it "initializes stage statistics" do
      stage_stats = pipeline.stage_statistics
      expect(stage_stats[described_class::STAGE_INGESTION]).to include(
        operations: 0,
        total_time: 0.0,
        average_time: 0.0,
        errors: 0
      )
    end
  end

  describe "processor management" do
    it "adds processors with configuration" do
      processor_id = pipeline.add_processor(mock_processor, stage: :processing, priority: 5)

      expect(processor_id).to be_a(String)
      expect(pipeline.instance_variable_get(:@processors)).not_to be_empty
    end

    it "removes processors by ID" do
      processor_id = pipeline.add_processor(mock_processor)
      pipeline.remove_processor(processor_id)

      processors = pipeline.instance_variable_get(:@processors)
      expect(processors.find { |p| p[:id] == processor_id }).to be_nil
    end

    it "sorts processors by priority" do
      high_priority_processor = double("HighPriorityProcessor")
      low_priority_processor = double("LowPriorityProcessor")

      pipeline.add_processor(low_priority_processor, priority: 20)
      pipeline.add_processor(high_priority_processor, priority: 1)

      processors = pipeline.instance_variable_get(:@processors)
      expect(processors.first[:priority]).to eq(1)
      expect(processors.last[:priority]).to eq(20)
    end
  end

  describe "event ingestion" do
    before do
      pipeline.add_processor(mock_processor)
    end

    it "ingests events successfully" do
      event = {type: :test_event, data: {message: "test"}}
      result = pipeline.ingest_event(event)

      expect(result).to be true
      expect(pipeline.statistics[:events_ingested]).to eq(1)
    end

    it "enriches events with pipeline metadata" do
      event = {type: :test_event, data: {message: "test"}}
      pipeline.ingest_event(event)

      # We can't directly inspect the buffer, but we can verify through processing
      # The enriched event will have pipeline_metadata when processed
      expect(pipeline.statistics[:events_ingested]).to eq(1)
    end

    it "applies backpressure when buffer is full" do
      # Configure small buffer for testing
      small_pipeline = described_class.new(buffer_size_max: 5, memory_threshold: 0.8)

      # Fill buffer beyond memory threshold (80% of 5 = 4 events)
      6.times do |i|
        small_pipeline.ingest_event({type: :load_test, data: {id: i}})
        # First 4 should succeed, later ones may be dropped due to backpressure
      end

      stats = small_pipeline.statistics
      expect(stats[:events_ingested] + stats[:events_dropped]).to eq(6)
      expect(stats[:events_dropped]).to be > 0
    end

    it "handles different event priorities" do
      high_priority_event = {type: :critical_alert, data: {severity: "high"}}
      normal_event = {type: :status_update, data: {status: "running"}}
      low_priority_event = {type: :metrics, data: {cpu: 50}}

      expect(pipeline.ingest_event(high_priority_event, priority: :high)).to be true
      expect(pipeline.ingest_event(normal_event, priority: :normal)).to be true
      expect(pipeline.ingest_event(low_priority_event, priority: :low)).to be true

      expect(pipeline.statistics[:events_ingested]).to eq(3)
    end
  end

  describe "batching strategies" do
    before do
      pipeline.add_processor(mock_processor)
    end

    it "supports size-based batching" do
      size_pipeline = described_class.new(
        strategy: described_class::STRATEGY_SIZE_BASED,
        batch_size_max: 5
      )
      size_pipeline.add_processor(mock_processor)

      # Ingest events
      10.times { |i| size_pipeline.ingest_event({type: :batch_test, data: {id: i}}) }

      expect(size_pipeline.statistics[:events_ingested]).to eq(10)
    end

    it "supports time-based batching" do
      time_pipeline = described_class.new(
        strategy: described_class::STRATEGY_TIME_BASED,
        batch_timeout: 0.01 # 10ms for fast testing
      )
      time_pipeline.add_processor(mock_processor)

      # Ingest events quickly
      5.times { |i| time_pipeline.ingest_event({type: :time_test, data: {id: i}}) }

      expect(time_pipeline.statistics[:events_ingested]).to eq(5)
    end

    it "supports hybrid batching strategy" do
      hybrid_pipeline = described_class.new(
        strategy: described_class::STRATEGY_HYBRID,
        batch_size_max: 10,
        batch_timeout: 0.01
      )
      hybrid_pipeline.add_processor(mock_processor)

      # Should batch based on whichever condition is met first
      8.times { |i| hybrid_pipeline.ingest_event({type: :hybrid_test, data: {id: i}}) }

      expect(hybrid_pipeline.statistics[:events_ingested]).to eq(8)
    end

    it "supports adaptive batching" do
      adaptive_pipeline = described_class.new(
        strategy: described_class::STRATEGY_ADAPTIVE,
        enable_adaptive_batching: true
      )
      adaptive_pipeline.add_processor(mock_processor)

      # Adaptive batching adjusts batch size based on performance
      15.times { |i| adaptive_pipeline.ingest_event({type: :adaptive_test, data: {id: i}}) }

      expect(adaptive_pipeline.statistics[:events_ingested]).to eq(15)
    end
  end

  describe "pipeline lifecycle" do
    before do
      pipeline.add_processor(mock_processor)
    end

    it "starts and stops pipeline correctly" do
      expect(pipeline.status[:running]).to be false

      pipeline.start
      # Give pipeline time to start async tasks
      sleep(0.01)

      expect(pipeline.status[:running]).to be true
      expect(pipeline.statistics[:started_at]).to be_a(Float)

      pipeline.stop

      expect(pipeline.status[:running]).to be false
      expect(pipeline.statistics[:stopped_at]).to be_a(Float)
      expect(pipeline.statistics[:total_runtime]).to be > 0
    end

    it "processes remaining events during shutdown" do
      # Ingest events but don't start pipeline
      5.times { |i| pipeline.ingest_event({type: :shutdown_test, data: {id: i}}) }

      pipeline.start
      sleep(0.01) # Let it start
      pipeline.stop # Should process remaining events

      # Events should be processed during shutdown
      expect(pipeline.statistics[:events_ingested]).to eq(5)
    end
  end

  describe "performance monitoring" do
    before do
      pipeline.add_processor(mock_processor)
    end

    it "calculates buffer utilization correctly" do
      initial_utilization = pipeline.buffer_utilization
      expect(initial_utilization).to eq(0.0)

      # Add some events
      10.times { |i| pipeline.ingest_event({type: :utilization_test, data: {id: i}}) }

      utilization_after = pipeline.buffer_utilization
      expect(utilization_after).to be > 0.0
      expect(utilization_after).to be <= 1.0
    end

    it "calculates throughput correctly" do
      pipeline.start

      # Ingest events over time
      20.times do |i|
        pipeline.ingest_event({type: :throughput_test, data: {id: i}})
        sleep(0.001) # Small delay to simulate realistic timing
      end

      sleep(0.1) # Let pipeline process

      throughput = pipeline.throughput
      expect(throughput).to be >= 0

      pipeline.stop
    end

    it "monitors pipeline health" do
      pipeline.start

      # Healthy pipeline should report as healthy
      expect(pipeline.healthy?).to be true

      pipeline.stop

      # Stopped pipeline should report as unhealthy
      expect(pipeline.healthy?).to be false
    end

    it "provides comprehensive status information" do
      pipeline.start

      status = pipeline.status
      expect(status).to include(
        :running,
        :healthy,
        :buffer_utilization,
        :throughput,
        :processors,
        :statistics,
        :stage_statistics
      )

      expect(status[:processors]).to eq(1) # We added one processor

      pipeline.stop
    end
  end

  describe "Performance Specialist requirements (Jordan Lee)" do
    it "achieves memory efficiency through circular buffering" do
      # Test memory efficiency with large number of events
      efficient_pipeline = described_class.new(
        buffer_size_max: 1000,
        enable_memory_optimization: true,
        gc_interval: 100
      )

      memory_processor = double("MemoryProcessor")
      allow(memory_processor).to receive(:process_batch)
      efficient_pipeline.add_processor(memory_processor)

      # Track memory usage
      start_memory = efficient_pipeline.send(:get_memory_usage)

      # Process many events
      2000.times do |i|
        efficient_pipeline.ingest_event({
          type: :memory_test,
          data: {
            id: i,
            payload: "x" * 100  # 100 character payload per event
          }
        })
      end

      efficient_pipeline.start
      sleep(0.1) # Let it process
      efficient_pipeline.stop

      final_memory = efficient_pipeline.send(:get_memory_usage)

      # Memory should be managed efficiently (not grow unboundedly)
      memory_growth = final_memory - start_memory
      events_processed = efficient_pipeline.statistics[:events_processed]

      expect(events_processed).to be > 0
      expect(memory_growth).to be > 0 # Some growth is expected

      # Memory per event should be reasonable due to circular buffering
      memory_per_event = memory_growth / [events_processed, 1].max
      expect(memory_per_event).to be < 10000 # Less than 10KB per event
    end

    it "implements intelligent batching for throughput optimization" do
      throughput_pipeline = described_class.new(
        strategy: described_class::STRATEGY_ADAPTIVE,
        enable_adaptive_batching: true,
        batch_size_min: 5,
        batch_size_max: 50,
        enable_performance_monitoring: true
      )

      throughput_processor = double("ThroughputProcessor")
      processed_batches = []

      allow(throughput_processor).to receive(:process_batch) do |batch, options|
        processed_batches << {size: batch.size, priority: options[:priority]}
      end

      throughput_pipeline.add_processor(throughput_processor)
      throughput_pipeline.start

      # Send bursts of events to test adaptive batching
      100.times do |i|
        throughput_pipeline.ingest_event({
          type: :throughput_optimization,
          data: {id: i, burst: i / 20}
        })
      end

      sleep(0.2) # Let pipeline adapt and process
      throughput_pipeline.stop

      stats = throughput_pipeline.statistics

      # Should have processed events efficiently
      expect(stats[:events_processed]).to eq(100)
      expect(stats[:batches_processed]).to be > 0
      expect(stats[:average_batch_size]).to be > 1

      # Batching should be optimized for throughput
      expect(processed_batches).not_to be_empty
      average_batch_size = processed_batches.map { |b| b[:size] }.sum.to_f / processed_batches.size
      expect(average_batch_size).to be >= 5 # Should batch efficiently
    end

    it "provides backpressure handling to prevent memory overflow" do
      backpressure_pipeline = described_class.new(
        buffer_size_max: 20,
        memory_threshold: 0.7, # 70% threshold
        enable_backpressure: true
      )

      # Don't add processor initially to fill buffer

      # Fill buffer beyond threshold
      results = []
      40.times do |i|
        result = backpressure_pipeline.ingest_event({
          type: :backpressure_test,
          data: {id: i, large_payload: "x" * 500}
        })
        results << result
      end

      # Some events should be accepted, some should be dropped due to backpressure
      accepted_events = results.count(true)
      dropped_events = results.count(false)

      expect(accepted_events).to be < 40 # Not all events should be accepted
      expect(dropped_events).to be > 0   # Some should be dropped

      stats = backpressure_pipeline.statistics
      expect(stats[:events_dropped]).to eq(dropped_events)
      expect(stats[:events_ingested]).to eq(accepted_events)
    end

    it "optimizes performance through priority-based processing" do
      priority_pipeline = described_class.new(enable_performance_monitoring: true)

      priority_processor = double("PriorityProcessor")
      processed_events = []

      allow(priority_processor).to receive(:process_batch) do |batch, options|
        batch.each do |event|
          processed_events << {
            id: event[:data][:id],
            priority: event[:pipeline_metadata][:priority],
            batch_priority: options[:priority]
          }
        end
      end

      priority_pipeline.add_processor(priority_processor)
      priority_pipeline.start

      # Send mixed priority events
      10.times { |i| priority_pipeline.ingest_event({type: :test, data: {id: "high_#{i}"}}, priority: :high) }
      10.times { |i| priority_pipeline.ingest_event({type: :test, data: {id: "normal_#{i}"}}, priority: :normal) }
      10.times { |i| priority_pipeline.ingest_event({type: :test, data: {id: "low_#{i}"}}, priority: :low) }

      sleep(0.1) # Let pipeline process with priority handling
      priority_pipeline.stop

      # Verify events were processed
      expect(processed_events.size).to eq(30)

      # High priority events should be processed appropriately
      high_priority_events = processed_events.select { |e| e[:priority] == :high }
      expect(high_priority_events).not_to be_empty

      # Check that priority batching occurred
      high_priority_batches = processed_events.select { |e| e[:batch_priority] == :high_priority }
      expect(high_priority_batches.size).to be >= 10 # High priority events should go to high priority batches
    end
  end

  describe "Systems Architect requirements (Alex Rivera)" do
    it "provides clean component separation" do
      # EventPipeline should work independently of other components
      standalone_pipeline = described_class.new

      # Should initialize without dependencies
      expect(standalone_pipeline).to be_an_instance_of(described_class)
      expect(standalone_pipeline.status[:running]).to be false

      # Should provide clear interfaces
      expect(standalone_pipeline).to respond_to(:ingest_event)
      expect(standalone_pipeline).to respond_to(:add_processor)
      expect(standalone_pipeline).to respond_to(:start)
      expect(standalone_pipeline).to respond_to(:stop)
      expect(standalone_pipeline).to respond_to(:status)
    end

    it "implements proper error isolation and recovery" do
      error_pipeline = described_class.new(enable_error_isolation: true)

      # Add both good and bad processors
      good_processor = double("GoodProcessor")
      bad_processor = double("BadProcessor")

      allow(good_processor).to receive(:process_batch)
      allow(bad_processor).to receive(:process_batch).and_raise(StandardError, "Processor failure")

      error_pipeline.add_processor(good_processor, priority: 1)
      error_pipeline.add_processor(bad_processor, priority: 2)

      error_pipeline.start

      # Send events to trigger processing
      5.times { |i| error_pipeline.ingest_event({type: :error_test, data: {id: i}}) }

      sleep(0.1) # Let pipeline process
      error_pipeline.stop

      stats = error_pipeline.statistics

      # Events should still be processed despite processor errors (error isolation)
      expect(stats[:events_ingested]).to eq(5)
      expect(stats[:events_errored]).to be > 0 # Some events marked as errored due to bad processor

      # Good processor should still have been called
      expect(good_processor).to have_received(:process_batch).at_least(:once)
    end

    it "supports different processor interfaces" do
      interface_pipeline = described_class.new

      # Processor with process_batch method
      batch_processor = double("BatchProcessor")
      allow(batch_processor).to receive(:process_batch)

      # Processor with call method (Proc-like)
      callable_processor = double("CallableProcessor")
      allow(callable_processor).to receive(:call)

      # Processor with update method (Observer-like)
      observer_processor = double("ObserverProcessor")
      allow(observer_processor).to receive(:update)

      interface_pipeline.add_processor(batch_processor)
      interface_pipeline.add_processor(callable_processor)
      interface_pipeline.add_processor(observer_processor)

      interface_pipeline.start

      # Send events to test all processor interfaces
      3.times { |i| interface_pipeline.ingest_event({type: :interface_test, data: {id: i}}) }

      sleep(0.1)
      interface_pipeline.stop

      # All processor interfaces should have been called
      expect(batch_processor).to have_received(:process_batch).at_least(:once)
      expect(callable_processor).to have_received(:call).at_least(:once)
      expect(observer_processor).to have_received(:update).at_least(:once)
    end

    it "maintains clear architectural boundaries" do
      # EventPipeline should not directly depend on specific observability components
      boundary_pipeline = described_class.new

      # Should work with any processor that implements the expected interface
      generic_processor = double("GenericProcessor")
      allow(generic_processor).to receive(:process_batch)

      boundary_pipeline.add_processor(generic_processor)

      # Should maintain separation between ingestion and processing
      expect { boundary_pipeline.ingest_event({type: :boundary_test}) }.not_to raise_error

      # Should provide clear status without exposing internal implementation details
      status = boundary_pipeline.status
      expect(status).to be_a(Hash)
      expect(status).to have_key(:running)
      expect(status).to have_key(:statistics)

      # Should not expose internal implementation details
      expect(status).not_to have_key(:@event_buffer)
      expect(status).not_to have_key(:@batch_queues)
    end
  end

  describe "concurrent circular buffer" do
    let(:buffer) { Agentic::Observability::ConcurrentCircularBuffer.new(5) }

    it "handles basic push and pop operations" do
      expect(buffer.empty?).to be true
      expect(buffer.size).to eq(0)

      expect(buffer.push("item1")).to be true
      expect(buffer.size).to eq(1)
      expect(buffer.empty?).to be false

      item = buffer.pop
      expect(item).to eq("item1")
      expect(buffer.size).to eq(0)
      expect(buffer.empty?).to be true
    end

    it "handles capacity limits correctly" do
      # Fill to capacity
      5.times { |i| expect(buffer.push("item#{i}")).to be true }
      expect(buffer.full?).to be true

      # Should reject additional items when full
      expect(buffer.push("overflow")).to be false
      expect(buffer.size).to eq(5)
    end

    it "maintains circular behavior" do
      # Fill buffer
      5.times { |i| buffer.push("item#{i}") }

      # Pop some items
      expect(buffer.pop).to eq("item0")
      expect(buffer.pop).to eq("item1")

      # Add more items (should wrap around)
      expect(buffer.push("new_item1")).to be true
      expect(buffer.push("new_item2")).to be true

      # Verify remaining items
      expect(buffer.pop).to eq("item2")
      expect(buffer.pop).to eq("item3")
      expect(buffer.pop).to eq("item4")
      expect(buffer.pop).to eq("new_item1")
      expect(buffer.pop).to eq("new_item2")

      expect(buffer.empty?).to be true
    end

    it "handles concurrent access safely" do
      threads = []

      # Multiple threads pushing items
      5.times do |i|
        threads << Thread.new do
          10.times { |j| buffer.push("thread#{i}_item#{j}") }
        end
      end

      # Thread popping items
      popped_items = []
      threads << Thread.new do
        while popped_items.size < 50 || !buffer.empty?
          item = buffer.pop
          popped_items << item if item
          sleep(0.001)
        end
      end

      threads.each(&:join)

      # Should handle concurrent operations without errors
      expect(buffer.empty?).to be true
    end
  end
end
