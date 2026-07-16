# frozen_string_literal: true

require "monitor"

module Agentic
  module Performance
    # Intelligent caching system with TTL, invalidation, and memory management
    #
    # Provides high-performance caching with:
    # - Time-to-live (TTL) expiration
    # - Manual and automatic invalidation
    # - Memory-aware eviction policies
    # - Thread-safe operations
    # - Cache statistics and monitoring
    # - Plugin-based storage backends
    #
    # Design Goals:
    # 1. High-performance read/write operations with minimal latency
    # 2. Intelligent memory management with configurable limits
    # 3. Flexible invalidation strategies (time, dependency, manual)
    # 4. Thread-safe concurrent access
    # 5. Extensible storage backends (memory, Redis, file-based)
    #
    # Architect Team Guidance:
    # - Jordan Lee (Performance Specialist): Optimization and memory efficiency
    # - Alex Rivera (Systems Architect): Distributed caching and scalability
    class Cache
      # Cache entry with metadata
      class Entry
        attr_reader :key, :value, :created_at, :accessed_at, :access_count, :ttl, :tags

        def initialize(key, value, ttl: nil, tags: [])
          @key = key
          @value = value
          @created_at = Time.now.to_f
          @accessed_at = @created_at
          @access_count = 0
          @ttl = ttl
          @tags = Array(tags).freeze
          @mutex = Mutex.new
        end

        # Check if entry is expired
        # @return [Boolean] True if expired
        def expired?
          return false unless @ttl
          Time.now.to_f - @created_at > @ttl
        end

        # Get value and update access statistics
        # @return [Object] The cached value
        def get
          @mutex.synchronize do
            @accessed_at = Time.now.to_f
            @access_count += 1
            @value
          end
        end

        # Get value size for memory tracking
        # @return [Integer] Estimated size in bytes
        def size
          @size ||= estimate_size(@value)
        end

        # Get entry metadata
        # @return [Hash] Entry metadata
        def metadata
          {
            key: @key,
            created_at: @created_at,
            accessed_at: @accessed_at,
            access_count: @access_count,
            ttl: @ttl,
            size: size,
            tags: @tags,
            expired: expired?
          }
        end

        private

        # Estimate object size in bytes
        def estimate_size(obj)
          case obj
          when String
            obj.bytesize
          when Numeric
            8 # Approximate
          when Array
            obj.sum { |item| estimate_size(item) } + (obj.size * 8)
          when Hash
            obj.sum { |k, v| estimate_size(k) + estimate_size(v) } + (obj.size * 16)
          when TrueClass, FalseClass, NilClass
            1
          else
            # Fallback estimation
            obj.to_s.bytesize + 100
          end
        end
      end

      # Eviction policies
      module EvictionPolicy
        # Least Recently Used
        LRU = :lru

        # Least Frequently Used
        LFU = :lfu

        # Time-based (oldest first)
        FIFO = :fifo

        # Random eviction
        RANDOM = :random

        # Size-based (largest first)
        LARGEST_FIRST = :largest_first
      end

      # Default configuration
      DEFAULT_CONFIG = {
        max_size: 1000,              # Maximum number of entries
        max_memory: 100 * 1024 * 1024, # 100MB maximum memory usage
        default_ttl: 3600,            # 1 hour default TTL
        eviction_policy: EvictionPolicy::LRU,
        eviction_threshold: 0.9,      # Evict when 90% full
        cleanup_interval: 300,        # 5 minutes
        enable_statistics: true,
        enable_compression: false,
        compression_threshold: 1024   # Compress values larger than 1KB
      }.freeze

      attr_reader :config, :statistics

      def initialize(config = {})
        @config = DEFAULT_CONFIG.merge(config)
        @storage = {}
        @mutex = Monitor.new
        @statistics = {
          hits: 0,
          misses: 0,
          sets: 0,
          deletes: 0,
          evictions: 0,
          expired_cleanups: 0,
          memory_usage: 0,
          entry_count: 0
        }

        # Start background cleanup if interval is configured
        start_cleanup_thread if @config[:cleanup_interval] > 0
      end

      # Get value from cache
      # @param key [String] Cache key
      # @return [Object, nil] Cached value or nil if not found/expired
      def get(key)
        key = normalize_key(key)

        @mutex.synchronize do
          entry = @storage[key]

          if entry.nil?
            @statistics[:misses] += 1
            return nil
          end

          if entry.expired?
            @storage.delete(key)
            update_memory_usage
            @statistics[:expired_cleanups] += 1
            @statistics[:misses] += 1
            return nil
          end

          @statistics[:hits] += 1
          entry.get
        end
      end

      # Set value in cache
      # @param key [String] Cache key
      # @param value [Object] Value to cache
      # @param ttl [Integer, nil] Time-to-live in seconds
      # @param tags [Array<String>] Tags for invalidation
      # @return [Boolean] True if stored successfully
      def set(key, value, ttl: nil, tags: [])
        key = normalize_key(key)
        ttl ||= @config[:default_ttl]

        @mutex.synchronize do
          # Check if we need to evict entries
          if should_evict?
            evict_entries
          end

          # Create and store entry
          entry = Entry.new(key, value, ttl: ttl, tags: tags)
          @storage[key] = entry

          update_memory_usage
          @statistics[:sets] += 1

          true
        end
      end

      # Delete value from cache
      # @param key [String] Cache key
      # @return [Boolean] True if key existed
      def delete(key)
        key = normalize_key(key)

        @mutex.synchronize do
          entry = @storage.delete(key)
          if entry
            update_memory_usage
            @statistics[:deletes] += 1
            true
          else
            false
          end
        end
      end

      # Check if key exists and is not expired
      # @param key [String] Cache key
      # @return [Boolean] True if key exists
      def exist?(key)
        key = normalize_key(key)

        @mutex.synchronize do
          entry = @storage[key]
          return false unless entry

          if entry.expired?
            @storage.delete(key)
            update_memory_usage
            @statistics[:expired_cleanups] += 1
            false
          else
            true
          end
        end
      end

      # Get or set value (cache-aside pattern)
      # @param key [String] Cache key
      # @param ttl [Integer, nil] Time-to-live in seconds
      # @param tags [Array<String>] Tags for invalidation
      # @param block [Proc] Block to compute value if not cached
      # @return [Object] Cached or computed value
      def fetch(key, ttl: nil, tags: [], &block)
        value = get(key)
        return value unless value.nil?

        return nil unless block

        computed_value = block.call
        set(key, computed_value, ttl: ttl, tags: tags)
        computed_value
      end

      # Clear entire cache
      def clear
        @mutex.synchronize do
          @storage.clear
          update_memory_usage
        end
      end

      # Invalidate entries by tags
      # @param tags [Array<String>] Tags to invalidate
      # @return [Integer] Number of invalidated entries
      def invalidate_by_tags(*tags)
        tags = tags.flatten.map(&:to_s)
        return 0 if tags.empty?

        @mutex.synchronize do
          keys_to_delete = []

          @storage.each do |key, entry|
            if (entry.tags & tags).any?
              keys_to_delete << key
            end
          end

          keys_to_delete.each { |key| @storage.delete(key) }

          update_memory_usage
          @statistics[:deletes] += keys_to_delete.size

          keys_to_delete.size
        end
      end

      # Get cache statistics
      # @return [Hash] Current cache statistics
      def stats
        @mutex.synchronize do
          hit_rate = (@statistics[:hits] + @statistics[:misses] > 0) ?
            @statistics[:hits].to_f / (@statistics[:hits] + @statistics[:misses]) : 0.0

          @statistics.merge({
            hit_rate: hit_rate,
            entry_count: @storage.size,
            memory_usage: calculate_memory_usage,
            memory_limit: @config[:max_memory],
            size_limit: @config[:max_size]
          })
        end
      end

      # Get all cache keys
      # @return [Array<String>] All cache keys
      def keys
        @mutex.synchronize do
          @storage.keys.dup
        end
      end

      # Get cache size
      # @return [Integer] Number of entries
      def size
        @storage.size
      end

      # Get memory usage in bytes
      # @return [Integer] Memory usage
      def memory_usage
        @statistics[:memory_usage]
      end

      # Cleanup expired entries
      # @return [Integer] Number of cleaned up entries
      def cleanup_expired
        @mutex.synchronize do
          expired_keys = []

          @storage.each do |key, entry|
            expired_keys << key if entry.expired?
          end

          expired_keys.each { |key| @storage.delete(key) }

          update_memory_usage
          @statistics[:expired_cleanups] += expired_keys.size

          expired_keys.size
        end
      end

      # Get detailed information about cache entries
      # @param limit [Integer] Maximum number of entries to return
      # @return [Array<Hash>] Entry metadata
      def inspect_entries(limit: 100)
        @mutex.synchronize do
          @storage.values.first(limit).map(&:metadata)
        end
      end

      # Preload multiple values
      # @param keys_and_values [Hash] Key-value pairs to preload
      # @param ttl [Integer, nil] Time-to-live for all entries
      # @param tags [Array<String>] Tags for all entries
      def preload(keys_and_values, ttl: nil, tags: [])
        keys_and_values.each do |key, value|
          set(key, value, ttl: ttl, tags: tags)
        end
      end

      # Warmup cache using block to compute values
      # @param keys [Array<String>] Keys to warm up
      # @param ttl [Integer, nil] Time-to-live for entries
      # @param tags [Array<String>] Tags for entries
      # @param block [Proc] Block that takes key and returns value
      def warmup(keys, ttl: nil, tags: [], &block)
        return unless block

        keys.each do |key|
          next if exist?(key)

          value = block.call(key)
          set(key, value, ttl: ttl, tags: tags) if value
        end
      end

      private

      # Normalize cache key to string
      def normalize_key(key)
        case key
        when String then key
        when Symbol then key.to_s
        else key.to_s
        end
      end

      # Check if eviction is needed
      def should_evict?
        memory_threshold = (@config[:max_memory] * @config[:eviction_threshold]).to_i

        @storage.size >= @config[:max_size] || calculate_memory_usage >= memory_threshold
      end

      # Evict entries based on policy
      def evict_entries
        target_size = (@config[:max_size] * 0.7).to_i  # Evict to 70% capacity
        (@config[:max_memory] * 0.7).to_i

        # Evict only the overflow (at least one entry); a fixed batch minimum
        # would wipe out small caches entirely
        eviction_count = [@storage.size - target_size, 1].max

        entries_to_evict = case @config[:eviction_policy]
        when EvictionPolicy::LRU
          @storage.values.sort_by(&:accessed_at).first(eviction_count)
        when EvictionPolicy::LFU
          @storage.values.sort_by(&:access_count).first(eviction_count)
        when EvictionPolicy::FIFO
          @storage.values.sort_by(&:created_at).first(eviction_count)
        when EvictionPolicy::LARGEST_FIRST
          @storage.values.sort_by(&:size).reverse.first(eviction_count)
        when EvictionPolicy::RANDOM
          @storage.values.sample(eviction_count)
        else
          []
        end

        entries_to_evict.each do |entry|
          @storage.delete(entry.key)
          @statistics[:evictions] += 1
        end

        update_memory_usage
      end

      # Calculate total memory usage
      def calculate_memory_usage
        @storage.values.sum(&:size)
      end

      # Update memory usage statistics
      def update_memory_usage
        @statistics[:memory_usage] = calculate_memory_usage
        @statistics[:entry_count] = @storage.size
      end

      # Start background cleanup thread
      def start_cleanup_thread
        @cleanup_thread = Thread.new do
          Thread.current.name = "cache-cleanup"
          loop do
            sleep(@config[:cleanup_interval])
            cleanup_expired
          rescue => e
            # Log error but continue cleanup thread
            puts "Cache cleanup error: #{e.message}" if $DEBUG
          end
        end
      end
    end
  end
end
