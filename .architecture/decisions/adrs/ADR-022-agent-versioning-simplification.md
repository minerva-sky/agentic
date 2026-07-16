# ADR-022: Agent Versioning Simplification

## Status

Accepted

## Context

The current agent storage system implements **semantic versioning** (SemVer) for stored agents, using version numbers like "1.0.0", "1.0.1", "1.2.0" with automatic version incrementing based on changes.

Current implementation:
- Agents stored with semantic versions (major.minor.patch)
- Version auto-incremented when agent stored again
- Version history tracked with timestamps
- Users can retrieve specific versions or latest
- Storage path: `~/.agentic/agents/{agent_id}/{version}.json`

Example:
```
~/.agentic/agents/
└── abc-123-def/
    ├── 1.0.0.json (2024-05-01T10:00:00Z)
    ├── 1.0.1.json (2024-05-02T14:30:00Z)
    └── 1.1.0.json (2024-05-03T09:15:00Z)
```

Architecture review findings:

**Pragmatic Enforcer (YAGNI Guardian):**
- **Critical Question**: "Do users actually need version management?"
- No evidence of version conflict scenarios
- Semantic versioning adds complexity without demonstrated value
- Simpler approaches (timestamps) may be sufficient

**Sam Rodriguez (Maintainability):**
- Magic numbers: Version incrementing logic scattered through code
- Complex version comparison and selection logic
- Unclear semantics: What constitutes a major vs. minor vs. patch change?

**Jordan Lee (Performance):**
- Version string parsing adds overhead
- Version selection requires sorting and comparison logic

**Consensus Decision:**
- Keep versioning (useful for debugging and history)
- Simplify from semantic versioning to timestamps
- Remove version increment complexity

Problems with current semantic versioning:

1. **Ambiguous Semantics**: No clear rules for when to increment major vs. minor vs. patch
2. **Manual Tracking Burden**: Users or system must decide version significance
3. **Comparison Complexity**: Semantic version comparison more complex than timestamp comparison
4. **Auto-Increment Issues**: Automatic incrementing can create confusing version jumps
5. **Conflict Potential**: Parallel agent creation can create version conflicts
6. **Over-Engineering**: Full SemVer machinery (pre-release, build metadata) unused

Benefits retained from versioning:
- **History Tracking**: Ability to see how agent evolved over time
- **Rollback**: Ability to retrieve previous agent versions
- **Debugging**: Understanding which agent version produced specific results
- **Auditing**: Tracking when agents were created/modified

## Decision

We will **replace semantic versioning with ISO 8601 timestamp-based versioning** for agent storage.

### 1. Timestamp-Based Version Format

Use ISO 8601 UTC timestamps as version identifiers:

```ruby
# Old: Semantic version
version = "1.0.0"

# New: ISO 8601 timestamp
version = "2025-11-11T14:30:00.123456Z"
```

Timestamp format specification:
- **Format**: `YYYY-MM-DDTHH:MM:SS.ffffffZ`
- **Timezone**: Always UTC (Z suffix)
- **Precision**: Microseconds (6 decimal places)
- **Sorting**: Natural string sorting gives chronological order
- **Uniqueness**: Microsecond precision prevents collisions

### 2. Updated Storage Structure

```ruby
class FileStorageAdapter
  def store(agent, name: nil, metadata: {})
    agent_id = agent.id || SecureRandom.uuid
    version = generate_version_timestamp

    agent_dir = File.join(@base_path, agent_id)
    FileUtils.mkdir_p(agent_dir)

    agent_file = File.join(agent_dir, "#{version}.json")

    agent_data = {
      id: agent_id,
      name: name || generate_agent_name,
      version: version,
      timestamp: Time.now.utc.iso8601(6),
      agent: serialize_agent(agent),
      capabilities: extract_capabilities(agent),
      metadata: metadata
    }

    File.write(agent_file, JSON.pretty_generate(agent_data))

    update_index(agent_id, agent_data)

    agent_id
  end

  private

  def generate_version_timestamp
    Time.now.utc.iso8601(6)
  end
end
```

