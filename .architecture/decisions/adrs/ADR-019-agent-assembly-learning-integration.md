# ADR-019: Agent Assembly Learning Integration

## Status

Accepted

## Context

The Agentic framework includes a comprehensive learning system infrastructure with `ExecutionHistoryStore`, `PatternRecognizer`, and `StrategyOptimizer` components. However, this learning system is currently **disconnected from the agent assembly process**.

Current situation:
1. `AgentAssemblyEngine` selects capabilities using static rules (keyword matching) or LLM-assisted strategies
2. Execution history is stored but never consulted during assembly
3. No feedback loop exists between task execution outcomes and future capability selection
4. Successful capability combinations are not learned or recommended
5. Assembly strategies don't improve based on real-world performance data

Architecture review findings (Taylor Kim - Agent Systems Engineer, Jamie Chen - Domain Expert):
- **Medium Risk**: Lack of learning integration means system won't improve with usage
- Core architectural goal of "self-improving framework" is not realized
- Pattern recognition and execution history components exist but unused
- Missing feedback loop from task completion to future assemblies

This is inconsistent with the framework's vision of being a **self-improving agent orchestration system**. Without learning integration, the framework cannot:
- Recommend capabilities based on historical success
- Avoid capability combinations that led to failures
- Optimize agent assembly based on real-world performance
- Adapt to domain-specific patterns over time

## Decision

We will **integrate the learning system with agent assembly** through a frequency-based learning approach that captures execution feedback and improves future capability selection decisions.

### 1. Assembly Feedback Collection

Capture the relationship between assembled agents and task outcomes:

```ruby
# After task execution completes
class Task
  def perform(agent)
    result = execute_task_with_agent(agent)

    # Record assembly feedback
    record_assembly_feedback(
      task: self,
      agent: agent,
      capabilities_used: agent.capabilities.keys,
      result: result,
      success: result.success?,
      execution_time: result.duration,
      quality_score: calculate_quality_score(result)
    )

    result
  end
end
```

### 2. Execution History Enhancement

Extend `ExecutionHistoryStore` to track agent assembly metadata:

```ruby
class ExecutionHistoryStore
  def record_execution(execution_record)
    {
      task_id: execution_record.task_id,
      task_description: execution_record.task.description,
      task_type: infer_task_type(execution_record.task),
      agent_id: execution_record.agent.id,
      capabilities: execution_record.agent.capabilities.keys,
      capability_versions: execution_record.agent.capability_versions,
      result: execution_record.result,
      success: execution_record.success?,
      quality_score: execution_record.quality_score,
      execution_time_ms: execution_record.duration,
      timestamp: Time.now.utc
    }
  end

  def query_similar_tasks(task, limit: 10)
    # Find historical tasks similar to current task
    # Returns execution records with agent assembly info
  end
end
```

### 3. Pattern Recognition for Capabilities

Enhance `PatternRecognizer` to identify successful capability patterns:

```ruby
class PatternRecognizer
  # Find capability combinations that frequently succeed
  def recommend_capabilities(task, context = {})
    # 1. Identify task type/category
    task_type = categorize_task(task)

    # 2. Query execution history for similar tasks
    similar_executions = execution_history.query_similar_tasks(task)

    # 3. Calculate capability frequency and success rate
    capability_stats = analyze_capability_performance(similar_executions)

    # 4. Return ranked capability recommendations
    capability_stats
      .filter { |cap, stats| stats[:success_rate] >= 0.6 }
      .sort_by { |cap, stats| stats[:frequency] * stats[:success_rate] }
      .reverse
      .take(10)
  end

  private

  def analyze_capability_performance(executions)
    capabilities = {}

    executions.each do |exec|
      exec[:capabilities].each do |capability|
        capabilities[capability] ||= {
          total_uses: 0,
          successful_uses: 0,
          total_quality_score: 0.0
        }

        capabilities[capability][:total_uses] += 1
        capabilities[capability][:successful_uses] += 1 if exec[:success]
        capabilities[capability][:total_quality_score] += exec[:quality_score]
      end
    end

    # Calculate statistics
    capabilities.transform_values do |stats|
      {
        frequency: stats[:total_uses],
        success_rate: stats[:successful_uses].to_f / stats[:total_uses],
        avg_quality: stats[:total_quality_score] / stats[:total_uses]
      }
    end
  end
end
```

### 4. Learning-Enhanced Composition Strategy

Create a new composition strategy that uses learning data:

