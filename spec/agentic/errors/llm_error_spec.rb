# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::Errors::LlmError do
  describe "base error class" do
    it "initializes with a message" do
      error = described_class.new("An error occurred")
      expect(error.message).to eq("An error occurred")
      expect(error.response).to be_nil
      expect(error.context).to eq({})
    end

    it "initializes with a response" do
      response = {"error" => {"message" => "Something went wrong"}}
      error = described_class.new("An error occurred", response: response)
      expect(error.response).to eq(response)
    end

    it "initializes with context" do
      context = {request_id: "req123"}
      error = described_class.new("An error occurred", context: context)
      expect(error.context).to eq(context)
    end
  end

  describe "subclasses" do
    describe Agentic::Errors::LlmRefusalError do
      it "initializes with a refusal message" do
        error = described_class.new("I can't do that")
        expect(error.message).to eq("LLM refused to respond: I can't do that")
        expect(error.refusal_message).to eq("I can't do that")
      end
    end

    describe Agentic::Errors::LlmParseError do
      it "initializes with a parse exception" do
        parse_exception = JSON::ParserError.new("Invalid JSON")
        error = described_class.new("Failed to parse JSON", parse_exception: parse_exception)
        expect(error.message).to eq("Failed to parse JSON")
        expect(error.parse_exception).to eq(parse_exception)
      end
    end

    describe Agentic::Errors::LlmNetworkError do
      it "initializes with a network exception" do
        network_exception = StandardError.new("Connection failed")
        error = described_class.new("Network error", network_exception: network_exception)
        expect(error.message).to eq("Network error")
        expect(error.network_exception).to eq(network_exception)
      end

      it "is retryable" do
        error = described_class.new("Network error")
        expect(error.retryable?).to be true
      end
    end

    describe Agentic::Errors::LlmRateLimitError do
      it "initializes with a retry_after value" do
        error = described_class.new("Rate limit exceeded", retry_after: 30)
        expect(error.message).to eq("Rate limit exceeded")
        expect(error.retry_after).to eq(30)
      end

      it "is retryable" do
        error = described_class.new("Rate limit exceeded")
        expect(error.retryable?).to be true
      end
    end

    describe Agentic::Errors::LlmAuthenticationError do
      it "initializes with a message" do
        error = described_class.new("Invalid API key")
        expect(error.message).to eq("Invalid API key")
      end

      it "is not retryable" do
        error = described_class.new("Invalid API key")
        expect(error.retryable?).to be false
      end
    end

    describe Agentic::Errors::LlmServerError do
      it "initializes with a message" do
        error = described_class.new("Server error")
        expect(error.message).to eq("Server error")
      end

      it "is retryable" do
        error = described_class.new("Server error")
        expect(error.retryable?).to be true
      end
    end

    describe Agentic::Errors::LlmTimeoutError do
      it "initializes with a message" do
        error = described_class.new("Request timed out")
        expect(error.message).to eq("Request timed out")
      end

      it "is retryable" do
        error = described_class.new("Request timed out")
        expect(error.retryable?).to be true
      end
    end

    describe Agentic::Errors::LlmInvalidRequestError do
      it "initializes with a message" do
        error = described_class.new("Invalid request")
        expect(error.message).to eq("Invalid request")
      end

      it "is not retryable" do
        error = described_class.new("Invalid request")
        expect(error.retryable?).to be false
      end
    end
  end
end
