# ADR-021: Task, Agent, and Workspace Integration

## Status
**DRAFT** - Under architect review

## Context

Phase 1 implemented three core classes for workspace and artifact management:
- `Artifact`: File metadata with automatic reference detection
- `ArtifactGraph`: Graph-based dependency management using RGL
- `Workspace`: Isolated execution environments with multi-layer security

Phase 2 requires integrating these classes with the existing `Task` and `Agent` classes to enable agents to generate files within isolated workspaces.

### Current Architecture

**Task Class** (`lib/agentic/task.rb`):
- Represents a unit of work to be executed by an agent
- Has: `id`, `description`, `agent_spec`, `input`, `output`, `status`, `failure`
- Executes via `perform(agent)` which calls `agent.execute(prompt)`
- Supports structured output schemas via `execute_with_schema`
- Observable pattern for status changes

**Agent Class** (`lib/agentic/agent.rb`):
- Represents an AI agent with capabilities
- Has: `role`, `purpose`, `backstory`, `instructions`, `capabilities`, `llm_client`
- Executes tasks via `execute(task)` or `execute_prompt(prompt)`
- Capability-based architecture: `add_capability`, `execute_capability`
- Builds system messages with agent personality

### Integration Requirements

From Architecture Review (High Priority):
1. **Define explicit interface contracts** between Task, Agent, and Workspace
2. **Register file_generation capability** in CapabilityManager
3. **Add workspace lifecycle management** (create, use, cleanup)
4. **Implement ArtifactVerificationStrategy** for quality assurance

## Decision

### 1. Integration Contract Design

**Principle**: Workspace is **optional** - tasks can run with or without workspaces. Only tasks that generate files need workspaces.

#### Task → Workspace Relationship

```ruby
class Task
  attr_reader :workspace  # Optional: nil if task doesn't generate files

  def initialize(description:, agent_spec:, input: {}, workspace: nil, **options)
    @workspace = workspace
    # ... existing initialization
  end

  # Check if task has workspace for file generation
  def has_workspace?
    !@workspace.nil?
  end

  # Get workspace path for agent to use
  def workspace_path
    @workspace&.path
  end
end
```

**Design Rationale** (Alex Rivera - Systems Architect):
- Workspace as optional parameter maintains backward compatibility
- Tasks without file generation don't pay workspace overhead
- Clean separation: Task owns workspace lifecycle, Agent uses it

#### Agent → Workspace Relationship

```ruby
class Agent
  # Workspace is passed as context during execution, not stored on agent
  # This allows same agent to work with different workspaces

  def execute_with_workspace(prompt, workspace)
    # Agent can access workspace to generate artifacts
    # Workspace path is included in prompt context
    context = build_workspace_context(workspace)
    execute_prompt("#{context}\n\n#{prompt}")
  end

  private

  def build_workspace_context(workspace)
    <<~CONTEXT
      [Workspace Information]
      You have access to an isolated workspace for generating files.
      Workspace path: #{workspace.path}

      When generating files, respond with JSON describing each artifact:
      {
        "artifacts": [
          {
            "name": "relative/path/to/file.rb",
            "type": "ruby_class",
            "content": "file content here",
            "references": ["other_file.rb"]
          }
        ]
      }
    CONTEXT
  end
end
```

**Design Rationale** (Jamie Chen - AI Agent Expert):
- Agent doesn't own workspace (stateless agent design)
- Workspace context injected at execution time
- Agent can describe artifacts in structured format
- LLM naturally generates file metadata

### 2. File Generation Capability

**Capability Definition**:

```ruby
# lib/agentic/capabilities/file_generation_capability.rb
module Agentic
  module Capabilities
    class FileGenerationCapability
      def self.specification
        CapabilitySpecification.new(
          name: "file_generation",
          version: "1.0.0",
          description: "Generate code files and artifacts within an isolated workspace",
          inputs: {
            task_description: { type: :string, required: true },
            workspace_path: { type: :string, required: true },
            constraints: { type: :hash, required: false }
          },
          outputs: {
            artifacts: { type: :array, description: "Generated artifacts" },
            workspace_id: { type: :string, description: "Workspace identifier" }
          }
        )
      end

      def self.execute(agent:, inputs:)
        # Create or use provided workspace
        workspace = inputs[:workspace] || create_workspace(inputs[:workspace_path])

        # Execute agent with workspace context
        prompt = build_file_generation_prompt(inputs)
        result = agent.execute_with_workspace(prompt, workspace)

        # Parse response and create artifacts
        artifacts = parse_artifact_descriptions(result)
        artifacts.each { |artifact| workspace.add_artifact(artifact) }

        # Return result with workspace info
        {
          artifacts: artifacts.map(&:to_h),
          workspace_id: workspace.id,
          workspace_path: workspace.path
        }
      end
    end
  end
end
```

