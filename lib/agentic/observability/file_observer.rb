# frozen_string_literal: true

require "json"
require "fileutils"

module Agentic
  module Observability
    # FileObserver writes events to a local file for dashboard consumption
    # This provides observability without network complexity
    class FileObserver
      attr_reader :log_path, :max_file_size, :max_files

      DEFAULT_LOG_PATH = File.join(Dir.home, ".agentic", "observability", "events.jsonl").freeze
      DEFAULT_MAX_FILE_SIZE = 10 * 1024 * 1024 # 10MB
      DEFAULT_MAX_FILES = 5

      def initialize(log_path: nil, max_file_size: DEFAULT_MAX_FILE_SIZE, max_files: DEFAULT_MAX_FILES)
        @log_path = log_path || DEFAULT_LOG_PATH
        @max_file_size = max_file_size
        @max_files = max_files
        @write_mutex = Mutex.new

        ensure_log_directory
        cleanup_old_files if should_rotate?
      end

      # Handle event from ObservabilityEngine
      # @param event_data [EventData] The event to log
      def handle_event(event_data)
        log_entry = create_log_entry(event_data)
        write_to_file(log_entry)
      end

      # Get recent events for local CLI display
      # @param limit [Integer] Maximum number of events to return
      # @return [Array<Hash>] Recent events
      def recent_events(limit: 50)
        return [] unless File.exist?(@log_path)

        events = []
        File.open(@log_path, "r") do |file|
          file.each_line do |line|
            events << JSON.parse(line.strip)
          rescue JSON::ParserError
            # Skip invalid lines
          end
        end

        events.last(limit)
      end

      # Get events since a specific timestamp
      # @param since [Time, String] Timestamp to filter from
      # @return [Array<Hash>] Events since timestamp
      def events_since(since)
        since_time = since.is_a?(String) ? Time.parse(since) : since
        recent_events.select do |event|
          event_time = Time.parse(event["timestamp"])
          event_time > since_time
        end
      rescue ArgumentError => e
        Agentic.logger.warn("Failed to parse timestamp: #{e.message}")
        []
      end

      # Get current file size for rotation decisions
      # @return [Integer] File size in bytes
      def current_file_size
        File.exist?(@log_path) ? File.size(@log_path) : 0
      end

      # Check if file should be rotated
      # @return [Boolean] True if rotation is needed
      def should_rotate?
        current_file_size > @max_file_size
      end

      # Manually trigger file rotation
      def rotate_file!
        return unless File.exist?(@log_path)

        @write_mutex.synchronize do
          rotate_file_unsafe!
        end
      end

      # Get observability directory path
      # @return [String] Directory path
      def observability_dir
        File.dirname(@log_path)
      end

      # Get statistics about logged events
      # @return [Hash] Statistics
      def statistics
        return default_statistics unless File.exist?(@log_path)

        event_count = 0
        first_event = nil
        last_event = nil

        File.open(@log_path, "r") do |file|
          file.each_line do |line|
            event_count += 1

            begin
              event = JSON.parse(line.strip)
              first_event ||= event["timestamp"]
              last_event = event["timestamp"]
            rescue JSON::ParserError
              # Skip invalid lines
            end
          end
        end

        {
          total_events: event_count,
          file_size: current_file_size,
          first_event_at: first_event,
          last_event_at: last_event,
          log_path: @log_path
        }
      end

      private

      # Unsafe rotation - must be called within mutex
      def rotate_file_unsafe!
        return unless File.exist?(@log_path)

        # Move current file to timestamped backup
        timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
        backup_path = "#{@log_path}.#{timestamp}"

        File.rename(@log_path, backup_path)
        Agentic.logger&.info("Rotated observability log to #{backup_path}")

        # Clean up old files
        cleanup_old_files
      end

      def create_log_entry(event_data)
        {
          timestamp: Time.now.iso8601,
          type: event_data.type,
          data: event_data.data,
          source: event_data.source,
          metadata: event_data.metadata
        }
      end

      def write_to_file(log_entry)
        @write_mutex.synchronize do
          # Check for rotation before writing (use current_file_size directly to avoid deadlock)
          if current_file_size > @max_file_size
            rotate_file_unsafe!
          end

          File.open(@log_path, "a") do |file|
            file.puts(JSON.generate(log_entry))
            file.flush
          end
        end
      rescue => e
        # Log for visibility, then propagate so callers (e.g. FileAdapter's
        # error handling) can record the failure in their statistics. The
        # adapter and engine layers keep observability failures non-fatal.
        Agentic.logger.error("Failed to write observability event: #{e.message}")
        raise
      end

      def ensure_log_directory
        dir = File.dirname(@log_path)
        FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
      rescue => e
        Agentic.logger.error("Failed to create observability directory: #{e.message}")
      end

      def cleanup_old_files
        pattern = "#{@log_path}.*"
        old_files = Dir.glob(pattern).sort

        # Keep only max_files - 1 old files (plus current file)
        files_to_remove = old_files[0..-((@max_files - 1) + 1)]

        files_to_remove.each do |file|
          File.delete(file)
          Agentic.logger.debug("Removed old observability file: #{file}")
        end
      rescue => e
        Agentic.logger.warn("Failed to cleanup old observability files: #{e.message}")
      end

      def default_statistics
        {
          total_events: 0,
          file_size: 0,
          first_event_at: nil,
          last_event_at: nil,
          log_path: @log_path
        }
      end
    end
  end
end
