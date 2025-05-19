# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::TaskFailure do
  let(:message) { "Test failure message" }
  let(:type) { "TestErrorType" }
  let(:context) { {"key" => "value"} }

  describe "#initialize" do
    it "sets the attributes correctly" do
      failure = described_class.new(message: message, type: type, context: context)

      expect(failure.message).to eq(message)
      expect(failure.type).to eq(type)
      expect(failure.context).to eq(context)
      expect(failure.timestamp).to be_a(Time)
    end

    it "defaults to empty context" do
      failure = described_class.new(message: message, type: type)
      expect(failure.context).to eq({})
    end
  end

  describe "#to_h" do
    it "returns a hash representation" do
      freeze_time = Time.now
      allow(Time).to receive(:now).and_return(freeze_time)

      failure = described_class.new(message: message, type: type, context: context)
      hash = failure.to_h

      expect(hash).to be_a(Hash)
      expect(hash[:message]).to eq(message)
      expect(hash[:type]).to eq(type)
      expect(hash[:context]).to eq(context)
      expect(hash[:timestamp]).to eq(freeze_time.iso8601)
    end
  end

  describe ".from_exception" do
    it "creates a failure from an exception" do
      exception = StandardError.new("Exception message")
      allow(exception).to receive(:backtrace).and_return(["line1", "line2"])

      failure = described_class.from_exception(exception, {agent_id: "agent-123"})

      expect(failure.message).to eq("Exception message")
      expect(failure.type).to eq("StandardError")
      expect(failure.context[:agent_id]).to eq("agent-123")
      expect(failure.context[:backtrace]).to eq(["line1", "line2"])
    end
  end
end
