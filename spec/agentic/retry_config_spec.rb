# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::RetryConfig do
  let(:default_config) { described_class.new }
  let(:custom_config) do
    described_class.new(
      max_retries: 5,
      retryable_errors: [Agentic::Errors::LlmTimeoutError],
      backoff_strategy: :linear,
      backoff_options: { base_delay: 2.0, jitter_factor: 0.3 },
      before_retry: lambda { |attempt:, **_| puts "Retrying (#{attempt})" },
      after_retry: lambda { |attempt:, **_| puts "Retried (#{attempt})" }
    )
  end
  
  describe "#initialize" do
    it "sets default values" do
      expect(default_config.max_retries).to eq(3)
      expect(default_config.retryable_errors).to include(Agentic::Errors::LlmTimeoutError)
      expect(default_config.retryable_errors).to include(Agentic::Errors::LlmRateLimitError)
      expect(default_config.retryable_errors).to include(Agentic::Errors::LlmServerError)
      expect(default_config.retryable_errors).to include(Agentic::Errors::LlmNetworkError)
      expect(default_config.backoff_strategy).to eq(:exponential)
      expect(default_config.backoff_options[:base_delay]).to eq(1.0)
      expect(default_config.backoff_options[:jitter_factor]).to eq(0.25)
      expect(default_config.before_retry).to be_nil
      expect(default_config.after_retry).to be_nil
    end
    
    it "allows custom values" do
      expect(custom_config.max_retries).to eq(5)
      expect(custom_config.retryable_errors).to eq([Agentic::Errors::LlmTimeoutError])
      expect(custom_config.backoff_strategy).to eq(:linear)
      expect(custom_config.backoff_options[:base_delay]).to eq(2.0)
      expect(custom_config.backoff_options[:jitter_factor]).to eq(0.3)
      expect(custom_config.before_retry).to be_a(Proc)
      expect(custom_config.after_retry).to be_a(Proc)
    end
    
    it "merges backoff options with defaults" do
      config = described_class.new(backoff_options: { base_delay: 2.0 })
      expect(config.backoff_options[:base_delay]).to eq(2.0)
      expect(config.backoff_options[:jitter_factor]).to eq(0.25)
    end
  end
  
  describe "#to_handler" do
    it "creates a RetryHandler with the configuration" do
      handler = custom_config.to_handler
      expect(handler).to be_a(Agentic::RetryHandler)
      expect(handler.max_retries).to eq(5)
      expect(handler.retryable_errors).to eq([Agentic::Errors::LlmTimeoutError])
      expect(handler.backoff_strategy).to eq(:linear)
      expect(handler.instance_variable_get(:@backoff_options)[:base_delay]).to eq(2.0)
      expect(handler.instance_variable_get(:@backoff_options)[:jitter_factor]).to eq(0.3)
      expect(handler.instance_variable_get(:@before_retry)).to be_a(Proc)
      expect(handler.instance_variable_get(:@after_retry)).to be_a(Proc)
    end
  end
end