```ruby
class LearningEnhancedCompositionStrategy < AgentCompositionStrategy
  def select_capabilities(requirements, registry)
    # 1. Get rule-based candidate capabilities (baseline)
    baseline_capabilities = select_baseline_capabilities(requirements, registry)

    # 2. Get learning-based recommendations
    learned_recommendations = pattern_recognizer.recommend_capabilities(
      task: requirements[:task],
      context: requirements
    )

    # 3. Merge and rank capabilities
    merged_capabilities = merge_capability_sources(
      baseline: baseline_capabilities,
      learned: learned_recommendations,
      weights: { baseline: 0.4, learned: 0.6 } # Prefer learned patterns
    )

    # 4. Add dependencies
    add_dependencies(merged_capabilities, registry)
  end

  private

  def merge_capability_sources(baseline:, learned:, weights:)
    # Combine scores from both sources
    # Boost capabilities that appear in both
    # Filter out capabilities with low combined score
  end
end
```

### 5. Integration with AgentAssemblyEngine

Update the assembly engine to use learning-enhanced strategy:

```ruby
class AgentAssemblyEngine
  def assemble_agent(task, strategy: nil, store: true)
    # Default to learning-enhanced strategy if available and enabled
    strategy ||= determine_default_strategy(task)

    # Check for existing agent with learning-based matching
    if existing_agent = find_agent_with_learning(task)
      return existing_agent
    end

    # Proceed with assembly using learning-enhanced strategy
    requirements = analyze_requirements(task)
    capabilities = strategy.select_capabilities(requirements, @registry)
    agent = build_agent(task, capabilities)

    # Store agent with assembly metadata
    store_agent_with_metadata(agent, task, capabilities) if store

    agent
  end

  private

  def determine_default_strategy(task)
    # Use learning strategy if sufficient historical data exists
    if pattern_recognizer.has_sufficient_data?(task)
      LearningEnhancedCompositionStrategy.new(pattern_recognizer)
    else
      # Fall back to rule-based for new task types
      DefaultCompositionStrategy.new
    end
  end

  def find_agent_with_learning(task)
    # Enhanced matching using learned patterns
    candidates = agent_store.find_candidates_for_task(task)

    return nil if candidates.empty?

    # Score candidates using learned quality metrics
    scored_candidates = candidates.map do |agent|
      score = calculate_learned_match_score(agent, task)
      [agent, score]
    end

    best_match, score = scored_candidates.max_by { |_, s| s }

    # Return if score exceeds learned threshold
    best_match if score >= learned_threshold_for_task(task)
  end
end
```

### 6. Quality Score Calculation

Define how to measure task execution quality:

```ruby
module Agentic
  class QualityScorer
    def self.calculate(task_result)
      scores = []

      # Success/failure (0.0 or 1.0)
      scores << (task_result.success? ? 1.0 : 0.0)

      # Verification confidence (if available)
      if task_result.verification_result
        scores << task_result.verification_result.confidence
      end

      # Execution time penalty (faster is better)
      time_score = calculate_time_score(task_result.duration)
      scores << time_score

      # Token usage efficiency (if available)
      if task_result.token_usage
        efficiency_score = calculate_efficiency_score(task_result.token_usage)
        scores << efficiency_score
      end

      # Weighted average
      scores.sum / scores.size
    end
  end
end
```

## Consequences

### Positive

1. **Self-Improvement**: Framework improves with usage, realizing core architectural goal
2. **Domain Adaptation**: Automatically adapts to domain-specific patterns without manual configuration
3. **Cost Optimization**: Learns which capability combinations are most efficient
4. **Reduced Assembly Time**: Successful patterns discovered faster than LLM-assisted analysis
5. **Quality Improvement**: Learns to avoid capability combinations that led to failures
6. **Data-Driven**: Decisions based on real execution data rather than heuristics
7. **Transparent**: Learning process observable and explainable

### Negative

1. **Cold Start Problem**: New task types have no historical data to learn from
2. **Bias Risk**: Early successes/failures may bias future assemblies inappropriately
3. **Storage Requirements**: Execution history grows over time, requires management
4. **Complexity**: Additional components and logic increase system complexity
5. **Computation Overhead**: Pattern analysis adds latency to assembly process
6. **Privacy Concerns**: Historical data may contain sensitive information

### Neutral

1. **Gradual Improvement**: Benefits increase over time as more data is collected
2. **Fallback Required**: Must maintain non-learning strategies for cold start
3. **Monitoring Needed**: Learning effectiveness requires metrics and dashboards

## Alternatives Considered

### Alternative 1: Embedding-Based Similarity Learning

**Approach**: Use LLM embeddings to find semantically similar historical tasks

**Pros**:
- More sophisticated similarity matching
- Can find similar tasks even with different wording
- Better generalization across task types

**Cons**:
- Requires LLM API calls for every assembly (high cost)
- Adds significant latency
- More complex implementation
- Requires embedding storage and vector search

**Decision**: Deferred to future enhancement. Start with frequency-based learning (simpler, faster), add embedding-based similarity later if needed.

### Alternative 2: Reinforcement Learning

