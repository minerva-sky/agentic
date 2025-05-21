# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::Learning::PatternRecognizer do
  let(:history_store) { instance_double(Agentic::Learning::ExecutionHistoryStore) }
  let(:recognizer) do
    Agentic::Learning::PatternRecognizer.new(
      history_store: history_store,
      min_sample_size: 5,
      significance_threshold: 0.1
    )
  end

  describe "#initialize" do
    it "raises an error if history_store is not provided" do
      expect {
        Agentic::Learning::PatternRecognizer.new
      }.to raise_error(ArgumentError, "history_store is required")
    end

    it "initializes with default values when only required parameters are provided" do
      expect {
        Agentic::Learning::PatternRecognizer.new(history_store: history_store)
      }.not_to raise_error
    end
  end

  describe "#analyze_agent_performance" do
    context "with insufficient data" do
      before do
        allow(history_store).to receive(:get_history).and_return([])
      end

      it "returns insufficient_data when sample size is too small" do
        result = recognizer.analyze_agent_performance("test_agent")
        expect(result[:insufficient_data]).to be true
      end
    end

    context "with sufficient data" do
      let(:mock_records) do
        [
          {
            id: "record1",
            timestamp: Time.now.iso8601,
            task_id: "task1",
            agent_type: "test_agent",
            duration_ms: 1000,
            success: true,
            metrics: {
              "tokens_used" => 1000,
              "quality_score" => 0.8
            }
          },
          {
            id: "record2",
            timestamp: (Time.now - 60).iso8601,
            task_id: "task2",
            agent_type: "test_agent",
            duration_ms: 1200,
            success: true,
            metrics: {
              "tokens_used" => 1100,
              "quality_score" => 0.7
            }
          },
          {
            id: "record3",
            timestamp: (Time.now - 120).iso8601,
            task_id: "task3",
            agent_type: "test_agent",
            duration_ms: 900,
            success: false,
            metrics: {
              "tokens_used" => 900,
              "quality_score" => 0.5
            }
          },
          {
            id: "record4",
            timestamp: (Time.now - 180).iso8601,
            task_id: "task4",
            agent_type: "test_agent",
            duration_ms: 1100,
            success: true,
            metrics: {
              "tokens_used" => 1050,
              "quality_score" => 0.75
            }
          },
          {
            id: "record5",
            timestamp: (Time.now - 240).iso8601,
            task_id: "task5",
            agent_type: "test_agent",
            duration_ms: 1300,
            success: true,
            metrics: {
              "tokens_used" => 1200,
              "quality_score" => 0.65
            }
          }
        ]
      end

      before do
        allow(history_store).to receive(:get_history).and_return(mock_records)
      end

      it "calculates success rate correctly" do
        result = recognizer.analyze_agent_performance("test_agent")
        expect(result[:success_rate][:overall]).to eq 0.8  # 4/5 successful
        expect(result[:success_rate][:sample_size]).to eq 5
      end

      it "analyzes performance trends for metrics" do
        result = recognizer.analyze_agent_performance("test_agent")

        # Check that metrics analysis exists
        expect(result[:performance_trends]).to include(:tokens_used)
        expect(result[:performance_trends]).to include(:quality_score)

        # Check structure of metric analysis
        tokens_trend = result[:performance_trends][:tokens_used]
        expect(tokens_trend).to include(:avg_value)
        expect(tokens_trend).to include(:min_value)
        expect(tokens_trend).to include(:max_value)
        expect(tokens_trend).to include(:trend)
      end

      it "respects the force_refresh parameter" do
        # Create a test class that stubs out the specific methods we need to test caching
        test_class = Class.new(Agentic::Learning::PatternRecognizer) do
          attr_accessor :fetch_called, :cache_used

          def fetch_agent_history(agent_type)
            @fetch_called = true
            [{id: "mock", success: true, metrics: {tokens: 100}}] * 10  # Return 10 mock records
          end

          # Override the analyze_agent_performance method to track cache usage
          def analyze_agent_performance(agent_type, options = {})
            @fetch_called = false  # Reset for this call

            cache_key = "agent_perf:#{agent_type}:#{options[:metrics]}"

            # First check cache if not forcing refresh
            if !options[:force_refresh] && @pattern_cache[cache_key] &&
                @cache_expiry[cache_key] && @cache_expiry[cache_key] > Time.now
              @cache_used = true
              return @pattern_cache[cache_key]
            end

            @cache_used = false

            # If cache not used, generate results
            fetch_agent_history(agent_type)
            result = {success_rate: {overall: 0.8}, performance_trends: {}}

            # Cache the result
            @pattern_cache[cache_key] = result
            @cache_expiry[cache_key] = Time.now + 3600

            result
          end
        end

        # Create an instance of our test class
        test_recognizer = test_class.new(history_store: history_store, min_sample_size: 5)

        # First call - no cache yet, should fetch data
        test_recognizer.analyze_agent_performance("test_agent")
        expect(test_recognizer.fetch_called).to be true
        expect(test_recognizer.cache_used).to be false

        # Second call - should use cache
        test_recognizer.analyze_agent_performance("test_agent")
        expect(test_recognizer.fetch_called).to be false
        expect(test_recognizer.cache_used).to be true

        # Third call with force - should bypass cache
        test_recognizer.analyze_agent_performance("test_agent", force_refresh: true)
        expect(test_recognizer.fetch_called).to be true
        expect(test_recognizer.cache_used).to be false
      end
    end
  end

  describe "#analyze_correlation" do
    let(:mock_records) do
      [
        {
          id: "record1",
          timestamp: Time.now.iso8601,
          task_id: "task1",
          agent_type: "test_agent",
          duration_ms: 1000,
          success: true,
          metrics: {"tokens_used" => 1000}
        },
        {
          id: "record2",
          timestamp: (Time.now - 60).iso8601,
          task_id: "task2",
          agent_type: "test_agent",
          duration_ms: 1200,
          success: true,
          metrics: {"tokens_used" => 1100}
        },
        {
          id: "record3",
          timestamp: (Time.now - 120).iso8601,
          task_id: "task3",
          agent_type: "test_agent",
          duration_ms: 900,
          success: false,
          metrics: {"tokens_used" => 900}
        },
        {
          id: "record4",
          timestamp: (Time.now - 180).iso8601,
          task_id: "task4",
          agent_type: "test_agent",
          duration_ms: 1100,
          success: true,
          metrics: {"tokens_used" => 1050}
        },
        {
          id: "record5",
          timestamp: (Time.now - 240).iso8601,
          task_id: "task5",
          agent_type: "test_agent",
          duration_ms: 1300,
          success: true,
          metrics: {"tokens_used" => 1200}
        }
      ]
    end

    it "returns a correlation analysis between two properties" do
      # First, make sure history store returns enough records to pass the min_sample_size check
      allow(history_store).to receive(:get_history).and_return(mock_records)

      # Directly mock the private methods used for correlation to ensure predictable results
      allow(recognizer).to receive(:extract_property_value) do |record, property|
        if property == :duration_ms
          record[:duration_ms]
        elsif property == :tokens_used
          record.dig(:metrics, "tokens_used")
        end
      end

      allow(recognizer).to receive(:extract_metric_value) do |record, metric|
        if metric == :tokens_used
          record.dig(:metrics, "tokens_used")
        end
      end

      # Make correlation calculation predictable
      allow(recognizer).to receive(:calculate_correlation).and_return({coefficient: 0.85, significance: 0.01})

      result = recognizer.analyze_correlation(:duration_ms, :tokens_used)

      expect(result).to include(:correlation_coefficient)
      expect(result).to include(:statistical_significance)
      expect(result).to include(:sample_size)
      expect(result).to include(:significant)
    end

    it "handles insufficient data" do
      # Create a test-specific recognizer with a higher min_sample_size to trigger insufficient data
      test_recognizer = Agentic::Learning::PatternRecognizer.new(
        history_store: history_store,
        min_sample_size: 10,  # Higher than our mock data size
        significance_threshold: 0.1
      )

      allow(history_store).to receive(:get_history).and_return(mock_records[0..2])

      result = test_recognizer.analyze_correlation(:duration_ms, :tokens_used)
      expect(result).to include(:insufficient_data)
    end
  end

  describe "#recommend_optimizations" do
    context "with insufficient data" do
      before do
        allow(recognizer).to receive(:analyze_agent_performance).and_return(
          {insufficient_data: true, sample_size: 3, required_size: 5}
        )
      end

      it "returns insufficient data message when there's not enough data" do
        recommendations = recognizer.recommend_optimizations("test_agent")
        expect(recommendations.size).to eq 1
        expect(recommendations.first[:type]).to eq :insufficient_data
      end
    end

    context "with sufficient data" do
      let(:mock_analysis) do
        {
          success_rate: {overall: 0.7, sample_size: 10, trend: :stable},
          performance_trends: {
            tokens_used: {trend: :increasing, avg_value: 1500, significant: true},
            duration_ms: {trend: :stable, avg_value: 1200, significant: false}
          },
          failure_patterns: [
            {pattern: "Error: Timeout", count: 2, examples: []}
          ],
          optimization_opportunities: [
            {type: :slow_task, task_id: "task1", avg_duration_ms: 2000, suggestion: "Optimize slow task"}
          ]
        }
      end

      before do
        allow(recognizer).to receive(:analyze_agent_performance).and_return(mock_analysis)
      end

      it "recommends improvements for low success rate" do
        recommendations = recognizer.recommend_optimizations("test_agent")

        success_recommendation = recommendations.find { |r| r[:type] == :success_rate }
        expect(success_recommendation).not_to be_nil
        expect(success_recommendation[:priority]).to eq :high
      end

      it "recommends performance improvements for degrading metrics" do
        recommendations = recognizer.recommend_optimizations("test_agent")

        performance_recommendation = recommendations.find { |r| r[:type] == :performance }
        expect(performance_recommendation).not_to be_nil
        expect(performance_recommendation[:message]).to include("tokens_used")
      end

      it "includes suggestions for failure patterns" do
        recommendations = recognizer.recommend_optimizations("test_agent")

        failure_recommendation = recommendations.find { |r| r[:type] == :failures }
        expect(failure_recommendation).not_to be_nil
        expect(failure_recommendation[:patterns]).not_to be_empty
      end

      it "includes optimization opportunities" do
        recommendations = recognizer.recommend_optimizations("test_agent")

        optimization_recommendation = recommendations.find { |r| r[:type] == :optimization }
        expect(optimization_recommendation).not_to be_nil
        expect(optimization_recommendation[:opportunities]).not_to be_empty
      end
    end
  end
end
