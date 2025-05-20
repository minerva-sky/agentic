# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::LlmResponse do
  let(:raw_json_response) do
    {
      "id" => "response-123",
      "choices" => [
        {
          "message" => {
            "content" => '{"key": "value"}'
          }
        }
      ],
      "usage" => {
        "prompt_tokens" => 10,
        "completion_tokens" => 5,
        "total_tokens" => 15
      }
    }
  end
  
  let(:raw_text_response) do
    {
      "id" => "response-456",
      "choices" => [
        {
          "message" => {
            "content" => "Plain text response"
          }
        }
      ],
      "usage" => {
        "prompt_tokens" => 8,
        "completion_tokens" => 3,
        "total_tokens" => 11
      }
    }
  end
  
  let(:raw_refusal_response) do
    {
      "id" => "response-789",
      "choices" => [
        {
          "message" => {
            "content" => nil,
            "refusal" => "I'm sorry, I can't help with that."
          }
        }
      ]
    }
  end
  
  let(:llm_error) do
    Agentic::Errors::LlmNetworkError.new("Network error", network_exception: StandardError.new("Connection failed"))
  end
  
  let(:refusal_error) do
    Agentic::Errors::LlmRefusalError.new(
      "I'm sorry, I can't help with that.",
      refusal_category: :harmful_content
    )
  end
  
  describe "#initialize" do
    it "parses JSON content" do
      response = described_class.new(raw_json_response)
      expect(response.content).to eq({"key" => "value"})
      expect(response.refusal).to be_nil
      expect(response.raw_response).to eq(raw_json_response)
      expect(response.error).to be_nil
      expect(response.stats).to be_a(Agentic::GenerationStats)
      expect(response.stats.prompt_tokens).to eq(10)
      expect(response.stats.completion_tokens).to eq(5)
      expect(response.stats.total_tokens).to eq(15)
    end
    
    it "handles text content" do
      response = described_class.new(raw_text_response)
      expect(response.content).to eq("Plain text response")
      expect(response.refusal).to be_nil
      expect(response.error).to be_nil
      expect(response.stats.prompt_tokens).to eq(8)
    end
    
    it "handles refusals" do
      response = described_class.new(raw_refusal_response)
      expect(response.content).to be_nil
      expect(response.refusal).to eq("I'm sorry, I can't help with that.")
      expect(response.error).to be_nil
      expect(response.refusal_error).to be_nil
    end
    
    it "handles errors" do
      response = described_class.new(nil, error: llm_error)
      expect(response.content).to be_nil
      expect(response.refusal).to be_nil
      expect(response.error).to eq(llm_error)
    end
    
    it "handles refusal errors" do
      response = described_class.new(raw_refusal_response, refusal_error: refusal_error)
      expect(response.refusal).to eq("I'm sorry, I can't help with that.")
      expect(response.refusal_error).to eq(refusal_error)
      expect(response.refusal_category).to eq(:harmful_content)
    end
  end
  
  describe ".success" do
    it "creates a successful response" do
      response = described_class.success(raw_json_response, {"key" => "value"})
      expect(response.content).to eq({"key" => "value"})
      expect(response.successful?).to be true
      expect(response.refused?).to be false
      expect(response.error?).to be false
    end
  end
  
  describe ".refusal" do
    it "creates a refusal response" do
      response = described_class.refusal(raw_refusal_response, "I'm sorry, I can't help with that.")
      expect(response.refusal).to eq("I'm sorry, I can't help with that.")
      expect(response.successful?).to be false
      expect(response.refused?).to be true
      expect(response.error?).to be false
    end
    
    it "accepts a refusal error" do
      response = described_class.refusal(
        raw_refusal_response, 
        "I'm sorry, I can't help with that.",
        refusal_error
      )
      expect(response.refusal).to eq("I'm sorry, I can't help with that.")
      expect(response.refusal_error).to eq(refusal_error)
      expect(response.refusal_category).to eq(:harmful_content)
      expect(response.retryable_refusal?).to be false
    end
  end
  
  describe ".error" do
    it "creates an error response" do
      response = described_class.error(llm_error, raw_json_response)
      expect(response.error).to eq(llm_error)
      expect(response.successful?).to be false
      expect(response.refused?).to be false
      expect(response.error?).to be true
    end
  end
  
  describe "#successful?" do
    it "returns true for successful responses" do
      response = described_class.new(raw_json_response)
      expect(response.successful?).to be true
    end
    
    it "returns false for refusals" do
      response = described_class.new(raw_refusal_response)
      expect(response.successful?).to be false
    end
    
    it "returns false for errors" do
      response = described_class.new(nil, error: llm_error)
      expect(response.successful?).to be false
    end
  end
  
  describe "#refused?" do
    it "returns true for refusals" do
      response = described_class.new(raw_refusal_response)
      expect(response.refused?).to be true
    end
    
    it "returns true for refusal errors" do
      response = described_class.new(nil, refusal_error: refusal_error)
      expect(response.refused?).to be true
    end
    
    it "returns false for successful responses" do
      response = described_class.new(raw_json_response)
      expect(response.refused?).to be false
    end
    
    it "returns false for errors" do
      response = described_class.new(nil, error: llm_error)
      expect(response.refused?).to be false
    end
  end
  
  describe "#refusal_category" do
    it "returns nil for non-refusals" do
      response = described_class.new(raw_json_response)
      expect(response.refusal_category).to be_nil
    end
    
    it "returns the category from the refusal error" do
      response = described_class.new(raw_refusal_response, refusal_error: refusal_error)
      expect(response.refusal_category).to eq(:harmful_content)
    end
  end
  
  describe "#retryable_refusal?" do
    it "returns false for non-refusals" do
      response = described_class.new(raw_json_response)
      expect(response.retryable_refusal?).to be false
    end
    
    it "returns false for harmful content refusals" do
      response = described_class.new(
        raw_refusal_response, 
        refusal_error: refusal_error
      )
      expect(response.retryable_refusal?).to be false
    end
    
    it "returns true for clarification refusals" do
      clarification_error = Agentic::Errors::LlmRefusalError.new(
        "I need more clarification",
        refusal_category: :needs_clarification
      )
      response = described_class.new(
        raw_refusal_response, 
        refusal_error: clarification_error
      )
      expect(response.retryable_refusal?).to be true
    end
  end
  
  describe "#error?" do
    it "returns true for errors" do
      response = described_class.new(nil, error: llm_error)
      expect(response.error?).to be true
    end
    
    it "returns false for successful responses" do
      response = described_class.new(raw_json_response)
      expect(response.error?).to be false
    end
    
    it "returns false for refusals" do
      response = described_class.new(raw_refusal_response)
      expect(response.error?).to be false
    end
  end
  
  describe "#raise_if_error!" do
    it "raises the error if one occurred" do
      response = described_class.new(nil, error: llm_error)
      expect { response.raise_if_error! }.to raise_error(Agentic::Errors::LlmNetworkError)
    end
    
    it "does nothing if no error occurred" do
      response = described_class.new(raw_json_response)
      expect { response.raise_if_error! }.not_to raise_error
    end
  end
  
  describe "#to_h" do
    it "returns content for successful responses" do
      response = described_class.new(raw_json_response)
      hash = response.to_h
      expect(hash[:content]).to eq({"key" => "value"})
      expect(hash[:refusal]).to be_nil
      expect(hash[:error]).to be_nil
      expect(hash[:refusal_category]).to be_nil
      expect(hash[:stats]).to be_a(Hash)
      expect(hash[:stats][:prompt_tokens]).to eq(10)
    end
    
    it "returns refusal for refusals" do
      response = described_class.new(raw_refusal_response)
      hash = response.to_h
      expect(hash[:refusal]).to eq("I'm sorry, I can't help with that.")
      expect(hash[:content]).to be_nil
      expect(hash[:error]).to be_nil
    end
    
    it "returns refusal category for categorized refusals" do
      response = described_class.new(raw_refusal_response, refusal_error: refusal_error)
      hash = response.to_h
      expect(hash[:refusal]).to eq("I'm sorry, I can't help with that.")
      expect(hash[:refusal_category]).to eq(:harmful_content)
      expect(hash[:retryable]).to be false
      expect(hash[:content]).to be_nil
      expect(hash[:error]).to be_nil
    end
    
    it "returns error information for errors" do
      response = described_class.new(nil, error: llm_error)
      hash = response.to_h
      expect(hash[:error][:message]).to eq("Network error")
      expect(hash[:error][:type]).to eq("Agentic::Errors::LlmNetworkError")
      expect(hash[:content]).to be_nil
      expect(hash[:refusal]).to be_nil
      expect(hash[:refusal_category]).to be_nil
    end
  end
end