# frozen_string_literal: true

require "time" # Time#iso8601/Time.parse - require what you use

module Agentic
  module Learning
    # PatternRecognizer identifies patterns and optimization opportunities from execution history.
    # It analyzes historical task and plan executions to detect recurring patterns,
    # success/failure correlations, and potential optimization points.
    #
    # @example Analyzing patterns in task executions
    #   history_store = Agentic::Learning::ExecutionHistoryStore.new
    #   recognizer = Agentic::Learning::PatternRecognizer.new(history_store: history_store)
    #   patterns = recognizer.analyze_agent_performance("research_agent")
    #
    class PatternRecognizer
      # Initialize a new PatternRecognizer
      #
      # @param options [Hash] Configuration options
      # @option options [Logger] :logger Custom logger (defaults to Agentic.logger)
      # @option options [ExecutionHistoryStore] :history_store The history store to analyze
      # @option options [Integer] :min_sample_size Minimum sample size for pattern detection (defaults to 10)
      # @option options [Float] :significance_threshold Statistical significance threshold (defaults to 0.05)
      # @option options [Integer] :time_window_days Time window in days for analysis (defaults to 30)
      def initialize(options = {})
        @logger = options[:logger] || Agentic.logger
        @history_store = options[:history_store] || raise(ArgumentError, "history_store is required")
        @min_sample_size = options[:min_sample_size] || 10
        @significance_threshold = options[:significance_threshold] || 0.05
        @time_window_days = options[:time_window_days] || 30
        @pattern_cache = {}
        @cache_expiry = {}
      end

      # Analyze performance patterns for a specific agent type
      #
      # @param agent_type [String] The agent type to analyze
      # @param options [Hash] Analysis options
      # @option options [Array<Symbol>] :metrics Specific metrics to analyze (defaults to all)
      # @option options [Boolean] :force_refresh Force a fresh analysis even if cached (defaults to false)
      # @return [Hash] Analysis results with identified patterns
      def analyze_agent_performance(agent_type, options = {})
        cache_key = "agent_perf:#{agent_type}:#{options[:metrics]}"

        # Check cache first if not forcing refresh
        if !options[:force_refresh] && @pattern_cache[cache_key] && @cache_expiry[cache_key] && @cache_expiry[cache_key] > Time.now
          return @pattern_cache[cache_key]
        end

        # Fetch relevant history
        history = fetch_agent_history(agent_type)

        if history.size < @min_sample_size
          @logger.info("Insufficient data to analyze patterns for #{agent_type} (#{history.size} < #{@min_sample_size})")
          return {insufficient_data: true, sample_size: history.size, required_size: @min_sample_size}
        end

        # Perform analysis
        patterns = {
          success_rate: calculate_success_rate(history),
          performance_trends: analyze_performance_trends(history, options[:metrics]),
          failure_patterns: identify_failure_patterns(history),
          optimization_opportunities: identify_optimization_opportunities(history)
        }

        # Cache results
        @pattern_cache[cache_key] = patterns
        @cache_expiry[cache_key] = Time.now + 3600 # Cache for 1 hour

        patterns
      end

      # Identify correlation between task properties and success/performance
      #
      # @param task_property [Symbol] The property to analyze correlation for
      # @param performance_metric [Symbol] The performance metric to correlate with
      # @return [Hash] Correlation analysis results
      def analyze_correlation(task_property, performance_metric)
        # Fetch all history within time window
        end_time = Time.now
        start_time = end_time - (@time_window_days * 24 * 60 * 60)

        history = @history_store.get_history(start_time: start_time, end_time: end_time)

        if history.size < @min_sample_size
          return {insufficient_data: true, sample_size: history.size}
        end

        # Extract property and metric values
        data_points = history.map do |record|
          property_value = extract_property_value(record, task_property)
          metric_value = extract_metric_value(record, performance_metric)

          {property: property_value, metric: metric_value} if property_value && metric_value
        end.compact

        # Calculate correlation
        if data_points.size < @min_sample_size
          return {insufficient_data: true, sample_size: data_points.size}
        end

        correlation = calculate_correlation(data_points)

        {
          correlation_coefficient: correlation[:coefficient],
          statistical_significance: correlation[:significance],
          sample_size: data_points.size,
          significant: correlation[:significance] < @significance_threshold
        }
      end

      # Recommend optimization strategies based on recognized patterns
      #
      # @param agent_type [String] The agent type to generate recommendations for
      # @return [Array<Hash>] List of recommended optimization strategies
      def recommend_optimizations(agent_type)
        # Start with performance analysis
        performance = analyze_agent_performance(agent_type, force_refresh: true)

        if performance[:insufficient_data]
          return [{type: :insufficient_data, message: "Need more execution data to make recommendations"}]
        end

        recommendations = []

        # Check success rate
        if performance[:success_rate][:overall] < 0.8
          recommendations << {
            type: :success_rate,
            priority: :high,
            message: "Improve success rate (currently #{(performance[:success_rate][:overall] * 100).round(1)}%)",
            suggestions: generate_success_rate_suggestions(performance)
          }
        end

        # Check performance trends
        slow_metrics = performance[:performance_trends].select { |_, v| v[:trend] == :increasing && v[:significant] }
        if slow_metrics.any?
          recommendations << {
            type: :performance,
            priority: :medium,
            message: "Performance degradation detected in #{slow_metrics.keys.join(", ")}",
            suggestions: generate_performance_suggestions(slow_metrics)
          }
        end

        # Check failure patterns
        if performance[:failure_patterns]&.any?
          recommendations << {
            type: :failures,
            priority: :high,
            message: "Address common failure patterns",
            patterns: performance[:failure_patterns].first(3),
            suggestions: generate_failure_suggestions(performance[:failure_patterns])
          }
        end

        # Check optimization opportunities
        if performance[:optimization_opportunities]&.any?
          recommendations << {
            type: :optimization,
            priority: :medium,
            message: "Potential optimization opportunities identified",
            opportunities: performance[:optimization_opportunities],
            suggestions: performance[:optimization_opportunities].map { |o| o[:suggestion] }
          }
        end

        recommendations
      end

      private

      def fetch_agent_history(agent_type)
        end_time = Time.now
        start_time = end_time - (@time_window_days * 24 * 60 * 60)

        @history_store.get_history(
          agent_type: agent_type,
          start_time: start_time,
          end_time: end_time
        )
      end

      def calculate_success_rate(history)
        return {overall: 0, sample_size: 0} if history.empty?

        # Overall success rate
        successful = history.count { |record| record[:success] }
        overall_rate = successful.to_f / history.size

        # Success rate over time
        time_periods = split_into_time_periods(history, 5) # Split into 5 periods
        period_rates = time_periods.map do |period|
          successful = period.count { |record| record[:success] }
          successful.to_f / period.size
        end

        # Trend analysis
        trend = if period_rates.size >= 3
          if period_rates.last > period_rates.first
            :improving
          elsif period_rates.last < period_rates.first
            :declining
          else
            :stable
          end
        else
          :insufficient_data
        end

        {
          overall: overall_rate,
          sample_size: history.size,
          period_rates: period_rates,
          trend: trend
        }
      end

      def analyze_performance_trends(history, metric_keys = nil)
        return {} if history.empty?

        # Extract all available metrics if none specified
        metric_keys ||= history.flat_map { |r| r[:metrics]&.keys || [] }.uniq.map(&:to_sym)

        # Analyze each metric
        metric_keys.each_with_object({}) do |metric, results|
          # Extract metric values
          values = history.map { |record| record.dig(:metrics, metric.to_s) }.compact

          next if values.empty?

          # Split into time periods
          time_periods = split_into_time_periods(history, 5)
          period_values = time_periods.map do |period|
            period_metrics = period.map { |record| record.dig(:metrics, metric.to_s) }.compact
            period_metrics.empty? ? nil : period_metrics.sum / period_metrics.size.to_f
          end.compact

          # Determine trend
          trend = if period_values.size >= 3
            if period_values.last > period_values.first * 1.2
              :increasing  # 20% increase
            elsif period_values.last < period_values.first * 0.8
              :decreasing  # 20% decrease
            else
              :stable
            end
          else
            :insufficient_data
          end

          # Calculate statistical significance
          significant = period_values.size >= 3 &&
            trend != :stable &&
            calculate_significance(period_values.first, period_values.last, period_values.size) < @significance_threshold

          results[metric] = {
            avg_value: values.sum / values.size.to_f,
            min_value: values.min,
            max_value: values.max,
            trend: trend,
            period_values: period_values,
            significant: significant
          }
        end
      end

      def identify_failure_patterns(history)
        failures = history.reject { |record| record[:success] }
        return [] if failures.empty?

        # Group failures by context patterns
        failure_groups = {}

        failures.each do |failure|
          # Extract failure pattern from context
          pattern = extract_failure_pattern(failure)

          failure_groups[pattern] ||= []
          failure_groups[pattern] << failure
        end

        # Sort by frequency and return top patterns
        failure_groups
          .map { |pattern, occurrences| {pattern: pattern, count: occurrences.size, examples: occurrences.first(3)} }
          .sort_by { |p| -p[:count] }
          .first(5)
      end

      def identify_optimization_opportunities(history)
        opportunities = []

        # Look for consistently slow tasks
        duration_by_task = {}
        history.each do |record|
          next unless record[:task_id]
          duration_by_task[record[:task_id]] ||= []
          duration_by_task[record[:task_id]] << record[:duration_ms]
        end

        # Find tasks with high average duration
        slow_tasks = duration_by_task
          .select { |_, durations| durations.size >= 3 }
          .map { |task_id, durations| [task_id, durations.sum / durations.size.to_f] }
          .sort_by { |_, avg_duration| -avg_duration }
          .first(3)

        slow_tasks.each do |task_id, avg_duration|
          opportunities << {
            type: :slow_task,
            task_id: task_id,
            avg_duration_ms: avg_duration.round,
            suggestion: "Optimize slow task #{task_id} (avg: #{(avg_duration / 1000).round(2)}s)"
          }
        end

        # Look for resource-intensive tasks
        if history.any? { |r| r.dig(:metrics, "tokens_used") }
          tokens_by_task = {}
          history.each do |record|
            next unless record[:task_id] && record.dig(:metrics, "tokens_used")
            tokens_by_task[record[:task_id]] ||= []
            tokens_by_task[record[:task_id]] << record[:metrics]["tokens_used"]
          end

          token_heavy_tasks = tokens_by_task
            .select { |_, tokens| tokens.size >= 3 }
            .map { |task_id, tokens| [task_id, tokens.sum / tokens.size.to_f] }
            .sort_by { |_, avg_tokens| -avg_tokens }
            .first(3)

          token_heavy_tasks.each do |task_id, avg_tokens|
            opportunities << {
              type: :token_heavy,
              task_id: task_id,
              avg_tokens: avg_tokens.round,
              suggestion: "Reduce token usage in task #{task_id} (avg: #{avg_tokens.round} tokens)"
            }
          end
        end

        opportunities
      end

      def split_into_time_periods(history, num_periods)
        return [] if history.empty?

        # Sort by timestamp
        sorted = history.sort_by { |r| r[:timestamp] }

        # Calculate time range
        start_time = Time.parse(sorted.first[:timestamp])
        end_time = Time.parse(sorted.last[:timestamp])
        total_duration = end_time - start_time

        return [sorted] if total_duration < 60 # If less than a minute, return as single period

        # Split into periods
        period_duration = total_duration / num_periods

        periods = []
        num_periods.times do |i|
          period_start = start_time + (i * period_duration)
          period_end = period_start + period_duration

          period_records = sorted.select do |record|
            record_time = Time.parse(record[:timestamp])
            record_time >= period_start && (i == num_periods - 1 || record_time < period_end)
          end

          periods << period_records unless period_records.empty?
        end

        periods
      end

      def extract_property_value(record, property)
        case property
        when :agent_type
          record[:agent_type]
        when :duration
          record[:duration_ms]
        when :task_id
          record[:task_id]
        when :plan_id
          record[:plan_id]
        else
          # Try to extract from metrics or context
          record.dig(:metrics, property.to_s) || record.dig(:context, property.to_s)
        end
      end

      def extract_metric_value(record, metric)
        case metric
        when :success
          record[:success] ? 1 : 0
        when :duration
          record[:duration_ms]
        else
          # Try to extract from metrics
          record.dig(:metrics, metric.to_s)
        end
      end

      def calculate_correlation(data_points)
        # Simple correlation calculation - can be replaced with more sophisticated approach
        x_values = data_points.map { |p| p[:property].to_f }
        y_values = data_points.map { |p| p[:metric].to_f }

        n = x_values.size
        sum_x = x_values.sum
        sum_y = y_values.sum
        sum_xy = x_values.zip(y_values).map { |x, y| x * y }.sum
        sum_x2 = x_values.map { |x| x**2 }.sum
        sum_y2 = y_values.map { |y| y**2 }.sum

        numerator = n * sum_xy - sum_x * sum_y
        denominator = Math.sqrt((n * sum_x2 - sum_x**2) * (n * sum_y2 - sum_y**2))

        coefficient = denominator.zero? ? 0 : numerator / denominator

        # Calculate p-value (simplified)
        t = coefficient * Math.sqrt((n - 2) / (1 - coefficient**2))
        p_value = 2 * (1 - calculate_t_distribution(t.abs, n - 2))

        {coefficient: coefficient, significance: p_value}
      end

      def calculate_significance(value1, value2, sample_size)
        # Simplified significance calculation
        # In a real implementation, use a proper statistical library
        diff = (value2 - value1).abs
        variance = (diff * 0.5)**2  # Simplified variance estimate

        # t-statistic for paired samples
        t = diff / Math.sqrt(variance / sample_size)

        # Approximate p-value
        2 * (1 - calculate_t_distribution(t.abs, sample_size - 1))
      end

      def calculate_t_distribution(t, df)
        # Very simplified t-distribution approximation
        # In a real implementation, use a proper statistical library
        if t > 10
          1.0
        else
          0.5 + 0.5 * (1 - Math.exp(-0.09 * t * Math.sqrt(df)))
        end
      end

      def extract_failure_pattern(failure)
        # Extract a simplified pattern from failure context
        # In a real implementation, use more sophisticated pattern recognition

        if failure[:context] && failure[:context][:error_type]
          "Error: #{failure[:context][:error_type]}"
        elsif failure[:context] && failure[:context][:failure_reason]
          "Reason: #{failure[:context][:failure_reason]}"
        else
          "Unknown failure"
        end
      end

      def generate_success_rate_suggestions(performance)
        suggestions = []

        if performance[:failure_patterns].any?
          top_failure = performance[:failure_patterns].first
          suggestions << "Address most common failure pattern: #{top_failure[:pattern]}"
        end

        if performance[:success_rate][:trend] == :declining
          suggestions << "Investigate recent changes that may have affected success rate"
        end

        suggestions << "Implement more robust error handling" if suggestions.empty?
        suggestions
      end

      def generate_performance_suggestions(slow_metrics)
        slow_metrics.map do |metric, data|
          case metric
          when :duration_ms, :duration
            "Optimize execution time (#{(data[:avg_value] / 1000).round(2)}s avg)"
          when :tokens_used
            "Reduce token usage (#{data[:avg_value].round} avg)"
          else
            "Optimize #{metric} metric (#{data[:avg_value].round(2)} avg)"
          end
        end
      end

      def generate_failure_suggestions(failure_patterns)
        failure_patterns.first(3).map do |pattern|
          "Fix '#{pattern[:pattern]}' failure (occurs #{pattern[:count]} times)"
        end
      end
    end
  end
end
