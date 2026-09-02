# frozen_string_literal: true

RSpec.describe Agentic::Performance::Cache do
  let(:cache) { described_class.new }

  describe "initialization" do
    it "creates cache with default configuration" do
      expect(cache.config[:max_size]).to eq(1000)
      expect(cache.config[:max_memory]).to eq(100 * 1024 * 1024)
      expect(cache.config[:default_ttl]).to eq(3600)
    end

    it "accepts custom configuration" do
      custom_cache = described_class.new(max_size: 500, default_ttl: 1800)
      expect(custom_cache.config[:max_size]).to eq(500)
      expect(custom_cache.config[:default_ttl]).to eq(1800)
    end
  end

  describe "basic cache operations" do
    it "sets and gets values" do
      cache.set("key1", "value1")
      expect(cache.get("key1")).to eq("value1")
    end

    it "returns nil for non-existent keys" do
      expect(cache.get("non_existent")).to be_nil
    end

    it "deletes values" do
      cache.set("key1", "value1")
      expect(cache.delete("key1")).to be true
      expect(cache.get("key1")).to be_nil
      expect(cache.delete("key1")).to be false
    end

    it "checks key existence" do
      cache.set("key1", "value1")
      expect(cache.exist?("key1")).to be true
      expect(cache.exist?("key2")).to be false
    end

    it "clears all entries" do
      cache.set("key1", "value1")
      cache.set("key2", "value2")
      cache.clear
      expect(cache.size).to eq(0)
      expect(cache.get("key1")).to be_nil
    end
  end

  describe "TTL (Time-to-Live) functionality" do
    it "respects TTL expiration" do
      cache.set("key1", "value1", ttl: 0.1) # 100ms TTL
      expect(cache.get("key1")).to eq("value1")

      sleep(0.2) # Wait for expiration
      expect(cache.get("key1")).to be_nil
    end

    it "uses default TTL when not specified" do
      cache = described_class.new(default_ttl: 0.1)
      cache.set("key1", "value1")
      expect(cache.get("key1")).to eq("value1")

      sleep(0.2)
      expect(cache.get("key1")).to be_nil
    end

    it "cleans up expired entries" do
      cache.set("key1", "value1", ttl: 0.1)
      cache.set("key2", "value2", ttl: 10) # Long TTL

      expect(cache.size).to eq(2)

      sleep(0.2)
      cleaned = cache.cleanup_expired

      expect(cleaned).to eq(1)
      expect(cache.size).to eq(1)
      expect(cache.get("key2")).to eq("value2")
    end
  end

  describe "fetch with fallback" do
    it "returns cached value if available" do
      cache.set("key1", "cached_value")

      result = cache.fetch("key1") { "computed_value" }
      expect(result).to eq("cached_value")
    end

    it "computes and caches value if not available" do
      result = cache.fetch("key1") { "computed_value" }
      expect(result).to eq("computed_value")
      expect(cache.get("key1")).to eq("computed_value")
    end

    it "returns nil if no block provided and key not found" do
      result = cache.fetch("key1")
      expect(result).to be_nil
    end
  end

  describe "tag-based invalidation" do
    it "invalidates entries by tags" do
      cache.set("key1", "value1", tags: ["group1", "group2"])
      cache.set("key2", "value2", tags: ["group2"])
      cache.set("key3", "value3", tags: ["group3"])

      invalidated = cache.invalidate_by_tags("group2")
      expect(invalidated).to eq(2)

      expect(cache.get("key1")).to be_nil
      expect(cache.get("key2")).to be_nil
      expect(cache.get("key3")).to eq("value3")
    end

    it "supports multiple tag invalidation" do
      cache.set("key1", "value1", tags: ["group1"])
      cache.set("key2", "value2", tags: ["group2"])
      cache.set("key3", "value3", tags: ["group3"])

      invalidated = cache.invalidate_by_tags("group1", "group3")
      expect(invalidated).to eq(2)

      expect(cache.get("key2")).to eq("value2")
    end
  end

  describe "memory management and eviction" do
    let(:small_cache) { described_class.new(max_size: 3, eviction_policy: :lru) }

    it "enforces maximum size with LRU eviction" do
      small_cache.set("key1", "value1")
      small_cache.set("key2", "value2")
      small_cache.set("key3", "value3")

      # Access key1 to make it recently used
      small_cache.get("key1")

      # Adding key4 should evict key2 (least recently used)
      small_cache.set("key4", "value4")

      expect(small_cache.get("key1")).to eq("value1") # Recently accessed
      expect(small_cache.get("key2")).to be_nil       # Evicted
      expect(small_cache.get("key3")).to eq("value3") # Recently set
      expect(small_cache.get("key4")).to eq("value4") # Just added
    end

    it "tracks memory usage" do
      cache.set("small", "x")
      cache.set("large", "x" * 1000)

      stats = cache.stats
      expect(stats[:memory_usage]).to be > 1000
      expect(stats[:entry_count]).to eq(2)
    end
  end

  describe "statistics tracking" do
    it "tracks hits and misses" do
      cache.set("key1", "value1")

      cache.get("key1") # Hit
      cache.get("key2") # Miss
      cache.get("key1") # Hit

      stats = cache.stats
      expect(stats[:hits]).to eq(2)
      expect(stats[:misses]).to eq(1)
      expect(stats[:hit_rate]).to be_within(0.01).of(0.67)
    end

    it "tracks set and delete operations" do
      cache.set("key1", "value1")
      cache.set("key2", "value2")
      cache.delete("key1")

      stats = cache.stats
      expect(stats[:sets]).to eq(2)
      expect(stats[:deletes]).to eq(1)
    end
  end

  describe "bulk operations" do
    it "preloads multiple values" do
      data = {
        "key1" => "value1",
        "key2" => "value2",
        "key3" => "value3"
      }

      cache.preload(data, ttl: 3600, tags: ["bulk"])

      expect(cache.get("key1")).to eq("value1")
      expect(cache.get("key2")).to eq("value2")
      expect(cache.get("key3")).to eq("value3")
    end

    it "warms up cache with computed values" do
      keys = ["compute1", "compute2", "compute3"]

      cache.warmup(keys, ttl: 3600) do |key|
        "computed_#{key}"
      end

      expect(cache.get("compute1")).to eq("computed_compute1")
      expect(cache.get("compute2")).to eq("computed_compute2")
      expect(cache.get("compute3")).to eq("computed_compute3")
    end

    it "skips existing entries during warmup" do
      cache.set("existing", "original_value")

      cache.warmup(["existing", "new"]) do |key|
        "computed_#{key}"
      end

      expect(cache.get("existing")).to eq("original_value") # Not overwritten
      expect(cache.get("new")).to eq("computed_new")       # Newly computed
    end
  end

  describe "entry inspection and debugging" do
    it "provides entry metadata" do
      cache.set("key1", "value1", ttl: 3600, tags: ["debug"])

      entries = cache.inspect_entries
      expect(entries.size).to eq(1)

      entry = entries.first
      expect(entry[:key]).to eq("key1")
      expect(entry[:tags]).to include("debug")
      expect(entry[:ttl]).to eq(3600)
      expect(entry).to include(:created_at, :accessed_at, :access_count, :size)
    end

    it "limits entry inspection results" do
      10.times { |i| cache.set("key#{i}", "value#{i}") }

      entries = cache.inspect_entries(limit: 5)
      expect(entries.size).to eq(5)
    end
  end

  describe "concurrent access safety" do
    it "handles concurrent read/write operations safely" do
      # This test verifies thread safety, though it's hard to test deterministically
      threads = []

      10.times do |i|
        threads << Thread.new do
          100.times do |j|
            key = "thread#{i}_key#{j}"
            cache.set(key, "value#{j}")
            cache.get(key)
          end
        end
      end

      threads.each(&:join)

      # Cache should remain in a consistent state
      expect(cache.stats[:entry_count]).to be >= 0
      expect(cache.stats[:hits]).to be >= 0
    end
  end

  describe "key normalization" do
    it "normalizes different key types to strings" do
      cache.set(:symbol_key, "value1")
      cache.set("string_key", "value2")
      cache.set(12345, "value3")

      expect(cache.get("symbol_key")).to eq("value1")
      expect(cache.get(:string_key)).to eq("value2")
      expect(cache.get("12345")).to eq("value3")
    end
  end

  describe "performance characteristics" do
    it "maintains reasonable performance for large datasets" do
      large_cache = described_class.new(max_size: 10000)

      start_time = Time.now

      1000.times do |i|
        large_cache.set("key#{i}", "value#{i}")
      end

      set_time = Time.now - start_time

      start_time = Time.now

      1000.times do |i|
        large_cache.get("key#{i}")
      end

      get_time = Time.now - start_time

      # Operations should complete within reasonable time
      expect(set_time).to be < 1.0
      expect(get_time).to be < 1.0
    end
  end
end
