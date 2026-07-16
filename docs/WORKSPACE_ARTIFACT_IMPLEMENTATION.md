# Workspace and Artifact Management Implementation Guide

## Overview

This guide provides step-by-step instructions for implementing workspace and artifact management with graph-based references in the Agentic framework.

## Architecture

See **ADR-020: Workspace and Artifact Management with Graph-Based References** for full architectural rationale.

### Key Concepts

1. **Workspace**: Isolated directory for artifact generation with security boundaries
2. **Artifact**: Generated file content with type, references, and metadata
3. **ArtifactGraph**: Graph structure managing artifact relationships using RGL

### Graph-Based References

Unlike linear task dependencies, artifacts form a **directed graph** of references:

```
User.rb
  ↑
  |
UserService.rb  →  UserRepository.rb
  ↑
  |
UserController.rb
```

This structure exists **independent of task execution order**.

## Implementation Phases

### Phase 1: Core Classes (Week 1, 5-6 days)

#### Day 1-2: Workspace Class

**File**: `lib/agentic/workspace.rb`

```ruby
# frozen_string_literal: true

require "securerandom"
require "fileutils"

module Agentic
  # Manages an isolated workspace for artifact generation
  #
  # @example
  #   workspace = Workspace.new("/tmp/my_project")
  #   workspace.add_artifact(artifact)
  #   workspace.cleanup
  class Workspace
    include Observable

    attr_reader :id, :path, :metadata, :artifact_graph

    # Maximum workspace size in bytes (100MB)
    MAX_SIZE_BYTES = 100 * 1024 * 1024

    # Allowed file extensions for security
    ALLOWED_EXTENSIONS = %w[.rb .js .py .json .md .txt .yml .yaml .css .html].freeze

    # Initialize a new workspace
    # @param path [String] Directory path for the workspace
    # @param options [Hash] Configuration options
    # @option options [Boolean] :persistent Keep workspace after cleanup
    # @option options [Array<String>] :allowed_extensions Additional allowed extensions
    def initialize(path, options = {})
      @id = SecureRandom.uuid
      @path = validate_and_create_path(path)
      @metadata = build_metadata(options)
      @artifact_graph = ArtifactGraph.new
      @created_at = Time.now

      notify_observers(:workspace_created, workspace_id: @id, path: @path)
    end

    # Add an artifact to the workspace
    # @param artifact [Artifact] The artifact to add
    # @return [Artifact] The added artifact
    def add_artifact(artifact)
      validate_artifact(artifact)

      @artifact_graph.add_node(artifact)
      write_artifact_to_filesystem(artifact)

      notify_observers(:artifact_added, {
        workspace_id: @id,
        artifact_name: artifact.name,
        artifact_type: artifact.type
      })

      artifact
    end

    # Find an artifact by name and optionally type
    # @param name [String] Artifact name
    # @param type [Symbol, nil] Optional artifact type filter
    # @return [Artifact, nil] Found artifact or nil
    def find_artifact(name:, type: nil)
      @artifact_graph.find_node(name: name, type: type)
    end

    # Get artifacts that reference the given artifact
    # @param artifact [Artifact, String] Artifact or artifact name
    # @return [Array<Artifact>] Dependent artifacts
    def artifacts_referencing(artifact)
      @artifact_graph.dependents_of(artifact)
    end

    # Get artifacts referenced by the given artifact
    # @param artifact [Artifact, String] Artifact or artifact name
    # @return [Array<Artifact>] Dependency artifacts
    def artifacts_referenced_by(artifact)
      @artifact_graph.dependencies_of(artifact)
    end

    # Clean up workspace (remove directory)
    # Does nothing if workspace is persistent
    def cleanup
      return if @metadata[:persistent]

      notify_observers(:workspace_cleanup_started, workspace_id: @id)

      FileUtils.rm_rf(@path) if Dir.exist?(@path)

      notify_observers(:workspace_cleaned, workspace_id: @id)
    end

    # Get current workspace size in bytes
    # @return [Integer] Total size of all artifacts
    def size
      @artifact_graph.sum { |artifact| artifact.content.bytesize }
    end

    private

    def validate_and_create_path(path)
      # Ensure absolute path
      abs_path = File.expand_path(path)

      # Create directory if it doesn't exist
      FileUtils.mkdir_p(abs_path) unless Dir.exist?(abs_path)

      abs_path
    end

    def build_metadata(options)
      {
        persistent: options[:persistent] || false,
        allowed_extensions: options[:allowed_extensions] || [],
        created_at: Time.now,
        created_by: "agentic"
      }
    end

    def validate_artifact(artifact)
      # Path traversal prevention
      if artifact.name.include?("..") || artifact.name.start_with?("/")
        raise SecurityError, "Invalid artifact name: path traversal detected"
      end

      # Extension whitelist
      ext = File.extname(artifact.name)
      allowed = ALLOWED_EXTENSIONS + (@metadata[:allowed_extensions] || [])

      unless allowed.include?(ext)
        raise SecurityError, "Disallowed file extension: #{ext}"
      end

      # Artifact size limit
      if artifact.content.bytesize > 10 * 1024 * 1024 # 10MB per file
        raise SecurityError, "Artifact too large: #{artifact.content.bytesize} bytes"
      end

      # Workspace size limit
      if size + artifact.content.bytesize > MAX_SIZE_BYTES
        raise SecurityError, "Workspace size limit exceeded"
      end

      # Content validation
      Security::Sanitizer.sanitize_file_content(artifact.content, artifact.type)

      # Reference validation
      artifact.references.each do |ref|
        if ref.include?("..") || ref.start_with?("/")
          raise SecurityError, "Invalid artifact reference: #{ref}"
        end
      end
    end

    def write_artifact_to_filesystem(artifact)
      full_path = File.join(@path, artifact.name)

      # Ensure parent directory exists
      FileUtils.mkdir_p(File.dirname(full_path))

      # Write with restrictive permissions
      File.write(full_path, artifact.content, mode: 0o644)

      # Audit log
      Agentic.logger.info("Artifact written: #{artifact.name} (#{artifact.content.bytesize} bytes) to workspace #{@id}")
    end
  end
end
```