**Design Rationale** (Taylor Kim - Agent Systems Engineer):
- Capability encapsulates file generation workflow
- Agent receives structured task, returns artifact descriptions
- Capability handles workspace creation and artifact persistence
- Clean separation: agent generates content, capability manages storage

### 3. Workspace Lifecycle Management

**Three Lifecycle Patterns**:

```ruby
# Pattern 1: Task-Managed Workspace (Automatic)
task = Task.new(
  description: "Generate Ruby class",
  agent_spec: coding_agent_spec,
  workspace: Workspace.new("/tmp/task_#{task.id}")  # Task owns cleanup
)

# Pattern 2: Shared Workspace (Manual)
shared_workspace = Workspace.new("/project/src", persistent: true)
task1 = Task.new(..., workspace: shared_workspace)
task2 = Task.new(..., workspace: shared_workspace)
# User responsible for cleanup

# Pattern 3: No Workspace (Default)
task = Task.new(
  description: "Analyze data",
  agent_spec: analyst_spec
  # No workspace needed
)
```

**Cleanup Strategy**:

```ruby
class Task
  def cleanup_workspace
    return unless @workspace && !@workspace.metadata[:persistent]
    @workspace.cleanup
  end

  # Call after task completes
  def after_completion
    cleanup_workspace if should_cleanup_workspace?
  end

  private

  def should_cleanup_workspace?
    has_workspace? && status == :completed && !@workspace.metadata[:persistent]
  end
end
```

**Design Rationale** (Alex Rivera - Systems Architect):
- Three patterns cover common use cases
- Task-managed: one-off generations (auto-cleanup)
- Shared: multi-task projects (manual cleanup)
- None: non-file tasks (no overhead)

**When to Use Each Pattern**:

**Pattern 1: Task-Managed Workspace** - Use when:
- Task generates files for one-time use (e.g., code analysis, temporary builds)
- Files don't need to persist after task completion
- Each task needs isolated workspace to avoid conflicts
- Auto-cleanup is desired (workspace deleted after task completes)

Example scenarios:
- Generate test fixtures for a single test run
- Create temporary configuration files for validation
- Build throwaway prototypes or examples
- Generate analysis reports that are immediately processed

```ruby
# Example: Generate temporary test files
task = Task.new(
  description: "Generate test fixtures for User model",
  agent_spec: test_agent_spec,
  workspace: Workspace.new("/tmp/test_fixtures_#{SecureRandom.uuid}")
)
# Workspace automatically cleaned up after task completes
```

**Pattern 2: Shared Workspace** - Use when:
- Multiple tasks/agents collaborate on same codebase
- Files need to persist across task executions
- Building up a project incrementally (model → controller → tests)
- Manual control over workspace lifecycle is required

Example scenarios:
- Multi-agent software development (one agent per component)
- Incremental code generation across multiple tasks
- Building a complete application with coordinated agents
- Persistent project workspaces that outlive individual tasks

```ruby
# Example: Multi-agent project development
project_workspace = Workspace.new("/project/myapp", persistent: true)

# Task 1: Generate models
model_task = Task.new(
  description: "Generate User and Post models",
  agent_spec: model_agent_spec,
  workspace: project_workspace
)

# Task 2: Generate controllers (uses files from Task 1)
controller_task = Task.new(
  description: "Generate controllers for models",
  agent_spec: controller_agent_spec,
  workspace: project_workspace  # Same workspace
)

# Task 3: Generate tests
test_task = Task.new(
  description: "Generate integration tests",
  agent_spec: test_agent_spec,
  workspace: project_workspace  # Same workspace
)

# User controls when to clean up
project_workspace.cleanup  # Manual cleanup when done
```

**Pattern 3: No Workspace** - Use when:
- Task doesn't generate files (analysis, planning, decision-making)
- Agent only produces text/data, not artifacts
- No file system interaction needed
- Minimizing overhead for non-generation tasks

Example scenarios:
- Data analysis and insights generation
- Task planning and decomposition
- Code review and recommendations
- Question answering and information retrieval

```ruby
# Example: Task planning without file generation
analysis_task = Task.new(
  description: "Analyze codebase and recommend refactorings",
  agent_spec: analyst_agent_spec
  # No workspace parameter - task produces text output only
)
```

### 4. Artifact Verification Integration

**Verification Hook**:

```ruby
class Workspace
  def add_artifact(artifact, verify: true)
    validate_artifact(artifact)  # Existing security checks

    if verify
      verification_result = verify_artifact(artifact)
      unless verification_result.passed?
        raise ArtifactVerificationError, verification_result.message
      end
    end

    @artifact_graph.add_node(artifact)
    write_artifact_to_filesystem(artifact)

    notify(:artifact_added, ...)
    artifact
  end

  def verify_artifact(artifact)
    strategy = ArtifactVerificationStrategy.for_type(artifact.type)
    strategy.verify(artifact)
  end
end
```

**Verification Strategy Stub**:

