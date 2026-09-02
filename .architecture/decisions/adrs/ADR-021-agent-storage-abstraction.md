# ADR-021: Agent Storage Abstraction

## Status

Accepted

## Context

The current agent storage implementation uses a concrete file-based approach (`PersistentAgentStore`) that writes JSON files to `~/.agentic/agents/` directory. This implementation is tightly coupled throughout the codebase, particularly in `AgentAssemblyEngine` and `Agentic` module initialization.

Current implementation characteristics:
1. **File-Based Only**: Stores agents as JSON files in local filesystem
2. **Hardcoded Path**: Uses `~/.agentic/agents/` with limited configuration
3. **Synchronous I/O**: All read/write operations block execution
4. **No Abstraction**: `PersistentAgentStore` is used directly, not through an interface
5. **Single-Machine**: Cannot share agents across deployments or scale horizontally

Architecture review findings:

**Alex Rivera (Systems Architect):**
- **Medium Risk**: File-based storage creates deployment complexity and limits concurrent access
- File-based storage doesn't scale beyond single-machine deployments
- Direct coupling between `AgentAssemblyEngine` and storage lacks abstraction

**Jordan Lee (Performance):**
- **Medium Risk**: File-based storage I/O becomes bottleneck at scale (>1000 agents)
- Synchronous file operations add latency to agent assembly

**Pragmatic Enforcer:**
- File-based storage adequate for current single-user, local execution scope
- Don't over-engineer until scaling needs proven

Scaling scenarios requiring alternative storage:
- **Multi-User Deployments**: Shared agent repository across users
- **Cloud-Native**: Deployments without persistent local filesystem
- **High-Volume**: Applications assembling 100+ agents/second
- **Team Collaboration**: Shared agent library across development teams
- **CI/CD Pipelines**: Ephemeral environments needing external storage

However, current users are primarily single-user, local development scenarios where file-based storage works well.

## Decision

We will **introduce a storage abstraction layer** while keeping the file-based implementation as the default. This provides future flexibility without premature implementation of alternative backends.

### 1. Storage Interface Definition

Define a Ruby module specifying the storage contract:

```ruby
module Agentic
  module Storage
    # Interface for agent storage implementations
    module AgentStorageAdapter
      # Store an agent with metadata
      # @param agent [Agent] The agent to store
      # @param name [String] Optional name for the agent
      # @param metadata [Hash] Additional metadata
      # @return [String] The agent's storage ID
      def store(agent, name: nil, metadata: {})
        raise NotImplementedError
      end

      # Build an agent from storage
      # @param id_or_name [String] Agent ID or name
      # @param version [String, nil] Specific version or latest
      # @return [Agent, nil] The agent or nil if not found
      def build_agent(id_or_name, version: nil)
        raise NotImplementedError
      end

      # List all stored agents
      # @param filter [Hash] Optional filters (capability, timestamp, metadata)
      # @return [Array<Hash>] Array of agent metadata
      def list_all(filter = {})
        raise NotImplementedError
      end

      # Get version history for an agent
      # @param id_or_name [String] Agent ID or name
      # @return [Array<Hash>] Version history with timestamps
      def version_history(id_or_name)
        raise NotImplementedError
      end

      # Delete an agent
      # @param id_or_name [String] Agent ID or name
      # @param version [String, nil] Specific version or all versions
      # @return [Boolean] Success status
      def delete(id_or_name, version: nil)
        raise NotImplementedError
      end

      # Check if an agent exists
      # @param id_or_name [String] Agent ID or name
      # @param version [String, nil] Specific version or any
      # @return [Boolean] True if exists
      def exists?(id_or_name, version: nil)
        raise NotImplementedError
      end

      # Search for agents matching criteria
      # @param query [Hash] Search criteria
      # @return [Array<Hash>] Matching agents
      def search(query = {})
        raise NotImplementedError
      end
    end
  end
end
```

### 2. File Storage Adapter

Rename and update existing implementation to use the interface:

