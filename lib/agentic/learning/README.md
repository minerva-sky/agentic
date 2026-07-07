# Learning System Components

The Learning System in Agentic provides capabilities for capturing and analyzing execution data, identifying patterns, and optimizing strategies based on historical performance.

## Overview

The Learning System consists of three main components:

1. **ExecutionHistoryStore**: Captures and stores task and plan execution data.
2. **PatternRecognizer**: Analyzes execution history to identify patterns and optimization opportunities.
3. **StrategyOptimizer**: Uses insights from pattern analysis to optimize prompts, parameters, and task sequences.

## Usage

```ruby
# Initialize components
history_store = Agentic::Learning::ExecutionHistoryStore.new
recognizer = Agentic::Learning::PatternRecognizer.new(history_store: history_store)
optimizer = Agentic::Learning::StrategyOptimizer.new(
  pattern_recognizer: recognizer,
  history_store: history_store,
  llm_client: llm_client # Optional
)

# Record execution data
history_store.record_execution(
  task_id: "task-123",
  agent_type: "research_agent",
  duration_ms: 1500,
  success: true,
  metrics: { tokens_used: 2000 }
)

# Analyze patterns
patterns = recognizer.analyze_agent_performance("research_agent")

# Get optimization recommendations
recommendations = recognizer.recommend_optimizations("research_agent")

# Optimize a prompt template
improved_prompt = optimizer.optimize_prompt_template(
  original_template: "Please research the topic: {topic}",
  agent_type: "research_agent"
)

# Optimize LLM parameters
improved_params = optimizer.optimize_llm_parameters(
  original_params: { temperature: 0.7, max_tokens: 2000 },
  agent_type: "research_agent"
)

# Generate a performance report
report = optimizer.generate_performance_report("research_agent")
```

## Factory Method

The Learning module provides a factory method to create all components at once:

```ruby
learning_system = Agentic::Learning.create(
  storage_path: "/path/to/history",
  llm_client: llm_client,
  auto_optimize: false
)

# Access individual components
history_store = learning_system[:history_store]
recognizer = learning_system[:pattern_recognizer]
optimizer = learning_system[:strategy_optimizer]
```

## Integration with PlanOrchestrator

The Learning System can be integrated with the PlanOrchestrator to automatically record execution data:

```ruby
learning_system = Agentic::Learning.create(storage_path: "history")

orchestrator = Agentic::PlanOrchestrator.new(
  lifecycle_hooks: Agentic::Learning.lifecycle_hooks(learning_system)
)
```

Hooks are a construction-time seam; the learning system's hooks record every
task success and failure (and chain any hooks you already pass).