# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::Errors::LlmRefusalError do
  describe "#initialize" do
    it "sets the refusal message and response" do
      error = described_class.new(
        "I cannot provide that information",
        response: {"id" => "test-response"}
      )

      expect(error.message).to eq("LLM refused to respond: I cannot provide that information")
      expect(error.refusal_message).to eq("I cannot provide that information")
      expect(error.response).to eq({"id" => "test-response"})
    end

    it "detects refusal category from message" do
      harmful_error = described_class.new("This content is harmful")
      expect(harmful_error.refusal_category).to eq(:harmful_content)

      clarify_error = described_class.new("This request needs clarification")
      expect(clarify_error.refusal_category).to eq(:needs_clarification)

      format_error = described_class.new("The format of your request is incorrect")
      expect(format_error.refusal_category).to eq(:format_error)

      unclear_error = described_class.new("Your instructions are unclear")
      expect(unclear_error.refusal_category).to eq(:unclear_instructions)

      capability_error = described_class.new("I don't have the capability to do that")
      expect(capability_error.refusal_category).to eq(:capability_limitation)

      general_error = described_class.new("I cannot do that")
      expect(general_error.refusal_category).to eq(:general_refusal)
    end

    it "allows explicit refusal category specification" do
      error = described_class.new(
        "I cannot do that",
        refusal_category: :custom_category
      )

      expect(error.refusal_category).to eq(:custom_category)
    end
  end

  describe "#retryable_with_modifications?" do
    it "returns true for retryable refusal categories" do
      unclear_error = described_class.new("Your instructions are unclear")
      expect(unclear_error.retryable_with_modifications?).to be true

      clarify_error = described_class.new("This request needs clarification")
      expect(clarify_error.retryable_with_modifications?).to be true

      format_error = described_class.new("The format of your request is incorrect")
      expect(format_error.retryable_with_modifications?).to be true
    end

    it "returns false for non-retryable refusal categories" do
      harmful_error = described_class.new("This content is harmful")
      expect(harmful_error.retryable_with_modifications?).to be false

      capability_error = described_class.new("I don't have the capability to do that")
      expect(capability_error.retryable_with_modifications?).to be false

      general_error = described_class.new("I cannot do that")
      expect(general_error.retryable_with_modifications?).to be false
    end
  end
end
