# frozen_string_literal: true

RSpec.describe "Component Performance", :slow, type: :performance do
  describe "Startup Time Benchmarks" do
    it "loads core components efficiently" do
      start_time = Time.now

      require_relative "../../lib/agentic"

      load_time = Time.now - start_time

      # Should load in under 1 second
      expect(load_time).to be < 1.0
      puts "Core library load time: #{(load_time * 1000).round(2)}ms"
    end

    it "initializes ObservabilityEngine quickly" do
      start_time = Time.now

      _engine = Agentic::ObservabilityEngine.new

      init_time = Time.now - start_time

      # Should initialize in under 100ms
      expect(init_time).to be < 0.1
      puts "ObservabilityEngine init time: #{(init_time * 1000).round(2)}ms"
    end

    it "creates verification strategies efficiently" do
      start_time = Time.now

      10.times do
        Agentic::Verification::StrategyFactory.create(:schema, config: {strict_mode: false})
      end

      creation_time = Time.now - start_time
      avg_time = creation_time / 10

      # Should create each strategy in under 10ms
      expect(avg_time).to be < 0.01
      puts "Average strategy creation time: #{(avg_time * 1000).round(2)}ms"
    end
  end

  describe "Memory Usage Benchmarks" do
    it "maintains reasonable memory usage during event processing" do
      engine = Agentic::ObservabilityEngine.new
      observer = double("Observer")
      allow(observer).to receive(:update)

      engine.add_local_observer(observer)

      # Measure memory before
      GC.start
      memory_before = `ps -o rss= -p #{Process.pid}`.to_i

      # Process many events
      1000.times do |i|
        engine.notify(:test_event, data: {iteration: i, data: "x" * 100}, source: self)
      end

      # Measure memory after
      GC.start
      memory_after = `ps -o rss= -p #{Process.pid}`.to_i
      memory_increase = memory_after - memory_before

      # Should not increase memory by more than 10MB for 1000 events
      expect(memory_increase).to be < 10_000
      puts "Memory increase for 1000 events: #{memory_increase}KB"
    end

    it "cleans up observers properly to prevent memory leaks" do
      engine = Agentic::ObservabilityEngine.new

      # Add many observers
      observers = 100.times.map do
        observer = double("Observer")
        allow(observer).to receive(:update)
        engine.add_local_observer(observer)
        observer
      end

      expect(engine.local_observers.size).to eq(100)

      # Remove all observers
      observers.each { |observer| engine.remove_local_observer(observer) }

      expect(engine.local_observers.size).to eq(0)

      # Force garbage collection
      observers.clear
      GC.start

      # Memory should be recoverable
      expect(engine.local_observers.size).to eq(0)
    end
  end

  describe "Event Processing Performance" do
    let(:engine) { Agentic::ObservabilityEngine.new }

    it "processes events efficiently with multiple observers" do
      observers = 10.times.map do
        observer = double("Observer")
        allow(observer).to receive(:update)
        engine.add_local_observer(observer)
        observer
      end

      start_time = Time.now

      100.times do |i|
        engine.notify(:performance_test, data: {iteration: i}, source: self)
      end

      processing_time = Time.now - start_time
      events_per_second = 100 / processing_time

      # Should process at least 1000 events per second with 10 observers
      expect(events_per_second).to be > 1000
      puts "Event processing rate: #{events_per_second.round(0)} events/second"

      # Verify all observers received all events
      observers.each do |observer|
        expect(observer).to have_received(:update).exactly(100).times
      end
    end

    it "handles concurrent event processing efficiently" do
      observer = double("Observer")
      allow(observer).to receive(:update)
      engine.add_local_observer(observer)

      start_time = Time.now

      threads = 5.times.map do |thread_id|
        Thread.new do
          20.times do |i|
            engine.notify(:concurrent_test, data: {thread: thread_id, iteration: i}, source: self)
          end
        end
      end

      threads.each(&:join)

      processing_time = Time.now - start_time

      # Should handle 100 concurrent events in under 1 second
      expect(processing_time).to be < 1.0
      puts "Concurrent processing time: #{(processing_time * 1000).round(2)}ms for 100 events"

      # Verify all events were processed
      expect(observer).to have_received(:update).exactly(100).times
    end
  end

  describe "Verification Strategy Performance" do
    let(:llm_client) { instance_double(Agentic::LlmClient) }

    before do
      allow(llm_client).to receive(:complete).and_return(
        Agentic::LlmResponse.new({}, parsed_content: "Valid")
      )
    end

    it "creates verification hubs efficiently" do
      start_time = Time.now

      10.times do
        Agentic::Verification::StrategyFactory.create_hub(
          strategies_config: [
            {type: :schema, config: {strict_mode: false}},
            {type: :llm, config: {confidence_threshold: 0.7}}
          ],
          llm_client: llm_client
        )
      end

      creation_time = Time.now - start_time
      avg_time = creation_time / 10

      # Should create hub in under 20ms
      expect(avg_time).to be < 0.02
      puts "Average verification hub creation time: #{(avg_time * 1000).round(2)}ms"
    end

    it "processes schema verification efficiently" do
      strategy = Agentic::Verification::StrategyFactory.create(:schema)

      task = Agentic::Task.new(
        description: "Performance test task",
        agent_spec: {type: "test_agent"}
      )

      result = Agentic::TaskResult.new(
        task_id: task.id,
        success: true,
        output: {message: "Test completed"}
      )

      start_time = Time.now

      100.times do
        verification_result = strategy.verify(task, result)
        expect(verification_result.verified).to be true
      end

      verification_time = Time.now - start_time
      avg_time = verification_time / 100

      # Should verify in under 5ms each
      expect(avg_time).to be < 0.005
      puts "Average schema verification time: #{(avg_time * 1000).round(2)}ms"
    end
  end
end
