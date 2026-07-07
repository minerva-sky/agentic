# frozen_string_literal: true

require "spec_helper"

RSpec.describe "round 15 framework features" do
  describe "did-you-mean in ValidationError" do
    let(:contract) do
      Agentic::CapabilitySpecification.new(
        name: "quote", description: "q", version: "1.0.0",
        inputs: {mode: {type: "string", required: true}, weight_kg: {type: "number", required: true}}
      )
    end

    it "diagnoses a renamed key from missing-plus-similar-extra" do
      expect {
        Agentic::CapabilityValidator.new(contract).validate_inputs!(mode: "air", weight_kilo: 50)
      }.to raise_error(Agentic::Errors::ValidationError) { |error|
        expect(error.hints).to eq(["You sent :weight_kilo - did you mean :weight_kg?"])
        expect(error.message).to include("did you mean :weight_kg?")
      }
    end

    it "stays silent when nothing extra is close to anything missing" do
      expect {
        Agentic::CapabilityValidator.new(contract).validate_inputs!(mode: "air", banana: true)
      }.to raise_error(Agentic::Errors::ValidationError) { |error|
        expect(error.hints).to be_empty
      }
    end
  end

  describe "did-you-mean in plan refactoring errors" do
    it "suggests the close description when rewiring to an unknown task" do
      orchestrator = Agentic::PlanOrchestrator.new
      orders = Agentic::Task.new(description: "fetch_orders", agent_spec: {"name" => "w", "instructions" => "w"})
      ledger = Agentic::Task.new(description: "ledger", agent_spec: {"name" => "w", "instructions" => "w"})
      orchestrator.add_task(orders)
      orchestrator.add_task(ledger)

      expect {
        orchestrator.rewire_task(ledger, ["fetch_order"])
      }.to raise_error(ArgumentError, /fetch_order \(did you mean fetch_orders\?\)/)
    end

    it "suggests on remove_task with a typo'd reference" do
      orchestrator = Agentic::PlanOrchestrator.new
      orders = Agentic::Task.new(description: "fetch_orders", agent_spec: {"name" => "w", "instructions" => "w"})
      orchestrator.add_task(orders)

      expect {
        orchestrator.remove_task("fetch_ordrs")
      }.to raise_error(ArgumentError, /did you mean fetch_orders\?/)
    end
  end

  describe "Suggestions" do
    it "refuses to guess wildly (threshold scales with length)" do
      expect(Agentic::Suggestions.suggest("zz", %w[fetch_orders ledger])).to be_nil
      expect(Agentic::Suggestions.hint("zz", %w[fetch_orders])).to eq("")
    end
  end
end
