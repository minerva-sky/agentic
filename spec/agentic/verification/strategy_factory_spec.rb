# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::Verification::StrategyFactory do
  let(:llm_client) { double("LlmClient") }
  let(:config) { {confidence_threshold: 0.8} }

  describe ".create" do
    context "with llm strategy type" do
      it "creates LlmVerificationStrategy with required dependencies" do
        strategy = described_class.create(:llm, config: config, llm_client: llm_client)

        expect(strategy).to be_a(Agentic::Verification::LlmVerificationStrategy)
        expect(strategy.llm_client).to eq(llm_client)
      end

      context "without required llm_client dependency" do
        it "raises ArgumentError" do
          expect { described_class.create(:llm, config: config) }
            .to raise_error(ArgumentError, "LLM verification strategy requires :llm_client dependency")
        end
      end
    end

    context "with schema strategy type" do
      it "creates SchemaVerificationStrategy" do
        strategy = described_class.create(:schema, config: config)

        expect(strategy).to be_a(Agentic::Verification::SchemaVerificationStrategy)
      end
    end

    context "with string strategy type" do
      it "converts string to symbol and creates strategy" do
        strategy = described_class.create("schema", config: config)

        expect(strategy).to be_a(Agentic::Verification::SchemaVerificationStrategy)
      end
    end

    context "with unknown strategy type" do
      it "raises ArgumentError with available types" do
        expect { described_class.create(:unknown, config: config) }
          .to raise_error(ArgumentError, /Unknown verification strategy type: unknown. Available: llm, schema/)
      end
    end

    context "with empty config" do
      it "creates strategy with default configuration" do
        strategy = described_class.create(:schema)

        expect(strategy).to be_a(Agentic::Verification::SchemaVerificationStrategy)
      end
    end
  end

  describe ".create_multiple" do
    let(:strategies_config) do
      [
        {type: :llm, config: {confidence_threshold: 0.8}, dependencies: {llm_client: llm_client}},
        {type: :schema, config: {strict_mode: true}}
      ]
    end

    it "creates multiple strategies from configuration" do
      strategies = described_class.create_multiple(strategies_config)

      expect(strategies.size).to eq(2)
      expect(strategies[0]).to be_a(Agentic::Verification::LlmVerificationStrategy)
      expect(strategies[1]).to be_a(Agentic::Verification::SchemaVerificationStrategy)
    end

    context "with string keys in configuration" do
      let(:strategies_config) do
        [
          {"type" => "llm", "config" => {"confidence_threshold" => 0.8}, "dependencies" => {llm_client: llm_client}},
          {"type" => "schema", "config" => {"strict_mode" => true}}
        ]
      end

      it "handles string keys correctly" do
        strategies = described_class.create_multiple(strategies_config)

        expect(strategies.size).to eq(2)
        expect(strategies[0]).to be_a(Agentic::Verification::LlmVerificationStrategy)
        expect(strategies[1]).to be_a(Agentic::Verification::SchemaVerificationStrategy)
      end
    end

    context "with global dependencies" do
      let(:global_dependencies) { {llm_client: llm_client} }
      let(:strategies_config) do
        [
          {type: :llm, config: {confidence_threshold: 0.8}},
          {type: :schema, config: {strict_mode: true}}
        ]
      end

      it "merges global dependencies with strategy-specific ones" do
        strategies = described_class.create_multiple(strategies_config, global_dependencies)

        expect(strategies[0]).to be_a(Agentic::Verification::LlmVerificationStrategy)
        expect(strategies[0].llm_client).to eq(llm_client)
      end
    end

    context "with strategy-specific dependencies overriding global ones" do
      let(:global_llm_client) { double("GlobalLlmClient") }
      let(:specific_llm_client) { double("SpecificLlmClient") }
      let(:global_dependencies) { {llm_client: global_llm_client} }
      let(:strategies_config) do
        [
          {type: :llm, config: {}, dependencies: {llm_client: specific_llm_client}}
        ]
      end

      it "uses strategy-specific dependencies over global ones" do
        strategies = described_class.create_multiple(strategies_config, global_dependencies)

        expect(strategies[0].llm_client).to eq(specific_llm_client)
      end
    end

    context "with missing configuration keys" do
      let(:strategies_config) do
        [
          {type: :schema}
        ]
      end

      it "handles missing config and dependencies gracefully" do
        strategies = described_class.create_multiple(strategies_config)

        expect(strategies.size).to eq(1)
        expect(strategies[0]).to be_a(Agentic::Verification::SchemaVerificationStrategy)
      end
    end
  end

  describe ".available_types" do
    it "returns available strategy types" do
      types = described_class.available_types

      expect(types).to contain_exactly(:llm, :schema)
    end
  end

  describe ".register" do
    let(:custom_strategy_class) do
      Class.new(Agentic::Verification::VerificationStrategy) do
        def initialize(config = {})
          super
        end
      end
    end

    let(:original_strategies) { described_class.const_get(:STRATEGIES).dup }

    before do
      # Stub STRATEGIES to be mutable for testing
      strategies = original_strategies.dup
      stub_const("#{described_class}::STRATEGIES", strategies)
    end

    it "registers new strategy type" do
      described_class.register(:custom, custom_strategy_class)

      expect(described_class.available_types).to include(:custom)

      strategy = described_class.create(:custom)
      expect(strategy).to be_a(custom_strategy_class)
    end

    context "with invalid strategy class" do
      let(:invalid_class) { Class.new }

      it "raises ArgumentError" do
        expect { described_class.register(:invalid, invalid_class) }
          .to raise_error(ArgumentError, "Strategy class must inherit from VerificationStrategy")
      end
    end
  end

  describe ".create_hub" do
    let(:strategies_config) do
      [
        {type: :llm, dependencies: {llm_client: llm_client}},
        {type: :schema}
      ]
    end
    let(:hub_config) { {fail_fast: true} }

    it "creates verification hub with strategies" do
      hub = described_class.create_hub(
        strategies_config: strategies_config,
        hub_config: hub_config,
        llm_client: llm_client
      )

      expect(hub).to be_a(Agentic::Verification::VerificationHub)
      expect(hub.strategies.size).to eq(2)
      expect(hub.config[:fail_fast]).to be true
    end

    context "with empty strategies config" do
      it "creates hub with no strategies" do
        hub = described_class.create_hub

        expect(hub).to be_a(Agentic::Verification::VerificationHub)
        expect(hub.strategies).to be_empty
      end
    end

    context "with global dependencies for hub creation" do
      it "passes global dependencies to strategy creation" do
        hub = described_class.create_hub(
          strategies_config: [{type: :llm}],
          llm_client: llm_client
        )

        expect(hub.strategies.first).to be_a(Agentic::Verification::LlmVerificationStrategy)
        expect(hub.strategies.first.llm_client).to eq(llm_client)
      end
    end
  end
end
