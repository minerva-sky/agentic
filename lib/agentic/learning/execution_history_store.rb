# frozen_string_literal: true

require "date"
require "json"
require "fileutils"

module Agentic
  module Learning
    # ExecutionHistoryStore is responsible for capturing, storing, and retrieving
    # execution metrics and performance data for agent tasks and plans.
    #
    # @example Recording a task execution
    #   history_store = Agentic::Learning::ExecutionHistoryStore.new
    #   history_store.record_execution(
    #     task_id: task.id,
    #     agent_type: "research_agent",
    #     duration_ms: 1200,
    #     success: true,
    #     metrics: { tokens_used: 1500, prompt_tokens: 500 }
    #   )
    #
    # @example Retrieving execution history for a specific agent type
    #   records = history_store.get_history(agent_type: "research_agent")
    #
    class ExecutionHistoryStore
      # Initialize a new ExecutionHistoryStore with the given options
      #
      # @param options [Hash] Configuration options
      # @option options [Logger] :logger Custom logger (defaults to Agentic.logger)
      # @option options [String] :storage_path Directory to store execution history (defaults to ~/.agentic/history)
      # @option options [Integer] :retention_days Number of days to retain history (defaults to 30)
      # @option options [Boolean] :anonymize Whether to anonymize data (defaults to true)
      def initialize(options = {})
        @logger = options[:logger] || Agentic.logger
        @storage_path = options[:storage_path] || default_storage_path
        @retention_days = options[:retention_days] || 30
        @anonymize = options.fetch(:anonymize, true)
        @memory_cache = []
        @cache_size_limit = options[:cache_size_limit] || 1000

        ensure_storage_path_exists
      end

      # Record a new execution in the history store
      #
      # @param execution_data [Hash] Execution data to record
      # @option execution_data [String] :task_id ID of the executed task
      # @option execution_data [String] :plan_id ID of the plan (optional)
      # @option execution_data [String] :agent_type Type of agent used
      # @option execution_data [Integer] :duration_ms Execution time in milliseconds
      # @option execution_data [Boolean] :success Whether execution succeeded
      # @option execution_data [Hash] :metrics Additional metrics
      # @option execution_data [Hash] :context Additional context information
      # @return [Boolean] true if successfully recorded
      def record_execution(execution_data)
        record = build_record(execution_data)

        # Add to memory cache
        @memory_cache << record
        @memory_cache.shift if @memory_cache.size > @cache_size_limit

        # Persist to storage
        save_record(record)

        # Clean up old records periodically
        cleanup_old_records if rand < 0.05 # 5% chance to trigger cleanup

        true
      rescue => e
        @logger.error("Failed to record execution history: #{e.message}")
        false
      end

      # Retrieve execution history based on filter criteria
      #
      # @param filters [Hash] Filter criteria
      # @option filters [String] :task_id Filter by task ID
      # @option filters [String] :plan_id Filter by plan ID
      # @option filters [String] :agent_type Filter by agent type
      # @option filters [Boolean] :success Filter by success status
      # @option filters [Time] :start_time Filter by start time
      # @option filters [Time] :end_time Filter by end time
      # @option filters [Integer] :limit Maximum number of records to return
      # @return [Array<Hash>] Array of matching history records
      def get_history(filters = {})
        records = load_records(filters)
        limit = filters[:limit] || records.size
        records.first(limit)
      end

      # Retrieve aggregated metrics from execution history
      #
      # @param metric_name [Symbol] Name of the metric to aggregate
      # @param filters [Hash] Filter criteria
      # @option filters [String] :agent_type Filter by agent type
      # @option filters [Boolean] :success Filter by success status
      # @option filters [Time] :start_time Filter by start time
      # @option filters [Time] :end_time Filter by end time
      # @param aggregation [Symbol] Aggregation method (:avg, :sum, :min, :max)
      # @return [Float, Integer] Aggregated metric value
      def get_metric(metric_name, filters = {}, aggregation = :avg)
        records = get_history(filters)
        values = records.map { |r| r.dig(:metrics, metric_name.to_s) }.compact

        return nil if values.empty?

        case aggregation
        when :avg then values.sum / values.size.to_f
        when :sum then values.sum
        when :min then values.min
        when :max then values.max
        end
      end

      # Delete all history older than retention_days
      #
      # @return [Integer] Number of records deleted
      def cleanup_old_records
        cutoff_date = Date.today - @retention_days
        count = 0

        Dir.glob(File.join(@storage_path, "**/*.json")).each do |file|
          date_str = File.basename(file, ".json")
          date = begin
            Date.parse(date_str)
          rescue
            nil
          end
          if date && date < cutoff_date
            File.delete(file)
            count += 1
          end
        end

        @logger.info("Cleaned up #{count} old history records")
        count
      end

      private

      def default_storage_path
        path = File.join(Dir.home, ".agentic", "history")
        FileUtils.mkdir_p(path) unless Dir.exist?(path)
        path
      end

      def ensure_storage_path_exists
        FileUtils.mkdir_p(@storage_path) unless Dir.exist?(@storage_path)
      end

      def build_record(execution_data)
        timestamp = Time.now
        {
          id: SecureRandom.uuid,
          timestamp: timestamp.iso8601,
          task_id: execution_data[:task_id],
          plan_id: execution_data[:plan_id],
          agent_type: execution_data[:agent_type],
          duration_ms: execution_data[:duration_ms],
          success: execution_data[:success],
          metrics: execution_data[:metrics] || {},
          context: @anonymize ? anonymize_context(execution_data[:context]) : execution_data[:context]
        }.compact
      end

      def anonymize_context(context)
        return nil unless context

        # Implement context anonymization logic
        # For example, replace actual content with length information
        anonymized = {}
        context.each do |key, value|
          anonymized[key] = if value.is_a?(String)
            "#{value.length} chars"
          elsif value.is_a?(Hash)
            anonymize_context(value)
          elsif value.is_a?(Array)
            "#{value.length} items"
          else
            value
          end
        end

        anonymized
      end

      def save_record(record)
        date_str = Date.parse(record[:timestamp]).iso8601
        dir_path = File.join(@storage_path, date_str)
        FileUtils.mkdir_p(dir_path) unless Dir.exist?(dir_path)

        file_path = File.join(dir_path, "#{record[:id]}.json")
        File.write(file_path, JSON.pretty_generate(record))
      end

      def load_records(filters)
        # Apply memory cache first for recent records
        records = @memory_cache.dup

        # Determine date range for file loading
        end_date = filters[:end_time] ? Date.parse(filters[:end_time].iso8601) : Date.today
        start_date = if filters[:start_time]
          Date.parse(filters[:start_time].iso8601)
        else
          end_date - (@retention_days / 2)
        end

        # Load files within date range
        (start_date..end_date).each do |date|
          date_str = date.iso8601
          dir_path = File.join(@storage_path, date_str)
          next unless Dir.exist?(dir_path)

          Dir.glob(File.join(dir_path, "*.json")).each do |file|
            record = JSON.parse(File.read(file), symbolize_names: true)
            records << record
          end
        end

        # Apply filters
        records = filter_records(records, filters)

        # Sort by timestamp descending
        records.sort_by { |r| r[:timestamp] }.reverse
      end

      def filter_records(records, filters)
        records.select do |record|
          matches = true

          matches = false if filters[:task_id] && record[:task_id] != filters[:task_id]
          matches = false if filters[:plan_id] && record[:plan_id] != filters[:plan_id]
          matches = false if filters[:agent_type] && record[:agent_type] != filters[:agent_type]
          matches = false if !filters[:success].nil? && record[:success] != filters[:success]

          if filters[:start_time]
            record_time = Time.parse(record[:timestamp])
            matches = false if record_time < filters[:start_time]
          end

          if filters[:end_time]
            record_time = Time.parse(record[:timestamp])
            matches = false if record_time > filters[:end_time]
          end

          matches
        end
      end
    end
  end
end
