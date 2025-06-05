# Streaming Observability Architecture for Agentic

## Overview

This document outlines the design for adding real-time streaming observability to the Agentic framework, enabling live insights into task execution, agent assembly, plan building, and orchestration.

## Current State Assessment

### Existing Observability Infrastructure
- **Observable Pattern**: Thread-safe event notification system
- **ExecutionObserver**: CLI real-time feedback with progress tracking
- **Lifecycle Hooks**: Callback system for plan orchestrator events
- **Task State Transitions**: Observable state changes in task execution
- **Structured Logging**: Comprehensive logging throughout the system

### Gaps Identified
1. **No streaming intermediary steps** during task execution
2. **Limited visibility** into agent assembly process
3. **No real-time insights** into LLM interactions
4. **Missing observability** for plan construction phases
5. **No aggregated metrics** streaming capability

## Streaming Architecture Design

### Core Components

#### 1. StreamingObservabilityHub
Central coordinator for all streaming observability events.

```ruby
class StreamingObservabilityHub
  include Singleton
  
  # Event streams for different types of observability data
  attr_reader :task_stream, :agent_stream, :plan_stream, :metrics_stream
  
  # Stream processors for different output formats
  attr_reader :processors
end
```

#### 2. ObservabilityStream
Generic streaming interface supporting multiple backends.

```ruby
class ObservabilityStream
  # Stream types: :sse, :websocket, :file, :memory, :stdout
  def initialize(type:, config: {})
  
  # Emit structured events with metadata
  def emit(event_type, payload, metadata: {})
  
  # Support for event filtering and transformation
  def filter(&block)
  def transform(&block)
end
```

#### 3. Enhanced Observable Pattern
Extend existing Observable to support streaming and buffering.

```ruby
module StreamingObservable
  include Observable
  
  # Stream-aware notification with buffering
  def notify_streaming_observers(event_type, payload, stream_config: {})
  
  # Support for progress events with percentages
  def notify_progress(percentage, description, metadata: {})
  
  # Batch event support for performance
  def notify_batch(events)
end
```

### Integration Points

#### 1. Task Execution Streaming

**Enhanced Task Class:**
```ruby
class Task
  include StreamingObservable
  
  # Stream task lifecycle events
  def perform(agent)
    stream_event(:task_started, {
      task_id: @id,
      description: @description,
      agent_spec: @agent_spec.to_h
    })
    
    # Stream LLM request details
    stream_event(:llm_request_started, {
      prompt_length: build_prompt.length,
      estimated_tokens: estimate_tokens(build_prompt)
    })
    
    # Stream intermediate steps during agent execution
    @output = agent.execute(build_prompt) do |step|
      stream_event(:execution_step, {
        step_type: step[:type],
        content: step[:content],
        timestamp: Time.now
      })
    end
    
    stream_event(:task_completed, {
      task_id: @id,
      output_size: @output&.to_s&.length || 0,
      execution_time: Time.now - start_time
    })
  end
end
```

#### 2. Agent Assembly Streaming

**Enhanced AgentAssemblyEngine:**
```ruby
class AgentAssemblyEngine
  include StreamingObservable
  
  def assemble_agent(task, strategy: nil, store: true)
    stream_event(:assembly_started, {
      task_id: task.id,
      strategy_type: strategy&.class&.name
    })
    
    # Stream requirement analysis
    requirements = analyze_requirements(task) do |capability, score|
      stream_event(:capability_analyzed, {
        capability: capability,
        importance_score: score,
        reasoning: "Inferred from task description"
      })
    end
    
    # Stream capability selection
    capabilities = select_capabilities(requirements, strategy) do |selected|
      stream_event(:capability_selected, {
        capability: selected[:name],
        version: selected[:version],
        selection_reason: selected[:reason]
      })
    end
    
    # Stream agent construction
    agent = build_agent(task, capabilities) do |step|
      stream_event(:agent_build_step, {
        step: step[:name],
        progress: step[:progress],
        details: step[:details]
      })
    end
    
    stream_event(:assembly_completed, {
      agent_id: agent.id,
      capabilities_count: capabilities.length,
      assembly_time: Time.now - start_time
    })
    
    agent
  end
end
```

#### 3. Plan Orchestrator Streaming

