# ADR-020: Multi-Agent Coordination Strategy

## Status

Accepted - Deferred to v0.4.0+

## Context

The current Agentic framework operates on a **single-agent-per-task** execution model. Each task in a plan is assigned to exactly one agent, and agents do not communicate or coordinate with each other during execution.

Current limitations:
1. **No Inter-Agent Communication**: Agents cannot share information, request assistance, or coordinate activities
2. **Static Task Assignment**: Once a task is assigned to an agent, it cannot be delegated or transferred
3. **No Agent Specialization Hierarchy**: All agents are peers; no distinction between coordinator and specialist agents
4. **Limited Problem Decomposition**: Complex problems requiring multiple specialized agents cannot be effectively solved
5. **No Shared Context**: Agents cannot build on each other's work within a single execution

Architecture review findings (Jamie Chen - AI Agent Domain Expert):
- **High Risk**: Lack of multi-agent coordination limits ability to solve complex, decomposed problems
- Current single-agent model suitable for independent, well-scoped tasks only
- No team orchestration for coordinated multi-agent task execution
- Missing agent hierarchy for delegation patterns

Real-world scenarios requiring multi-agent coordination:
- **Research Tasks**: Researcher agent coordinates searcher, summarizer, and verifier agents
- **Software Development**: Architect agent coordinates designer, coder, and tester agents
- **Data Analysis**: Analyst agent coordinates data collector, processor, and visualizer agents
- **Content Creation**: Editor agent coordinates researcher, writer, and reviewer agents

However, the framework review also identified this as a **YAGNI concern**:
- No concrete multi-agent scenarios demonstrated yet
- Single-agent quality should be prioritized first
- Adding multi-agent coordination significantly increases complexity
- Most current use cases are satisfied by sequential single-agent tasks

## Decision

We will **defer multi-agent coordination to v0.4.0+** while establishing the architectural foundation for future implementation.

### Decision Rationale

**Why Defer:**
1. **YAGNI Principle**: No validated use cases requiring multi-agent coordination yet
2. **Focus on Foundation**: Single-agent quality, security, and learning integration are higher priorities
3. **Complexity Management**: Multi-agent systems significantly increase architectural complexity
4. **User Feedback Needed**: Need real-world validation of multi-agent requirements before design

**Why Establish Foundation:**
1. **Avoid Rearchitecture**: Design current system to accommodate future multi-agent patterns
2. **Enable Experimentation**: Provide hooks for experimental multi-agent implementations
3. **Inform v0.4.0 Design**: Document requirements and constraints for future implementation

### Architectural Foundation (Implement in v0.3.x)

#### 1. Agent Communication Interface

Define standard message-passing interface (not implemented, but specified):

```ruby
module Agentic
  module AgentCommunication
    # Message structure for inter-agent communication
    class AgentMessage
      attr_reader :from_agent_id, :to_agent_id, :message_type, :content, :context

      def initialize(from:, to:, type:, content:, context: {})
        # Future: Standard message format for agent-to-agent communication
      end
    end

    # Interface for agents that can communicate (not enforced yet)
    module Communicable
      def send_message(to_agent, message)
        raise NotImplementedError, "Multi-agent coordination available in v0.4.0+"
      end

      def receive_message(message)
        raise NotImplementedError, "Multi-agent coordination available in v0.4.0+"
      end
    end
  end
end
```

#### 2. Task Context Sharing

Add execution context that can be shared across agents:

```ruby
class ExecutionContext
  attr_reader :task_chain_id, :shared_state, :agent_outputs

  def initialize(task_chain_id:)
    @task_chain_id = task_chain_id
    @shared_state = {}
    @agent_outputs = {}
  end

  # Allow agents to store outputs accessible to other agents in the same chain
  def store_output(agent_id, task_id, output)
    @agent_outputs["#{agent_id}:#{task_id}"] = output
  end

  def get_output(agent_id, task_id)
    @agent_outputs["#{agent_id}:#{task_id}"]
  end

  # Shared state for coordination
  def set_shared(key, value)
    @shared_state[key] = value
  end

  def get_shared(key)
    @shared_state[key]
  end
end
```

#### 3. Agent Role Hints

Add optional role metadata to agent specifications:

```ruby
class AgentSpecification
  attr_reader :name, :description, :instructions, :role_type

  def initialize(name:, description:, instructions:, role_type: :specialist)
    @name = name
    @description = description
    @instructions = instructions
    @role_type = role_type # :specialist, :coordinator (future)
  end
end
```

#### 4. Reserved Namespace

Reserve namespace for future multi-agent components:

