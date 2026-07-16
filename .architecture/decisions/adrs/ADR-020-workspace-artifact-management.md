# ADR-020: Workspace and Artifact Management with Graph-Based References

## Status

**Status**: Proposed
**Date**: 2026-01-05
**Decision Makers**: Architecture Team
**Related**: Architecture review workspace-and-artifact-management-with-graph-based-references.md

## Context

Users want to generate multi-file projects (e.g., a complete Ruby gem, React application) rather than just JSON descriptions. Current system produces text/JSON outputs only. Recent execution (result-20260105_123828.json) showed agents generating code descriptions instead of actual files, with Task 6 failing because it couldn't access outputs from Tasks 1-5.

Key insight: **Task dependencies aren't necessarily linear. Artifacts should be referential (graph-based).**

Example: `UserService.rb` references `User.rb`, and `UserController.rb` references `UserService.rb`. These relationships exist regardless of which tasks created them or in what order.

## Decision

We will implement two core features:

###1. Workspace Management

A `Workspace` provides an isolated directory for artifact generation with:
- Security boundaries (path validation, size limits)
- Lifecycle management (create, use, cleanup)
- Integration with existing ObservabilityEngine

###2. Artifact Management with Graph-Based References

An `Artifact` represents generated content with:
- Type (ruby_class, javascript_module, etc.)
- Content
- References to other artifacts (graph edges)
- Metadata

An `ArtifactGraph` manages relationships using RGL (Ruby Graph Library):
- Add/query artifacts
- Resolve dependencies
- Detect circular references
- Topological sorting

## Architecture

### Core Classes

```ruby
class Workspace
  attr_reader :id, :path, :metadata, :artifact_graph

  def initialize(path, options = {})
    @id = SecureRandom.uuid
    @path = validate_and_create_path(path)
    @metadata = build_metadata(options)
    @artifact_graph = ArtifactGraph.new
  end

  def add_artifact(artifact)
    validate_artifact(artifact) # Security checks
    @artifact_graph.add_node(artifact)
    write_artifact_to_filesystem(artifact)
    notify_observers(:artifact_added, artifact)
  end

  def find_artifact(name:, type: nil)
    @artifact_graph.find_node(name: name, type: type)
  end

  def cleanup
    return if @metadata[:persistent]
    FileUtils.rm_rf(@path) if Dir.exist?(@path)
  end
end

class Artifact
  attr_reader :name, :type, :path, :content, :references, :metadata

  def initialize(name:, type:, content:, references: [], metadata: {})
    @name = name
    @type = type
    @content = content
    @references = references # Array of artifact names
    @metadata = metadata
  end

  def self.detect_references(content, type)
    case type
    when :ruby_class
      content.scan(/require_relative ['"](.+)['"]/).flatten
    when :javascript_module
      content.scan(/import .+ from ['"](.+)['"]/).flatten
    else
      []
    end
  end
end

class ArtifactGraph
  include Enumerable

  def initialize
    @graph = RGL::DirectedAdjacencyGraph.new
    @artifacts = {}
  end

  def add_node(artifact)
    @artifacts[artifact.name] = artifact
    @graph.add_vertex(artifact.name)
    artifact.references.each { |ref| @graph.add_edge(artifact.name, ref) }
  end

  def dependencies_of(artifact)
    name = artifact.is_a?(String) ? artifact : artifact.name
    @graph.adjacent_vertices(name).map { |n| @artifacts[n] }.compact
  end

  def detect_cycles
    @graph.strongly_connected_components.select { |c| c.size > 1 }
  end

  def topological_sort
    @graph.topsort_iterator.to_a.map { |n| @artifacts[n] }.compact
  end
end
```

### Integration with Task System

```ruby
class Task
  attr_accessor :workspace # Optional

  def perform(agent)
    result = agent.execute(self)

    if @workspace && result.respond_to?(:artifacts)
      result.artifacts.each { |artifact| @workspace.add_artifact(artifact) }
    end

    result
  end
end
```

### Security Validation

```ruby
class Workspace
  MAX_SIZE_BYTES = 100 * 1024 * 1024 # 100MB
  ALLOWED_EXTENSIONS = %w[.rb .js .py .json .md .txt .yml].freeze

  private

  def validate_artifact(artifact)
    # Path traversal prevention
    raise SecurityError, "Invalid name" if artifact.name.include?('..')
    raise SecurityError, "Invalid name" if artifact.name.start_with?('/')

    # Extension whitelist
    ext = File.extname(artifact.name)
    raise SecurityError, "Disallowed extension" unless ALLOWED_EXTENSIONS.include?(ext)

    # Size limits
    raise SecurityError, "Too large" if artifact.content.bytesize > 10.megabytes
    raise SecurityError, "Workspace full" if workspace_size_exceeds_limit?

    # Content validation
    Security::Sanitizer.sanitize_file_content(artifact.content, artifact.type)
  end
end
```

## Consequences

### Positive

- **Graph Model Matches Reality**: File references are naturally graph-based, not linear
- **Decouples Task Order from Artifact Relationships**: Tasks can execute in any order; graph captures actual dependencies
- **Security Boundaries**: Workspace provides clear isolation for file operations
- **Verification Integration**: Can validate artifacts after generation (syntax, linting, references)
- **Observable Integration**: Leverages existing event system for workspace/artifact lifecycle
- **Ruby Ecosystem Fit**: Uses RGL (mature graph library), idiomatic patterns

### Negative

- **Added Complexity**: Graph model more complex than linear dependencies
- **Security Critical**: File writing requires careful validation (implemented)
- **Testing Surface**: More test coverage needed for graph operations
- **Memory Usage**: Large workspaces (1000+ files) need monitoring

### Neutral

- **Three New Classes**: Workspace, Artifact, ArtifactGraph (contained scope)
- **Optional Integration**: Task.workspace is optional - backward compatible
- **Learning Curve**: Developers need to understand graph model

## Implementation Plan

**Week 1: Core Classes**
- Workspace with security validation
- Artifact with reference detection
- ArtifactGraph using RGL
- Comprehensive tests (>90% coverage)

**Week 2: Integration**
- Task.workspace attribute
- Agent workspace awareness
- Security::Sanitizer extensions
- Observable events

**Week 3: Polish**
- CLI --workspace option
- file_generation capability
- ArtifactVerificationStrategy
- Documentation

## Alternatives Considered

### 1. Linear Task Dependencies

**Approach**: Tasks pass outputs as inputs to next task.

**Rejected because**: 
- Doesn't match how files reference each other
- Forces artificial task ordering
- Can't represent many-to-many relationships
- Doesn't solve multi-file generation within single task

### 2. No Workspace Abstraction

**Approach**: Tasks write directly to filesystem, no container.

**Rejected because**:
- No security boundary
- No artifact relationship tracking
- No lifecycle management
- No cleanup mechanism

### 3. Separate ArtifactTask Class

**Approach**: Create ArtifactTask < Task subclass.

**Rejected because**:
- Unnecessary abstraction
- Forces type checking everywhere
- Optional workspace attribute is cleaner
- Violates YAGNI

## References

- Previous artifact system design (archived to docs/future/artifact-system/)
- Architecture review: artifact-generation-system---documentation-vs-implementation-gap-analysis-COMPLETE.md
- RGL (Ruby Graph Library): https://github.com/monora/rgl

## Notes

User explicitly requested graph-based artifact references instead of linear task dependencies. This is a sound architectural decision that matches the domain (file systems have graph-like reference structures, not linear chains).

Security is mandatory and implemented upfront - no file writing without validation.
