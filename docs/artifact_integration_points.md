# Artifact Generation Integration Points

## Current System Flow

The existing Agentic system follows this flow:

1. **Planning Phase**: `CLI#plan` → `TaskPlanner` → `ExecutionPlan` containing `TaskDefinition`s
2. **Execution Phase**: `CLI#execute` → `PlanOrchestrator` → `Task.from_definition` → `Agent#execute` → `TaskResult`
3. **Output Phase**: Results are displayed as text and optionally saved to JSON files

## Integration Points for Artifact Generation

### 1. TaskPlanner Integration

**Current**: TaskPlanner generates TaskDefinitions with basic agent specifications
**Enhanced**: TaskPlanner should recognize when a goal requires artifact generation

```ruby
# Enhanced TaskPlanner analysis
def analyze_goal
  # Existing logic plus artifact detection
  if goal_requires_artifacts?(@goal)
    @artifact_planning_needed = true
    analyze_artifact_requirements
  end
  
  # Generate tasks with artifact specifications
  generate_artifact_aware_tasks
end

private

def goal_requires_artifacts?(goal)
  artifact_keywords = [
    'create', 'build', 'generate', 'develop', 'implement', 
    'write code', 'application', 'program', 'script', 'file'
  ]
  artifact_keywords.any? { |keyword| goal.downcase.include?(keyword) }
end
```

**Integration Strategy**: Extend TaskPlanner to include artifact analysis without breaking existing functionality.

### 2. TaskDefinition Enhancement

**Current**: TaskDefinition contains `description` and `agent` specification
**Enhanced**: Add optional artifact specifications

```ruby
class TaskDefinition
  attr_reader :description, :agent, :artifact_specs # NEW
  
  def initialize(description:, agent:, artifact_specs: nil) # ENHANCED
    @description = description
    @agent = agent
    @artifact_specs = artifact_specs # NEW
  end
  
  def requires_artifacts? # NEW
    !@artifact_specs.nil? && !@artifact_specs.empty?
  end
end
```

**Integration Strategy**: Backward-compatible addition to existing TaskDefinition.

### 3. Task System Integration

**Current**: `Task.from_definition` creates standard Task instances
**Enhanced**: Create `ArtifactTask` instances when artifact specs are present

```ruby
# In Task class
def self.from_definition(definition, input = {})
  if definition.requires_artifacts?
    ArtifactTask.from_definition(definition, input)
  else
    new(
      description: definition.description,
      agent_spec: definition.agent,
      input: input
    )
  end
end
```

**Integration Strategy**: Factory method enhancement with seamless fallback to standard Tasks.

### 4. Agent System Integration

**Current**: Agents execute prompts and return text/JSON responses
**Enhanced**: Agents can generate structured content for artifacts

```ruby
class Agent
  def execute(task)
    if task.is_a?(ArtifactTask)
      execute_artifact_task(task)
    else
      # Existing logic for regular tasks
      execute_prompt(task.is_a?(String) ? task : task.build_prompt)
    end
  end
  
  private
  
  def execute_artifact_task(artifact_task)
    # Generate content for each artifact specification
    artifacts = artifact_task.artifact_specs.map do |spec|
      generate_artifact_content(spec, artifact_task.input)
    end
    
    # Write artifacts to workspace
    workspace_manager = WorkspaceManager.new(artifact_task.workspace_path)
    written_artifacts = workspace_manager.write_artifacts(artifacts)
    
    # Return artifact-aware result
    ArtifactResult.new(
      task_id: artifact_task.id,
      success: true,
      artifacts: written_artifacts,
      workspace_metadata: workspace_manager.metadata
    )
  end
end
```

**Integration Strategy**: Conditional execution path in existing Agent#execute method.

### 5. PlanOrchestrator Integration

**Current**: Orchestrator manages Task execution and lifecycle
**Enhanced**: Handle ArtifactTask workspace management and cleanup

```ruby
class PlanOrchestrator
  def execute_plan(agent_provider)
    # Existing setup...
    
    # Initialize workspace manager if artifact tasks are present
    if has_artifact_tasks?
      @workspace_manager = GlobalWorkspaceManager.new(@plan_id)
      setup_workspace_cleanup
    end
    
    # Existing execution logic with artifact-aware hooks
    execute_with_artifact_support(agent_provider)
  end
  
  private
  
  def has_artifact_tasks?
    @tasks.values.any? { |task| task.is_a?(ArtifactTask) }
  end
  
  def setup_workspace_cleanup
    # Register cleanup hooks for proper workspace management
    @lifecycle_hooks[:plan_completed] = lambda do |plan_id:, status:, **kwargs|
      @workspace_manager&.cleanup unless status == :completed
      # Call original hook if present
      original_hook = kwargs[:original_plan_completed_hook]
      original_hook&.call(plan_id: plan_id, status: status, **kwargs)
    end
  end
end
```

**Integration Strategy**: Conditional workspace management that doesn't affect regular task execution.

### 6. CLI Integration

**Current**: CLI handles plan creation and execution with text output
**Enhanced**: CLI supports artifact workspace specification and result handling