```ruby
module Agentic
  module MultiAgent
    # Reserved for v0.4.0+
    # - AgentTeam
    # - CoordinationProtocol
    # - DelegationStrategy
    # - ConsensusBuilder
  end
end
```

### Design Patterns for v0.4.0+ (Not Implemented)

Document intended multi-agent patterns for future implementation:

#### Pattern 1: Agent Team

```ruby
# Future API design
class AgentTeam
  def initialize(coordinator:, specialists:)
    @coordinator = coordinator
    @specialists = specialists
  end

  def execute_task(task)
    # Coordinator breaks down task
    # Delegates to specialists
    # Aggregates results
  end
end
```

#### Pattern 2: Delegation

```ruby
# Future API design
class CoordinatorAgent < Agent
  def execute_with_delegation(task)
    # Analyze task
    # Identify subtasks requiring specialists
    # Delegate to appropriate agents
    # Synthesize results
  end
end
```

#### Pattern 3: Consensus

```ruby
# Future API design
class ConsensusBuilder
  def build_consensus(task, agents:, strategy: :majority)
    # Multiple agents independently solve task
    # Aggregate results using strategy (majority, average, voting, etc.)
  end
end
```

## Consequences

### Positive

1. **Focused Roadmap**: Prioritizes proven high-value features (security, learning) over speculative ones
2. **Reduced Complexity**: Avoids premature architectural complexity
3. **Validated Design**: Time to gather real-world multi-agent requirements
4. **Clean Foundation**: Establishes hooks without committing to specific implementation
5. **User-Driven**: Future design based on actual user needs rather than assumptions
6. **Incremental Adoption**: Single-agent patterns remain simple for users who don't need coordination

### Negative

1. **Delayed Functionality**: Users needing multi-agent coordination must wait for v0.4.0+
2. **Workaround Required**: Complex problems require manual coordination in application code
3. **Competitive Gap**: Other agent frameworks may offer multi-agent coordination sooner
4. **Learning Delay**: Less early feedback on multi-agent patterns
5. **Potential Rearchitecture**: If foundation proves insufficient, may require larger changes

### Neutral

1. **Clear Timeline**: Sets expectations for multi-agent features
2. **Experimentation Possible**: Advanced users can experiment with coordination patterns
3. **Documentation Required**: Must clearly communicate current limitations and future plans

## Alternatives Considered

### Alternative 1: Implement Basic Multi-Agent Coordination Now

**Approach**: Build simple agent team and delegation patterns in v0.3.x

**Pros**:
- Earlier availability of multi-agent features
- Earlier validation of design
- Competitive feature parity
- Enables more complex use cases immediately

**Cons**:
- Significantly increases v0.3.x scope
- Delays critical security and learning features
- Risk of wrong abstraction without validated requirements
- Higher testing and documentation burden
- May compromise single-agent quality focus

**Decision**: Rejected - Risk/reward not favorable without validated requirements.

### Alternative 2: Full Multi-Agent System

**Approach**: Implement comprehensive multi-agent architecture with teams, protocols, consensus, delegation

**Pros**:
- Complete solution for all multi-agent scenarios
- Highly differentiated feature
- Research-grade capabilities

**Cons**:
- Extremely high complexity
- 3-6 month implementation timeline
- Blocks all other v0.3.x and v0.4.0 features
- Risk of over-engineering
- Maintenance burden
- May not match real user needs

**Decision**: Rejected - Massive scope, unclear value proposition.

### Alternative 3: No Multi-Agent Coordination Ever

**Approach**: Focus exclusively on single-agent orchestration, never add multi-agent features

**Pros**:
- Simplest possible architecture
- Clear scope boundaries
- Easier maintenance
- Lower complexity

**Cons**:
- Limits framework applicability
- Less competitive
- Misses legitimate use cases
- Doesn't align with "agent orchestration" vision

**Decision**: Rejected - Multi-agent coordination aligns with framework vision, just needs proper timing.

### Alternative 4: Plugin-Based Multi-Agent Extensions

**Approach**: Let community/third parties build multi-agent extensions through plugin system

**Pros**:
- Community-driven innovation
- Multiple approaches can coexist
- Framework stays focused
- Real validation of needs

**Cons**:
- Fragmented ecosystem
- No standard patterns
- Quality/compatibility concerns
- May require core changes anyway

**Decision**: Partially adopted - Allow experimentation while planning official implementation.

## Implementation Notes

### v0.3.x: Foundation Only