**Tests**: `spec/agentic/workspace_spec.rb` (~200 lines)

#### Day 3: Artifact Class

**File**: `lib/agentic/artifact.rb`

```ruby
# frozen_string_literal: true

module Agentic
  # Represents a generated file artifact with metadata and references
  #
  # @example
  #   artifact = Artifact.new(
  #     name: "user.rb",
  #     type: :ruby_class,
  #     content: "class User; end",
  #     references: []
  #   )
  class Artifact
    attr_reader :name, :type, :content, :references, :metadata, :created_at

    # Initialize a new artifact
    # @param name [String] Filename (relative path within workspace)
    # @param type [Symbol] Artifact type (:ruby_class, :javascript_module, etc.)
    # @param content [String] File content
    # @param references [Array<String>] Names of artifacts this one references
    # @param metadata [Hash] Additional metadata
    def initialize(name:, type:, content:, references: [], metadata: {})
      @name = name
      @type = type
      @content = content
      @references = references
      @metadata = metadata
      @created_at = Time.now
    end

    # Automatically detect references from content
    # @param content [String] File content
    # @param type [Symbol] Artifact type
    # @return [Array<String>] Detected references
    def self.detect_references(content, type)
      case type
      when :ruby_class
        extract_ruby_requires(content)
      when :javascript_module
        extract_js_imports(content)
      when :python_module
        extract_python_imports(content)
      else
        []
      end
    end

    # Convert to hash for serialization
    # @return [Hash] Artifact as hash
    def to_h
      {
        name: @name,
        type: @type,
        content: @content,
        references: @references,
        metadata: @metadata,
        created_at: @created_at.iso8601
      }
    end

    private

    def self.extract_ruby_requires(content)
      # Match require_relative 'filename' or require_relative "filename"
      content.scan(/require_relative\s+['"]([^'"]+)['"]/).flatten
    end

    def self.extract_js_imports(content)
      # Match import ... from 'filename' or import ... from "filename"
      content.scan(/import\s+.+\s+from\s+['"]([^'"]+)['"]/).flatten
    end

    def self.extract_python_imports(content)
      # Match from module import or import module
      imports = content.scan(/from\s+(\S+)\s+import/).flatten
      imports += content.scan(/import\s+(\S+)/).flatten
      imports.uniq
    end
  end
end
```

**Tests**: `spec/agentic/artifact_spec.rb` (~150 lines)

#### Day 4: ArtifactGraph Class

**File**: `lib/agentic/artifact_graph.rb`