```ruby
module Agentic
  module Storage
    class FileStorageAdapter
      include AgentStorageAdapter

      def initialize(base_path: nil)
        @base_path = base_path || File.join(Dir.home, ".agentic", "agents")
        @index_path = File.join(@base_path, "index.json")
        ensure_storage_directory
      end

      def store(agent, name: nil, metadata: {})
        # Existing PersistentAgentStore logic
      end

      def build_agent(id_or_name, version: nil)
        # Existing PersistentAgentStore logic
      end

      # ... implement all interface methods
    end
  end
end
```

### 3. Configuration-Based Adapter Selection

Add storage configuration to `Agentic.configure`:

```ruby
module Agentic
  class Configuration
    attr_accessor :storage_adapter
    attr_accessor :storage_options

    def initialize
      @storage_adapter = :file  # default
      @storage_options = {}
    end
  end

  def self.configure
    yield(configuration)
    initialize_storage
  end

  def self.storage
    @storage ||= create_storage_adapter
  end

  private

  def self.create_storage_adapter
    adapter_class = case configuration.storage_adapter
    when :file
      Storage::FileStorageAdapter
    when :memory
      Storage::MemoryStorageAdapter
    when :redis
      require "agentic/storage/redis_adapter"
      Storage::RedisStorageAdapter
    when :database
      require "agentic/storage/database_adapter"
      Storage::DatabaseStorageAdapter
    else
      if configuration.storage_adapter.is_a?(Class)
        configuration.storage_adapter
      else
        raise ArgumentError, "Unknown storage adapter: #{configuration.storage_adapter}"
      end
    end

    adapter_class.new(**configuration.storage_options)
  end
end
```

### 4. Update AgentAssemblyEngine

Inject storage adapter instead of direct instantiation:

```ruby
class AgentAssemblyEngine
  def initialize(registry, storage: nil)
    @registry = registry
    @storage = storage || Agentic.storage
  end

  def assemble_agent(task, strategy: nil, store: true)
    # ... assembly logic ...

    if store
      @storage.store(agent, name: generated_name, metadata: metadata)
    end

    agent
  end

  def find_existing_agent(task)
    # Use @storage instead of direct PersistentAgentStore
    candidates = @storage.search(capabilities: required_capabilities)
    # ... matching logic ...
  end
end
```

### 5. Memory Storage Adapter (Testing/Development)

Provide in-memory implementation for testing:

```ruby
module Agentic
  module Storage
    class MemoryStorageAdapter
      include AgentStorageAdapter

      def initialize
        @agents = {}
        @index = {}
      end

      def store(agent, name: nil, metadata: {})
        id = agent.id || SecureRandom.uuid
        version = Time.now.utc.iso8601

        @agents[id] ||= {}
        @agents[id][version] = {
          agent: agent,
          name: name,
          metadata: metadata,
          timestamp: Time.now.utc
        }

        @index[id] = name if name

        id
      end

      def build_agent(id_or_name, version: nil)
        id = @index[id_or_name] || id_or_name
        versions = @agents[id]

        return nil unless versions

        version_key = version || versions.keys.max
        entry = versions[version_key]

        entry[:agent]
      end

      # ... implement all interface methods
    end
  end
end
```

### 6. Placeholder for Future Adapters

Document interface for future implementations without implementing:

```ruby
# Future: Redis-backed storage for shared agent repositories
# module Agentic
#   module Storage
#     class RedisStorageAdapter
#       include AgentStorageAdapter
#
#       def initialize(redis_url:, **options)
#         @redis = Redis.new(url: redis_url, **options)
#       end
#
#       # ... implementation using Redis for storage
#     end
#   end
# end

# Future: Database-backed storage for enterprise deployments
# module Agentic
#   module Storage
#     class DatabaseStorageAdapter
#       include AgentStorageAdapter
#
#       def initialize(connection:)
#         @db = connection
#       end
#
#       # ... implementation using ActiveRecord or Sequel
#     end
#   end
# end
```

## Consequences

### Positive

1. **Future Flexibility**: Can add database, Redis, S3 backends without breaking changes
2. **Testing Improvement**: In-memory adapter simplifies testing without file I/O
3. **Deployment Options**: Enables cloud-native and multi-user deployments
4. **Dependency Injection**: Testable without file system dependencies
5. **Clean Architecture**: Follows interface segregation and dependency inversion principles
6. **Minimal Overhead**: Abstraction adds negligible performance cost
7. **Backward Compatible**: Existing code continues to work with file-based default

