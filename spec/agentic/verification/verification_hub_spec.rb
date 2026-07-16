# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::Verification::VerificationHub do
  let(:task) { double("Task", id: "task_123") }
  let(:successful_result) { double("TaskResult", failed?: false, successful?: true) }
  let(:failed_result) { double("TaskResult", failed?: true, successful?: false) }
  let(:strategy) { double("VerificationStrategy") }
  let(:verification_result) do
    Agentic::Verification::VerificationResult.new(
      task_id: task.id,
      verified: true,
      confidence: 0.8,
      messages: ["Strategy passed"]
    )
  end

  describe ".new" do
    context "with default configuration" do
      subject { described_class.new }

      it { is_expected.to be_a(described_class) }

      it "initializes with empty strategies" do
        expect(subject.strategies).to be_empty
      end

      it "uses default configuration" do
        expect(subject.config[:fail_fast]).to be false
        expect(subject.config[:min_confidence]).to eq(0.0)
        expect(subject.config[:require_all_strategies]).to be true
      end
    end

    context "with custom configuration" do
      let(:custom_config) { {fail_fast: true, min_confidence: 0.5} }

      subject { described_class.new(config: custom_config) }

      it "merges custom config with defaults" do
        expect(subject.config[:fail_fast]).to be true
        expect(subject.config[:min_confidence]).to eq(0.5)
        expect(subject.config[:require_all_strategies]).to be true
      end
    end

    context "with initial strategies" do
      subject { described_class.new(strategies: [strategy]) }

      it "initializes with provided strategies" do
        expect(subject.strategies).to contain_exactly(strategy)
      end
    end
  end

  describe "#add_strategy" do
    subject { described_class.new }

    context "with valid strategy" do
      before do
        allow(strategy).to receive(:is_a?).with(Agentic::Verification::VerificationStrategy).and_return(true)
      end

      it "adds strategy to collection" do
        expect { subject.add_strategy(strategy) }
          .to change { subject.strategies.size }.from(0).to(1)
      end
    end

    context "with invalid strategy" do
      before do
        allow(strategy).to receive(:is_a?).with(Agentic::Verification::VerificationStrategy).and_return(false)
      end

      it "raises ArgumentError" do
        expect { subject.add_strategy(strategy) }
          .to raise_error(ArgumentError, "Strategy must be a VerificationStrategy instance")
      end
    end
  end

  describe "#add_strategy_from_factory" do
    subject { described_class.new }

    before do
      stub_const("Agentic::Verification::StrategyFactory", double("StrategyFactory"))
      allow(Agentic::Verification::StrategyFactory).to receive(:create).and_return(strategy)
      allow(strategy).to receive(:is_a?).with(Agentic::Verification::VerificationStrategy).and_return(true)
    end

    it "creates strategy using factory and adds it" do
      expect(Agentic::Verification::StrategyFactory)
        .to receive(:create).with(:llm, config: {threshold: 0.8}, llm_client: "client")

      subject.add_strategy_from_factory(:llm, config: {threshold: 0.8}, llm_client: "client")

      expect(subject.strategies).to contain_exactly(strategy)
    end
  end

  describe "#verify" do
    subject { described_class.new }

    context "when task result failed" do
      it "returns failed result without running strategies" do
        result = subject.verify(task, failed_result)

        expect(result.task_id).to eq(task.id)
        expect(result.verified).to be false
        expect(result.confidence).to eq(0.0)
        expect(result.messages).to include("Task failed, skipping verification")
      end
    end

    context "when no strategies configured" do
      it "returns passing result by default" do
        result = subject.verify(task, successful_result)

        expect(result.task_id).to eq(task.id)
        expect(result.verified).to be true
        expect(result.confidence).to eq(1.0)
        expect(result.messages).to include("No verification strategies configured, passing by default")
      end
    end

    context "with single successful strategy" do
      before do
        allow(strategy).to receive(:is_a?).with(Agentic::Verification::VerificationStrategy).and_return(true)
        allow(strategy).to receive(:verify).and_return(verification_result)
        subject.add_strategy(strategy)
      end

      it "returns successful verification result" do
        result = subject.verify(task, successful_result)

        expect(result.task_id).to eq(task.id)
        expect(result.verified).to be true
        expect(result.confidence).to eq(0.8)
        expect(result.messages).to include("Strategy passed")
      end
    end

    context "with multiple strategies" do
      let(:strategy2) { double("VerificationStrategy") }
      let(:verification_result2) do
        Agentic::Verification::VerificationResult.new(
          task_id: task.id,
          verified: true,
          confidence: 0.9,
          messages: ["Strategy 2 passed"]
        )
      end

      before do
        [strategy, strategy2].each do |s|
          allow(s).to receive(:is_a?).with(Agentic::Verification::VerificationStrategy).and_return(true)
        end
        allow(strategy).to receive(:verify).and_return(verification_result)
        allow(strategy2).to receive(:verify).and_return(verification_result2)
        subject.add_strategy(strategy)
        subject.add_strategy(strategy2)
      end

      it "combines results from all strategies" do
        result = subject.verify(task, successful_result)

        expect(result.verified).to be true
        expect(result.confidence).to be_within(0.001).of(0.85) # Average of 0.8 and 0.9
        expect(result.messages).to include("Strategy passed", "Strategy 2 passed")
      end
    end

    context "with failing strategy" do
      let(:failing_result) do
        Agentic::Verification::VerificationResult.new(
          task_id: task.id,
          verified: false,
          confidence: 0.3,
          messages: ["Strategy failed"]
        )
      end

      before do
        allow(strategy).to receive(:is_a?).with(Agentic::Verification::VerificationStrategy).and_return(true)
        allow(strategy).to receive(:verify).and_return(failing_result)
        subject.add_strategy(strategy)
      end

      it "returns failed verification result" do
        result = subject.verify(task, successful_result)

        expect(result.verified).to be false
        expect(result.confidence).to eq(0.3)
        expect(result.messages).to include("Strategy failed")
      end
    end

    context "with min_confidence configuration" do
      subject { described_class.new(config: {min_confidence: 0.9}) }

      before do
        allow(strategy).to receive(:is_a?).with(Agentic::Verification::VerificationStrategy).and_return(true)
        allow(strategy).to receive(:verify).and_return(verification_result) # confidence 0.8
        subject.add_strategy(strategy)
      end

      it "fails when confidence below threshold" do
        result = subject.verify(task, successful_result)

        expect(result.verified).to be false
        expect(result.messages).to include(/Combined confidence below minimum threshold/)
      end
    end

    context "with fail_fast configuration" do
      subject { described_class.new(config: {fail_fast: true}) }
      let(:strategy2) { double("VerificationStrategy") }
      let(:failing_result) do
        Agentic::Verification::VerificationResult.new(
          task_id: task.id,
          verified: false,
          confidence: 0.3,
          messages: ["Strategy failed"]
        )
      end

      before do
        [strategy, strategy2].each do |s|
          allow(s).to receive(:is_a?).with(Agentic::Verification::VerificationStrategy).and_return(true)
        end
        allow(strategy).to receive(:verify).and_return(failing_result)
        subject.add_strategy(strategy)
        subject.add_strategy(strategy2)
      end

      it "stops at first failure" do
        expect(strategy2).not_to receive(:verify)

        result = subject.verify(task, successful_result)
        expect(result.verified).to be false
      end
    end

    context "when strategy raises exception" do
      before do
        allow(strategy).to receive(:is_a?).with(Agentic::Verification::VerificationStrategy).and_return(true)
        allow(strategy).to receive(:verify).and_raise(StandardError, "Strategy error")
        allow(strategy).to receive_message_chain(:class, :name).and_return("TestStrategy")
        subject.add_strategy(strategy)
      end

      context "with require_all_strategies false" do
        subject { described_class.new(config: {require_all_strategies: false}) }

        it "continues with other strategies" do
          allow(Agentic.logger).to receive(:warn)

          result = subject.verify(task, successful_result)

          expect(result.verified).to be false
          expect(result.messages).to include(/All verification strategies failed: TestStrategy/)
        end
      end

      context "with require_all_strategies true" do
        subject { described_class.new(config: {require_all_strategies: true}) }

        it "returns error result" do
          allow(Agentic.logger).to receive(:error)

          result = subject.verify(task, successful_result)

          expect(result.verified).to be false
          expect(result.messages.first).to match(/Verification hub error/)
        end
      end
    end
  end

  describe "#strategy_count" do
    subject { described_class.new }

    it "returns number of strategies" do
      expect(subject.strategy_count).to eq(0)

      allow(strategy).to receive(:is_a?).with(Agentic::Verification::VerificationStrategy).and_return(true)
      subject.add_strategy(strategy)

      expect(subject.strategy_count).to eq(1)
    end
  end

  describe "#clear_strategies" do
    subject { described_class.new }

    before do
      allow(strategy).to receive(:is_a?).with(Agentic::Verification::VerificationStrategy).and_return(true)
      subject.add_strategy(strategy)
    end

    it "removes all strategies" do
      expect { subject.clear_strategies }
        .to change { subject.strategy_count }.from(1).to(0)
    end
  end
end
