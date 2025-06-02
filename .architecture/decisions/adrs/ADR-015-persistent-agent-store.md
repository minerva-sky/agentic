# ADR-015: Persistent Agent Store

## Status

Accepted

## Context

To enable more efficient agent reuse and evolution, we need a mechanism to persistently store and retrieve agent configurations. This system should support:

1. Storing complete agent configurations, including capabilities
2. Retrieving agents by ID or name
3. Versioning agent configurations as they evolve
4. Filtering and searching for suitable agents based on capabilities or metadata
5. Tracking agent provenance and usage history

Without a persistent store, agents must be recreated from scratch for each task, even when similar agents have been previously assembled. This leads to inefficiency and missed opportunities for improvement through agent evolution.

## Decision

We will implement a `PersistentAgentStore` class that handles agent storage and retrieval. The store will:

1. Use a file-based storage system with a configurable storage path
2. Support semantic versioning for agent configurations
3. Maintain an in-memory index for efficient lookup
4. Store agent configurations as structured JSON
5. Support rich filtering and querying capabilities

Key operations:

```ruby
# Store an agent
store.store(agent, name: "my_agent", metadata: { category: "research" })

# Build an agent from stored configuration
store.build_agent("my_agent")  # By name
store.build_agent(agent_id)    # By ID
store.build_agent(id, version: "1.2.0")  # Specific version

# List and filter agents
store.list_all()  # All agents
store.all(filter: { capability: "web_search" })  # With specific capability
store.all(filter: { metadata: { category: "research" } })  # With metadata

# Get version history
store.version_history(agent_id)

# Delete agents
store.delete(agent_id)
store.delete(agent_id, version: "1.0.0")  # Specific version
```

We will use the following design:
- File-based storage with one directory per agent
- Each version stored as a separate JSON file
- An index file for quick lookup without loading all agent files
- Agent data will include capabilities, metadata, and configuration

## Consequences

### Positive

1. Enables reuse of previously assembled agents for similar tasks
2. Supports agent evolution through versioning
3. Provides rich filtering for agent discovery
4. Maintains complete agent provenance for auditing
5. Simplifies integration with agent assembly system

### Negative

1. File-based storage has scalability limitations
2. Limited transactional support compared to databases
3. Requires additional synchronization in multi-process scenarios
4. Increases code complexity with versioning logic

### Neutral

1. Requires filesystem access for storage
2. Creates dependency on JSON serialization format
3. May require migration strategies for major version changes

## Implementation Notes

The store will create a directory structure like:

```
storage_path/
  index.json           # Main index with all agents
  agent_id_1/
    1.0.0.json         # First version
    1.0.1.json         # Second version
  agent_id_2/
    1.0.0.json         # First version
```

The index will contain minimal information for quick lookups, while the full agent configuration will be stored in the version-specific files. The store will automatically rebuild the index if it becomes out of sync with the filesystem.

For thread safety, file operations will use appropriate locking mechanisms. The store will gracefully handle partial or corrupted data through validation and error recovery.

To support multiple storage backends in the future, the implementation will follow a repository pattern with a clear interface for storage operations.