### 3. Version Comparison Simplification

```ruby
# Old: Semantic version comparison
def compare_versions(v1, v2)
  Gem::Version.new(v1) <=> Gem::Version.new(v2)
end

def latest_version(versions)
  versions.map { |v| Gem::Version.new(v) }.max.to_s
end

# New: String comparison (timestamps naturally sort)
def compare_versions(v1, v2)
  v1 <=> v2  # Direct string comparison
end

def latest_version(versions)
  versions.max  # Simple max on strings
end
```

### 4. Updated API

Agent retrieval remains the same, but internal implementation simplified:

```ruby
# Retrieve latest version (implicit)
agent = storage.build_agent("agent_id")

# Retrieve specific version
agent = storage.build_agent("agent_id", version: "2025-11-11T14:30:00.123456Z")

# List version history
history = storage.version_history("agent_id")
# Returns:
# [
#   {version: "2025-11-11T14:30:00.123456Z", timestamp: ...},
#   {version: "2025-11-10T09:15:30.789012Z", timestamp: ...},
#   ...
# ]
```

### 5. Human-Readable Version Display

For CLI and UI display, provide helper to format timestamps:

```ruby
module Agentic
  module Storage
    module VersionFormatter
      def self.format_version(version_timestamp)
        time = Time.parse(version_timestamp)

        {
          timestamp: version_timestamp,
          date: time.strftime("%Y-%m-%d"),
          time: time.strftime("%H:%M:%S"),
          relative: format_relative_time(time),
          sortable: version_timestamp
        }
      end

      def self.format_relative_time(time)
        seconds = Time.now.utc - time

        case seconds
        when 0..59
          "#{seconds.to_i} seconds ago"
        when 60..3599
          "#{(seconds / 60).to_i} minutes ago"
        when 3600..86399
          "#{(seconds / 3600).to_i} hours ago"
        when 86400..604799
          "#{(seconds / 86400).to_i} days ago"
        else
          time.strftime("%Y-%m-%d")
        end
      end
    end
  end
end
```

CLI output example:
```
$ agentic agents version-history my-agent
Version History for: my-agent

2025-11-11 14:30:00 (5 minutes ago)
2025-11-11 09:15:30 (5 hours ago)
2025-11-10 16:45:12 (yesterday)
2025-11-09 10:30:00 (2 days ago)
```

### 6. Migration Path

Provide migration utility for existing semantic-versioned agents:

```ruby
module Agentic
  module Storage
    class VersionMigrator
      def self.migrate_to_timestamps(storage_path)
        agents = load_all_agents(storage_path)

        agents.each do |agent_dir|
          versions = Dir.glob(File.join(agent_dir, "*.json"))

          versions.each do |version_file|
            # Read existing agent file
            agent_data = JSON.parse(File.read(version_file))

            # Use stored timestamp as new version
            timestamp = agent_data["timestamp"]
            new_version = timestamp || infer_timestamp_from_mtime(version_file)

            # Rename file to timestamp-based name
            new_filename = "#{new_version}.json"
            new_path = File.join(File.dirname(version_file), new_filename)

            # Update version field in data
            agent_data["version"] = new_version

            # Write to new file
            File.write(new_path, JSON.pretty_generate(agent_data))

            # Delete old file if different
            File.delete(version_file) unless version_file == new_path
          end

          puts "Migrated: #{agent_dir}"
        end
      end

      private

      def self.infer_timestamp_from_mtime(file_path)
        File.mtime(file_path).utc.iso8601(6)
      end
    end
  end
end

# Usage
Agentic::Storage::VersionMigrator.migrate_to_timestamps(
  File.join(Dir.home, ".agentic", "agents")
)
```

