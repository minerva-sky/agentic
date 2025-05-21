# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::LlmClient do
  let(:llm_config) { Agentic::LlmConfig.new(model: "test-model") }
  let(:client) { described_class.new(llm_config) }
  let(:mock_openai_client) { instance_double(OpenAI::Client) }

  describe "#initialize" do
    it "creates an OpenAI::Client instance" do
      expect(client.client).to be_an_instance_of(OpenAI::Client)
    end

    it "initializes a RetryHandler" do
      expect(client.retry_handler).to be_an_instance_of(Agentic::RetryHandler)
    end

    it "accepts custom retry options" do
      custom_options = {max_retries: 5, backoff_strategy: :linear}
      custom_client = described_class.new(llm_config, custom_options)
      expect(custom_client.retry_handler.max_retries).to eq(5)
      expect(custom_client.retry_handler.backoff_strategy).to eq(:linear)
    end
  end

  describe "#complete" do
    let(:messages) { [{role: "user", content: "Hello"}] }
    let(:response) { {"choices" => [{"message" => {"content" => "Hi there!"}}]} }

    before do
      allow(client).to receive(:client).and_return(mock_openai_client)
    end

    it "sends a completion request with correct parameters" do
      expect(mock_openai_client).to receive(:chat).with(
        parameters: {
          model: llm_config.model,
          messages: messages
        }
      ).and_return(response)
      client.complete(messages)
    end

    it "returns an LlmResponse object with the content" do
      allow(mock_openai_client).to receive(:chat).and_return(response)
      result = client.complete(messages)
      expect(result).to be_a(Agentic::LlmResponse)
      expect(result.content).to eq(response.dig("choices", 0, "message", "content"))
      expect(result.successful?).to be true
    end

    context "with structured output" do
      let(:messages) { [{role: "user", content: "What is the capital of France?"}] }
      let(:schema) do
        Agentic::StructuredOutputs::Schema.new("location") do |s|
          s.string :capital
          s.string :country
        end
      end
      let(:response_with_schema) do
        {
          "choices" => [
            {
              "message" => {
                "content" => '{"capital": "Paris", "country": "France"}'
              }
            }
          ]
        }
      end

      before do
        allow(mock_openai_client).to receive(:chat).and_return(response_with_schema)
      end

      it "returns an LlmResponse with parsed JSON content" do
        result = client.complete(messages, output_schema: schema)
        expect(result).to be_a(Agentic::LlmResponse)
        expect(result.content).to eq({"capital" => "Paris", "country" => "France"})
        expect(result.successful?).to be true
      end
    end

    context "with refusals" do
      let(:refusal_response) do
        {
          "choices" => [
            {
              "message" => {
                "content" => nil,
                "refusal" => "I cannot provide that information"
              }
            }
          ]
        }
      end

      it "handles refusals gracefully" do
        allow(mock_openai_client).to receive(:chat).and_return(refusal_response)
        result = client.complete(messages)
        expect(result).to be_a(Agentic::LlmResponse)
        expect(result.refused?).to be true
        expect(result.refusal).to eq("I cannot provide that information")
        expect(result.successful?).to be false
      end

      it "creates a refusal error with context" do
        allow(mock_openai_client).to receive(:chat).and_return(refusal_response)
        result = client.complete(messages)
        expect(result.refusal_error).to be_a(Agentic::Errors::LlmRefusalError)
        expect(result.refusal_error.refusal_message).to eq("I cannot provide that information")
        expect(result.refusal_error.context).to include(:input_messages)
      end

      it "categorizes different types of refusals" do
        harmful_response = {
          "choices" => [
            {
              "message" => {
                "content" => nil,
                "refusal" => "I cannot provide harmful content"
              }
            }
          ]
        }

        clarification_response = {
          "choices" => [
            {
              "message" => {
                "content" => nil,
                "refusal" => "I need more clarification on your request"
              }
            }
          ]
        }

        allow(mock_openai_client).to receive(:chat).and_return(harmful_response)
        harmful_result = client.complete(messages)
        expect(harmful_result.refusal_category).to eq(:harmful_content)
        expect(harmful_result.retryable_refusal?).to be false

        allow(mock_openai_client).to receive(:chat).and_return(clarification_response)
        clarification_result = client.complete(messages)
        expect(clarification_result.refusal_category).to eq(:needs_clarification)
        expect(clarification_result.retryable_refusal?).to be true
      end

      it "raises refusal errors when fail_on_error is true" do
        allow(mock_openai_client).to receive(:chat).and_return(refusal_response)
        expect { client.complete(messages, fail_on_error: true) }
          .to raise_error(Agentic::Errors::LlmRefusalError)
      end
    end

    context "with JSON parsing errors" do
      let(:invalid_json_response) do
        {
          "choices" => [
            {
              "message" => {
                "content" => '{"capital": "Paris", "country": "France", invalid json'
              }
            }
          ]
        }
      end

      let(:schema) do
        Agentic::StructuredOutputs::Schema.new("location") do |s|
          s.string :capital
          s.string :country
        end
      end

      it "returns an LlmResponse with error for invalid JSON" do
        allow(mock_openai_client).to receive(:chat).and_return(invalid_json_response)
        result = client.complete(messages, output_schema: schema)
        expect(result).to be_a(Agentic::LlmResponse)
        expect(result.error?).to be true
        expect(result.error).to be_a(Agentic::Errors::LlmParseError)
      end
    end

    context "with API errors" do
      let(:timeout_error) { OpenAI::Timeout.new("Request timed out") }
      let(:auth_error) { OpenAI::AuthenticationError.new("Invalid API key") }
      let(:rate_limit_error) {
        error = OpenAI::RateLimitError.new("Rate limit exceeded")
        allow(error).to receive(:response).and_return(double(headers: {"retry-after" => "30"}, to_h: {}))
        error
      }

      it "handles timeout errors" do
        allow(mock_openai_client).to receive(:chat).and_raise(timeout_error)
        result = client.complete(messages, use_retries: false)
        expect(result).to be_a(Agentic::LlmResponse)
        expect(result.error?).to be true
        expect(result.error).to be_a(Agentic::Errors::LlmTimeoutError)
      end

      it "handles authentication errors" do
        allow(mock_openai_client).to receive(:chat).and_raise(auth_error)
        result = client.complete(messages, use_retries: false)
        expect(result).to be_a(Agentic::LlmResponse)
        expect(result.error?).to be true
        expect(result.error).to be_a(Agentic::Errors::LlmAuthenticationError)
      end

      it "handles rate limit errors" do
        allow(mock_openai_client).to receive(:chat).and_raise(rate_limit_error)
        result = client.complete(messages, use_retries: false)
        expect(result).to be_a(Agentic::LlmResponse)
        expect(result.error?).to be true
        expect(result.error).to be_a(Agentic::Errors::LlmRateLimitError)
        expect(result.error.retry_after).to eq(30)
      end

      it "raises errors when fail_on_error is true" do
        allow(mock_openai_client).to receive(:chat).and_raise(auth_error)
        expect { client.complete(messages, fail_on_error: true, use_retries: false) }
          .to raise_error(Agentic::Errors::LlmAuthenticationError)
      end
    end

    context "with retries" do
      let(:timeout_error) { OpenAI::Timeout.new("Request timed out") }

      it "retries transient errors" do
        # First call raises a timeout, second call succeeds
        allow(mock_openai_client).to receive(:chat)
          .and_raise(timeout_error)
          .and_return(response)

        # Customize the retry handler for faster tests
        allow(client.retry_handler).to receive(:calculate_backoff_delay).and_return(0.01)

        result = client.complete(messages)
        expect(result).to be_a(Agentic::LlmResponse)
        expect(result.successful?).to be true
        expect(result.content).to eq("Hi there!")
      end

      it "gives up after max retries" do
        # All calls raise timeout errors
        allow(mock_openai_client).to receive(:chat).and_raise(timeout_error)

        # Customize the retry handler for faster tests
        allow(client.retry_handler).to receive(:calculate_backoff_delay).and_return(0.01)
        allow(client.retry_handler).to receive(:max_retries).and_return(2)

        result = client.complete(messages)
        expect(result).to be_a(Agentic::LlmResponse)
        expect(result.error?).to be true
        expect(result.error).to be_a(Agentic::Errors::LlmTimeoutError)
      end
    end
  end

  describe "#models" do
    let(:models_response) { {"data" => [{"id" => "model1"}, {"id" => "model2"}]} }

    before do
      allow(client).to receive(:client).and_return(mock_openai_client)
      allow(mock_openai_client).to receive_message_chain(:models, :list).and_return(models_response)
    end

    it "returns the list of models" do
      expect(client.models).to eq(models_response["data"])
    end

    it "handles errors gracefully" do
      error = OpenAI::AuthenticationError.new("Invalid API key")
      allow(mock_openai_client).to receive_message_chain(:models, :list).and_raise(error)

      expect(client.models).to be_nil
    end

    it "raises errors when fail_on_error is true" do
      error = OpenAI::AuthenticationError.new("Invalid API key")
      allow(mock_openai_client).to receive_message_chain(:models, :list).and_raise(error)

      expect { client.models(fail_on_error: true) }.to raise_error(Agentic::Errors::LlmAuthenticationError)
    end
  end

  describe "#query_generation_stats" do
    let(:generation_id) { "gen123" }
    let(:stats) { {"id" => generation_id, "usage" => {"total_tokens" => 100}} }

    before do
      allow(client).to receive(:client).and_return(mock_openai_client)
    end

    it "queries generation stats with the given ID" do
      expect(mock_openai_client).to receive(:query_generation_stats).with(generation_id).and_return(stats)
      expect(client.query_generation_stats(generation_id)).to eq(stats)
    end

    it "handles errors gracefully" do
      error = OpenAI::AuthenticationError.new("Invalid API key")
      allow(mock_openai_client).to receive(:query_generation_stats).and_raise(error)

      expect(client.query_generation_stats(generation_id)).to be_nil
    end

    it "raises errors when fail_on_error is true" do
      error = OpenAI::AuthenticationError.new("Invalid API key")
      allow(mock_openai_client).to receive(:query_generation_stats).and_raise(error)

      expect { client.query_generation_stats(generation_id, fail_on_error: true) }
        .to raise_error(Agentic::Errors::LlmAuthenticationError)
    end
  end

  describe "live API request", :vcr do
    let(:llm_config) { Agentic::LlmConfig.new(model: "gpt-4o-mini") }
    let(:client) { described_class.new(llm_config) }
    let(:messages) { [{role: "user", content: "What is the capital of France?"}] }

    it "successfully makes a request to the OpenAI GPT-4o-mini model" do
      VCR.use_cassette("gpt4o_mini_completion") do
        response = client.complete(messages)

        expect(response).to be_a(Agentic::LlmResponse)
        expect(response.content).to include("Paris")
        expect(response.successful?).to be true
      end
    end
  end
end
