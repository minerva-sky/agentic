# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::Tools do
  describe ".resolve" do
    it "returns nothing for an unset or blank list" do
      expect(described_class.resolve(nil)).to eq([])
      expect(described_class.resolve(" , ")).to eq([])
    end

    it "maps registry names to tool classes" do
      expect(described_class.resolve(" approval_demo ")).to eq([Agentic::Tools::ApprovalDemo])
    end

    it "refuses an unknown name and lists the known ones" do
      expect { described_class.resolve("approval_demo,shell") }
        .to raise_error(Agentic::Errors::ConfigurationError, /"shell".*approval_demo/)
    end
  end

  describe Agentic::Tools::ApprovalDemo do
    it "needs approval and runs once approved" do
      expect(described_class.new.requires_approval?).to be(true)
      expect(described_class.new.execute(note: "hi")).to eq("approved and wrote: hi")
    end
  end

  describe "configuration" do
    around do |ex|
      old = ENV["AGENTIC_TOOLS"]
      ex.run
    ensure
      ENV["AGENTIC_TOOLS"] = old
    end

    it "reads AGENTIC_TOOLS and hands the tools to the adapter" do
      ENV["AGENTIC_TOOLS"] = "approval_demo"
      config = Agentic::LegacyConfiguration.new
      config.access_token = "test"
      expect(config.tools).to eq([Agentic::Tools::ApprovalDemo])

      adapter = Agentic::RubyLlmAdapter.from_configuration(config)
      expect(adapter.instance_variable_get(:@tools)).to eq([Agentic::Tools::ApprovalDemo])
    end

    it "defaults to no tools" do
      ENV.delete("AGENTIC_TOOLS")
      expect(Agentic::LegacyConfiguration.new.tools).to eq([])
    end
  end
end