## Consequences

### Positive

1. **Simplicity**: String comparison replaces complex semantic version parsing
2. **Clarity**: Timestamps convey exact creation time, not subjective significance
3. **Natural Sorting**: Chronological order without custom comparison logic
4. **No Ambiguity**: Clear meaning (when agent was created), no judgment calls
5. **Performance**: Faster comparison and sorting
6. **Reduced Code**: Remove version increment, comparison, and parsing logic
7. **Better Debugging**: Exact timestamps more useful than abstract version numbers
8. **Collision Resistance**: Microsecond precision prevents simultaneous creation conflicts

### Negative

1. **Less Semantic Information**: Can't distinguish "major" changes from "minor" tweaks
2. **Longer Identifiers**: `2025-11-11T14:30:00.123456Z` vs. `1.0.0` (28 vs. 5 characters)
3. **Not Human-Memorable**: Can't easily remember/communicate specific versions
4. **Breaking Change**: Requires migration for existing agents
5. **Convention Break**: Deviates from common software versioning patterns

### Neutral

1. **Still Versioned**: Full history still maintained, just different format
2. **Retrieval Unchanged**: API for getting specific versions remains the same
3. **Display Impact**: CLI/UI need formatting helpers for readability

## Alternatives Considered

### Alternative 1: Keep Semantic Versioning

**Approach**: Maintain current SemVer implementation

**Pros**:
- No migration required
- Familiar to developers
- Semantic information preserved
- Industry standard

**Cons**:
- Complexity without demonstrated value
- Ambiguous increment rules
- Comparison overhead
- Conflict potential

**Decision**: Rejected - Complexity not justified by benefits.

### Alternative 2: Simple Integer Sequences

**Approach**: Use incrementing integers (1, 2, 3, ...)

**Pros**:
- Very simple
- Short identifiers
- Easy to remember
- Easy to compare

**Cons**:
- No temporal information
- Requires counter management
- Conflict potential in distributed scenarios
- Loses timestamp information

**Decision**: Rejected - Timestamps provide more value for debugging.

### Alternative 3: No Versioning

**Approach**: Single version per agent, overwrite on store

**Pros**:
- Simplest possible
- No version management at all
- Smallest storage footprint

**Cons**:
- Loses history
- No rollback capability
- Poor debugging experience
- Risky for production

**Decision**: Rejected - Version history is valuable for debugging and auditing.

### Alternative 4: Hybrid Approach

**Approach**: Timestamps internally, optional semantic labels

```ruby
storage.store(agent, version_label: "v1.0.0")
# Stored as: 2025-11-11T14:30:00.123456Z
# Labeled as: v1.0.0
```

**Pros**:
- Best of both worlds
- Flexibility for users who want semantic versions
- Timestamps for sorting, labels for communication

**Cons**:
- Increased complexity
- Adds optional field to track
- May confuse users

**Decision**: Deferred - Can add labels later if demand emerges.

### Alternative 5: Content-Addressed Versions

**Approach**: Use hash of agent content as version (like Git)

```ruby
version = Digest::SHA256.hexdigest(agent.to_json)[0..16]
```

**Pros**:
- Deterministic
- Deduplication
- Content-based identity

**Cons**:
- No temporal information
- Cryptic identifiers
- Harder to understand history

**Decision**: Rejected - Temporal information more important than content addressing.

## Implementation Notes

### Phase 1: Core Implementation (Medium Priority)

**Tasks:**
1. Update `FileStorageAdapter` to generate timestamp versions
2. Remove semantic version increment logic
3. Update version comparison methods
4. Update version retrieval logic
5. Add version formatter helpers

**Estimated Effort**: 2-3 days
**Target**: v0.3.x

### Phase 2: Migration Tool (Medium Priority)

**Tasks:**
1. Implement `VersionMigrator`
2. Add rollback capability
3. Test with existing agent stores
4. Document migration process

