# ADR-016: Agent Assembly Engine

## Status

Accepted

## Context

A key requirement for the Agentic framework is the ability to dynamically assemble agents based on task requirements. Currently, agents are constructed manually or through predefined configurations, which:

1. Requires foreknowledge of task requirements
2. Results in either overly generic or overly specialized agents
3. Misses opportunities for capability reuse and optimization
4. Does not leverage knowledge from previous similar tasks

We need a system that can analyze task requirements, select appropriate capabilities, and assemble agents optimized for specific tasks. This system should also integrate with our persistent storage to reuse existing agents when appropriate.

## Decision

We will implement an `AgentAssemblyEngine` that handles the dynamic construction of agents based on task analysis. The engine will:

1. Analyze task requirements to determine needed capabilities
2. Select appropriate capabilities using pluggable selection strategies
3. Build agents with the selected capabilities
4. Store assembled agents for future reuse
5. Find and reuse suitable existing agents when possible

Key components:

```ruby
# Main engine
engine = AgentAssemblyEngine.new(registry, agent_store)

# Assemble an agent for a task
agent = engine.assemble_agent(task, strategy: strategy, store: true)

# Analyze task requirements
requirements = engine.analyze_requirements(task)

# Select capabilities based on requirements
capabilities = engine.select_capabilities(requirements, strategy)

# Build an agent with selected capabilities
agent = engine.build_agent(task, capabilities)
```

The engine will support multiple composition strategies through a Strategy pattern:

1. `DefaultCompositionStrategy`: Basic capability selection based on requirements
2. `LlmAssistedCompositionStrategy`: Uses an LLM to suggest optimal capabilities
3. Custom strategies can be implemented for specialized domains

## Consequences

### Positive

1. Enables task-optimized agent assembly
2. Supports agent reuse through integration with persistent store
3. Pluggable strategies allow domain-specific optimization
4. Reduces manual configuration requirements
5. Promotes capability-based agent design

### Negative

1. Increases system complexity
2. Requires accurate task requirement analysis
3. May lead to capability explosion without governance
4. LLM-assisted strategies add external dependencies

### Neutral

1. Changes agent construction paradigm from static to dynamic
2. Requires integration with the capability registry and agent store
3. May require adjustment of existing agent usage patterns

## Implementation Notes

### Task Requirement Analysis

The engine will analyze tasks using multiple approaches:

1. Task description analysis using pattern matching or NLP
2. Agent specification analysis for explicit capability requirements
3. Task input analysis for capability hints
4. LLM-assisted analysis for complex requirements

### Capability Selection

Selection strategies will consider:
- Capability relevance to the task
- Capability performance metrics from learning system
- Capability dependencies and compatibility
- Agent resource constraints

### Agent Matching

When finding existing agents for a task, the engine will:
1. Identify primary capabilities required for the task
2. Find agents with these capabilities
3. Score agents based on capability match
4. Return the best matching agent if score exceeds threshold

### Integration with Learning System

The engine will integrate with the learning system to:
1. Record capability selection decisions
2. Track assembled agent performance
3. Improve selection strategies based on outcomes
4. Optimize capability compositions

## Future Considerations

1. Support for agent composition constraints (e.g., maximum capabilities)
2. Advanced capability compatibility checking
3. Agent performance benchmarking for selection decisions
4. Multi-agent assembly for complex tasks
5. Capability governance and approval workflows