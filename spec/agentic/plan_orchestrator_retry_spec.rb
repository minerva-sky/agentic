# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::PlanOrchestrator, "retry behavior" do
  let(:task) do
    Agentic::Task.new(
      description: "Retryable task",
      agent_spec: {"instructions" => "You are a test agent"},
      input: {"retryable" => true}
    )
  end

  let(:agent) { double("Agent", id: "test-agent") }
  let(:agent_provider) do
    provider = double("AgentProvider")
    allow(provider).to receive(:get_agent_for_task).and_return(agent)
    provider
  end

  # Helper to create a TaskFailure
  def create_failure(type)
    Agentic::TaskFailure.new(
      message: "Test #{type} error",
      type: type,
      context: {agent_id: "test-agent"}
    )
  end

  describe "retry policy configuration" do
    it "uses default retry policy when none is provided" do
      orchestrator = described_class.new

      # We don't have direct access to the retry policy, so we'll use our knowledge
      # of the defaults to verify behavior
      expect(orchestrator.retry?(task: task, failure: create_failure("TimeoutError"))).to be true
      expect(orchestrator.retry?(task: task, failure: create_failure("OtherError"))).to be false
    end

    it "allows customizing retryable error types" do
      orchestrator = described_class.new(retry_policy: {
        retryable_errors: ["CustomError", "NetworkError"]
      })

      expect(orchestrator.retry?(task: task, failure: create_failure("CustomError"))).to be true
      expect(orchestrator.retry?(task: task, failure: create_failure("NetworkError"))).to be true
      expect(orchestrator.retry?(task: task, failure: create_failure("TimeoutError"))).to be false
    end

    it "respects max_retries configuration" do
      orchestrator = described_class.new(retry_policy: {max_retries: 2})
      failure = create_failure("TimeoutError")

      # First retry attempt (retry_count = 0)
      expect(orchestrator.retry?(task: task, failure: failure)).to be true

      # Second retry attempt (retry_count = 1)
      task.retry_count = 1
      expect(orchestrator.retry?(task: task, failure: failure)).to be true

      # Third retry attempt (retry_count = 2) - should not retry
      task.retry_count = 2
      expect(orchestrator.retry?(task: task, failure: failure)).to be false
    end
  end

  describe "backoff strategies" do
    it "applies constant backoff strategy" do
      orchestrator = described_class.new(retry_policy: {
        backoff_strategy: :constant,
        backoff_constant: 2
      })
      allow(orchestrator).to receive(:sleep)

      task.retry_count = 1
      orchestrator.apply_retry_backoff(task: task)

      expect(orchestrator).to have_received(:sleep).with(a_value_within(1).of(2))
    end

    it "applies linear backoff strategy" do
      orchestrator = described_class.new(retry_policy: {
        backoff_strategy: :linear,
        backoff_base: 1
      })
      allow(orchestrator).to receive(:sleep)

      task.retry_count = 3
      orchestrator.apply_retry_backoff(task: task)

      expect(orchestrator).to have_received(:sleep).with(a_value_within(1).of(3))
    end

    it "applies exponential backoff strategy" do
      orchestrator = described_class.new(retry_policy: {
        backoff_strategy: :exponential,
        backoff_base: 1
      })
      allow(orchestrator).to receive(:sleep)

      task.retry_count = 3
      orchestrator.apply_retry_backoff(task: task)

      # Should be approximately 1 * 2^(3-1) = 4
      expect(orchestrator).to have_received(:sleep).with(a_value_within(1).of(4))
    end

    it "does not apply backoff when strategy is :none" do
      orchestrator = described_class.new(retry_policy: {
        backoff_strategy: :none
      })
      allow(orchestrator).to receive(:sleep)

      task.retry_count = 1
      orchestrator.apply_retry_backoff(task: task)

      expect(orchestrator).not_to have_received(:sleep)
    end
  end

  describe "human intervention" do
    it "identifies errors requiring human intervention" do
      orchestrator = described_class.new

      expect(orchestrator.requires_intervention?(failure: create_failure("AuthenticationError"))).to be true
      expect(orchestrator.requires_intervention?(failure: create_failure("PermissionDeniedError"))).to be true
      expect(orchestrator.requires_intervention?(failure: create_failure("ConfigurationError"))).to be true
      expect(orchestrator.requires_intervention?(failure: create_failure("OtherError"))).to be false
    end
  end
end