```ruby
# lib/agentic/verification/artifact_verification_strategy.rb
module Agentic
  module Verification
    class ArtifactVerificationStrategy
      def self.for_type(artifact_type)
        case artifact_type
        when :ruby_class
          RubyArtifactVerificationStrategy.new
        when :javascript_module
          JavaScriptArtifactVerificationStrategy.new
        else
          BasicArtifactVerificationStrategy.new
        end
      end

      def verify(artifact)
        VerificationResult.new(passed: true, message: "No verification implemented")
      end
    end

    class BasicArtifactVerificationStrategy < ArtifactVerificationStrategy
      def verify(artifact)
        # Basic checks: content not empty, valid UTF-8
        if artifact.content.nil? || artifact.content.empty?
          return VerificationResult.new(passed: false, message: "Artifact content is empty")
        end

        unless artifact.content.valid_encoding?
          return VerificationResult.new(passed: false, message: "Artifact content has invalid encoding")
        end

        VerificationResult.new(passed: true, message: "Basic verification passed")
      end
    end

    VerificationResult = Struct.new(:passed, :message, keyword_init: true) do
      def passed?
        passed
      end
    end
  end
end
```

**Design Rationale** (Morgan Taylor - Security Specialist, Sam Rodriguez - Maintainability):
- Verification is opt-in (default: true) but can be disabled
- Strategy pattern allows language-specific verification
- Stub implementation provides foundation for enhancement
- Security validation happens first, then quality verification

### 5. Integration Sequence

**Typical Workflow**:

```
1. User creates Task with Workspace
   ↓
2. Task.perform(agent) called
   ↓
3. Task passes workspace context to Agent
   ↓
4. Agent executes with workspace awareness
   ↓
5. Agent returns artifact descriptions (JSON)
   ↓
6. Task/Capability parses and creates Artifacts
   ↓
7. Workspace validates and verifies each Artifact
   ↓
8. Artifacts written to filesystem
   ↓
9. Task completes, workspace cleanup (if not persistent)
```

## Consequences

### Positive

1. **✅ Clean Separation**: Task manages lifecycle, Agent generates content, Workspace enforces security
2. **✅ Backward Compatible**: Existing tasks without workspaces work unchanged
3. **✅ Flexible**: Supports one-off generation, shared workspaces, and no-workspace tasks
4. **✅ Extensible**: Verification strategies can be enhanced per language
5. **✅ Observable**: All workspace operations emit events for monitoring

### Negative

1. **⚠️ Complexity**: Adds another abstraction layer (workspace context in prompts)
2. **⚠️ LLM Dependency**: Relies on LLM to correctly format artifact descriptions
3. **⚠️ Error Handling**: More failure points (workspace creation, artifact parsing, verification)

### Risks

1. **Medium**: LLM may not reliably generate structured artifact descriptions
   - **Mitigation**: Use structured output schemas, provide clear examples
2. **Low**: Workspace cleanup failures could leak disk space
   - **Mitigation**: Periodic cleanup job, monitoring workspace count/size
3. **Low**: Multi-agent coordination on shared workspace
   - **Mitigation**: Defer to Phase 3, start with single-agent-per-workspace

## Implementation Plan

### Phase 2A: Core Integration (This Phase)

1. ✅ Add `workspace` parameter to Task
2. ✅ Add `execute_with_workspace` to Agent
3. ✅ Implement FileGenerationCapability
4. ✅ Register capability in CapabilityManager
5. ✅ Add ArtifactVerificationStrategy stub
6. ✅ Write integration tests

### Phase 2B: Verification Enhancement (Future)

1. Implement RubyArtifactVerificationStrategy (syntax checking)
2. Implement JavaScriptArtifactVerificationStrategy
3. Add LLM-based verification (code quality, adherence to requirements)

### Phase 2C: Advanced Features (Future)

1. Workspace transactions (rollback on failure)
2. Artifact discovery (suggest what to generate)
3. Multi-agent coordination
4. Workspace pooling

## References

- ADR-020: Workspace & Artifact Management (Graph-based Design)
- Architecture Review: Core Workspace & Artifact Management Classes (Phase 1)
- `lib/agentic/task.rb`: Existing Task implementation
- `lib/agentic/agent.rb`: Existing Agent implementation
- `ArchitectureConsiderations.md`: Overall system architecture

## Architect Sign-off

- [ ] Alex Rivera (Systems Architect) - Integration contracts
- [ ] Jamie Chen (AI Agent Expert) - Agent workflow patterns
- [ ] Morgan Taylor (Security Specialist) - Security validation flow
- [ ] Sam Rodriguez (Maintainability Expert) - Code structure and testing
- [ ] Taylor Kim (Agent Systems Engineer) - Capability integration
- [ ] Jordan Lee (Performance Specialist) - Performance implications
- [ ] Riley Park (Ruby Expert) - Ruby idioms and conventions
- [ ] Pragmatic Enforcer (YAGNI) - Complexity justification
