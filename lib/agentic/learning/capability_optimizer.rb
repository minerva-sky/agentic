# frozen_string_literal: true

module Agentic
  module Learning
    # CapabilityOptimizer improves capability implementations and composition
    # based on execution history and performance metrics.
    #
    # @example Optimizing a capability implementation
    #   history_store = Agentic::Learning::ExecutionHistoryStore.new
    #   recognizer = Agentic::Learning::PatternRecognizer.new(history_store: history_store)
    #   optimizer = Agentic::Learning::CapabilityOptimizer.new(
    #     pattern_recognizer: recognizer,
    #     history_store: history_store,
    #     registry: Agentic.agent_capability_registry
    #   )
    #
    #   # Get optimization suggestions for a capability
    #   suggestions = optimizer.get_optimization_suggestions("text_generation")
    #
    class CapabilityOptimizer
      # Initialize a new CapabilityOptimizer
      #
      # @param options [Hash] Configuration options
      # @option options [Logger] :logger Custom logger (defaults to Agentic.logger)
      # @option options [PatternRecognizer] :pattern_recognizer Pattern recognizer for insights
      # @option options [ExecutionHistoryStore] :history_store History store for performance data
      # @option options [AgentCapabilityRegistry] :registry The capability registry
      # @option options [LlmClient] :llm_client LLM client for generating optimizations (optional)
      # @option options [Boolean] :auto_apply_optimizations Whether to automatically apply optimizations
      def initialize(options = {})
        @logger = options[:logger] || Agentic.logger
        @pattern_recognizer = options[:pattern_recognizer] || raise(ArgumentError, "pattern_recognizer is required")
        @history_store = options[:history_store] || raise(ArgumentError, "history_store is required")
        @registry = options[:registry] || Agentic.agent_capability_registry
        @llm_client = options[:llm_client]
        @auto_apply_optimizations = options.fetch(:auto_apply_optimizations, false)
        @optimization_cache = {}
        @last_optimization = {}
      end

      # Get optimization suggestions for a capability
      #
      # @param capability_name [String] The name of the capability
      # @param version [String, nil] The version of the capability (latest if nil)
      # @param options [Hash] Additional options
      # @option options [Boolean] :force Force new suggestions even if recently generated
      # @return [Hash] Optimization suggestions
      def get_optimization_suggestions(capability_name, version = nil, options = {})
        # Get the capability from the registry
        capability = @registry.get(capability_name, version)
        return {success: false, reason: "Capability not found"} unless capability

        version = capability.version
        cache_key = "#{capability_name}:#{version}"

        # Check cache
        unless options[:force]
          if @optimization_cache[cache_key] && @last_optimization[cache_key] &&
              @last_optimization[cache_key] > Time.now - 24 * 60 * 60
            return @optimization_cache[cache_key]
          end
        end

        # Get capability execution history
        history = get_capability_history(capability_name, version)

        # Check if we have enough data
        if history.size < 10
          result = {
            success: false,
            reason: "Insufficient execution data",
            capability: capability_name,
            version: version,
            suggestions: []
          }

          @optimization_cache[cache_key] = result
          @last_optimization[cache_key] = Time.now

          return result
        end

        # Analyze performance
        performance = analyze_capability_performance(history)

        # Generate suggestions
        suggestions = generate_optimization_suggestions(capability, performance)

        result = {
          success: true,
          capability: capability_name,
          version: version,
          performance: performance,
          suggestions: suggestions
        }

        @optimization_cache[cache_key] = result
        @last_optimization[cache_key] = Time.now

        result
      end

      # Optimize capability composition for a task
      #
      # @param task [Task] The task to optimize capabilities for
      # @param options [Hash] Additional options
      # @return [Hash] Optimized capability composition
      def optimize_capability_composition(task, options = {})
        # Get task description
        description = task.description

        # Get currently used capabilities
        if task.input && task.input[:capabilities]
          current_capabilities = task.input[:capabilities]
        else
          # If no capabilities specified, use default inference
          requirements = {}
          if task.agent_spec
            engine = Agentic::AgentAssemblyEngine.new(@registry)
            requirements = engine.analyze_requirements(task)
          end

          current_capabilities = requirements.keys
        end

        # No need to optimize if no capabilities
        if current_capabilities.empty?
          return {
            success: false,
            reason: "No capabilities to optimize",
            original_capabilities: [],
            optimized_capabilities: []
          }
        end

        # Get capability performance data
        capability_performance = {}
        current_capabilities.each do |capability|
          suggestions = get_optimization_suggestions(capability.to_s)
          capability_performance[capability.to_s] = suggestions[:performance] if suggestions[:success]
        end

        # Generate optimized composition
        if @llm_client
          generate_optimized_composition_with_llm(
            description,
            current_capabilities,
            capability_performance,
            options
          )
        else
          generate_optimized_composition_heuristic(
            description,
            current_capabilities,
            capability_performance,
            options
          )
        end
      end

      # Apply optimization to a capability
      #
      # @param capability_name [String] The name of the capability
      # @param optimization [Hash] The optimization to apply
      # @param options [Hash] Additional options
      # @return [Boolean] Whether the optimization was applied successfully
      def apply_optimization(capability_name, optimization, options = {})
        # Get the capability and provider
        capability = @registry.get(capability_name)
        return false unless capability

        provider = @registry.get_provider(capability_name)
        return false unless provider

        # Check optimization type
        case optimization[:type]
        when :implementation
          # For implementation optimizations, we would need to create a new provider
          # This is a simplified example - in a real implementation, we would need to
          # handle different implementation types (Proc, Class, etc.)
          if provider.implementation.is_a?(Proc) && optimization[:new_implementation].is_a?(Proc)
            # Create a new provider with the optimized implementation
            new_provider = Agentic::CapabilityProvider.new(
              capability: capability,
              implementation: optimization[:new_implementation]
            )

            # Register the new provider
            @registry.register(capability, new_provider)

            return true
          end
        when :parameters
          # For parameter optimizations, we would update the capability's parameters
          # This is a simplified example - in a real implementation, we would need to
          # handle different parameter types
          if optimization[:parameters].is_a?(Hash)
            # Update parameters (this would depend on the actual capability implementation)
            # For this example, we just log that we would update the parameters
            @logger.info("Would update parameters for #{capability_name}: #{optimization[:parameters]}")

            return true
          end
        end

        false
      end

      # Record capability execution metrics
      #
      # @param capability_name [String] The name of the capability
      # @param version [String] The version of the capability
      # @param metrics [Hash] The execution metrics
      # @param result [Hash] The execution result
      # @return [Boolean] Whether the metrics were recorded successfully
      def record_execution(capability_name, version, metrics, result)
        success = result && !result.key?(:error)

        @history_store.record_execution(
          capability_name: capability_name,
          capability_version: version,
          duration_ms: metrics[:duration_ms],
          success: success,
          metrics: metrics,
          context: {
            result_summary: summarize_result(result),
            error: (result && result[:error]) ? result[:error] : nil
          }
        )

        true
      end

      private

      # Get execution history for a capability
      def get_capability_history(capability_name, version)
        # Get execution history for this capability
        end_time = Time.now
        start_time = end_time - (30 * 24 * 60 * 60) # 30 days

        @history_store.get_history(
          capability_name: capability_name,
          capability_version: version,
          start_time: start_time,
          end_time: end_time
        )
      end

      # Analyze capability performance based on history
      def analyze_capability_performance(history)
        # Calculate success rate
        total = history.size
        successful = history.count { |h| h[:success] }
        success_rate = successful.to_f / total

        # Calculate average duration
        durations = history.map { |h| h[:duration_ms] }.compact
        avg_duration = durations.empty? ? nil : durations.sum / durations.size.to_f

        # Calculate trend
        if history.size >= 10
          recent = history.first(5)
          older = history.last(5)

          recent_success = recent.count { |h| h[:success] }.to_f / recent.size
          older_success = older.count { |h| h[:success] }.to_f / older.size

          trend = if (recent_success - older_success).abs < 0.1
            :stable
          elsif recent_success > older_success
            :improving
          else
            :declining
          end
        else
          trend = :unknown
        end

        # Calculate error patterns
        errors = history.select { |h| !h[:success] && h[:context] && h[:context][:error] }
        error_patterns = {}

        errors.each do |error|
          message = error[:context][:error].to_s
          error_patterns[message] ||= 0
          error_patterns[message] += 1
        end

        top_errors = error_patterns.sort_by { |_, count| -count }.first(3).map do |message, count|
          {message: message, count: count}
        end

        {
          success_rate: success_rate,
          avg_duration_ms: avg_duration,
          total_executions: total,
          trend: trend,
          top_errors: top_errors
        }
      end

      # Generate optimization suggestions for a capability
      def generate_optimization_suggestions(capability, performance)
        suggestions = []

        # Check success rate
        if performance[:success_rate] < 0.8
          suggestions << {
            type: :reliability,
            importance: :high,
            message: "Improve reliability to address the #{performance[:success_rate] * 100}% success rate"
          }

          # Add specific suggestions based on error patterns
          performance[:top_errors].each do |error|
            suggestions << {
              type: :error_handling,
              importance: :high,
              message: "Address common error: #{error[:message]} (#{error[:count]} occurrences)"
            }
          end
        end

        # Check performance
        if performance[:avg_duration_ms] && performance[:avg_duration_ms] > 1000
          suggestions << {
            type: :performance,
            importance: :medium,
            message: "Improve performance to reduce average duration (#{performance[:avg_duration_ms].round}ms)"
          }
        end

        # Check trend
        if performance[:trend] == :declining
          suggestions << {
            type: :trend,
            importance: :high,
            message: "Address declining success rate trend"
          }
        end

        # Add dependency suggestions
        if capability.dependencies&.any?
          dependency_names = capability.dependencies.map { |d| d[:name] }

          dependency_names.each do |dep_name|
            dep_suggestions = get_optimization_suggestions(dep_name)

            if dep_suggestions[:success] && dep_suggestions[:performance][:success_rate] < 0.9
              suggestions << {
                type: :dependency,
                importance: :medium,
                message: "Improve or replace dependency: #{dep_name} (#{dep_suggestions[:performance][:success_rate] * 100}% success rate)"
              }
            end
          end
        end

        # Use LLM for advanced suggestions if available
        if @llm_client && performance[:total_executions] >= 20
          llm_suggestions = generate_llm_suggestions(capability, performance)
          suggestions.concat(llm_suggestions) if llm_suggestions.any?
        end

        suggestions
      end

      # Generate suggestions using LLM
      def generate_llm_suggestions(capability, performance)
        # Format the capability details
        capability_details = <<~DETAILS
          Capability: #{capability.name} v#{capability.version}
          Description: #{capability.description}
          Inputs: #{capability.inputs.map { |name, spec| "#{name} (#{spec[:type] || "any"})" }.join(", ")}
          Outputs: #{capability.outputs.map { |name, spec| "#{name} (#{spec[:type] || "any"})" }.join(", ")}
          Dependencies: #{capability.dependencies.map { |d| "#{d[:name]} v#{d[:version]}" }.join(", ")}
        DETAILS

        # Format the performance details
        performance_details = <<~DETAILS
          Success Rate: #{(performance[:success_rate] * 100).round(1)}%
          Average Duration: #{performance[:avg_duration_ms] ? "#{performance[:avg_duration_ms].round}ms" : "Unknown"}
          Total Executions: #{performance[:total_executions]}
          Trend: #{performance[:trend]}
          Top Errors: #{performance[:top_errors].map { |e| "#{e[:message]} (#{e[:count]} occurrences)" }.join(", ")}
        DETAILS

        # Create the prompt
        prompt = <<~PROMPT
          As an AI specialized in optimizing AI agent capabilities, please analyze this capability and its performance metrics.
          
          Capability Details:
          #{capability_details}
          
          Performance Metrics:
          #{performance_details}
          
          Based on this information, provide 2-3 specific optimization suggestions that could improve this capability's 
          performance, reliability, or effectiveness. Focus on practical, implementable changes rather than general advice.
          
          Format your response as a JSON array of suggestion objects, each with:
          - type: The type of suggestion (implementation, parameters, error_handling, etc.)
          - importance: The importance level (high, medium, low)
          - message: A clear, specific suggestion message
          - details: Optional implementation details or examples
        PROMPT

        # Get suggestions from the LLM
        response = @llm_client.complete(
          prompt: prompt,
          response_format: {type: "json"}
        )

        # Parse the response
        begin
          suggestions = JSON.parse(response.to_s, symbolize_names: true)

          if suggestions.is_a?(Array)
            suggestions
          elsif suggestions.is_a?(Hash) && suggestions[:suggestions].is_a?(Array)
            suggestions[:suggestions]
          else
            @logger.warn("Unexpected LLM response format for capability suggestions")
            []
          end
        rescue => e
          @logger.error("Failed to parse LLM capability suggestions: #{e.message}")
          []
        end
      end

      # Generate optimized capability composition using LLM
      def generate_optimized_composition_with_llm(description, current_capabilities, capability_performance, options)
        # Format current capabilities
        capabilities_text = current_capabilities.map do |capability|
          perf = capability_performance[capability.to_s]
          if perf
            "- #{capability} (Success rate: #{(perf[:success_rate] * 100).round(1)}%, " \
            "Avg duration: #{perf[:avg_duration_ms] ? "#{perf[:avg_duration_ms].round}ms" : "Unknown"})"
          else
            "- #{capability} (No performance data available)"
          end
        end.join("\n")

        # Get all available capabilities
        available_capabilities = @registry.list.keys - current_capabilities.map(&:to_s)
        available_text = available_capabilities.map { |c| "- #{c}" }.join("\n")

        # Create the prompt
        prompt = <<~PROMPT
          As an AI specialized in composing capabilities for AI agents, please analyze this task and the currently used capabilities.
          
          Task Description:
          #{description}
          
          Currently Used Capabilities:
          #{capabilities_text}
          
          Other Available Capabilities:
          #{available_text}
          
          Based on this information, suggest an optimized set of capabilities for this task. You can:
          1. Keep capabilities that are well-suited for the task
          2. Remove capabilities that are unnecessary or underperforming
          3. Add new capabilities from the available list that would enhance task performance
          4. Suggest a different composition or sequence of capabilities
          
          Format your response as a JSON object with:
          {
            "optimized_capabilities": ["capability1", "capability2", ...],
            "additions": ["new_capability1", ...],
            "removals": ["removed_capability1", ...],
            "rationale": "Explanation of your changes"
          }
        PROMPT

        # Get suggestions from the LLM
        response = @llm_client.complete(
          prompt: prompt,
          response_format: {type: "json"}
        )

        # Parse the response
        begin
          result = JSON.parse(response.to_s, symbolize_names: true)

          if result[:optimized_capabilities].is_a?(Array)
            {
              success: true,
              original_capabilities: current_capabilities,
              optimized_capabilities: result[:optimized_capabilities],
              additions: result[:additions] || [],
              removals: result[:removals] || [],
              rationale: result[:rationale] || "No rationale provided"
            }
          else
            @logger.warn("Unexpected LLM response format for capability composition")
            {
              success: false,
              reason: "Failed to generate optimized composition",
              original_capabilities: current_capabilities,
              optimized_capabilities: current_capabilities
            }
          end
        rescue => e
          @logger.error("Failed to parse LLM capability composition: #{e.message}")
          {
            success: false,
            reason: "Failed to parse optimization response",
            original_capabilities: current_capabilities,
            optimized_capabilities: current_capabilities
          }
        end
      end

      # Generate optimized capability composition using heuristics
      def generate_optimized_composition_heuristic(description, current_capabilities, capability_performance, options)
        optimized = current_capabilities.dup
        additions = []
        removals = []
        changes = []

        # Remove low-performing capabilities
        current_capabilities.each do |capability|
          capability_name = capability.to_s
          perf = capability_performance[capability_name]

          if perf && perf[:success_rate] < 0.5 && perf[:total_executions] > 10
            # Only remove if it's not a critical capability
            # This is a simplified check - in a real implementation, we would need
            # to determine if a capability is critical based on the task
            unless description.downcase.include?(capability_name.downcase)
              optimized.delete(capability)
              removals << capability_name
              changes << "Removed low-performing capability: #{capability_name} (#{(perf[:success_rate] * 100).round}% success rate)"
            end
          end
        end

        # Add capabilities based on task description
        available_capabilities = @registry.list.keys - current_capabilities.map(&:to_s)

        available_capabilities.each do |capability|
          # Check if the capability is relevant to the task
          # This is a simplified check - in a real implementation, we would need
          # a more sophisticated relevance determination
          if description.downcase.include?(capability.downcase)
            optimized << capability
            additions << capability
            changes << "Added potentially relevant capability: #{capability}"
          end
        end

        # Handle common combinations
        if optimized.include?("data_analysis") && !optimized.include?("text_generation")
          optimized << "text_generation"
          additions << "text_generation"
          changes << "Added text_generation to support data_analysis"
        end

        if optimized.include?("web_search") && !optimized.include?("summarization")
          optimized << "summarization"
          additions << "summarization"
          changes << "Added summarization to process web_search results"
        end

        if changes.empty?
          {
            success: false,
            reason: "No composition improvements identified",
            original_capabilities: current_capabilities,
            optimized_capabilities: current_capabilities
          }
        else
          {
            success: true,
            original_capabilities: current_capabilities,
            optimized_capabilities: optimized,
            additions: additions,
            removals: removals,
            rationale: "Applied composition optimizations: #{changes.join(", ")}"
          }
        end
      end

      # Summarize a result for storage
      def summarize_result(result)
        return "No result" unless result

        if result[:error]
          "Error: #{result[:error]}"
        else
          summary = []

          result.each do |key, value|
            summary << if value.is_a?(String)
              "#{key}: #{value.length} chars"
            elsif value.is_a?(Array)
              "#{key}: #{value.length} items"
            elsif value.is_a?(Hash)
              "#{key}: #{value.keys.join(", ")}"
            else
              "#{key}: #{value}"
            end
          end

          summary.join(", ")
        end
      end
    end
  end
end