**What to Implement:**
1. `ExecutionContext` with shared state support
2. `AgentMessage` structure definition (interface only)
3. `role_type` attribute on `AgentSpecification`
4. Reserved `MultiAgent` namespace
5. Documentation of deferral and future plans

**What NOT to Implement:**
- Agent communication protocol
- Team orchestration
- Delegation logic
- Consensus building
- Coordinator agents

**Estimated Effort**: 2-3 days (minimal)

### v0.4.0+: Full Implementation

**Requirements Gathering (Before Implementation):**
1. Survey users for multi-agent use cases
2. Analyze community feedback and feature requests
3. Study other agent frameworks (AutoGPT, LangGraph, CrewAI)
4. Prototype coordination patterns with real scenarios
5. Define performance and complexity budgets

**Design Decisions Needed:**
1. Synchronous vs. asynchronous agent communication
2. Centralized vs. decentralized coordination
3. Message-passing vs. shared-memory architecture
4. Failure handling in multi-agent scenarios
5. Resource allocation across agents
6. Observability for multi-agent workflows

**Implementation Phases:**
1. **Phase 1**: Agent communication protocol (2 weeks)
2. **Phase 2**: Agent teams with coordinator pattern (2 weeks)
3. **Phase 3**: Delegation and specialization (2 weeks)
4. **Phase 4**: Consensus and voting mechanisms (1 week)
5. **Phase 5**: Testing, documentation, examples (2 weeks)

**Total Estimated Effort**: 9 weeks

### Documentation Requirements

**Immediate (v0.3.x):**
1. **Roadmap Document**: Clearly communicate multi-agent plans for v0.4.0+
2. **Limitation Notice**: Document that current version is single-agent only
3. **Workaround Guide**: Show how to manually coordinate multiple agents
4. **Feature Request Process**: How to submit multi-agent requirements

**Future (v0.4.0+):**
1. **Multi-Agent Patterns Guide**: Common coordination patterns and when to use them
2. **Team Composition Guide**: How to design agent teams for complex tasks
3. **Performance Guide**: Multi-agent overhead and optimization strategies
4. **Migration Guide**: Updating single-agent code to multi-agent patterns

## Related ADRs

- ADR-016: Agent Assembly Engine (single-agent assembly foundation)
- ADR-019: Agent Assembly Learning Integration (may need multi-agent learning in future)
- ADR-011: Task Observable Pattern (observability for multi-agent coordination)

## Future Considerations (v0.4.0+ Design)

### Key Research Questions

1. **Communication Overhead**: How to minimize latency in agent-to-agent communication?
2. **Deadlock Prevention**: How to prevent coordination deadlocks?
3. **Fault Tolerance**: What happens when one agent in a team fails?
4. **Resource Management**: How to allocate LLM API quota across multiple agents?
5. **Observability**: How to visualize and debug multi-agent workflows?
6. **Testing**: How to test multi-agent coordination reliably?

### Potential Architecture (Strawman)

```ruby
# Example v0.4.0+ API (subject to change)
team = Agentic::MultiAgent::AgentTeam.new do |team|
  team.coordinator = Agentic.assemble_agent(coordinator_task)

  team.add_specialist(:researcher, capabilities: [:web_search, :document_analysis])
  team.add_specialist(:analyst, capabilities: [:data_analysis, :visualization])
  team.add_specialist(:writer, capabilities: [:text_generation, :editing])

  team.coordination_strategy = :delegation
  team.communication_mode = :message_passing
end

result = team.execute(complex_task)
```

### Integration with Learning System

Multi-agent patterns should integrate with learning system (ADR-019):
- Learn which team compositions work for which task types
- Optimize agent selection for roles
- Improve coordination strategies based on outcomes
- Reduce communication overhead through learned patterns

### Success Metrics for v0.4.0+

When multi-agent coordination is implemented, measure:
1. **Task Success Rate**: Do multi-agent tasks complete more successfully?
2. **Quality Improvement**: Do multi-agent results have higher quality scores?
3. **User Adoption**: What % of users enable multi-agent features?
4. **Performance Impact**: How much overhead does coordination add?
5. **Complexity Impact**: Does it significantly increase user code complexity?

## Validation Gates

Before implementing multi-agent coordination in v0.4.0+, validate:

1. **User Demand**: At least 10 users request multi-agent features
2. **Use Case Documentation**: At least 5 concrete use cases documented
3. **Competitive Analysis**: Understanding of how other frameworks solve this
4. **Technical Feasibility**: Prototype proves approach viable
5. **Resource Availability**: Team capacity for 9-week implementation

If validation gates not met, defer to v0.5.0+.