**Estimated Effort**: 1-2 days
**Target**: v0.3.x

### Phase 3: CLI Updates (Low Priority)

**Tasks:**
1. Update CLI commands to display formatted timestamps
2. Add relative time formatting
3. Update documentation and examples

**Estimated Effort**: 1 day
**Target**: v0.3.x

### Testing Strategy

1. **Unit Tests**: Timestamp generation, comparison, formatting
2. **Integration Tests**: Store and retrieve with timestamp versions
3. **Migration Tests**: Verify migration from SemVer to timestamps
4. **Backward Compatibility Tests**: Ensure API contracts maintained

### Backward Compatibility

**API Compatibility**: Maintained
```ruby
# These calls work identically before and after change
agent = storage.build_agent("agent_id")
agent = storage.build_agent("agent_id", version: version_string)
history = storage.version_history("agent_id")
```

**Storage Format**: Requires migration
- Provide migration tool
- Document migration process
- Support reading both formats during transition (v0.3.x)
- Remove SemVer support in v0.4.0

### Migration Strategy

**v0.3.x Release:**
1. Introduce timestamp versioning as new format
2. Maintain backward compatibility with SemVer reading
3. All new agents stored with timestamp versions
4. Provide migration tool
5. Warn when reading old SemVer agents

**v0.3.x → v0.4.0 Transition:**
1. Encourage users to migrate
2. Provide migration documentation and tooling
3. Continue reading both formats

**v0.4.0 Release:**
1. Timestamp versioning only
2. Remove SemVer reading support
3. Migration required for old agents

### Documentation Requirements

1. **Migration Guide**: Step-by-step migration from SemVer to timestamps
2. **Version Format Specification**: Detailed timestamp format documentation
3. **API Changes**: Document any API differences (should be none)
4. **Best Practices**: When/why to retrieve specific versions
5. **Troubleshooting**: Common migration issues and solutions

## Related ADRs

- ADR-015: Persistent Agent Store (original storage implementation with SemVer)
- ADR-021: Agent Storage Abstraction (storage interface affected by versioning)
- ADR-019: Agent Assembly Learning Integration (learning may benefit from simpler versioning)

## Future Considerations

### Version Labels (Optional)

If users request semantic labels:

```ruby
storage.store(agent, label: "production-release")
storage.store(agent, label: "v1.0.0")

agent = storage.build_agent("agent_id", label: "production-release")
```

Internally still timestamp-based, labels are metadata.

### Version Tags

Similar to Git tags:

```ruby
storage.tag_version("agent_id", "2025-11-11T14:30:00.123456Z", tag: "stable")
agent = storage.build_agent("agent_id", tag: "stable")
```

### Version Annotations

Rich metadata for versions:

```ruby
{
  version: "2025-11-11T14:30:00.123456Z",
  timestamp: "2025-11-11T14:30:00.123456Z",
  author: "user@example.com",
  message: "Improved web search capabilities",
  changes: {
    added_capabilities: ["advanced_search"],
    removed_capabilities: ["basic_search"],
    modified_metadata: {...}
  }
}
```

### Version Comparison Helpers

For convenience:

```ruby
module Agentic
  module Storage
    module VersionComparison
      def self.between(start_version, end_version, agent_id)
        # Return all versions between two timestamps
      end

      def self.since(version, agent_id)
        # Return all versions since a timestamp
      end

      def self.latest_n(n, agent_id)
        # Return n most recent versions
      end
    end
  end
end
```

## Success Criteria

The simplification is successful if:

1. **Code Reduction**: 100+ lines of version management code removed
2. **Performance Improvement**: Version operations 20%+ faster
3. **No API Breaking Changes**: Existing code continues working
4. **Smooth Migration**: 95%+ of agents migrate successfully
5. **Improved Debuggability**: Developers report timestamps more useful than SemVer
6. **Community Acceptance**: No significant pushback on change
