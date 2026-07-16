# frozen_string_literal: true

require "concurrent"

module Agentic
  module Observability
    # EventPipeline provides high-performance event processing through intelligent batching,
    # memory-efficient buffering, and backpressure handling. Designed to achieve the
    # projected 30-50% memory reduction and 20-40% latency improvement.
    #
    # Design Goals:
    # 1. Memory efficiency through circular buffers and intelligent batching
    # 2. Backpressure handling to prevent memory overflow
    # 3. Configurable batching strategies for different event patterns
    # 4. Performance monitoring and adaptive optimization
    # 5. Error isolation and recovery mechanisms
    #
    # Architect Team Guidance:
    # - Jordan Lee (Performance Specialist): Intelligent batching and memory optimization
    # - Alex Rivera (Systems Architect): Clean component separation and error isolation
    class EventPipeline
      # Batch processing strategies
      STRATEGY_TIME_BASED = :time_based      # Batch by time intervals
      STRATEGY_SIZE_BASED = :size_based      # Batch by buffer size
      STRATEGY_ADAPTIVE = :adaptive          # Adapt strategy based on event patterns
      STRATEGY_HYBRID = :hybrid              # Combine time and size-based batching

      # Pipeline stages
      STAGE_INGESTION = :ingestion          # Event ingestion and initial buffering
      STAGE_BATCHING = :batching            # Intelligent batch formation
      STAGE_PROCESSING = :processing        # Batch processing and delivery
      STAGE_CLEANUP = :cleanup              # Memory cleanup and optimization

      # Default configuration optimized for performance
      DEFAULT_CONFIG = {
        # Batching configuration
        batch_size_min: 10,                 # Minimum batch size
        batch_size_max: 100,                # Maximum batch size
        batch_timeout: 0.05,                # 50ms batch timeout
        strategy: STRATEGY_HYBRID,          # Default to hybrid strategy

        # Memory management
        buffer_size_max: 10000,             # Maximum buffer size before backpressure
        memory_threshold: 0.8,              # Memory threshold for backpressure (80%)
        gc_interval: 1000,                  # Events between garbage collection hints

        # Performance optimization
        enable_backpressure: true,          # Enable backpressure handling
        enable_adaptive_batching: true,     # Enable adaptive batch sizing
        enable_performance_monitoring: true, # Enable performance metrics
        enable_memory_optimization: true,    # Enable memory optimization features

        # Error handling
        max_retries: 3,                     # Maximum retry attempts for failed batches
        error_backoff_base: 0.1,            # Base backoff time for retries (seconds)
        enable_error_isolation: true        # Isolate errors to prevent cascade failures
      }.freeze

      attr_reader :config, :statistics, :stage_statistics

      def initialize(config = {})
        @config = DEFAULT_CONFIG.merge(config)
        @running = false
        @processors = []
        @worker_threads = []

        # Circular buffer for memory efficiency
        @event_buffer = create_circular_buffer(@config[:buffer_size_max])
        @buffer_mutex = Mutex.new
        @buffer_condition = ConditionVariable.new

        # Batch processing queues
        @batch_queues = create_batch_queues
        @processing_pool = create_processing_pool

        # Performance monitoring
        @statistics = initialize_statistics
        @stage_statistics = initialize_stage_statistics
        @performance_monitor = create_performance_monitor

        # Adaptive batching state
        @adaptive_state = initialize_adaptive_state

        Agentic.logger&.debug("EventPipeline initialized with strategy: #{@config[:strategy]}")
      end

      # Add a processor for handling batched events
      # @param processor [Object, Proc] Processor that handles event batches
      # @param stage [Symbol] Pipeline stage for processor
      # @param priority [Integer] Processor priority (lower = higher priority)
      def add_processor(processor, stage: STAGE_PROCESSING, priority: 10)
        processor_config = {
          processor: processor,
          stage: stage,
          priority: priority,
          id: SecureRandom.uuid,
          statistics: {processed: 0, errors: 0, average_time: 0.0}
        }

        @processors << processor_config
        @processors.sort_by! { |p| p[:priority] }

        Agentic.logger&.debug("Added processor for stage #{stage} with priority #{priority}")
        processor_config[:id]
      end

      # Remove a processor by ID
      # @param processor_id [String] Processor ID returned from add_processor
      def remove_processor(processor_id)
        @processors.reject! { |p| p[:id] == processor_id }
        Agentic.logger&.debug("Removed processor #{processor_id}")
      end

      # Ingest event into the pipeline
      # @param event [Hash] Event data to process
      # @param priority [Symbol] Event priority (:high, :normal, :low)
      # @return [Boolean] True if event was accepted, false if backpressure applied
      def ingest_event(event, priority: :normal)
        start_time = Time.now.to_f

        # Apply backpressure if buffer is full
        if @config[:enable_backpressure] && buffer_full?
          @statistics[:events_dropped] += 1
          return false
        end

        # Enrich event with pipeline metadata
        enriched_event = enrich_event(event, priority)

        # Add to circular buffer
        buffer_success = add_to_buffer(enriched_event)

        if buffer_success
          @statistics[:events_ingested] += 1
          update_stage_statistics(STAGE_INGESTION, Time.now.to_f - start_time)
        else
          @statistics[:events_dropped] += 1
        end

        buffer_success
      end

      # Start the event processing pipeline
      def start
        return if @running

        @running = true
        @statistics[:started_at] = Time.now.to_f

        # Start background worker threads; start must not block the caller
        @worker_threads = [
          Thread.new { run_batch_formation_loop },
          Thread.new { run_batch_processing_loop }
        ]
        @worker_threads << Thread.new { run_performance_monitoring_loop } if @config[:enable_performance_monitoring]
        @worker_threads << Thread.new { run_memory_optimization_loop } if @config[:enable_memory_optimization]

        Agentic.logger&.info("EventPipeline started with #{@processors.size} processors")
      end

      # Stop the event processing pipeline
      def stop
        @running = false
        @statistics[:stopped_at] = Time.now.to_f
        @statistics[:total_runtime] = @statistics[:stopped_at] - (@statistics[:started_at] || @statistics[:stopped_at])

        # Wake any worker waiting on the buffer, then wait for workers to exit
        @buffer_mutex.synchronize { @buffer_condition.broadcast }
        @worker_threads.each { |thread| thread.join(2) || thread.kill }
        @worker_threads = []

        # Process remaining events
        process_remaining_events

        Agentic.logger&.info("EventPipeline stopped after #{@statistics[:total_runtime].round(2)}s")
      end

      # Get current buffer utilization
      # @return [Float] Buffer utilization (0.0 to 1.0)
      def buffer_utilization
        @event_buffer.size.to_f / @config[:buffer_size_max]
      end

      # Get processing throughput (events per second)
      # @return [Float] Current throughput
      def throughput
        runtime = (@statistics[:stopped_at] || Time.now.to_f) - (@statistics[:started_at] || Time.now.to_f)
        return 0.0 if runtime <= 0

        @statistics[:events_processed] / runtime
      end

      # Check if pipeline is healthy
      # @return [Boolean] True if pipeline is operating within normal parameters
      def healthy?
        return false unless @running

        # Check buffer utilization
        return false if buffer_utilization > 0.95

        # Check error rates
        total_events = @statistics[:events_processed] + @statistics[:events_errored]
        return false if total_events > 0 && (@statistics[:events_errored].to_f / total_events) > 0.1

        # Check processing latency
        return false if @statistics[:average_processing_latency] > 1.0

        true
      end

      # Get comprehensive pipeline status
      # @return [Hash] Detailed status information
      def status
        {
          running: @running,
          healthy: healthy?,
          buffer_utilization: buffer_utilization,
          throughput: throughput,
          processors: @processors.size,
          statistics: @statistics.dup,
          stage_statistics: @stage_statistics.dup,
          adaptive_state: @config[:enable_adaptive_batching] ? @adaptive_state.dup : nil
        }
      end

      private

      # Create circular buffer for memory efficiency
      def create_circular_buffer(max_size)
        ConcurrentCircularBuffer.new(max_size)
      end

      # Create batch processing queues
      def create_batch_queues
        {
          high_priority: Thread::Queue.new,
          normal_priority: Thread::Queue.new,
          low_priority: Thread::Queue.new
        }
      end

      # Create processing pool for concurrent batch processing
      def create_processing_pool
        Concurrent::ThreadPoolExecutor.new(
          min_threads: 2,
          max_threads: [4, Concurrent.processor_count].min,
          max_queue: 100,
          fallback_policy: :caller_runs
        )
      end

      # Initialize performance statistics
      def initialize_statistics
        {
          events_ingested: 0,
          events_processed: 0,
          events_dropped: 0,
          events_errored: 0,
          batches_formed: 0,
          batches_processed: 0,
          average_batch_size: 0.0,
          average_processing_latency: 0.0,
          memory_usage_peak: 0,
          gc_runs: 0,
          started_at: nil,
          stopped_at: nil,
          total_runtime: 0.0
        }
      end

      # Initialize stage-specific statistics
      def initialize_stage_statistics
        stages = [STAGE_INGESTION, STAGE_BATCHING, STAGE_PROCESSING, STAGE_CLEANUP]
        stages.each_with_object({}) do |stage, hash|
          hash[stage] = {
            operations: 0,
            total_time: 0.0,
            average_time: 0.0,
            errors: 0
          }
        end
      end

      # Create performance monitor
      def create_performance_monitor
        return nil unless @config[:enable_performance_monitoring]

        {
          last_check: Time.now.to_f,
          check_interval: 5.0, # 5 seconds
          metrics_history: []
        }
      end

      # Initialize adaptive batching state
      def initialize_adaptive_state
        {
          current_batch_size: @config[:batch_size_min],
          batch_size_trend: 0.0,
          latency_history: [],
          throughput_history: [],
          last_optimization: Time.now.to_f
        }
      end

      # Enrich event with pipeline metadata
      def enrich_event(event, priority)
        event.merge(
          pipeline_metadata: {
            ingested_at: Time.now.to_f,
            priority: priority,
            pipeline_id: object_id,
            sequence_number: @statistics[:events_ingested] + 1
          }
        )
      end

      # Add event to circular buffer
      def add_to_buffer(event)
        @buffer_mutex.synchronize do
          success = @event_buffer.push(event)
          @buffer_condition.signal if success
          success
        end
      end

      # Check if buffer is full (for backpressure)
      def buffer_full?
        buffer_utilization >= @config[:memory_threshold]
      end

      # Main batch formation loop
      def run_batch_formation_loop
        while @running
          begin
            batch = form_batch
            next if batch.empty?

            # Determine batch priority and route to appropriate queue
            batch_priority = determine_batch_priority(batch)
            @batch_queues[batch_priority].push(batch)

            @statistics[:batches_formed] += 1
            update_stage_statistics(STAGE_BATCHING, 0.001) # Minimal time for batching
          rescue => e
            Agentic.logger&.error("Batch formation error: #{e.message}")
            handle_stage_error(STAGE_BATCHING, e)
          end
        end
      end

      # Main batch processing loop
      def run_batch_processing_loop
        while @running
          begin
            # Process high priority batches first, then normal, then low
            batch = nil
            batch_priority = nil

            [:high_priority, :normal_priority, :low_priority].each do |priority|
              batch = begin
                @batch_queues[priority].pop(true)
              rescue ThreadError
                nil
              end
              if batch
                batch_priority = priority
                break
              end
            end

            unless batch
              sleep(0.005)
              next
            end

            # Process batch with appropriate processors
            process_batch(batch, batch_priority)
          rescue => e
            Agentic.logger&.error("Batch processing error: #{e.message}")
            handle_stage_error(STAGE_PROCESSING, e)
          end
        end
      end

      # Performance monitoring loop
      def run_performance_monitoring_loop
        while @running
          interruptible_sleep(@performance_monitor[:check_interval])
          break unless @running

          begin
            collect_performance_metrics
            optimize_adaptive_batching if @config[:enable_adaptive_batching]
          rescue => e
            Agentic.logger&.warn("Performance monitoring error: #{e.message}")
          end
        end
      end

      # Memory optimization loop
      def run_memory_optimization_loop
        gc_counter = 0

        while @running
          interruptible_sleep(1.0) # Check every second
          break unless @running

          begin
            gc_counter += 1

            if gc_counter >= @config[:gc_interval]
              optimize_memory_usage
              gc_counter = 0
            end
          rescue => e
            Agentic.logger&.warn("Memory optimization error: #{e.message}")
          end
        end
      end

      # Form batch based on configured strategy
      def form_batch
        case @config[:strategy]
        when STRATEGY_TIME_BASED
          form_time_based_batch
        when STRATEGY_SIZE_BASED
          form_size_based_batch
        when STRATEGY_ADAPTIVE
          form_adaptive_batch
        when STRATEGY_HYBRID
          form_hybrid_batch
        else
          form_size_based_batch # Fallback
        end
      end

      # Form batch based on time intervals
      def form_time_based_batch
        events = []
        start_time = Time.now

        while (Time.now - start_time) < @config[:batch_timeout]
          event = extract_event_from_buffer(timeout: 0.001)
          break unless event
          events << event
        end

        events
      end

      # Form batch based on size
      def form_size_based_batch
        events = []
        target_size = @config[:enable_adaptive_batching] ? @adaptive_state[:current_batch_size] : @config[:batch_size_max]

        target_size.times do
          event = extract_event_from_buffer(timeout: @config[:batch_timeout] / target_size)
          break unless event
          events << event
        end

        events
      end

      # Form batch using adaptive strategy
      def form_adaptive_batch
        # Use current adaptive batch size
        target_size = @adaptive_state[:current_batch_size]
        events = []

        target_size.times do
          event = extract_event_from_buffer(timeout: 0.01)
          break unless event
          events << event
        end

        events
      end

      # Form batch using hybrid strategy (time + size)
      def form_hybrid_batch
        events = []
        start_time = Time.now
        max_size = @config[:enable_adaptive_batching] ? @adaptive_state[:current_batch_size] : @config[:batch_size_max]

        while events.size < max_size && (Time.now - start_time) < @config[:batch_timeout]
          event = extract_event_from_buffer(timeout: 0.001)
          break unless event
          events << event
        end

        events
      end

      # Sleep in small increments so stop is not delayed by long intervals
      # @param duration [Numeric] Total time to sleep in seconds
      def interruptible_sleep(duration)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + duration
        while @running
          remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          break if remaining <= 0
          sleep([0.05, remaining].min)
        end
      end

      # Extract event from buffer
      def extract_event_from_buffer(timeout: 0.1)
        @buffer_mutex.synchronize do
          if @event_buffer.empty?
            @buffer_condition.wait(@buffer_mutex, timeout)
          end

          @event_buffer.pop
        end
      end

      # Determine batch priority based on contained events
      def determine_batch_priority(batch)
        return :low_priority if batch.empty?

        # Check for high-priority events
        high_priority_count = batch.count { |event| event[:pipeline_metadata][:priority] == :high }

        if high_priority_count > batch.size / 2
          :high_priority
        elsif high_priority_count > 0
          :normal_priority
        else
          :low_priority
        end
      end

      # Process a batch through all appropriate processors
      def process_batch(batch, priority)
        start_time = Time.now.to_f

        # Filter processors for this stage
        stage_processors = @processors.select { |p| p[:stage] == STAGE_PROCESSING }

        stage_processors.each do |processor_config|
          processor_start = Time.now.to_f

          begin
            processor = processor_config[:processor]

            if processor.respond_to?(:process_batch)
              processor.process_batch(batch, priority: priority)
            elsif processor.respond_to?(:call)
              processor.call(batch, priority: priority)
            elsif processor.respond_to?(:update)
              # Legacy observer interface
              batch.each { |event| processor.update(event[:type], event[:source], event) }
            end

            # Update processor statistics
            processor_time = Time.now.to_f - processor_start
            update_processor_statistics(processor_config, processor_time, batch.size)
          rescue => e
            handle_processor_error(processor_config, e, batch)
          end
        end

        # Update pipeline statistics
        processing_time = Time.now.to_f - start_time
        @statistics[:batches_processed] += 1
        @statistics[:events_processed] += batch.size

        # Update average batch size (exponential moving average)
        alpha = 0.1
        @statistics[:average_batch_size] = (alpha * batch.size) + ((1 - alpha) * @statistics[:average_batch_size])

        # Update average processing latency
        @statistics[:average_processing_latency] = (alpha * processing_time) + ((1 - alpha) * @statistics[:average_processing_latency])

        update_stage_statistics(STAGE_PROCESSING, processing_time)
      end

      # Update processor-specific statistics
      def update_processor_statistics(processor_config, processing_time, batch_size)
        stats = processor_config[:statistics]
        stats[:processed] += batch_size

        # Update average processing time (exponential moving average)
        alpha = 0.1
        stats[:average_time] = (alpha * processing_time) + ((1 - alpha) * stats[:average_time])
      end

      # Handle processor errors with isolation
      def handle_processor_error(processor_config, error, batch)
        stats = processor_config[:statistics]
        stats[:errors] += 1
        @statistics[:events_errored] += batch.size

        Agentic.logger&.error("Processor #{processor_config[:id]} error: #{error.message}")

        if @config[:enable_error_isolation]
          # Continue processing with other processors
          Agentic.logger&.warn("Continuing with other processors due to error isolation")
        else
          raise error
        end
      end

      # Update stage-specific statistics
      def update_stage_statistics(stage, processing_time)
        stats = @stage_statistics[stage]
        stats[:operations] += 1
        stats[:total_time] += processing_time
        stats[:average_time] = stats[:total_time] / stats[:operations]
      end

      # Handle stage-specific errors
      def handle_stage_error(stage, error)
        @stage_statistics[stage][:errors] += 1
        Agentic.logger&.error("Stage #{stage} error: #{error.message}")
      end

      # Collect performance metrics
      def collect_performance_metrics
        return unless @performance_monitor

        current_time = Time.now.to_f
        metrics = {
          timestamp: current_time,
          throughput: throughput,
          buffer_utilization: buffer_utilization,
          average_batch_size: @statistics[:average_batch_size],
          processing_latency: @statistics[:average_processing_latency],
          memory_usage: get_memory_usage
        }

        @performance_monitor[:metrics_history] << metrics

        # Keep only recent metrics (last 100 entries)
        @performance_monitor[:metrics_history] = @performance_monitor[:metrics_history].last(100)

        @performance_monitor[:last_check] = current_time
      end

      # Optimize adaptive batching based on performance metrics
      def optimize_adaptive_batching
        return unless @performance_monitor[:metrics_history].size > 2

        recent_metrics = @performance_monitor[:metrics_history].last(10)
        current_throughput = recent_metrics.map { |m| m[:throughput] }.sum / recent_metrics.size
        current_latency = recent_metrics.map { |m| m[:processing_latency] }.sum / recent_metrics.size

        # Store history for trend analysis
        @adaptive_state[:throughput_history] << current_throughput
        @adaptive_state[:latency_history] << current_latency

        # Keep history manageable
        @adaptive_state[:throughput_history] = @adaptive_state[:throughput_history].last(20)
        @adaptive_state[:latency_history] = @adaptive_state[:latency_history].last(20)

        # Optimize batch size based on throughput and latency trends
        if should_increase_batch_size?(current_throughput, current_latency)
          @adaptive_state[:current_batch_size] = [@adaptive_state[:current_batch_size] + 5, @config[:batch_size_max]].min
        elsif should_decrease_batch_size?(current_throughput, current_latency)
          @adaptive_state[:current_batch_size] = [@adaptive_state[:current_batch_size] - 5, @config[:batch_size_min]].max
        end

        @adaptive_state[:last_optimization] = Time.now.to_f
      end

      # Determine if batch size should be increased
      def should_increase_batch_size?(throughput, latency)
        return false if @adaptive_state[:current_batch_size] >= @config[:batch_size_max]
        return false if latency > 0.1 # Don't increase if latency is already high

        # Increase if throughput is improving or stable and latency is low
        @adaptive_state[:throughput_history].size > 5 &&
          throughput >= (@adaptive_state[:throughput_history][-2] || 0) &&
          latency < 0.05
      end

      # Determine if batch size should be decreased
      def should_decrease_batch_size?(throughput, latency)
        return false if @adaptive_state[:current_batch_size] <= @config[:batch_size_min]

        # Decrease if latency is increasing or throughput is declining
        latency > 0.1 ||
          (@adaptive_state[:throughput_history].size > 5 &&
           throughput < (@adaptive_state[:throughput_history][-2] || Float::INFINITY) * 0.9)
      end

      # Optimize memory usage
      def optimize_memory_usage
        # Hint garbage collection if needed
        current_memory = get_memory_usage
        @statistics[:memory_usage_peak] = [current_memory, @statistics[:memory_usage_peak]].max

        if current_memory > @statistics[:memory_usage_peak] * 0.8
          GC.start
          @statistics[:gc_runs] += 1
        end

        # Clean up old metrics history
        if @performance_monitor && @performance_monitor[:metrics_history].size > 200
          @performance_monitor[:metrics_history] = @performance_monitor[:metrics_history].last(100)
        end

        update_stage_statistics(STAGE_CLEANUP, 0.001)
      end

      # Get current memory usage
      def get_memory_usage
        GC.stat[:heap_live_slots] * GC.stat[:heap_slot_size]
      rescue
        0 # Fallback if GC stats unavailable
      end

      # Process any remaining events before shutdown
      def process_remaining_events
        # Drain batches that were formed but not yet processed
        @batch_queues.each do |priority, queue|
          until queue.empty?
            batch = begin
              queue.pop(true)
            rescue ThreadError
              break
            end
            process_batch(batch, priority)
          end
        end

        # Process remaining events in buffer
        remaining_events = []
        while (event = extract_event_from_buffer(timeout: 0.001))
          remaining_events << event
        end

        unless remaining_events.empty?
          # Process remaining events as final batch
          process_batch(remaining_events, :normal_priority)
          Agentic.logger&.info("Processed #{remaining_events.size} remaining events during shutdown")
        end
      end
    end

    # Concurrent circular buffer implementation for memory efficiency
    class ConcurrentCircularBuffer
      def initialize(capacity)
        @capacity = capacity
        @buffer = Array.new(capacity)
        @head = 0
        @tail = 0
        @size = 0
        @mutex = Mutex.new
      end

      def push(item)
        @mutex.synchronize do
          return false if @size >= @capacity

          @buffer[@tail] = item
          @tail = (@tail + 1) % @capacity
          @size += 1
          true
        end
      end

      def pop
        @mutex.synchronize do
          return nil if @size == 0

          item = @buffer[@head]
          @buffer[@head] = nil # Help GC
          @head = (@head + 1) % @capacity
          @size -= 1
          item
        end
      end

      def size
        @mutex.synchronize { @size }
      end

      def empty?
        size == 0
      end

      def full?
        size >= @capacity
      end
    end
  end
end
