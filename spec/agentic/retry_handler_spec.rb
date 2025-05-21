# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::RetryHandler do
  describe "#initialize" do
    it "sets default values" do
      handler = described_class.new
      expect(handler.max_retries).to eq(3)
      expect(handler.backoff_strategy).to eq(:exponential)
      expect(handler.retryable_errors).to include(Agentic::Errors::LlmTimeoutError)
    end

    it "accepts custom values" do
      handler = described_class.new(
        max_retries: 5,
        backoff_strategy: :linear,
        retryable_errors: [RuntimeError]
      )
      expect(handler.max_retries).to eq(5)
      expect(handler.backoff_strategy).to eq(:linear)
      expect(handler.retryable_errors).to eq([RuntimeError])
    end
  end

  describe "#with_retry" do
    let(:handler) { described_class.new(backoff_options: {base_delay: 0.001}) }

    it "executes the block successfully" do
      result = handler.with_retry { 42 }
      expect(result).to eq(42)
    end

    it "retries when a retryable error occurs" do
      attempt = 0

      result = handler.with_retry do
        attempt += 1
        if attempt == 1
          raise Agentic::Errors::LlmTimeoutError.new("Timeout")
        else
          "success"
        end
      end

      expect(result).to eq("success")
      expect(attempt).to eq(2)
    end

    it "gives up after max retries" do
      handler = described_class.new(max_retries: 2, backoff_options: {base_delay: 0.001})
      attempt = 0

      expect do
        handler.with_retry do
          attempt += 1
          raise Agentic::Errors::LlmTimeoutError.new("Timeout")
        end
      end.to raise_error(Agentic::Errors::LlmTimeoutError)

      expect(attempt).to eq(3) # Initial + 2 retries
    end
  end

  describe "backoff strategies" do
    let(:error) { Agentic::Errors::LlmTimeoutError.new("Timeout") }

    it "calculates constant backoff" do
      handler = described_class.new(
        backoff_strategy: :constant,
        backoff_options: {base_delay: 1.0, jitter_factor: 0}
      )

      delay = handler.send(:calculate_backoff_delay, 1)
      expect(delay).to eq(1.0)

      delay = handler.send(:calculate_backoff_delay, 3)
      expect(delay).to eq(1.0)
    end

    it "calculates linear backoff" do
      handler = described_class.new(
        backoff_strategy: :linear,
        backoff_options: {base_delay: 1.0, jitter_factor: 0}
      )

      delay = handler.send(:calculate_backoff_delay, 1)
      expect(delay).to eq(1.0)

      delay = handler.send(:calculate_backoff_delay, 3)
      expect(delay).to eq(3.0)
    end

    it "calculates exponential backoff" do
      handler = described_class.new(
        backoff_strategy: :exponential,
        backoff_options: {base_delay: 1.0, jitter_factor: 0}
      )

      delay = handler.send(:calculate_backoff_delay, 1)
      expect(delay).to eq(1.0)

      delay = handler.send(:calculate_backoff_delay, 3)
      expect(delay).to eq(4.0) # 1.0 * 2^(3-1)
    end

    it "applies jitter" do
      handler = described_class.new(
        backoff_strategy: :constant,
        backoff_options: {base_delay: 1.0, jitter_factor: 0.5}
      )

      # Run multiple times to ensure jitter is working
      delays = 10.times.map { handler.send(:calculate_backoff_delay, 1) }

      # All delays should be between 0.5 and 1.5
      expect(delays.min).to be >= 0.5
      expect(delays.max).to be <= 1.5

      # There should be some variation
      expect(delays.uniq.size).to be > 1
    end
  end
end