### Negative

1. **Increased Abstraction**: One more layer to understand and maintain
2. **Interface Maintenance**: Interface changes require updating all adapters
3. **Documentation Burden**: Must document interface and adapter development
4. **Potential Over-Engineering**: If alternative backends never implemented, abstraction is wasted
5. **Migration Complexity**: Moving between storage backends requires data migration

### Neutral

1. **Default Behavior Unchanged**: File storage remains default for simplicity
2. **Adapter Development Required**: Future backends need explicit implementation
3. **Configuration Needed**: Users wanting alternative storage must configure it

## Alternatives Considered

### Alternative 1: Multiple Concrete Implementations

**Approach**: Implement file, Redis, and database storage upfront, no interface

**Pros**:
- Concrete implementations available immediately
- No abstract interface needed
- Users can choose backend day one

**Cons**:
- Significant implementation effort (4-6 weeks)
- Adds dependencies (Redis, database gems)
- Maintenance burden for storage we don't know is needed
- Most users won't use alternative backends

**Decision**: Rejected - Violates YAGNI, significant effort for unproven need.

### Alternative 2: No Abstraction (Status Quo)

**Approach**: Keep `PersistentAgentStore` as-is, add features as needed

**Pros**:
- Simplest approach
- No abstraction overhead
- Works for current users

**Cons**:
- Future backends require breaking changes
- Tight coupling continues
- Testing requires file system
- Limits deployment flexibility

**Decision**: Rejected - Small abstraction cost provides significant future flexibility.

### Alternative 3: Plugin-Based Storage

**Approach**: Storage adapters as separate gems/plugins, no core interface

**Pros**:
- Maximum flexibility
- Community can provide adapters
- Core stays minimal

**Cons**:
- No standard interface
- Compatibility issues
- Quality concerns
- Fragmented ecosystem

**Decision**: Rejected - Standard interface more important than plugin flexibility.

### Alternative 4: Database Only

**Approach**: Remove file storage, require database for all deployments

**Pros**:
- Scalable from start
- Simpler (one implementation)
- Production-ready

**Cons**:
- Significant dependency (ActiveRecord/Sequel + database)
- Poor experience for simple use cases
- Setup complexity
- Requires database for local development

**Decision**: Rejected - Too heavy for a Ruby gem's default experience.

## Implementation Notes

### Phase 1: Interface and File Adapter (High Priority)

**Tasks:**
1. Define `AgentStorageAdapter` module interface
2. Rename `PersistentAgentStore` to `FileStorageAdapter`
3. Implement interface in `FileStorageAdapter`
4. Add `storage_adapter` configuration
5. Create `Agentic.storage` accessor
6. Update `AgentAssemblyEngine` to use injected storage

**Estimated Effort**: 3-5 days
**Target**: v0.3.x

### Phase 2: Memory Adapter (High Priority)

**Tasks:**
1. Implement `MemoryStorageAdapter`
2. Update test suite to use memory adapter
3. Add adapter switching in test helper

**Estimated Effort**: 2-3 days
**Target**: v0.3.x

### Phase 3: Documentation (High Priority)

**Tasks:**
1. Document `AgentStorageAdapter` interface
2. Write adapter development guide
3. Add storage configuration examples
4. Document file adapter defaults

**Estimated Effort**: 2 days
**Target**: v0.3.x

### Phase 4: Future Adapters (Low Priority - As Needed)

**Redis Adapter (if needed):**
- Estimated Effort: 1 week
- Dependencies: `redis` gem
- Use Cases: Shared agent repositories, distributed systems

**Database Adapter (if needed):**
- Estimated Effort: 1-2 weeks
- Dependencies: `activerecord` or `sequel`
- Use Cases: Enterprise deployments, complex queries

**S3 Adapter (if needed):**
- Estimated Effort: 3-5 days
- Dependencies: `aws-sdk-s3`
- Use Cases: Cloud-native applications, serverless

### Testing Strategy

