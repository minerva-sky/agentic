# frozen_string_literal: true

require "spec_helper"

RSpec.describe "round 10 framework features" do
  describe "relation-typed rules" do
    let(:spec) do
      Agentic::CapabilitySpecification.new(
        name: "provision", description: "Provision a box", version: "1.0.0",
        inputs: {
          cpu: {type: "number", required: true},
          memory: {type: "number", required: true},
          express: {type: "boolean"},
          customs_code: {type: "string"},
          api_key: {type: "string"},
          oauth_token: {type: "string"}
        },
        rules: {
          fits: {relation: :sum_lte, fields: [:cpu, :memory], limit: 100},
          customs: {relation: :requires, fields: [:express, :customs_code]},
          one_auth: {relation: :mutually_exclusive, fields: [:api_key, :oauth_token]}
        }
      )
    end
    let(:validator) { Agentic::CapabilityValidator.new(spec) }

    it "enforces sum_lte with a derived message" do
      expect {
        validator.validate_inputs!(cpu: 60, memory: 60)
      }.to raise_error(Agentic::Errors::ValidationError) { |error|
        violation = error.rule_violations.find { |v| v[:rule] == :fits }
        expect(violation[:message]).to eq("cpu + memory must total at most 100")
        expect(violation[:fields]).to eq([:cpu, :memory])
      }

      expect { validator.validate_inputs!(cpu: 40, memory: 60) }.not_to raise_error
    end

    it "enforces requires only when the trigger is present" do
      expect {
        validator.validate_inputs!(cpu: 1, memory: 1, express: true)
      }.to raise_error(Agentic::Errors::ValidationError, /express requires customs_code/)

      expect {
        validator.validate_inputs!(cpu: 1, memory: 1, express: true, customs_code: "HS-1")
      }.not_to raise_error
      expect { validator.validate_inputs!(cpu: 1, memory: 1) }.not_to raise_error
    end

    it "enforces mutual exclusion by presence" do
      expect {
        validator.validate_inputs!(cpu: 1, memory: 1, api_key: "k", oauth_token: "t")
      }.to raise_error(Agentic::Errors::ValidationError, /at most one of api_key, oauth_token/)

      expect { validator.validate_inputs!(cpu: 1, memory: 1, api_key: "k") }.not_to raise_error
    end

    it "rejects unknown relations loudly" do
      bad = Agentic::CapabilitySpecification.new(
        name: "x", description: "x", version: "1.0.0",
        inputs: {a: {type: "number", required: true}},
        rules: {odd: {relation: :sum_gte, fields: [:a], limit: 1}}
      )

      # Since round 11 this fails even earlier - at validator construction
      expect {
        Agentic::CapabilityValidator.new(bad)
      }.to raise_error(ArgumentError, /unknown relation :sum_gte/)
    end

    it "projects expressible relations into draft-07 keywords and x-agentic-rules" do
      schema = spec.to_json_schema

      expect(schema["dependencies"]).to eq({"express" => ["customs_code"]})
      expect(schema["allOf"]).to include({"not" => {"required" => %w[api_key oauth_token]}})

      fits = schema["x-agentic-rules"].find { |r| r["rule"] == "fits" }
      expect(fits["relation"]).to eq("sum_lte")
      expect(fits["limit"]).to eq(100)
      expect(fits["message"]).to eq("cpu + memory must total at most 100")
    end
  end

  describe "the retryable nil convention" do
    it "treats only an explicit false as hopeless" do
      hopeless = Agentic::TaskFailure.from_exception(Agentic::Errors::LlmAuthenticationError.new("401"))
      transient = Agentic::TaskFailure.from_exception(Agentic::Errors::LlmRateLimitError.new("429"))
      no_opinion = Agentic::TaskFailure.from_exception(RuntimeError.new("boom"))

      expect(hopeless.hopeless?).to be(true)
      expect(hopeless.possibly_transient?).to be(false)
      expect(transient.hopeless?).to be(false)
      expect(transient.possibly_transient?).to be(true)
      expect(no_opinion.retryable?).to be_nil
      expect(no_opinion.hopeless?).to be(false)
      expect(no_opinion.possibly_transient?).to be(true)
    end
  end
end
