# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::LlmConfig do
  let(:default_config) { described_class.new }
  let(:custom_config) do
    described_class.new(
      model: "gpt-4",
      max_tokens: 500,
      temperature: 0.8,
      top_p: 0.9,
      frequency_penalty: 0.1,
      presence_penalty: 0.2,
      additional_options: { stop: ["END"] }
    )
  end
  
  describe "#initialize" do
    it "sets default values" do
      expect(default_config.model).to eq("gpt-4o-2024-08-06")
      expect(default_config.max_tokens).to be_nil
      expect(default_config.temperature).to eq(0.7)
      expect(default_config.top_p).to eq(1.0)
      expect(default_config.frequency_penalty).to eq(0.0)
      expect(default_config.presence_penalty).to eq(0.0)
      expect(default_config.additional_options).to eq({})
    end
    
    it "allows custom values" do
      expect(custom_config.model).to eq("gpt-4")
      expect(custom_config.max_tokens).to eq(500)
      expect(custom_config.temperature).to eq(0.8)
      expect(custom_config.top_p).to eq(0.9)
      expect(custom_config.frequency_penalty).to eq(0.1)
      expect(custom_config.presence_penalty).to eq(0.2)
      expect(custom_config.additional_options).to eq({ stop: ["END"] })
    end
  end
  
  describe "attr_accessors" do
    it "allows reading and writing all attributes" do
      config = described_class.new
      
      config.model = "new-model"
      expect(config.model).to eq("new-model")
      
      config.max_tokens = 100
      expect(config.max_tokens).to eq(100)
      
      config.temperature = 0.5
      expect(config.temperature).to eq(0.5)
      
      config.top_p = 0.8
      expect(config.top_p).to eq(0.8)
      
      config.frequency_penalty = 0.3
      expect(config.frequency_penalty).to eq(0.3)
      
      config.presence_penalty = 0.4
      expect(config.presence_penalty).to eq(0.4)
      
      config.additional_options = { logit_bias: { 123 => -100 } }
      expect(config.additional_options).to eq({ logit_bias: { 123 => -100 } })
    end
  end
  
  describe "#to_api_parameters" do
    it "returns a hash with all parameters for API calls" do
      base_params = { messages: [{ role: "user", content: "Hello" }] }
      params = custom_config.to_api_parameters(base_params)
      
      expect(params).to include(
        messages: [{ role: "user", content: "Hello" }],
        model: "gpt-4",
        max_tokens: 500,
        temperature: 0.8,
        top_p: 0.9,
        frequency_penalty: 0.1,
        presence_penalty: 0.2,
        stop: ["END"]
      )
    end
    
    it "omits max_tokens if not specified" do
      params = default_config.to_api_parameters({})
      expect(params).not_to include(:max_tokens)
    end
    
    it "merges with base parameters" do
      base_params = { stream: true }
      params = default_config.to_api_parameters(base_params)
      expect(params[:stream]).to be true
      expect(params[:model]).to eq("gpt-4o-2024-08-06")
    end
    
    it "allows additional options to override default parameters" do
      config = described_class.new(
        model: "gpt-4",
        additional_options: { model: "custom-model" }
      )
      
      params = config.to_api_parameters({})
      expect(params[:model]).to eq("custom-model")
    end
  end
end
