# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::Verification::VerificationHelpers do
  let(:llm_client) { double("LlmClient") }

  describe ".create_verification_hub" do
    context "with default configuration" do
      it "creates hub with default schema strategy" do
        hub = described_class.create_verification_hub

        expect(hub).to be_a(Agentic::Verification::VerificationHub)
        expect(hub.strategies.size).to eq(1)
        expect(hub.strategies.first).to be_a(Agentic::Verification::SchemaVerificationStrategy)
      end
    end

    context "with custom strategies configuration" do
      let(:config) do
        {
          strategies: [
            {type: :schema, config: {strict_mode: true}}
          ],
          hub_config: {fail_fast: true}
        }
      end

      it "creates hub with custom configuration" do
        hub = described_class.create_verification_hub(config)

        expect(hub.config[:fail_fast]).to be true
        expect(hub.strategies.first.config[:strict_mode]).to be true
      end
    end

    context "with LLM client dependency" do
      let(:config) do
        {
          strategies: [
            {type: :llm, config: {confidence_threshold: 0.9}}
          ],
          llm_client: llm_client
        }
      end

      it "passes LLM client to strategies" do
        hub = described_class.create_verification_hub(config)

        expect(hub.strategies.first).to be_a(Agentic::Verification::LlmVerificationStrategy)
        expect(hub.strategies.first.llm_client).to eq(llm_client)
      end
    end

    context "with empty strategies array" do
      let(:config) { {strategies: []} }

      it "creates hub with no strategies" do
        hub = described_class.create_verification_hub(config)

        expect(hub.strategies).to be_empty
      end
    end
  end

  describe ".create_schema_verification_hub" do
    it "creates hub with schema verification only" do
      hub = described_class.create_schema_verification_hub

      expect(hub).to be_a(Agentic::Verification::VerificationHub)
      expect(hub.strategies.size).to eq(1)
      expect(hub.strategies.first).to be_a(Agentic::Verification::SchemaVerificationStrategy)
    end

    context "with custom schema configuration" do
      let(:config) do
        {
          schema_config: {strict_mode: true, confidence_on_match: 0.99},
          hub_config: {min_confidence: 0.8}
        }
      end

      it "applies custom configuration" do
        hub = described_class.create_schema_verification_hub(config)

        expect(hub.config[:min_confidence]).to eq(0.8)
        expect(hub.strategies.first.config[:strict_mode]).to be true
        expect(hub.strategies.first.config[:confidence_on_match]).to eq(0.99)
      end
    end
  end

  describe ".create_llm_verification_hub" do
    it "creates hub with LLM verification only" do
      hub = described_class.create_llm_verification_hub(llm_client)

      expect(hub).to be_a(Agentic::Verification::VerificationHub)
      expect(hub.strategies.size).to eq(1)
      expect(hub.strategies.first).to be_a(Agentic::Verification::LlmVerificationStrategy)
      expect(hub.strategies.first.llm_client).to eq(llm_client)
    end

    context "with custom LLM configuration" do
      let(:config) do
        {
          llm_config: {confidence_threshold: 0.9, max_retries: 3},
          hub_config: {fail_fast: true}
        }
      end

      it "applies custom configuration" do
        hub = described_class.create_llm_verification_hub(llm_client, config)

        expect(hub.config[:fail_fast]).to be true
        expect(hub.strategies.first.config[:confidence_threshold]).to eq(0.9)
        expect(hub.strategies.first.config[:max_retries]).to eq(3)
      end
    end
  end

  describe ".create_comprehensive_verification_hub" do
    it "creates hub with both schema and LLM verification" do
      hub = described_class.create_comprehensive_verification_hub(llm_client)

      expect(hub).to be_a(Agentic::Verification::VerificationHub)
      expect(hub.strategies.size).to eq(2)
      expect(hub.strategies[0]).to be_a(Agentic::Verification::SchemaVerificationStrategy)
      expect(hub.strategies[1]).to be_a(Agentic::Verification::LlmVerificationStrategy)
      expect(hub.strategies[1].llm_client).to eq(llm_client)
    end

    it "sets default minimum confidence" do
      hub = described_class.create_comprehensive_verification_hub(llm_client)

      expect(hub.config[:min_confidence]).to eq(0.7)
    end

    context "with custom configuration" do
      let(:config) do
        {
          schema_config: {strict_mode: true},
          llm_config: {confidence_threshold: 0.9},
          hub_config: {min_confidence: 0.8, fail_fast: true}
        }
      end

      it "applies custom configuration to all components" do
        hub = described_class.create_comprehensive_verification_hub(llm_client, config)

        expect(hub.config[:min_confidence]).to eq(0.8)
        expect(hub.config[:fail_fast]).to be true
        expect(hub.strategies[0].config[:strict_mode]).to be true
        expect(hub.strategies[1].config[:confidence_threshold]).to eq(0.9)
      end
    end
  end
end

