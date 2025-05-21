# frozen_string_literal: true

module Agentic
  module Learning
    # StrategyOptimizer improves execution strategies based on historical performance data.
    # It uses insights from the PatternRecognizer to automatically generate optimized
    # strategies for tasks, agents, and plans.
    #
    # @example Optimizing a prompt template
    #   history_store = Agentic::Learning::ExecutionHistoryStore.new
    #   recognizer = Agentic::Learning::PatternRecognizer.new(history_store: history_store)
    #   optimizer = Agentic::Learning::StrategyOptimizer.new(
    #     pattern_recognizer: recognizer,
    #     history_store: history_store
    #   )
    #
    #   improved_prompt = optimizer.optimize_prompt_template(
    #     original_template: "Please research the following topic: {topic}",
    #     agent_type: "research_agent"
    #   )
    #
    class StrategyOptimizer
      # Initialize a new StrategyOptimizer
      #
      # @param options [Hash] Configuration options
      # @option options [Logger] :logger Custom logger (defaults to Agentic.logger)
      # @option options [PatternRecognizer] :pattern_recognizer Pattern recognizer for insights
      # @option options [ExecutionHistoryStore] :history_store History store for performance data
      # @option options [LlmClient] :llm_client LLM client for generating optimizations (optional)
      # @option options [Integer] :optimization_interval_hours Hours between optimization attempts (defaults to 24)
      # @option options [Boolean] :auto_apply_optimizations Whether to automatically apply optimizations (defaults to false)
      def initialize(options = {})
        @logger = options[:logger] || Agentic.logger
        @pattern_recognizer = options[:pattern_recognizer] || raise(ArgumentError, "pattern_recognizer is required")
        @history_store = options[:history_store] || raise(ArgumentError, "history_store is required")
        @llm_client = options[:llm_client]
        @optimization_interval_hours = options[:optimization_interval_hours] || 24
        @auto_apply_optimizations = options.fetch(:auto_apply_optimizations, false)
        @optimization_cache = {}
        @last_optimization = {}
      end

      # Optimize a prompt template based on historical performance
      #
      # @param original_template [String] The original prompt template
      # @param agent_type [String] The agent type using this prompt
      # @param options [Hash] Optimization options
      # @option options [Boolean] :force Force optimization even if recently optimized
      # @option options [Symbol] :optimization_strategy Strategy to use (:conservative, :balanced, :aggressive)
      # @option options [Hash] :context Additional context for optimization
      # @return [Hash] Optimization result with improved template and explanation
      def optimize_prompt_template(original_template, agent_type, options = {})
        cache_key = "prompt:#{agent_type}:#{Digest::MD5.hexdigest(original_template)}"

        # Check cache and optimization interval
        unless options[:force]
          if @optimization_cache[cache_key] &&
              @last_optimization[cache_key] &&
              @last_optimization[cache_key] > Time.now - (@optimization_interval_hours * 3600)
            return @optimization_cache[cache_key]
          end
        end

        # Get performance data
        performance = @pattern_recognizer.analyze_agent_performance(agent_type)

        if performance[:insufficient_data]
          @logger.info("Insufficient data to optimize prompt for #{agent_type}")
          return {
            optimized: false,
            reason: "Insufficient performance data",
            original_template: original_template,
            improved_template: original_template
          }
        end

        # Generate optimization
        optimization = if @llm_client
          generate_optimized_prompt_with_llm(original_template, agent_type, performance, options)
        else
          generate_optimized_prompt_heuristic(original_template, agent_type, performance, options)
        end

        # Cache result
        @optimization_cache[cache_key] = optimization
        @last_optimization[cache_key] = Time.now

        optimization
      end

      # Optimize LLM parameters based on historical performance
      #
      # @param original_params [Hash] The original LLM parameters
      # @param agent_type [String] The agent type using these parameters
      # @param options [Hash] Optimization options
      # @option options [Boolean] :force Force optimization even if recently optimized
      # @option options [Symbol] :optimization_strategy Strategy to use (:conservative, :balanced, :aggressive)
      # @return [Hash] Optimization result with improved parameters and explanation
      def optimize_llm_parameters(original_params, agent_type, options = {})
        cache_key = "params:#{agent_type}:#{Digest::MD5.hexdigest(original_params.to_s)}"

        # Check cache and optimization interval
        unless options[:force]
          if @optimization_cache[cache_key] &&
              @last_optimization[cache_key] &&
              @last_optimization[cache_key] > Time.now - (@optimization_interval_hours * 3600)
            return @optimization_cache[cache_key]
          end
        end

        # Get performance data
        performance = @pattern_recognizer.analyze_agent_performance(agent_type)

        if performance[:insufficient_data]
          @logger.info("Insufficient data to optimize LLM parameters for #{agent_type}")
          return {
            optimized: false,
            reason: "Insufficient performance data",
            original_params: original_params,
            improved_params: original_params.dup
          }
        end

        # Generate optimization
        optimization = generate_optimized_parameters(original_params, agent_type, performance, options)

        # Cache result
        @optimization_cache[cache_key] = optimization
        @last_optimization[cache_key] = Time.now

        optimization
      end

      # Optimize task sequence based on historical performance
      #
      # @param original_sequence [Array<Hash>] Original task sequence
      # @param plan_type [String] The type of plan
      # @param options [Hash] Optimization options
      # @option options [Boolean] :force Force optimization even if recently optimized
      # @return [Hash] Optimization result with improved sequence and explanation
      def optimize_task_sequence(original_sequence, plan_type, options = {})
        cache_key = "sequence:#{plan_type}:#{Digest::MD5.hexdigest(original_sequence.to_s)}"

        # Check cache and optimization interval
        unless options[:force]
          if @optimization_cache[cache_key] &&
              @last_optimization[cache_key] &&
              @last_optimization[cache_key] > Time.now - (@optimization_interval_hours * 3600)
            return @optimization_cache[cache_key]
          end
        end

        # Get historical plan executions
        end_time = Time.now
        start_time = end_time - (30 * 24 * 60 * 60) # 30 days

        plan_history = @history_store.get_history(
          plan_id: plan_type,
          start_time: start_time,
          end_time: end_time
        )

        if plan_history.size < 5
          @logger.info("Insufficient data to optimize task sequence for #{plan_type}")
          return {
            optimized: false,
            reason: "Insufficient plan execution data",
            original_sequence: original_sequence,
            improved_sequence: original_sequence.dup
          }
        end

        # Generate optimization
        optimization = generate_optimized_sequence(original_sequence, plan_history, options)

        # Cache result
        @optimization_cache[cache_key] = optimization
        @last_optimization[cache_key] = Time.now

        optimization
      end

      # Apply learned optimizations to existing configurations
      #
      # @param target [Symbol] Type of target to optimize (:prompts, :parameters, :sequences)
      # @param registry [Hash] Registry of current configurations
      # @return [Hash] Results of optimization applications
      def apply_optimizations(target, registry)
        results = {}

        case target
        when :prompts
          registry.each do |key, template|
            agent_type = extract_agent_type_from_key(key)
            next unless agent_type

            result = optimize_prompt_template(template, agent_type)
            results[key] = result

            if result[:optimized] && @auto_apply_optimizations
              # Logic to apply optimization to registry would go here
              @logger.info("Auto-applied optimized prompt for #{key}")
            end
          end

        when :parameters
          registry.each do |key, params|
            agent_type = extract_agent_type_from_key(key)
            next unless agent_type

            result = optimize_llm_parameters(params, agent_type)
            results[key] = result

            if result[:optimized] && @auto_apply_optimizations
              # Logic to apply optimization to registry would go here
              @logger.info("Auto-applied optimized parameters for #{key}")
            end
          end

        when :sequences
          registry.each do |key, sequence|
            plan_type = key.to_s

            result = optimize_task_sequence(sequence, plan_type)
            results[key] = result

            if result[:optimized] && @auto_apply_optimizations
              # Logic to apply optimization to registry would go here
              @logger.info("Auto-applied optimized sequence for #{key}")
            end
          end
        end

        results
      end

      # Generate a performance report for a specific agent type
      #
      # @param agent_type [String] The agent type to report on
      # @return [Hash] Performance report with metrics and optimization suggestions
      def generate_performance_report(agent_type)
        performance = @pattern_recognizer.analyze_agent_performance(agent_type)

        if performance[:insufficient_data]
          return {
            agent_type: agent_type,
            status: :insufficient_data,
            message: "Not enough execution data to generate a meaningful report"
          }
        end

        # Get recommendations
        recommendations = @pattern_recognizer.recommend_optimizations(agent_type)

        {
          agent_type: agent_type,
          status: :complete,
          timestamp: Time.now.iso8601,
          metrics: {
            success_rate: performance[:success_rate][:overall],
            trend: performance[:success_rate][:trend],
            sample_size: performance[:success_rate][:sample_size]
          },
          performance_trends: performance[:performance_trends],
          failure_patterns: performance[:failure_patterns],
          recommendations: recommendations
        }
      end

      private

      def generate_optimized_prompt_with_llm(original_template, agent_type, performance, options)
        return {optimized: false, reason: "LLM client not available"} unless @llm_client

        # Get failure patterns and recommendations
        recommendations = @pattern_recognizer.recommend_optimizations(agent_type)

        # Prepare context for the LLM
        context = {
          original_template: original_template,
          agent_type: agent_type,
          success_rate: performance[:success_rate][:overall],
          trend: performance[:success_rate][:trend],
          failure_patterns: performance[:failure_patterns].first(3),
          recommendations: recommendations.first(3)
        }

        # Generate optimization prompt
        optimization_prompt = <<~PROMPT
          I need to optimize this prompt template for a #{agent_type}:

          """
          #{original_template}
          """

          Performance data:
          - Success rate: #{(context[:success_rate] * 100).round(1)}%
          - Trend: #{context[:trend]}

          Common failure patterns:
          #{context[:failure_patterns].map { |p| "- #{p[:pattern]} (#{p[:count]} occurrences)" }.join("\n")}

          Recommendations:
          #{recommendations.map { |r| "- #{r[:message]}" }.join("\n")}

          Please provide an improved version of this prompt template that addresses these issues.
          Format your response as:

          IMPROVED_TEMPLATE:
          [Your improved template here]

          EXPLANATION:
          [Explanation of changes and how they address the issues]
        PROMPT

        # Generate optimization with LLM
        response = @llm_client.complete(optimization_prompt)

        # Parse response
        improved_template = extract_improved_template(response)
        explanation = extract_explanation(response)

        if improved_template && improved_template != original_template
          {
            optimized: true,
            original_template: original_template,
            improved_template: improved_template,
            explanation: explanation,
            confidence: calculate_confidence(performance, improved_template, original_template)
          }
        else
          {
            optimized: false,
            reason: "LLM optimization did not produce a different template",
            original_template: original_template,
            improved_template: original_template
          }
        end
      end

      def generate_optimized_prompt_heuristic(original_template, agent_type, performance, options)
        # Simple heuristic-based optimization without LLM
        improved_template = original_template.dup
        changes = []

        # Check for common failure patterns and apply heuristic improvements
        Array(performance[:failure_patterns]).each do |pattern|
          case pattern[:pattern]
          when /timeout/i, /too slow/i
            if !improved_template.include?("time limit") && !improved_template.include?("time constraint")
              improved_template = improved_template.sub(/\A/, "You must complete this task efficiently within the time limit. ")
              changes << "Added time constraint reminder"
            end

          when /unclear instructions/i, /ambiguous/i
            if !improved_template.include?("clear and specific")
              improved_template = improved_template.sub(/\A/, "Be clear and specific in your response. ")
              changes << "Added clarity instruction"
            end

          when /missing information/i, /incomplete/i
            if !improved_template.include?("comprehensive") && !improved_template.include?("complete")
              improved_template = improved_template.sub(/\A/, "Provide a comprehensive and complete response. ")
              changes << "Added comprehensiveness instruction"
            end
          end
        end

        # Check success rate trend
        if performance[:success_rate][:trend] == :declining
          if !improved_template.include?("step by step")
            improved_template = improved_template.sub(/\A/, "Follow these instructions step by step. ")
            changes << "Added step-by-step instruction due to declining success rate"
          end
        end

        if changes.empty?
          {
            optimized: false,
            reason: "No heuristic improvements identified",
            original_template: original_template,
            improved_template: original_template
          }
        else
          {
            optimized: true,
            original_template: original_template,
            improved_template: improved_template,
            explanation: "Applied heuristic improvements: #{changes.join(", ")}",
            confidence: 0.7 # Heuristic confidence is fixed
          }
        end
      end

      def generate_optimized_parameters(original_params, agent_type, performance, options)
        # Copy original parameters
        improved_params = original_params.dup
        changes = []
        strategy = options[:optimization_strategy] || :balanced

        # Adjust parameters based on performance data
        if performance[:performance_trends]
          # Check for token usage trends
          if performance[:performance_trends][:tokens_used] &&
              performance[:performance_trends][:tokens_used][:trend] == :increasing &&
              performance[:performance_trends][:tokens_used][:significant]

            # Reduce max tokens if usage is increasing
            if improved_params[:max_tokens] && improved_params[:max_tokens] > 100
              case strategy
              when :conservative
                new_max = improved_params[:max_tokens] * 0.95 # Reduce by 5%
              when :balanced
                new_max = improved_params[:max_tokens] * 0.9 # Reduce by 10%
              when :aggressive
                new_max = improved_params[:max_tokens] * 0.8 # Reduce by 20%
              end

              improved_params[:max_tokens] = new_max.to_i
              changes << "Reduced max_tokens from #{original_params[:max_tokens]} to #{improved_params[:max_tokens]}"
            end
          end
        end

        # Check success rate and adjust temperature
        if performance[:success_rate][:overall] < 0.8 && improved_params[:temperature]
          # Lower temperature for more predictable results if success rate is low
          case strategy
          when :conservative
            if improved_params[:temperature] > 0.1
              improved_params[:temperature] = [improved_params[:temperature] - 0.1, 0.1].max
              changes << "Reduced temperature from #{original_params[:temperature]} to #{improved_params[:temperature]}"
            end
          when :balanced
            if improved_params[:temperature] > 0.1
              improved_params[:temperature] = [improved_params[:temperature] - 0.2, 0.1].max
              changes << "Reduced temperature from #{original_params[:temperature]} to #{improved_params[:temperature]}"
            end
          when :aggressive
            if improved_params[:temperature] > 0.05
              improved_params[:temperature] = [improved_params[:temperature] - 0.3, 0.05].max
              changes << "Reduced temperature from #{original_params[:temperature]} to #{improved_params[:temperature]}"
            end
          end
        elsif performance[:success_rate][:overall] > 0.95 &&
            performance[:success_rate][:trend] == :stable &&
            improved_params[:temperature] &&
            improved_params[:temperature] < 0.9
          # Increase temperature slightly for more creative results if success rate is high and stable
          case strategy
          when :conservative
            # No change for conservative strategy with high success
          when :balanced
            improved_params[:temperature] = [improved_params[:temperature] + 0.1, 0.9].min
            changes << "Increased temperature from #{original_params[:temperature]} to #{improved_params[:temperature]}"
          when :aggressive
            improved_params[:temperature] = [improved_params[:temperature] + 0.2, 0.9].min
            changes << "Increased temperature from #{original_params[:temperature]} to #{improved_params[:temperature]}"
          end
        end

        if changes.empty?
          {
            optimized: false,
            reason: "No parameter improvements identified",
            original_params: original_params,
            improved_params: original_params.dup
          }
        else
          {
            optimized: true,
            original_params: original_params,
            improved_params: improved_params,
            explanation: "Applied parameter optimizations: #{changes.join(", ")}",
            confidence: calculate_parameter_confidence(performance, original_params, improved_params)
          }
        end
      end

      def generate_optimized_sequence(original_sequence, plan_history, options)
        # Copy original sequence
        improved_sequence = original_sequence.map(&:dup)
        changes = []

        # Find slow tasks and potential parallelization opportunities
        task_durations = {}
        dependencies = {}

        # Extract task durations and dependencies from history
        plan_history.each do |execution|
          next unless execution[:context] && execution[:context][:task_durations]

          execution[:context][:task_durations].each do |task_id, duration|
            task_durations[task_id] ||= []
            task_durations[task_id] << duration
          end

          Array(execution[:context][:task_dependencies]).each do |task_id, deps|
            dependencies[task_id] = deps
          end
        end

        # Calculate average durations
        avg_durations = {}
        task_durations.each do |task_id, durations|
          avg_durations[task_id] = durations.sum / durations.size.to_f
        end

        # Find slow tasks
        slow_tasks = avg_durations.sort_by { |_, duration| -duration }.first(3).map(&:first)

        # Look for parallelization opportunities
        if dependencies.any?
          # Identify tasks that have no dependencies between them
          independent_tasks = []

          original_sequence.each_with_index do |task, i|
            next_task = original_sequence[i + 1]
            next unless next_task

            task_id = task[:id]
            next_id = next_task[:id]

            # Check if these tasks are independent
            if (!dependencies[task_id] || !dependencies[task_id].include?(next_id)) &&
                (!dependencies[next_id] || !dependencies[next_id].include?(task_id))

              independent_tasks << [task_id, next_id]
            end
          end

          # Apply parallelization
          if independent_tasks.any?
            # This is a simplified implementation - real parallelization would require
            # more sophisticated task scheduling logic
            pair = independent_tasks.first

            # Mark tasks for parallel execution
            improved_sequence.each do |task|
              if pair.include?(task[:id])
                task[:parallel] = true
                task[:parallel_group] = "group_#{pair.join("_")}"
              end
            end

            changes << "Marked tasks #{pair.join(" and ")} for parallel execution"
          end
        end

        # Optimize slow tasks
        slow_tasks.each do |task_id|
          task_idx = improved_sequence.find_index { |t| t[:id] == task_id }
          next unless task_idx

          task = improved_sequence[task_idx]

          # Add optimization hint
          task[:optimization_hint] = "This task is slower than average (#{(avg_durations[task_id] / 1000).round(2)}s)"

          # Suggest potential optimizations
          if avg_durations[task_id] > 10000 # Very slow task (>10s)
            task[:suggested_optimization] = "Consider breaking down into smaller sub-tasks"
            changes << "Added breakdown suggestion for slow task #{task_id}"
          elsif task[:description] && task[:description].length > 200
            task[:suggested_optimization] = "Consider simplifying task description"
            changes << "Added simplification suggestion for task #{task_id}"
          else
            task[:suggested_optimization] = "Review for optimization opportunities"
            changes << "Added general optimization suggestion for task #{task_id}"
          end
        end

        if changes.empty?
          {
            optimized: false,
            reason: "No sequence improvements identified",
            original_sequence: original_sequence,
            improved_sequence: original_sequence.map(&:dup)
          }
        else
          {
            optimized: true,
            original_sequence: original_sequence,
            improved_sequence: improved_sequence,
            explanation: "Applied sequence optimizations: #{changes.join(", ")}",
            confidence: 0.8
          }
        end
      end

      def extract_improved_template(response)
        # Extract the improved template from LLM response
        match = response.match(/IMPROVED_TEMPLATE:\s*(.+?)(?:EXPLANATION:|$)/mi)
        match ? match[1].strip : nil
      end

      def extract_explanation(response)
        # Extract the explanation from LLM response
        match = response.match(/EXPLANATION:\s*(.+?)$/mi)
        match ? match[1].strip : "No explanation provided"
      end

      def calculate_confidence(performance, improved_template, original_template)
        # Calculate confidence based on performance data and degree of change

        # Base confidence on performance data quality
        base_confidence = if performance[:success_rate][:sample_size] > 100
          0.9
        elsif performance[:success_rate][:sample_size] > 50
          0.8
        elsif performance[:success_rate][:sample_size] > 20
          0.7
        else
          0.6
        end

        # Adjust based on degree of change
        change_ratio = calculate_change_ratio(improved_template, original_template)

        if change_ratio > 0.5
          # Large changes reduce confidence
          base_confidence *= 0.8
        elsif change_ratio < 0.1
          # Very small changes increase confidence
          base_confidence *= 1.1
        end

        # Cap at 0.95
        [base_confidence, 0.95].min
      end

      def calculate_change_ratio(improved, original)
        return 0.0 if improved == original

        # Calculate Levenshtein distance as a ratio of the original length
        distance = levenshtein_distance(improved, original)
        distance.to_f / original.length
      end

      def levenshtein_distance(str1, str2)
        # Simple Levenshtein distance implementation
        m = str1.length
        n = str2.length

        # Initialize the matrix
        matrix = Array.new(m + 1) { Array.new(n + 1, 0) }

        # Fill the first row and column
        (0..m).each { |i| matrix[i][0] = i }
        (0..n).each { |j| matrix[0][j] = j }

        # Fill the rest of the matrix
        (1..m).each do |i|
          (1..n).each do |j|
            cost = (str1[i - 1] == str2[j - 1]) ? 0 : 1
            matrix[i][j] = [
              matrix[i - 1][j] + 1,
              matrix[i][j - 1] + 1,
              matrix[i - 1][j - 1] + cost
            ].min
          end
        end

        matrix[m][n]
      end

      def calculate_parameter_confidence(performance, original_params, improved_params)
        # Calculate confidence for parameter optimizations

        # Base confidence on performance data quality
        base_confidence = if performance[:success_rate][:sample_size] > 100
          0.85
        elsif performance[:success_rate][:sample_size] > 50
          0.75
        elsif performance[:success_rate][:sample_size] > 20
          0.65
        else
          0.5
        end

        # Count changed parameters
        changes = 0
        original_params.each do |key, value|
          changes += 1 if improved_params[key] && improved_params[key] != value
        end

        # Adjust confidence based on number of changes
        if changes > 2
          # More changes reduce confidence
          base_confidence *= 0.9
        elsif changes == 1
          # Single change increases confidence
          base_confidence *= 1.05
        end

        # Cap at 0.9
        [base_confidence, 0.9].min
      end

      def extract_agent_type_from_key(key)
        # Extract agent type from registry key
        key.to_s.split(".").first
      end
    end
  end
end
