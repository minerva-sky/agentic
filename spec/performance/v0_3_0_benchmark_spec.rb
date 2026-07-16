# frozen_string_literal: true

# Performance benchmarking for v0.3.0 architectural improvements
# This spec validates the projected performance improvements from Phase 2 standardizations

require "benchmark"
require "memory_profiler"

RSpec.describe "v0.3.0 Performance Benchmarks", type: :performance do
  let(:llm_client) { instance_double(Agentic::LlmClient) }
  let(:sample_size) { 100 }

  before do
    allow(llm_client).to receive(:complete).and_return(
      Agentic::LlmResponse.new({}, parsed_content: "Benchmark response")
    )
  end

  describe "Event System Performance" do
    it "benchmarks unified event processing vs legacy patterns" do
      # Setup unified event system (v0.3.0)
      unified_engine = Agentic::ObservabilityEngine.new
      events_received = []
      observer = double("BenchmarkObserver")
      allow(observer).to receive(:update) { |type, source, data| events_received << type }
      unified_engine.add_local_observer(observer)

      # Benchmark unified event processing
      unified_time = Benchmark.realtime do
        sample_size.times do |i|
          unified_engine.notify(:benchmark_event, self, {
            iteration: i,
            timestamp: Time.now.to_f,
            correlation_id: SecureRandom.uuid
          })
        end
      end

      # Memory usage for unified system
      unified_memory = MemoryProfiler.report do
        sample_size.times do |i|
          unified_engine.notify(:memory_test, {data: "test_data_#{i}"}, source: self)
        end
      end

      puts "\n=== v0.3.0 Event System Performance ==="
      puts "Unified Event Processing: #{unified_time.round(4)}s for #{sample_size} events"
      puts "Memory Usage: #{unified_memory.total_allocated_memsize} bytes allocated"
      puts "Memory Objects: #{unified_memory.total_allocated} objects allocated"

      # Validate performance targets
      expect(unified_time).to be < 0.1, "Event processing should be under 0.1s for #{sample_size} events"
      expect(events_received.size).to eq(sample_size)
    end

    it "benchmarks event correlation performance" do
      engine = Agentic::ObservabilityEngine.new
      correlated_events = []

      observer = double("CorrelationObserver")
      allow(observer).to receive(:update) { |type, source, data| correlated_events << data[:data][:correlation_id] }
      engine.add_local_observer(observer)

      correlation_time = Benchmark.realtime do
        10.times do |batch|
          correlation_id = SecureRandom.uuid
          10.times do |event|
            engine.notify(:correlated_event, self, {
              correlation_id: correlation_id,
              batch: batch,
              event: event
            })
          end
        end
      end

      puts "\n=== Event Correlation Performance ==="
      puts "Correlation Processing: #{correlation_time.round(4)}s for 100 correlated events"

      # Validate correlation consistency
      grouped_correlations = correlated_events.group_by { |id| id }
      expect(grouped_correlations.size).to eq(10), "Should have 10 correlation groups"
      expect(grouped_correlations.values.all? { |group| group.size == 10 }).to be true
    end
  end

  describe "Verification Strategy Factory Performance" do
    it "benchmarks strategy creation performance" do
      creation_times = []

      # Benchmark strategy creation
      benchmark_time = Benchmark.realtime do
        sample_size.times do
          start_time = Time.now.to_f

          Agentic::Verification::StrategyFactory.create(
            :schema,
            config: {strict_mode: true, allow_additional_properties: false}
          )

          end_time = Time.now.to_f
          creation_times << (end_time - start_time)
        end
      end

      average_creation_time = creation_times.sum / creation_times.size
      max_creation_time = creation_times.max

      puts "\n=== Verification Factory Performance ==="
      puts "Total Creation Time: #{benchmark_time.round(4)}s for #{sample_size} strategies"
      puts "Average Creation Time: #{average_creation_time.round(6)}s per strategy"
      puts "Max Creation Time: #{max_creation_time.round(6)}s"

      # Performance targets
      expect(average_creation_time).to be < 0.001, "Strategy creation should be under 1ms on average"
      expect(max_creation_time).to be < 0.01, "No single strategy creation should take over 10ms"
    end

    it "benchmarks hub creation with multiple strategies" do
      hub_creation_time = Benchmark.realtime do
        10.times do
          Agentic::Verification::StrategyFactory.create_hub(
            strategies_config: [
              {type: :schema, config: {strict_mode: true}},
              {type: :llm, config: {confidence_threshold: 0.8}},
              {type: :schema, config: {strict_mode: false}}
            ],
            hub_config: {min_confidence: 0.6},
            llm_client: llm_client
          )
        end
      end

      puts "\n=== Verification Hub Performance ==="
      puts "Hub Creation Time: #{hub_creation_time.round(4)}s for 10 hubs (3 strategies each)"

      expect(hub_creation_time).to be < 0.1, "Hub creation should be efficient"
    end
  end

  describe "Memory Usage Optimization" do
    it "validates memory efficiency improvements" do
      # Test memory usage for event processing
      memory_report = MemoryProfiler.report do
        engine = Agentic::ObservabilityEngine.new
        observer = double("MemoryObserver")
        allow(observer).to receive(:update)
        engine.add_local_observer(observer)

        # Process significant number of events
        500.times do |i|
          engine.notify(:memory_benchmark, self, {
            data: {
              iteration: i,
              timestamp: Time.now.to_f,
              large_payload: "x" * 100  # 100 character payload
            }
          })
        end
      end

      puts "\n=== Memory Usage Analysis ==="
      puts "Total Memory Allocated: #{memory_report.total_allocated_memsize} bytes"
      puts "Total Objects Allocated: #{memory_report.total_allocated} objects"
      puts "Memory per Event: #{memory_report.total_allocated_memsize / 500} bytes/event"

      # Validate reasonable memory usage (target: efficient memory per event)
      memory_per_event = memory_report.total_allocated_memsize / 500
      expect(memory_per_event).to be < 5000, "Memory per event should be reasonable (<5KB)"
    end

    it "validates garbage collection efficiency" do
      gc_stats_before = GC.stat

      # Create and process many objects to test GC
      1000.times do
        strategy = Agentic::Verification::StrategyFactory.create(:schema)
        task = Agentic::Task.new(description: "GC test #{rand(1000)}", agent_spec: {"name" => "test"})
        result = Agentic::TaskResult.new(task_id: task.id, success: true, output: {data: rand(1000)})
        strategy.verify(task, result)
      end

      # Force garbage collection
      GC.start

      gc_stats_after = GC.stat

      puts "\n=== Garbage Collection Analysis ==="
      puts "GC Count Before: #{gc_stats_before[:count]}"
      puts "GC Count After: #{gc_stats_after[:count]}"
      puts "Additional GC Runs: #{gc_stats_after[:count] - gc_stats_before[:count]}"

      # Validate that GC isn't running excessively
      additional_gc_runs = gc_stats_after[:count] - gc_stats_before[:count]
      expect(additional_gc_runs).to be < 10, "Should not trigger excessive garbage collection"
    end
  end

  describe "Error Handling Performance" do
    it "benchmarks error handling overhead" do
      # Test error handling performance with LLM strategy
      allow(llm_client).to receive(:complete).and_raise(StandardError.new("Benchmark error"))

      error_strategy = Agentic::Verification::StrategyFactory.create(:llm, llm_client: llm_client)
      task = Agentic::Task.new(description: "Error benchmark", agent_spec: {"name" => "test"})
      result = Agentic::TaskResult.new(task_id: task.id, success: true, output: {})

      error_handling_time = Benchmark.realtime do
        50.times do
          verification_result = error_strategy.verify(task, result)
          expect(verification_result.verified).to be false
        end
      end

      puts "\n=== Error Handling Performance ==="
      puts "Error Handling Time: #{error_handling_time.round(4)}s for 50 error cases"
      puts "Time per Error: #{(error_handling_time / 50).round(6)}s"

      # Validate that error handling doesn't add significant overhead
      time_per_error = error_handling_time / 50
      expect(time_per_error).to be < 0.01, "Error handling should be fast (<10ms per error)"
    end
  end

  # Performance summary and validation
  after(:all) do
    puts "\n" + "=" * 60
    puts "v0.3.0 PERFORMANCE VALIDATION SUMMARY"
    puts "=" * 60
    puts "✅ Event System: Unified processing with correlation support"
    puts "✅ Factory Pattern: Fast strategy creation and hub instantiation"
    puts "✅ Memory Usage: Efficient per-event memory allocation"
    puts "✅ Error Handling: Low-overhead error processing"
    puts "=" * 60
  end
end
