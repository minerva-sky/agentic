# frozen_string_literal: true

module Agentic
  # The Learning module provides components for capturing execution history,
  # recognizing patterns, and optimizing strategies based on feedback and metrics.
  #
  # @example Using the Learning System components
  #   # Initialize components
  #   history_store = Agentic::Learning::ExecutionHistoryStore.new
  #   recognizer = Agentic::Learning::PatternRecognizer.new(history_store: history_store)
  #   optimizer = Agentic::Learning::StrategyOptimizer.new(
  #     pattern_recognizer: recognizer,
  #     history_store: history_store
  #   )
  #
  #   # Record execution data
  #   history_store.record_execution(
  #     task_id: "task-123",
  #     agent_type: "research_agent",
  #     duration_ms: 1500,
  #     success: true,
  #     metrics: { tokens_used: 2000 }
  #   )
  #
  #   # Analyze patterns
  #   patterns = recognizer.analyze_agent_performance("research_agent")
  #
  #   # Optimize strategies
  #   improved_prompt = optimizer.optimize_prompt_template(
  #     original_template: "Please research the topic: {topic}",
  #     agent_type: "research_agent"
  #   )
  module Learning
    # Factory method to create a complete learning system
    #
    # @param options [Hash] Configuration options for all components
    # @option options [Logger] :logger Custom logger (defaults to Agentic.logger)
    # @option options [String] :storage_path Path for storing execution history
    # @option options [Boolean] :auto_optimize Whether to auto-apply optimizations
    # @option options [Symbol] :optimization_strategy Strategy (:conservative, :balanced, :aggressive)
    # @option options [LlmClient] :llm_client Optional LLM client for optimizations
    # @return [Hash] Hash containing all initialized learning system components
    def self.create(options = {})
      history_store = ExecutionHistoryStore.new(
        logger: options[:logger],
        storage_path: options[:storage_path],
        anonymize: options.fetch(:anonymize, true)
      )

      pattern_recognizer = PatternRecognizer.new(
        logger: options[:logger],
        history_store: history_store,
        min_sample_size: options[:min_sample_size] || 10
      )

      strategy_optimizer = StrategyOptimizer.new(
        logger: options[:logger],
        pattern_recognizer: pattern_recognizer,
        history_store: history_store,
        llm_client: options[:llm_client],
        auto_apply_optimizations: options.fetch(:auto_optimize, false)
      )

      {
        history_store: history_store,
        pattern_recognizer: pattern_recognizer,
        strategy_optimizer: strategy_optimizer
      }
    end

    # Register a learning system with a plan orchestrator
    #
    # @param plan_orchestrator [PlanOrchestrator] The plan orchestrator to integrate with
    # @param learning_system [Hash] The learning system components from Learning.create
    # @return [Boolean] true if successfully registered
    def self.register_with_orchestrator(plan_orchestrator, learning_system)
      # Register execution history tracking
      plan_orchestrator.on(:task_completed) do |task, result|
        learning_system[:history_store].record_execution(
          task_id: task.id,
          plan_id: task.context[:plan_id],
          agent_type: task.agent_spec&.type,
          duration_ms: result.metrics[:duration_ms],
          success: result.success?,
          metrics: result.metrics,
          context: {
            task_description: task.description,
            task_type: task.type,
            input_size: task.input ? task.input.to_s.length : 0
          }
        )
      end

      plan_orchestrator.on(:plan_completed) do |plan, results|
        # Record overall plan execution
        task_durations = {}
        task_dependencies = {}

        results.each do |task_id, result|
          task_durations[task_id] = result.metrics[:duration_ms] if result.metrics[:duration_ms]
        end

        # Extract dependencies from plan
        plan.tasks.each do |task|
          task_dependencies[task.id] = task.dependencies if task.dependencies&.any?
        end

        learning_system[:history_store].record_execution(
          plan_id: plan.id,
          success: results.values.all?(&:success?),
          duration_ms: results.values.sum { |r| r.metrics[:duration_ms] || 0 },
          metrics: {
            total_tasks: results.size,
            successful_tasks: results.values.count(&:success?),
            failed_tasks: results.values.count { |r| !r.success? }
          },
          context: {
            task_durations: task_durations,
            task_dependencies: task_dependencies
          }
        )
      end

      true
    end
  end
end
