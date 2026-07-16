# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Verification System Integration" do
  describe "end-to-end verification workflow" do
    let(:task) { build_task_with_schema(schema: simple_object_schema) }
    let(:result) { build_task_result(successful: true) }

    context "with schema verification" do
      it "successfully verifies task with valid schema" do
        hub = Agentic::Verification::VerificationHelpers.create_schema_verification_hub

        verification_result = hub.verify(task, result)

        expect(verification_result.verified).to be true
        expect(verification_result.confidence).to eq(0.95)
        expect(verification_result.task_id).to eq(task.id)
      end
    end

    context "with comprehensive verification using factories" do
      let(:llm_client) { build_llm_client }
      let(:task_with_complex_schema) { build_task_with_schema(schema: complex_schema) }

      it "creates verification hub with multiple strategies" do
        hub = Agentic::Verification::VerificationHelpers.create_comprehensive_verification_hub(llm_client)

        expect(hub.strategies.size).to eq(2)
        expect(hub.strategies[0]).to be_a(Agentic::Verification::SchemaVerificationStrategy)
        expect(hub.strategies[1]).to be_a(Agentic::Verification::LlmVerificationStrategy)
      end

      it "verifies task using schema strategy from comprehensive hub" do
        hub = Agentic::Verification::VerificationHelpers.create_comprehensive_verification_hub(llm_client)

        verification_result = hub.verify(task_with_complex_schema, result)

        expect(verification_result.task_id).to eq(task_with_complex_schema.id)
        # Note: This will only test schema verification as LLM verification is mocked
      end
    end

    context "with convenience methods" do
      it "provides simple verification interface using helpers" do
        hub = Agentic::Verification::VerificationHelpers.create_schema_verification_hub
        verification_result = hub.verify(task, result)

        expect(verification_result).to be_a(Agentic::Verification::VerificationResult)
        expect(verification_result.verified).to be true
      end

      it "handles batch verification using multiple hubs" do
        task2 = build_task_with_metadata_schema(schema: string_schema)
        result2 = build_task_result(successful: true)

        hub = Agentic::Verification::VerificationHelpers.create_schema_verification_hub
        verification_results = [
          hub.verify(task, result),
          hub.verify(task2, result2)
        ]

        expect(verification_results.size).to eq(2)
        verification_results.each do |vr|
          expect(vr).to be_a(Agentic::Verification::VerificationResult)
          expect(vr.verified).to be true
        end
      end
    end

    context "with failed task results" do
      let(:failed_result) { build_task_result(successful: false, failed: true) }

      it "skips verification for failed tasks" do
        hub = Agentic::Verification::VerificationHelpers.create_schema_verification_hub

        verification_result = hub.verify(task, failed_result)

        expect(verification_result.verified).to be false
        expect(verification_result.confidence).to eq(0.0)
        expect(verification_result.messages).to include(/Task failed, skipping/)
      end
    end

    context "with missing schema" do
      let(:task_without_schema) { build_task }

      it "passes verification with default confidence" do
        hub = Agentic::Verification::VerificationHelpers.create_schema_verification_hub

        verification_result = hub.verify(task_without_schema, result)

        expect(verification_result.verified).to be true
        expect(verification_result.confidence).to eq(0.5)
        expect(verification_result.messages).to include(/No schema specified/)
      end
    end
  end

  describe "factory usage examples" do
    it "demonstrates factory flexibility" do
      # Create various test objects using factories
      basic_task = build_task
      schema_task = build_task_with_schema(schema: simple_object_schema)
      metadata_task = build_task_with_metadata_schema(schema: complex_schema)

      successful_result = build_task_result(successful: true)
      failed_result = build_task_result(successful: false, failed: true)

      verification_result = build_verification_result(
        task_id: basic_task.id,
        verified: true,
        confidence: 0.9,
        messages: ["Custom verification message"]
      )

      # Verify factory-created objects work correctly
      expect(basic_task.id).to be_a(String)
      expect(schema_task.input).to have_key(:output_schema)
      expect(metadata_task.metadata).to have_key(:output_schema)
      expect(successful_result.successful?).to be true
      expect(failed_result.failed?).to be true
      expect(verification_result.verified).to be true
      expect(verification_result.confidence).to eq(0.9)
    end
  end
end
