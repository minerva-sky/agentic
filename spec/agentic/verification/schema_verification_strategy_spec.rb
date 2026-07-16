# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::Verification::SchemaVerificationStrategy do
  let(:task) { double("Task", id: "task_123") }
  let(:successful_result) { double("TaskResult", successful?: true, failed?: false) }
  let(:failed_result) { double("TaskResult", successful?: false, failed?: true) }

  describe ".new" do
    context "with default configuration" do
      subject { described_class.new }

      it "initializes with default config" do
        expect(subject.config[:strict_mode]).to be false
        expect(subject.config[:allow_additional_properties]).to be true
        expect(subject.config[:confidence_on_match]).to eq(0.95)
        expect(subject.config[:confidence_on_no_schema]).to eq(0.5)
      end
    end

    context "with custom configuration" do
      let(:config) { {strict_mode: true, confidence_on_match: 0.9} }
      subject { described_class.new(config) }

      it "merges custom config with defaults" do
        expect(subject.config[:strict_mode]).to be true
        expect(subject.config[:confidence_on_match]).to eq(0.9)
        expect(subject.config[:allow_additional_properties]).to be true # default preserved
      end
    end
  end

  describe "#verify" do
    subject { described_class.new }

    context "when task result failed" do
      it "returns failed task result without schema verification" do
        result = subject.verify(task, failed_result)

        expect(result.task_id).to eq(task.id)
        expect(result.verified).to be false
        expect(result.confidence).to eq(0.0)
        expect(result.messages).to include("Task failed, skipping schema verification")
      end
    end

    context "when no schema is found" do
      before do
        allow(task).to receive(:input).and_return({})
        allow(task).to receive(:respond_to?).with(:metadata).and_return(false)
      end

      it "returns no schema result with default confidence" do
        result = subject.verify(task, successful_result)

        expect(result.task_id).to eq(task.id)
        expect(result.verified).to be true
        expect(result.confidence).to eq(0.5)
        expect(result.messages).to include("No schema specified for verification, passing by default")
      end

      context "with custom confidence_on_no_schema" do
        let(:config) { {confidence_on_no_schema: 0.8} }
        subject { described_class.new(config) }

        it "uses custom confidence value" do
          result = subject.verify(task, successful_result)

          expect(result.confidence).to eq(0.8)
        end
      end
    end

    context "when schema is found in task input" do
      let(:schema) { {"type" => "object", "properties" => {"name" => {"type" => "string"}}} }

      context "with string key in input" do
        before do
          allow(task).to receive(:input).and_return({"output_schema" => schema})
        end

        it "performs schema validation" do
          result = subject.verify(task, successful_result)

          expect(result.task_id).to eq(task.id)
          expect(result.verified).to be true
          expect(result.confidence).to eq(0.95)
          expect(result.messages).to include("Output matches expected schema (simulated)")
        end
      end

      context "with symbol key in input" do
        before do
          allow(task).to receive(:input).and_return({output_schema: schema})
        end

        it "performs schema validation" do
          result = subject.verify(task, successful_result)

          expect(result.verified).to be true
          expect(result.confidence).to eq(0.95)
        end
      end

      context "with custom confidence_on_match" do
        let(:config) { {confidence_on_match: 0.85} }
        subject { described_class.new(config) }

        before do
          allow(task).to receive(:input).and_return({output_schema: schema})
        end

        it "uses custom confidence value" do
          result = subject.verify(task, successful_result)

          expect(result.confidence).to eq(0.85)
        end
      end
    end

    context "when schema is found in task metadata" do
      let(:schema) { {"type" => "string"} }
      let(:metadata) { {output_schema: schema} }

      before do
        allow(task).to receive(:input).and_return({})
        allow(task).to receive(:respond_to?).with(:metadata).and_return(true)
        allow(task).to receive(:metadata).and_return(metadata)
      end

      it "performs schema validation using metadata schema" do
        result = subject.verify(task, successful_result)

        expect(result.verified).to be true
        expect(result.confidence).to eq(0.95)
        expect(result.messages).to include("Output matches expected schema (simulated)")
      end

      context "when metadata is nil" do
        before do
          allow(task).to receive(:metadata).and_return(nil)
        end

        it "returns no schema result" do
          result = subject.verify(task, successful_result)

          expect(result.verified).to be true
          expect(result.confidence).to eq(0.5)
          expect(result.messages).to include("No schema specified for verification, passing by default")
        end
      end
    end

    context "when task input is not a hash" do
      before do
        allow(task).to receive(:input).and_return("string input")
        allow(task).to receive(:respond_to?).with(:metadata).and_return(false)
      end

      it "returns no schema result" do
        result = subject.verify(task, successful_result)

        expect(result.verified).to be true
        expect(result.confidence).to eq(0.5)
        expect(result.messages).to include("No schema specified for verification, passing by default")
      end
    end

    context "when schema validation raises exception" do
      before do
        allow(task).to receive(:input).and_return({output_schema: {"type" => "object"}})
        allow(subject).to receive(:perform_schema_validation).and_raise(StandardError, "Validation error")
        allow(Agentic.logger).to receive(:error)
      end

      it "returns error result" do
        result = subject.verify(task, successful_result)

        expect(result.task_id).to eq(task.id)
        expect(result.verified).to be false
        expect(result.confidence).to eq(0.0)
        expect(result.messages.first).to eq("Schema verification error: Validation error")
      end
    end
  end

  describe "private methods" do
    subject { described_class.new }

    describe "#extract_schema" do
      context "with schema in input hash (string key)" do
        let(:schema) { {"type" => "object"} }
        let(:task_with_schema) { double("Task", input: {"output_schema" => schema}) }

        it "extracts schema from string key" do
          extracted = subject.send(:extract_schema, task_with_schema)
          expect(extracted).to eq(schema)
        end
      end

      context "with schema in input hash (symbol key)" do
        let(:schema) { {"type" => "object"} }
        let(:task_with_schema) { double("Task", input: {output_schema: schema}) }

        it "extracts schema from symbol key" do
          extracted = subject.send(:extract_schema, task_with_schema)
          expect(extracted).to eq(schema)
        end
      end

      context "with schema in metadata" do
        let(:schema) { {"type" => "string"} }
        let(:metadata) { {output_schema: schema} }
        let(:task_with_metadata) do
          double("Task").tap do |t|
            allow(t).to receive(:input).and_return({})
            allow(t).to receive(:respond_to?).with(:metadata).and_return(true)
            allow(t).to receive(:metadata).and_return(metadata)
          end
        end

        it "extracts schema from metadata" do
          extracted = subject.send(:extract_schema, task_with_metadata)
          expect(extracted).to eq(schema)
        end
      end

      context "with no schema anywhere" do
        let(:task_without_schema) do
          double("Task").tap do |t|
            allow(t).to receive(:input).and_return({})
            allow(t).to receive(:respond_to?).with(:metadata).and_return(false)
          end
        end

        it "returns nil" do
          extracted = subject.send(:extract_schema, task_without_schema)
          expect(extracted).to be_nil
        end
      end

      context "with multiple schema locations" do
        let(:input_schema) { {"type" => "object"} }
        let(:metadata_schema) { {"type" => "string"} }
        let(:task_with_multiple) do
          double("Task").tap do |t|
            allow(t).to receive(:input).and_return({"output_schema" => input_schema})
            allow(t).to receive(:respond_to?).with(:metadata).and_return(true)
            allow(t).to receive(:metadata).and_return({output_schema: metadata_schema})
          end
        end

        it "prioritizes input schema over metadata" do
          extracted = subject.send(:extract_schema, task_with_multiple)
          expect(extracted).to eq(input_schema)
        end
      end
    end

    describe "#failed_task_result" do
      it "creates appropriate failure result" do
        result = subject.send(:failed_task_result, task)

        expect(result.task_id).to eq(task.id)
        expect(result.verified).to be false
        expect(result.confidence).to eq(0.0)
        expect(result.messages).to include("Task failed, skipping schema verification")
      end
    end

    describe "#no_schema_result" do
      it "creates appropriate no schema result" do
        result = subject.send(:no_schema_result, task)

        expect(result.task_id).to eq(task.id)
        expect(result.verified).to be true
        expect(result.confidence).to eq(0.5)
        expect(result.messages).to include("No schema specified for verification, passing by default")
      end
    end

    describe "#error_result" do
      let(:error) { StandardError.new("Test error") }

      it "creates appropriate error result" do
        result = subject.send(:error_result, task, error)

        expect(result.task_id).to eq(task.id)
        expect(result.verified).to be false
        expect(result.confidence).to eq(0.0)
        expect(result.messages.first).to eq("Schema verification error: Test error")
      end
    end

    describe "#perform_schema_validation" do
      let(:schema) { {"type" => "object"} }

      it "returns successful validation result (simulated)" do
        result = subject.send(:perform_schema_validation, task, successful_result, schema)

        expect(result).to be_a(Agentic::Verification::VerificationResult)
        expect(result.task_id).to eq(task.id)
        expect(result.verified).to be true
        expect(result.confidence).to eq(0.95)
        expect(result.messages).to include("Output matches expected schema (simulated)")
      end
    end
  end

  describe "inheritance" do
    it "inherits from VerificationStrategy" do
      expect(described_class.ancestors).to include(Agentic::Verification::VerificationStrategy)
    end
  end
end