**Approach**: Use RL algorithms (Q-learning, policy gradients) to learn optimal capability selection

**Pros**:
- Sophisticated optimization
- Can handle complex state spaces
- Proven approach in AI research

**Cons**:
- Very high complexity
- Requires extensive training data
- Difficult to debug and explain
- Overkill for current problem scope

**Decision**: Rejected - Too complex for initial implementation. Frequency-based learning provides 80% of benefit with 20% of complexity.

### Alternative 3: No Learning Integration

**Approach**: Keep learning system separate, rely on manual strategy tuning

**Pros**:
- Simplest implementation
- No cold start problem
- Predictable behavior

**Cons**:
- Misses core architectural goal
- No improvement over time
- Wastes learning infrastructure investment
- Less competitive with other agent frameworks

**Decision**: Rejected - Contradicts framework vision and architecture goals.

### Alternative 4: LLM-Only Learning

**Approach**: Feed execution history to LLM, let it recommend capabilities

**Pros**:
- Leverages LLM reasoning
- Can handle nuanced patterns
- Flexible

**Cons**:
- High API costs
- Slow assembly
- Unpredictable
- Requires careful prompt engineering

**Decision**: Rejected as primary approach - Can be used as hybrid enhancement to frequency-based learning.

## Implementation Notes

### Phase 1: Feedback Collection (High Priority)

1. Add `AssemblyFeedback` class to capture assembly-execution relationship
2. Integrate feedback collection into `Task.perform` method
3. Store feedback in `ExecutionHistoryStore`
4. Add quality score calculation

**Estimated Effort**: 3-5 days
**Target**: v0.3.x

### Phase 2: Pattern Recognition (High Priority)

1. Enhance `PatternRecognizer` with capability recommendation logic
2. Implement similarity-based task querying
3. Add capability frequency and success rate analysis
4. Create capability ranking algorithm

**Estimated Effort**: 5-7 days
**Target**: v0.3.x

### Phase 3: Learning-Enhanced Strategy (High Priority)

1. Implement `LearningEnhancedCompositionStrategy`
2. Add merging logic for baseline + learned capabilities
3. Integrate with `AgentAssemblyEngine`
4. Add configuration for learning thresholds

**Estimated Effort**: 5-7 days
**Target**: v0.3.x or v0.4.0

### Phase 4: Enhanced Agent Matching (Medium Priority)

1. Update `find_existing_agent` to use learned quality scores
2. Implement dynamic threshold calculation
3. Add agent match explanations

**Estimated Effort**: 3-5 days
**Target**: v0.4.0

### Phase 5: Monitoring and Analytics (Medium Priority)

1. Create learning effectiveness dashboard
2. Add metrics for recommendation quality
3. Implement A/B testing framework for strategies
4. Add learning data export/import

**Estimated Effort**: 5-7 days
**Target**: v0.4.0

### Testing Strategy

1. **Unit Tests**: Pattern recognition, quality scoring, capability ranking
2. **Integration Tests**: End-to-end learning cycle (assemble → execute → feedback → improve)
3. **Performance Tests**: Ensure pattern analysis doesn't slow assembly significantly
4. **Correctness Tests**: Verify learned patterns actually improve outcomes

### Cold Start Handling

1. **Minimum Data Threshold**: Require at least 10 executions before using learned recommendations
2. **Confidence Decay**: Reduce learning weight when limited data available
3. **Fallback Strategy**: Always maintain rule-based baseline for new task types
4. **Seed Data**: Provide initial execution history for common task types

### Privacy and Data Management

1. **Data Retention**: Configurable retention period (default: 90 days)
2. **Anonymization**: Option to anonymize task descriptions before storage
3. **Opt-Out**: Configuration to disable learning and execution history
4. **Export**: Ability to export and share anonymized learning data

## Related ADRs

- ADR-007: Learning System (foundational learning infrastructure)
- ADR-016: Agent Assembly Engine (integration point for learning)
- ADR-017: Streaming Observability (monitoring assembly and learning effectiveness)
- ADR-022: Agent Versioning Simplification (simpler versioning aids learning)

## Future Considerations

1. **Embedding-Based Similarity**: Upgrade from keyword matching to semantic similarity (v0.5.0+)
2. **Multi-Objective Optimization**: Balance quality, cost, and speed in capability selection
3. **Collaborative Filtering**: Learn from other users' execution patterns (with privacy controls)
4. **Transfer Learning**: Apply learned patterns across domains
5. **Active Learning**: Identify high-value experiments to improve learning faster
6. **Federated Learning**: Learn from distributed deployments without centralizing data
7. **Explainable Learning**: Provide detailed explanations of why capabilities were recommended
8. **Learning Rate Adaptation**: Automatically adjust learning sensitivity based on data quality