**Enhanced PlanOrchestrator:**
```ruby
class PlanOrchestrator
  include StreamingObservable
  
  def execute_plan(agent_provider)
    stream_event(:plan_execution_started, {
      plan_id: @plan_id,
      total_tasks: @tasks.length,
      concurrency_limit: @concurrency_limit
    })
    
    # Stream dependency analysis
    dependency_graph = analyze_dependencies do |analysis|
      stream_event(:dependency_analysis, analysis)
    end
    
    # Stream task scheduling decisions
    eligible_tasks.each do |task_id|
      stream_event(:task_scheduled, {
        task_id: task_id,
        scheduled_at: Time.now,
        dependencies_met: all_dependencies_met?(task_id)
      })
    end
    
    # Enhanced lifecycle hooks with streaming
    @lifecycle_hooks = build_streaming_lifecycle_hooks
    
    # Execute with streaming updates
    result = super(agent_provider)
    
    stream_event(:plan_execution_completed, {
      plan_id: @plan_id,
      final_status: result.status,
      total_execution_time: result.execution_time,
      task_summary: build_task_summary
    })
    
    result
  end
end
```

#### 4. TaskPlanner Streaming

**Enhanced TaskPlanner:**
```ruby
class TaskPlanner
  include StreamingObservable
  
  def analyze_goal
    stream_event(:goal_analysis_started, {
      goal: @goal,
      analysis_type: "llm_breakdown"
    })
    
    # Stream LLM planning interaction
    response = llm_request(system_message, user_message, schema) do |chunk|
      stream_event(:llm_planning_chunk, {
        chunk_type: chunk[:type],
        content: chunk[:content],
        tokens_processed: chunk[:tokens]
      })
    end
    
    # Stream task creation
    @tasks = response.content["tasks"].map.with_index do |task_data, index|
      stream_event(:task_defined, {
        task_index: index,
        description: task_data["description"],
        agent_type: task_data["agent"]["name"],
        complexity_estimate: estimate_complexity(task_data)
      })
      
      TaskDefinition.new(...)
    end
    
    stream_event(:goal_analysis_completed, {
      tasks_generated: @tasks.length,
      analysis_time: Time.now - start_time
    })
  end
end
```

### Stream Processing Architecture

#### 1. Event Formatting and Filtering

```ruby
class StreamProcessor
  def initialize(stream, filters: [], formatters: [])
    @stream = stream
    @filters = filters
    @formatters = formatters
  end
  
  def process(event)
    # Apply filters
    return unless @filters.all? { |filter| filter.call(event) }
    
    # Apply formatters
    formatted_event = @formatters.reduce(event) { |evt, formatter| formatter.call(evt) }
    
    # Emit to stream
    @stream.emit(formatted_event)
  end
end
```

#### 2. Stream Aggregation and Metrics

```ruby
class MetricsAggregator
  def initialize(window_size: 60)
    @window_size = window_size
    @metrics = {}
  end
  
  def process_event(event)
    case event[:type]
    when :task_completed
      track_task_completion(event)
    when :agent_assembly_completed  
      track_assembly_time(event)
    when :llm_request_completed
      track_llm_usage(event)
    end
    
    emit_aggregated_metrics if should_emit_metrics?
  end
  
  private
  
  def emit_aggregated_metrics
    StreamingObservabilityHub.instance.metrics_stream.emit(:metrics_update, {
      timestamp: Time.now,
      window_size: @window_size,
      metrics: calculate_current_metrics
    })
  end
end
```

#### 3. Multi-Output Support

```ruby
class MultiStreamOutput
  def initialize
    @outputs = {}
  end
  
  def add_output(name, stream)
    @outputs[name] = stream
  end
  
  def emit(event)
    @outputs.each do |name, stream|
      begin
        stream.emit(event)
      rescue => e
        Agentic.logger.warn("Failed to emit to stream #{name}: #{e.message}")
      end
    end
  end
end
```

## Implementation Strategy

### Phase 1: Core Streaming Infrastructure
1. **StreamingObservabilityHub** - Central coordination
2. **ObservabilityStream** - Generic streaming interface  
3. **Enhanced Observable** - Stream-aware event emission
4. **Basic CLI streaming** - Real-time console output

### Phase 2: Task and Agent Streaming
1. **Task execution streaming** - Intermediate steps and progress
2. **Agent assembly streaming** - Capability analysis and selection
3. **LLM interaction streaming** - Request/response details
4. **Enhanced ExecutionObserver** - Richer real-time feedback

