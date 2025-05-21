# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::TaskExecutionResult do
  let(:output) { {key: "value"} }
  let(:failure) { Agentic::TaskFailure.new(message: "Something went wrong", type: "ErrorType") }

  describe "#initialize" do
    it "initializes with status, output, and failure" do
      result = described_class.new(status: :completed, output: output, failure: nil)
      expect(result.status).to eq(:completed)
      expect(result.output).to eq(output)
      expect(result.failure).to be_nil
    end
  end

  describe ".success" do
    it "creates a successful result" do
      result = described_class.success(output)
      expect(result.status).to eq(:completed)
      expect(result.output).to eq(output)
      expect(result.failure).to be_nil
      expect(result.successful?).to be true
      expect(result.failed?).to be false
      expect(result.canceled?).to be false
    end
  end

  describe ".failure" do
    it "creates a failed result" do
      result = described_class.failure(failure)
      expect(result.status).to eq(:failed)
      expect(result.output).to be_nil
      expect(result.failure).to eq(failure)
      expect(result.successful?).to be false
      expect(result.failed?).to be true
      expect(result.canceled?).to be false
    end
  end

  describe ".canceled" do
    it "creates a canceled result" do
      result = described_class.canceled
      expect(result.status).to eq(:canceled)
      expect(result.output).to be_nil
      expect(result.failure).to be_nil
      expect(result.successful?).to be false
      expect(result.failed?).to be false
      expect(result.canceled?).to be true
    end
  end

  describe ".from_hash" do
    let(:hash) { {status: :completed, output: output, failure: nil} }
    let(:failure_hash) { {status: :failed, output: nil, failure: failure.to_h} }

    it "creates a result from a success hash" do
      result = described_class.from_hash(hash)
      expect(result.status).to eq(:completed)
      expect(result.output).to eq(output)
      expect(result.failure).to be_nil
    end

    it "creates a result from a failure hash" do
      result = described_class.from_hash(failure_hash)
      expect(result.status).to eq(:failed)
      expect(result.output).to be_nil
      expect(result.failure).to be_a(Agentic::TaskFailure)
      expect(result.failure.message).to eq("Something went wrong")
      expect(result.failure.type).to eq("ErrorType")
    end
  end

  describe "#to_h" do
    it "returns a hash for a successful result" do
      result = described_class.success(output)
      expect(result.to_h).to eq({
        status: :completed,
        output: output,
        failure: nil
      })
    end

    it "returns a hash for a failed result" do
      result = described_class.failure(failure)
      expect(result.to_h).to eq({
        status: :failed,
        output: nil,
        failure: failure.to_h
      })
    end
  end
end