```ruby
# frozen_string_literal: true

require "rgl/adjacency"
require "rgl/traversal"

module Agentic
  # Manages graph of artifact relationships using RGL
  #
  # @example
  #   graph = ArtifactGraph.new
  #   graph.add_node(artifact)
  #   dependencies = graph.dependencies_of(artifact)
  class ArtifactGraph
    include Enumerable

    def initialize
      @graph = RGL::DirectedAdjacencyGraph.new
      @artifacts = {} # artifact_name => Artifact object
    end

    # Add an artifact node to the graph
    # @param artifact [Artifact] The artifact to add
    def add_node(artifact)
      @artifacts[artifact.name] = artifact
      @graph.add_vertex(artifact.name)

      # Add edges for references
      artifact.references.each do |ref_name|
        @graph.add_edge(artifact.name, ref_name)
      end
    end

    # Get artifacts that the given artifact depends on
    # @param artifact [Artifact, String] Artifact or artifact name
    # @return [Array<Artifact>] Dependency artifacts
    def dependencies_of(artifact)
      artifact_name = artifact.is_a?(String) ? artifact : artifact.name
      @graph.adjacent_vertices(artifact_name).map { |name| @artifacts[name] }.compact
    end

    # Get artifacts that depend on the given artifact
    # @param artifact [Artifact, String] Artifact or artifact name
    # @return [Array<Artifact>] Dependent artifacts
    def dependents_of(artifact)
      artifact_name = artifact.is_a?(String) ? artifact : artifact.name
      @artifacts.values.select do |a|
        @graph.adjacent_vertices(a.name).include?(artifact_name)
      end
    end

    # Detect circular dependencies
    # @return [Array<Array<String>>] Arrays of artifact names in cycles
    def detect_cycles
      cycles = []
      @graph.strongly_connected_components.each do |component|
        cycles << component if component.size > 1
      end
      cycles
    end

    # Get artifacts in topological order (dependencies before dependents)
    # @return [Array<Artifact>] Sorted artifacts
    # @raise [CircularDependencyError] If circular dependencies exist
    def topological_sort
      @graph.topsort_iterator.to_a.map { |name| @artifacts[name] }.compact
    rescue RGL::TSort::Cyclic => e
      raise CircularDependencyError, "Circular dependency detected in artifacts"
    end

    # Find artifact by name and optionally type
    # @param name [String] Artifact name
    # @param type [Symbol, nil] Optional type filter
    # @return [Artifact, nil] Found artifact or nil
    def find_node(name:, type: nil)
      artifact = @artifacts[name]
      return nil unless artifact
      return artifact if type.nil? || artifact.type == type
      nil
    end

    # Get all artifacts
    # @return [Array<Artifact>] All artifacts in graph
    def all_nodes
      @artifacts.values
    end

    # Enumerate all artifacts
    # @yieldparam artifact [Artifact]
    def each(&block)
      @artifacts.values.each(&block)
    end
  end

  # Error raised when circular dependencies are detected
  class CircularDependencyError < StandardError; end
end
```

**Gemfile addition**:
```ruby
gem "rgl", "~> 0.6"
```

**Tests**: `spec/agentic/artifact_graph_spec.rb` (~250 lines)

#### Day 5: Comprehensive Testing

- Edge cases: circular references, missing dependencies, security violations
- Performance tests: 1000+ artifacts
- Integration tests: workspace + graph together

### Phase 2: Integration (Week 2, 5-6 days)

#### Day 1: Task Integration

**Modify**: `lib/agentic/task.rb`

```ruby
class Task
  include Agentic::Observable

  attr_reader :id, :description, :agent_spec, :input, :output, :status, :failure
  attr_accessor :workspace # NEW: Optional workspace for artifacts

  # ... existing code ...

  def perform(agent)
    notify_observers(:status_change, old_status, :in_progress)
    @status = :in_progress

    result = agent.execute(self)

    # NEW: If task has workspace and result contains artifacts
    if @workspace && result.respond_to?(:artifacts)
      result.artifacts.each { |artifact| @workspace.add_artifact(artifact) }
    end

    if result.success
      @output = result.output
      @status = :completed
      notify_observers(:status_change, :in_progress, :completed)
    else
      fail_with(result.failure)
    end

    result
  end
end
```

#### Day 2: Agent Integration

**Modify**: `lib/agentic/agent.rb`