RSpec.describe Agentic::Verification::ConvenienceMethods do
  let(:task) { double("Task", id: "task_123", input: {}) }
  let(:result) { double("TaskResult", successful?: true, failed?: false) }
  let(:llm_client) { double("LlmClient") }

  describe ".verify_task_result" do
    context "with schema verification type" do
      it "performs schema verification" do
        verification_result = described_class.verify_task_result(task, result, verification_type: :schema)

        expect(verification_result).to be_a(Agentic::Verification::VerificationResult)
        expect(verification_result.task_id).to eq(task.id)
      end
    end

    context "with LLM verification type" do
      it "performs LLM verification with provided client" do
        # Stub the random behavior for consistent testing
        allow_any_instance_of(Agentic::Verification::LlmVerificationStrategy).to receive(:rand).and_return(0.5)

        verification_result = described_class.verify_task_result(
          task, result,
          verification_type: :llm,
          llm_client: llm_client
        )

        expect(verification_result).to be_a(Agentic::Verification::VerificationResult)
        expect(verification_result.task_id).to eq(task.id)
      end

      context "without LLM client" do
        it "raises ArgumentError" do
          expect do
            described_class.verify_task_result(task, result, verification_type: :llm)
          end.to raise_error(ArgumentError, "LLM client required for LLM verification")
        end
      end
    end

    context "with comprehensive verification type" do
      it "performs comprehensive verification with provided client" do
        # Stub the random behavior for consistent testing
        allow_any_instance_of(Agentic::Verification::LlmVerificationStrategy).to receive(:rand).and_return(0.5)

        verification_result = described_class.verify_task_result(
          task, result,
          verification_type: :comprehensive,
          llm_client: llm_client
        )

        expect(verification_result).to be_a(Agentic::Verification::VerificationResult)
        expect(verification_result.task_id).to eq(task.id)
      end

      context "without LLM client" do
        it "raises ArgumentError" do
          expect do
            described_class.verify_task_result(task, result, verification_type: :comprehensive)
          end.to raise_error(ArgumentError, "LLM client required for comprehensive verification")
        end
      end
    end

    context "with unknown verification type" do
      it "raises ArgumentError" do
        expect do
          described_class.verify_task_result(task, result, verification_type: :unknown)
        end.to raise_error(ArgumentError, "Unknown verification type: unknown")
      end
    end
  end

  describe ".batch_verify" do
    let(:task2) { double("Task", id: "task_456", input: {}) }
    let(:result2) { double("TaskResult", successful?: true, failed?: false) }
    let(:task_results) { [[task, result], [task2, result2]] }

    context "with schema verification type" do
      it "verifies multiple task results" do
        verification_results = described_class.batch_verify(task_results, verification_type: :schema)

        expect(verification_results.size).to eq(2)
        verification_results.each do |vr|
          expect(vr).to be_a(Agentic::Verification::VerificationResult)
        end

        expect(verification_results[0].task_id).to eq(task.id)
        expect(verification_results[1].task_id).to eq(task2.id)
      end
    end

    context "with LLM verification type" do
      it "verifies multiple task results with LLM client" do
        # Stub the random behavior for consistent testing
        allow_any_instance_of(Agentic::Verification::LlmVerificationStrategy).to receive(:rand).and_return(0.5)

        verification_results = described_class.batch_verify(
          task_results,
          verification_type: :llm,
          llm_client: llm_client
        )

        expect(verification_results.size).to eq(2)
        verification_results.each do |vr|
          expect(vr).to be_a(Agentic::Verification::VerificationResult)
        end
      end

      context "without LLM client" do
        it "raises ArgumentError" do
          expect do
            described_class.batch_verify(task_results, verification_type: :llm)
          end.to raise_error(ArgumentError, "LLM client required for LLM verification")
        end
      end
    end

    context "with comprehensive verification type" do
      it "verifies multiple task results comprehensively" do
        # Stub the random behavior for consistent testing
        allow_any_instance_of(Agentic::Verification::LlmVerificationStrategy).to receive(:rand).and_return(0.5)

        verification_results = described_class.batch_verify(
          task_results,
          verification_type: :comprehensive,
          llm_client: llm_client
        )

        expect(verification_results.size).to eq(2)
        verification_results.each do |vr|
          expect(vr).to be_a(Agentic::Verification::VerificationResult)
        end
      end

      context "without LLM client" do
        it "raises ArgumentError" do
          expect do
            described_class.batch_verify(task_results, verification_type: :comprehensive)
          end.to raise_error(ArgumentError, "LLM client required for comprehensive verification")
        end
      end
    end

    context "with empty task results array" do
      it "returns empty array" do
        results = described_class.batch_verify([], verification_type: :schema)
        expect(results).to be_empty
      end
    end

    context "with unknown verification type" do
      it "raises ArgumentError" do
        expect do
          described_class.batch_verify(task_results, verification_type: :unknown)
        end.to raise_error(ArgumentError, "Unknown verification type: unknown")
      end
    end
  end
end