```ruby
class CLI < Thor
  desc "plan GOAL", "Create an execution plan for a goal"
  option :workspace, type: :string, aliases: "-w",
    desc: "Workspace directory for artifact generation"
  option :artifact_mode, type: :boolean,
    desc: "Enable artifact generation mode"
  def plan(goal)
    # Existing setup...
    
    # Configure artifact options
    if options[:artifact_mode] || options[:workspace]
      config.artifact_generation_enabled = true
      config.default_workspace = options[:workspace] || Dir.pwd
    end
    
    # Existing planning logic...
  end
  
  desc "execute", "Execute a plan"
  option :workspace, type: :string, aliases: "-w",
    desc: "Override workspace directory for artifact generation"
  option :keep_workspace, type: :boolean,
    desc: "Keep workspace after execution (don't cleanup)"
  def execute
    # Existing setup...
    
    # Configure artifact execution options
    if options[:workspace] || plan_has_artifacts?(plan_data)
      configure_artifact_execution
    end
    
    # Existing execution logic...
  end
  
  private
  
  def configure_artifact_execution
    workspace_dir = options[:workspace] || determine_workspace_from_plan
    ensure_workspace_exists(workspace_dir)
    
    # Add workspace cleanup to lifecycle hooks unless --keep-workspace
    unless options[:keep_workspace]
      add_workspace_cleanup_hook(workspace_dir)
    end
  end
end
```

**Integration Strategy**: Additive CLI options that enhance existing commands without breaking compatibility.

### 7. ExecutionObserver Integration

**Current**: Observer provides real-time feedback during task execution
**Enhanced**: Observer tracks artifact creation progress and file operations

```ruby
class ExecutionObserver
  def lifecycle_hooks
    base_hooks = existing_lifecycle_hooks
    
    if @artifact_mode_enabled
      base_hooks.merge(artifact_lifecycle_hooks)
    else
      base_hooks
    end
  end
  
  private
  
  def artifact_lifecycle_hooks
    {
      before_artifact_generation: method(:on_before_artifact_generation),
      after_artifact_written: method(:on_after_artifact_written),
      workspace_prepared: method(:on_workspace_prepared),
      verification_started: method(:on_verification_started),
      verification_completed: method(:on_verification_completed)
    }
  end
  
  def on_before_artifact_generation(task_id:, artifact_spec:)
    unless @options[:quiet]
      puts "  #{UI.colorize('📝', :blue)} Generating #{artifact_spec.type}: #{artifact_spec.name}"
    end
  end
  
  def on_after_artifact_written(task_id:, artifact:)
    unless @options[:quiet]
      file_size = File.size(artifact.path)
      puts "  #{UI.colorize('✅', :green)} Created #{artifact.path} (#{file_size} bytes)"
    end
  end
end
```

**Integration Strategy**: Conditional hook enhancement that maintains existing observer behavior.

### 8. Result System Integration

**Current**: TaskResult contains success/failure status and text output
**Enhanced**: ArtifactResult contains artifact metadata and file references

```ruby
class ArtifactResult < TaskResult
  attr_reader :artifacts, :workspace_metadata
  
  def initialize(task_id:, success:, output: nil, failure: nil, artifacts: [], workspace_metadata: {})
    super(task_id: task_id, success: success, output: output, failure: failure)
    @artifacts = artifacts
    @workspace_metadata = workspace_metadata
  end
  
  def to_h
    super.merge({
      artifacts: @artifacts.map(&:to_h),
      workspace_metadata: @workspace_metadata
    })
  end
  
  def file_count
    @artifacts.length
  end
  
  def total_size
    @artifacts.sum { |artifact| File.size(artifact.path) }
  end
end
```

**Integration Strategy**: Inheritance-based extension that maintains compatibility with existing result handling.

## Backward Compatibility Guarantees

### 1. Existing API Preservation
- All existing public APIs remain unchanged
- Standard Task execution continues to work exactly as before
- CLI commands maintain existing behavior when artifact options aren't used

### 2. Graceful Degradation
- Plans created without artifact specifications execute normally
- Missing workspace directories are created automatically
- Artifact generation failures fall back to text-based results

### 3. Configuration Compatibility
- Existing configuration files continue to work
- Artifact features are opt-in and don't affect default behavior
- LLM configuration and model selection remain unchanged

## Migration Path

### Phase 1: Core Infrastructure (Minimal Changes)
1. Add `ArtifactTask` and `ArtifactResult` classes
2. Enhance `TaskDefinition` with optional artifact specs
3. Update `Task.from_definition` factory method

### Phase 2: Generation Engine (Additive Features)
1. Implement `ArtifactGenerator` and workspace management
2. Add artifact generation capabilities to Agent system
3. Create basic artifact types and verification

### Phase 3: Full Integration (Enhanced UX)
1. Update CLI with artifact options and feedback
2. Enhance ExecutionObserver with artifact tracking
3. Add PlanOrchestrator workspace management

### Phase 4: Advanced Features (Extension Points)
1. Plugin system for custom artifact types
2. Template-based project generation
3. Advanced verification and quality metrics

This integration approach ensures that the artifact generation system enhances the existing Agentic framework without disrupting current functionality, while providing a clear path for incremental adoption and feature development.