1. **Interface Compliance Tests**: Shared test suite ensuring all adapters implement interface correctly
2. **Adapter-Specific Tests**: Unit tests for each adapter's implementation details
3. **Integration Tests**: End-to-end tests with different adapters
4. **Migration Tests**: Tests for moving data between adapters

### Migration Strategy

When users need to switch storage backends:

```ruby
# Migration utility (future)
module Agentic
  module Storage
    class Migrator
      def self.migrate(from:, to:)
        from_adapter = create_adapter(from)
        to_adapter = create_adapter(to)

        agents = from_adapter.list_all
        agents.each do |agent_meta|
          agent = from_adapter.build_agent(agent_meta[:id])
          to_adapter.store(agent,
            name: agent_meta[:name],
            metadata: agent_meta[:metadata])
        end
      end
    end
  end
end
```

### Configuration Examples

```ruby
# File storage (default)
Agentic.configure do |config|
  config.storage_adapter = :file
  config.storage_options = {
    base_path: "/var/lib/agentic/agents"
  }
end

# Memory storage (testing)
Agentic.configure do |config|
  config.storage_adapter = :memory
end

# Redis storage (future)
Agentic.configure do |config|
  config.storage_adapter = :redis
  config.storage_options = {
    redis_url: ENV["REDIS_URL"],
    ttl: 86400
  }
end

# Database storage (future)
Agentic.configure do |config|
  config.storage_adapter = :database
  config.storage_options = {
    connection: ActiveRecord::Base.connection
  }
end

# Custom adapter
Agentic.configure do |config|
  config.storage_adapter = MyCustomStorageAdapter
  config.storage_options = {
    custom_option: "value"
  }
end
```

## Related ADRs

- ADR-015: Persistent Agent Store (original file-based implementation)
- ADR-016: Agent Assembly Engine (primary consumer of storage interface)
- ADR-019: Agent Assembly Learning Integration (learning may need cross-deployment storage)
- ADR-022: Agent Versioning Simplification (storage format affected by versioning approach)

## Future Considerations

### Storage Adapter Registry

As more adapters are developed:

```ruby
module Agentic
  module Storage
    class AdapterRegistry
      def self.register(name, adapter_class)
        @adapters ||= {}
        @adapters[name] = adapter_class
      end

      def self.get(name)
        @adapters[name]
      end
    end
  end
end
```

### Async Storage Operations

For high-performance scenarios:

```ruby
module Agentic
  module Storage
    module AsyncStorageAdapter
      # Non-blocking variants
      def store_async(agent, name: nil, metadata: {})
        # Return a future/promise
      end

      def build_agent_async(id_or_name, version: nil)
        # Return a future/promise
      end
    end
  end
end
```

### Storage Plugins

External adapter gems:

```
agentic-storage-postgresql
agentic-storage-mongodb
agentic-storage-s3
agentic-storage-gcs
```

### Caching Layer

For frequently accessed agents:

```ruby
module Agentic
  module Storage
    class CachedStorageAdapter
      include AgentStorageAdapter

      def initialize(backend:, cache:)
        @backend = backend
        @cache = cache
      end

      def build_agent(id_or_name, version: nil)
        cache_key = "agent:#{id_or_name}:#{version}"

        @cache.fetch(cache_key) do
          @backend.build_agent(id_or_name, version: version)
        end
      end
    end
  end
end
```

### Storage Metrics

Track storage performance:

```ruby
module Agentic
  module Storage
    module Instrumented
      def store(agent, name: nil, metadata: {})
        start = Time.now
        result = super
        duration = Time.now - start

        Agentic.metrics.record(
          "storage.store.duration",
          duration,
          adapter: self.class.name
        )

        result
      end
    end
  end
end
```

## Success Criteria

The abstraction is successful if:

1. **No Breaking Changes**: Existing code continues working without modification
2. **Testing Improvement**: Test suite runs faster with memory adapter
3. **Alternative Implementations**: At least one non-file adapter implemented by v0.5.0
4. **Community Adoption**: Third-party storage adapters emerge
5. **Performance Neutral**: Abstraction adds <5% overhead vs. direct implementation
