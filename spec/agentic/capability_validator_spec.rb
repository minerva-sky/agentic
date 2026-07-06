# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::CapabilityValidator do
  let(:specification) do
    Agentic::CapabilitySpecification.new(
      name: "report_generation",
      description: "Generates a report",
      version: "1.0.0",
      inputs: {
        topic: {type: "string", required: true},
        depth: {type: "number"},
        options: {type: "object"}
      },
      outputs: {
        report: {type: "string", required: true},
        sections: {type: "array"}
      }
    )
  end

  subject(:validator) { described_class.new(specification) }

  describe "#validate_inputs!" do
    it "accepts inputs matching the declared contract" do
      expect {
        validator.validate_inputs!(topic: "AI trends", depth: 3)
      }.not_to raise_error
    end

    it "accepts string keys" do
      expect {
        validator.validate_inputs!("topic" => "AI trends")
      }.not_to raise_error
    end

    it "permits undeclared keys" do
      expect {
        validator.validate_inputs!(topic: "AI trends", surprise: :fine)
      }.not_to raise_error
    end

    it "collects every violation into one typed error" do
      expect {
        validator.validate_inputs!(depth: "very", options: 42)
      }.to raise_error(Agentic::Errors::ValidationError) { |error|
        expect(error.capability).to eq("report_generation")
        expect(error.kind).to eq(:inputs)
        expect(error.violations.keys).to contain_exactly(:topic, :depth, :options)
        expect(error.message).to include("report_generation")
      }
    end
  end

  describe "#validate_outputs!" do
    it "accepts outputs matching the declared contract" do
      expect {
        validator.validate_outputs!(report: "done", sections: %w[intro body])
      }.not_to raise_error
    end

    it "skips validation for nil outputs" do
      expect { validator.validate_outputs!(nil) }.not_to raise_error
    end

    it "rejects outputs missing required keys" do
      expect {
        validator.validate_outputs!(sections: [])
      }.to raise_error(Agentic::Errors::ValidationError) { |error|
        expect(error.kind).to eq(:outputs)
        expect(error.violations).to have_key(:report)
      }
    end
  end

  context "with no declared contract" do
    let(:specification) do
      Agentic::CapabilitySpecification.new(
        name: "freeform",
        description: "Anything goes",
        version: "1.0.0"
      )
    end

    it "validates nothing" do
      expect { validator.validate_inputs!(whatever: 1) }.not_to raise_error
      expect { validator.validate_outputs!(whatever: 1) }.not_to raise_error
    end
  end
end

RSpec.describe Agentic::CapabilityProvider do
  let(:specification) do
    Agentic::CapabilitySpecification.new(
      name: "echo",
      description: "Echoes its input",
      version: "1.0.0",
      inputs: {message: {type: "string", required: true}},
      outputs: {echo: {type: "string", required: true}}
    )
  end

  it "executes a conforming implementation" do
    provider = described_class.new(
      capability: specification,
      implementation: ->(inputs) { {echo: inputs[:message]} }
    )

    expect(provider.execute(message: "hello")).to eq(echo: "hello")
  end

  it "rejects violating inputs before executing the implementation" do
    called = false
    provider = described_class.new(
      capability: specification,
      implementation: ->(_inputs) {
        called = true
        {echo: "never"}
      }
    )

    expect { provider.execute(message: 42) }.to raise_error(Agentic::Errors::ValidationError)
    expect(called).to be false
  end

  it "rejects implementations that break their own output contract" do
    provider = described_class.new(
      capability: specification,
      implementation: ->(_inputs) { {wrong_key: "oops"} }
    )

    expect { provider.execute(message: "hello") }.to raise_error(Agentic::Errors::ValidationError) { |error|
      expect(error.kind).to eq(:outputs)
    }
  end
end

RSpec.describe "composed capability contracts" do
  let(:registry) { Agentic::AgentCapabilityRegistry.instance }

  before do
    registry.clear

    shout_spec = Agentic::CapabilitySpecification.new(
      name: "shout", description: "Upcases", version: "1.0.0",
      inputs: {text: {type: "string", required: true}},
      outputs: {text: {type: "string", required: true}}
    )
    registry.register(shout_spec, Agentic::CapabilityProvider.new(
      capability: shout_spec, implementation: ->(i) { {text: i[:text].upcase} }
    ))
  end

  it "validates the composition's own declared contract at its boundary" do
    registry.compose(
      "greeting", "Shouted greeting", "1.0.0",
      [{name: "shout", version: "1.0.0"}],
      ->(providers, inputs) { {greeting: providers.first.execute(text: "hi #{inputs[:name]}")[:text]} },
      inputs: {name: {type: "string", required: true}},
      outputs: {greeting: {type: "string", required: true}}
    )

    provider = registry.get_provider("greeting")

    expect(provider.execute(name: "matz")).to eq(greeting: "HI MATZ")
    expect { provider.execute({}) }.to raise_error(Agentic::Errors::ValidationError) { |error|
      expect(error.capability).to eq("greeting")
      expect(error.violations).to have_key(:name)
    }
  end
end
