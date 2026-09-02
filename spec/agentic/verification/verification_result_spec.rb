# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::Verification::VerificationResult do
  let(:task_id) { "task_123" }
  let(:verified) { true }
  let(:confidence) { 0.85 }
  let(:messages) { ["Verification passed", "High confidence"] }

  describe ".new" do
    subject do
      described_class.new(
        task_id: task_id,
        verified: verified,
        confidence: confidence,
        messages: messages
      )
    end

    it "initializes with provided attributes" do
      expect(subject.task_id).to eq(task_id)
      expect(subject.verified).to eq(verified)
      expect(subject.confidence).to eq(confidence)
      expect(subject.messages).to eq(messages)
    end

    context "without messages" do
      subject do
        described_class.new(
          task_id: task_id,
          verified: verified,
          confidence: confidence
        )
      end

      it "defaults messages to empty array" do
        expect(subject.messages).to eq([])
      end
    end

    context "with all required parameters" do
      it { is_expected.to be_a(described_class) }
    end
  end

  describe "#verified_with_confidence?" do
    context "when verified is true and confidence above default threshold" do
      subject do
        described_class.new(
          task_id: task_id,
          verified: true,
          confidence: 0.85
        )
      end

      it "returns true with default threshold" do
        expect(subject.verified_with_confidence?).to be true
      end

      it "returns true with custom threshold below confidence" do
        expect(subject.verified_with_confidence?(threshold: 0.7)).to be true
      end

      it "returns false with custom threshold above confidence" do
        expect(subject.verified_with_confidence?(threshold: 0.9)).to be false
      end
    end

    context "when verified is true but confidence below threshold" do
      subject do
        described_class.new(
          task_id: task_id,
          verified: true,
          confidence: 0.75
        )
      end

      it "returns false with default threshold" do
        expect(subject.verified_with_confidence?).to be false
      end

      it "returns true with lower threshold" do
        expect(subject.verified_with_confidence?(threshold: 0.7)).to be true
      end
    end

    context "when verified is false" do
      subject do
        described_class.new(
          task_id: task_id,
          verified: false,
          confidence: 0.95
        )
      end

      it "returns false regardless of confidence" do
        expect(subject.verified_with_confidence?).to be false
        expect(subject.verified_with_confidence?(threshold: 0.5)).to be false
      end
    end

    context "with edge case confidence values" do
      context "when confidence exactly equals threshold" do
        subject do
          described_class.new(
            task_id: task_id,
            verified: true,
            confidence: 0.8
          )
        end

        it "returns true" do
          expect(subject.verified_with_confidence?(threshold: 0.8)).to be true
        end
      end

      context "when confidence is 0.0" do
        subject do
          described_class.new(
            task_id: task_id,
            verified: true,
            confidence: 0.0
          )
        end

        it "returns false with any positive threshold" do
          expect(subject.verified_with_confidence?(threshold: 0.1)).to be false
        end

        it "returns true with zero threshold" do
          expect(subject.verified_with_confidence?(threshold: 0.0)).to be true
        end
      end

      context "when confidence is 1.0" do
        subject do
          described_class.new(
            task_id: task_id,
            verified: true,
            confidence: 1.0
          )
        end

        it "returns true with any threshold" do
          expect(subject.verified_with_confidence?(threshold: 0.99)).to be true
          expect(subject.verified_with_confidence?(threshold: 1.0)).to be true
        end
      end
    end
  end

  describe "#to_h" do
    subject do
      described_class.new(
        task_id: task_id,
        verified: verified,
        confidence: confidence,
        messages: messages
      )
    end

    it "returns hash representation" do
      expected_hash = {
        task_id: task_id,
        verified: verified,
        confidence: confidence,
        messages: messages
      }

      expect(subject.to_h).to eq(expected_hash)
    end

    context "with empty messages" do
      subject do
        described_class.new(
          task_id: task_id,
          verified: verified,
          confidence: confidence,
          messages: []
        )
      end

      it "includes empty messages array" do
        expect(subject.to_h[:messages]).to eq([])
      end
    end

    context "with nil values" do
      subject do
        described_class.new(
          task_id: nil,
          verified: false,
          confidence: 0.0
        )
      end

      it "includes nil values in hash" do
        expect(subject.to_h[:task_id]).to be_nil
      end
    end
  end

  describe "attribute readers" do
    subject do
      described_class.new(
        task_id: task_id,
        verified: verified,
        confidence: confidence,
        messages: messages
      )
    end

    it "provides read access to task_id" do
      expect(subject.task_id).to eq(task_id)
    end

    it "provides read access to verified" do
      expect(subject.verified).to eq(verified)
    end

    it "provides read access to confidence" do
      expect(subject.confidence).to eq(confidence)
    end

    it "provides read access to messages" do
      expect(subject.messages).to eq(messages)
    end

    it "does not allow modification of attributes" do
      expect { subject.task_id = "new_id" }.to raise_error(NoMethodError)
      expect { subject.verified = false }.to raise_error(NoMethodError)
      expect { subject.confidence = 0.5 }.to raise_error(NoMethodError)
    end

    it "allows modification of messages array (mutable)" do
      subject.messages << "New message"
      expect(subject.messages).to include("New message")
    end
  end

  describe "data types and validation" do
    context "with various data types" do
      it "accepts string task_id" do
        result = described_class.new(task_id: "string_id", verified: true, confidence: 0.5)
        expect(result.task_id).to eq("string_id")
      end

      it "accepts integer task_id" do
        result = described_class.new(task_id: 123, verified: true, confidence: 0.5)
        expect(result.task_id).to eq(123)
      end

      it "accepts boolean verified values" do
        true_result = described_class.new(task_id: "id", verified: true, confidence: 0.5)
        false_result = described_class.new(task_id: "id", verified: false, confidence: 0.5)

        expect(true_result.verified).to be true
        expect(false_result.verified).to be false
      end

      it "accepts numeric confidence values" do
        int_result = described_class.new(task_id: "id", verified: true, confidence: 1)
        float_result = described_class.new(task_id: "id", verified: true, confidence: 0.85)

        expect(int_result.confidence).to eq(1)
        expect(float_result.confidence).to eq(0.85)
      end

      it "accepts array of strings for messages" do
        result = described_class.new(task_id: "id", verified: true, confidence: 0.5, messages: ["msg1", "msg2"])
        expect(result.messages).to eq(["msg1", "msg2"])
      end
    end
  end
end