```ruby
class Agent
  def execute(task)
    workspace = task.workspace

    # Build context from workspace artifacts if available
    context = workspace ? build_workspace_context(workspace) : {}

    if task.is_a?(String)
      execute_prompt(task, context)
    else
      prompt = task.build_prompt
      execute_prompt(prompt, context)
    end
  end

  private

  def build_workspace_context(workspace)
    artifacts = workspace.artifact_graph.all_nodes

    {
      existing_artifacts: artifacts.map do |a|
        {name: a.name, type: a.type}
      end,
      existing_classes: artifacts.select { |a| a.type == :ruby_class }.map(&:name),
      existing_modules: artifacts.select { |a| a.type == :javascript_module }.map(&:name)
    }
  end
end
```

#### Day 3: Security::Sanitizer Extensions

**Modify**: `lib/agentic/security/sanitizer.rb`

```ruby
module Agentic
  module Security
    class Sanitizer
      # NEW: Sanitize file content based on type
      def self.sanitize_file_content(content, type)
        case type
        when :ruby_class
          validate_ruby_content(content)
        when :javascript_module
          validate_javascript_content(content)
        when :python_module
          validate_python_content(content)
        end

        content
      end

      private

      def self.validate_ruby_content(content)
        # Check Ruby syntax
        begin
          RubyVM::InstructionSequence.compile(content)
        rescue SyntaxError => e
          raise SecurityError, "Invalid Ruby syntax: #{e.message}"
        end

        # Scan for dangerous patterns
        RUBY_DANGEROUS_PATTERNS.each do |pattern|
          if content.match?(pattern)
            raise SecurityError, "Dangerous Ruby pattern detected: #{pattern.source}"
          end
        end
      end

      RUBY_DANGEROUS_PATTERNS = [
        /eval\(/,
        /system\(/,
        /exec\(/,
        /`[^`]+`/,
        /%x\{/,
        /File\.delete/,
        /FileUtils\.rm_rf/
      ].freeze

      def self.validate_javascript_content(content)
        # Basic checks for dangerous JS patterns
        JAVASCRIPT_DANGEROUS_PATTERNS.each do |pattern|
          if content.match?(pattern)
            raise SecurityError, "Dangerous JavaScript pattern detected: #{pattern.source}"
          end
        end
      end

      JAVASCRIPT_DANGEROUS_PATTERNS = [
        /eval\(/,
        /Function\(/,
        /innerHTML\s*=/,
        /document\.write/
      ].freeze
    end
  end
end
```

#### Day 4-5: Observable Integration and Tests

- Add workspace/artifact lifecycle hooks to ObservabilityEngine
- Integration tests for Task + Workspace + Agent
- Security integration tests

### Phase 3: CLI and Polish (Week 3, 5-6 days)

#### Day 1-2: CLI Integration

**Modify**: `lib/agentic/cli.rb`

```ruby
class CLI < Thor
  desc "plan GOAL", "Create an execution plan for a goal"
  option :workspace, type: :string, aliases: "-w",
    desc: "Workspace directory for artifact generation"
  def plan(goal)
    # ... existing setup ...

    # NEW: Create workspace if requested
    workspace = nil
    if options[:workspace]
      workspace_path = File.expand_path(options[:workspace])
      workspace = Workspace.new(workspace_path, persistent: true)
      puts "Created workspace: #{workspace_path}"
    end

    # ... existing planning logic ...

    # Store workspace info in plan if created
    plan_data[:workspace_id] = workspace.id if workspace
    plan_data[:workspace_path] = workspace.path if workspace

    # Save plan...
  end

  desc "execute", "Execute a plan"
  def execute
    # ... load plan ...

    # NEW: Load workspace if plan has one
    workspace = nil
    if plan_data[:workspace_path]
      workspace = Workspace.new(plan_data[:workspace_path], persistent: true)
      puts "Using workspace: #{workspace.path}"
    end

    # ... execution ...

    # NEW: Display artifact summary if workspace exists
    if workspace
      display_artifact_summary(workspace)
    end
  end

  private

  def display_artifact_summary(workspace)
    artifacts = workspace.artifact_graph.all_nodes

    puts "\n#{UI.colorize('═' * 60, :blue)}"
    puts UI.colorize(' GENERATED ARTIFACTS', :blue)
    puts UI.colorize('═' * 60, :blue)

    artifacts.group_by(&:type).each do |type, type_artifacts|
      puts "\n#{UI.colorize(type.to_s.tr('_', ' ').capitalize, :cyan)}:"
      type_artifacts.each do |artifact|
        size = artifact.content.bytesize
        refs = artifact.references.empty? ? "" : " (refs: #{artifact.references.join(', ')})"
        puts "  #{UI.colorize('✓', :green)} #{artifact.name} (#{size} bytes)#{refs}"
      end
    end

    puts "\n#{UI.colorize("Total: #{artifacts.size} artifacts", :blue)}"
    puts UI.colorize('═' * 60, :blue)
  end
end
```

#### Day 3: Capability Registration

**Modify**: `lib/agentic/agent_capability_registry.rb`

```ruby
# Register file_generation capability
AgentCapabilityRegistry.instance.register(
  AgentCapability.new(
    name: "file_generation",
    version: "1.0.0",
    description: "Generate and manage file artifacts in workspaces",
    metadata: {
      supported_types: [:ruby_class, :javascript_module, :python_module, :config_file, :markdown_doc],
      supports_references: true,
      workspace_aware: true
    }
  )
)
```

#### Day 4: Basic Verification Strategy

**File**: `lib/agentic/verification/artifact_verification_strategy.rb`

```ruby
module Agentic
  module Verification
    class ArtifactVerificationStrategy < VerificationStrategy
      def verify(task, result)
        return super unless task.workspace

        workspace = task.workspace
        artifacts = workspace.artifact_graph.all_nodes

        # Verify each artifact
        verifications = artifacts.map { |artifact| verify_artifact(artifact, workspace) }

        VerificationResult.new(
          task_id: task.id,
          success: verifications.all?(&:success),
          confidence: calculate_average_confidence(verifications),
          details: {
            artifacts_verified: artifacts.size,
            passed: verifications.count(&:success),
            failed: verifications.count { |v| !v.success }
          }
        )
      end

      private

      def verify_artifact(artifact, workspace)
        case artifact.type
        when :ruby_class
          verify_ruby_syntax(artifact)
        when :javascript_module
          verify_javascript_syntax(artifact)
        else
          basic_verification(artifact)
        end
      end

      def verify_ruby_syntax(artifact)
        RubyVM::InstructionSequence.compile(artifact.content)
        VerificationResult.new(
          task_id: "artifact_#{artifact.name}",
          success: true,
          confidence: 1.0,
          details: {artifact: artifact.name, check: "ruby_syntax"}
        )
      rescue SyntaxError => e
        VerificationResult.new(
          task_id: "artifact_#{artifact.name}",
          success: false,
          confidence: 0.0,
          details: {artifact: artifact.name, error: e.message}
        )
      end
    end
  end
end
```

#### Day 5: Documentation and Examples

- YARD documentation for all public APIs
- Usage examples in README
- Integration guide

## Testing Strategy

### Unit Tests

- `Workspace`: initialization, add_artifact, validation, cleanup
- `Artifact`: initialization, reference detection, serialization
- `ArtifactGraph`: add_node, dependencies, cycles, topological sort

### Integration Tests

- Task with workspace: artifact generation and storage
- Agent with workspace: context building from existing artifacts
- PlanOrchestrator with workspace: multi-task artifact coordination
- CLI with workspace: end-to-end workflow

### Security Tests

- Path traversal attempts
- Disallowed file extensions
- Size limit enforcement
- Malicious content patterns
- Circular reference detection

### Performance Tests

- 1000+ artifacts in graph
- Large file handling (10MB+)
- Parallel artifact generation
- Memory usage monitoring

## Security Checklist

- [x] Path traversal prevention (no `..` or `/` prefix)
- [x] File extension whitelist
- [x] Per-artifact size limits (10MB)
- [x] Workspace size limits (100MB)
- [x] Content validation (syntax, dangerous patterns)
- [x] Reference validation (workspace-relative only)
- [x] Audit logging for all file operations
- [x] Restrictive file permissions (0o644)

## Success Criteria

- [ ] All tests pass (>90% coverage)
- [ ] StandardRB compliance (no violations)
- [ ] Security validation catches known attack vectors
- [ ] Graph operations handle 1000+ artifacts in <1s
- [ ] CLI integration works end-to-end
- [ ] Documentation complete with examples

## Next Steps After Implementation

1. Create example multi-file project generation
2. Add RuboCop integration for Ruby artifacts
3. Add ESLint integration for JavaScript artifacts
4. Implement workspace templates (future feature)
5. Add performance monitoring and optimization

## References

- ADR-020: Workspace and Artifact Management
- RGL documentation: https://github.com/monora/rgl
- Security::Sanitizer: lib/agentic/security/sanitizer.rb
- Observable pattern: lib/agentic/observable.rb