### Phase 3: Plan and Orchestration Streaming
1. **Plan building streaming** - Goal analysis and task generation
2. **Orchestration streaming** - Scheduling and dependency resolution
3. **Metrics aggregation** - Real-time performance insights
4. **Advanced filtering** - Configurable event streams

### Phase 4: Advanced Features
1. **WebSocket support** - Browser-based real-time dashboards
2. **Stream persistence** - Event replay and analysis
3. **Custom processors** - Pluggable stream processing
4. **Integration APIs** - External monitoring system support

## Usage Examples

### 1. CLI with Streaming Output
```bash
# Stream all events to console
agentic plan "Build a Ruby gem" --stream=console

# Stream specific event types
agentic plan "Analyze codebase" --stream=console --filter=task,agent

# Stream to file for later analysis
agentic plan "Generate tests" --stream=file:/tmp/execution.jsonl
```

### 2. Programmatic Streaming
```ruby
# Create custom stream processor
processor = StreamProcessor.new(
  ConsoleStream.new,
  filters: [
    ->(event) { event[:type].to_s.include?('task') },
    ->(event) { event[:metadata][:importance] == :high }
  ],
  formatters: [
    JSONFormatter.new,
    TimestampFormatter.new
  ]
)

# Register with hub
StreamingObservabilityHub.instance.add_processor(:custom, processor)

# Execute with streaming
orchestrator = PlanOrchestrator.new(lifecycle_hooks: streaming_hooks)
result = orchestrator.execute_plan(agent_provider)
```

### 3. Web Dashboard Integration
```ruby
# WebSocket stream for browser dashboard
ws_stream = WebSocketStream.new(port: 8080, path: '/events')
StreamingObservabilityHub.instance.add_stream(:dashboard, ws_stream)

# Filtered stream for performance metrics only
metrics_stream = FilteredStream.new(
  ws_stream,
  filter: ->(event) { event[:type].to_s.include?('metrics') }
)
```

## Configuration

### Stream Configuration
```yaml
streaming:
  enabled: true
  default_streams:
    - type: console
      level: info
    - type: file
      path: logs/execution_stream.jsonl
      level: debug
  
  filters:
    console:
      include: [task_started, task_completed, plan_completed]
      exclude: [llm_chunk, debug_info]
    
    file:
      include: "*"
      
  metrics:
    aggregation_window: 60
    emit_interval: 10
    track_performance: true
```

### Event Schema
```json
{
  "timestamp": "2025-06-03T10:30:00Z",
  "event_type": "task_started",
  "source": {
    "component": "Task",
    "id": "task-123",
    "version": "0.2.0"
  },
  "payload": {
    "task_id": "task-123",
    "description": "Analyze Ruby codebase",
    "agent_spec": {...}
  },
  "metadata": {
    "session_id": "session-456",
    "plan_id": "plan-789",
    "importance": "high",
    "estimated_duration": 30
  }
}
```

## Performance Considerations

### Stream Buffering
- Configurable buffer sizes for high-throughput scenarios
- Automatic flushing based on time or size thresholds
- Memory-conscious buffering with overflow handling

### Asynchronous Processing
- Non-blocking event emission to prevent execution delays
- Background thread pools for stream processing
- Circuit breaker pattern for failing streams

### Resource Management
- Automatic stream cleanup and resource deallocation
- Configurable retention policies for persistent streams
- Memory usage monitoring and alerts

## Security and Privacy

### Event Filtering
- Automatic PII detection and redaction
- Configurable content filters for sensitive data
- Role-based access control for different stream types

### Data Protection
- Encryption for network streams (WSS, HTTPS)
- Secure credential handling for external integrations
- Audit logging for stream access and configuration changes

## Monitoring and Alerting

### Stream Health
- Automatic detection of failing streams
- Performance metrics for stream processing
- Alerting for abnormal event patterns

### System Integration
- OpenTelemetry compatibility for observability platforms
- Prometheus metrics export capability
- Custom webhook integrations for external alerting

## Conclusion

This streaming observability architecture provides comprehensive real-time insights into all aspects of the Agentic framework while maintaining performance and extensibility. The phased implementation approach ensures gradual adoption with immediate value at each stage.