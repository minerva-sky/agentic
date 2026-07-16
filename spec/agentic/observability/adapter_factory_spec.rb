# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::Observability::AdapterFactory do
  describe ".create" do
    it "creates console adapter with configuration" do
      adapter = described_class.create(:console, color: true, verbose: true)

      expect(adapter).to be_a(Agentic::Observability::ConsoleAdapter)
      expect(adapter.config[:color]).to be true
      expect(adapter.config[:verbose]).to be true
      expect(adapter.enabled?).to be true
    end

    it "creates file adapter with custom configuration" do
      log_path = "/tmp/test_events.jsonl"
      adapter = described_class.create(:file, log_path: log_path)

      expect(adapter).to be_a(Agentic::Observability::FileAdapter)
      expect(adapter.config[:log_path]).to eq(log_path)
      expect(adapter.enabled?).to be true
    end

    it "raises error for unknown adapter type" do
      expect {
        described_class.create(:unknown_type)
      }.to raise_error(ArgumentError, /Unknown adapter type: unknown_type/)
    end

    it "uses default configuration when none provided" do
      adapter = described_class.create(:file)

      expect(adapter.config[:log_path]).to include(".agentic/observability/events.jsonl")
      expect(adapter.config[:max_file_size]).to eq(10 * 1024 * 1024)
      expect(adapter.config[:max_files]).to eq(5)
    end
  end

  describe ".available_types" do
    it "returns available adapter types" do
      types = described_class.available_types

      expect(types).to include(:console, :file)
      expect(types).to be_an(Array)
    end
  end

  describe ".create_from_config" do
    it "creates multiple adapters from configuration hash" do
      config = {
        console: {enabled: true, color: false},
        file: {enabled: true, log_path: "/tmp/test.jsonl"}
      }

      adapters = described_class.create_from_config(config)

      expect(adapters.size).to eq(2)
      expect(adapters.map(&:class)).to include(
        Agentic::Observability::ConsoleAdapter,
        Agentic::Observability::FileAdapter
      )
    end

    it "creates adapters for all configured types, honoring the enabled flag" do
      config = {
        console: {enabled: true},
        file: {enabled: false}
      }

      adapters = described_class.create_from_config(config)

      # Disabled adapters are still instantiated so they can be discovered and
      # reported; the enabled flag governs whether they process events.
      expect(adapters.size).to eq(2)

      console_adapter = adapters.find { |a| a.is_a?(Agentic::Observability::ConsoleAdapter) }
      file_adapter = adapters.find { |a| a.is_a?(Agentic::Observability::FileAdapter) }

      expect(console_adapter.enabled?).to be true
      expect(file_adapter.enabled?).to be false
    end

    it "handles empty configuration gracefully" do
      adapters = described_class.create_from_config({})
      expect(adapters).to be_empty
    end
  end

  describe ".default_cli_config" do
    it "generates appropriate CLI configuration" do
      options = {quiet: false, verbose: true, color: true}
      config = described_class.default_cli_config(options)

      expect(config[:console][:enabled]).to be true
      expect(config[:console][:color]).to be true
      expect(config[:console][:verbose]).to be true
      expect(config[:file][:enabled]).to be true
    end

    it "disables console for quiet mode" do
      options = {quiet: true}
      config = described_class.default_cli_config(options)

      expect(config[:console][:enabled]).to be false
    end
  end

  describe ".validate_config" do
    it "validates valid configuration" do
      config = {
        console: {color: true, verbose: false},
        file: {log_path: "/tmp/test.jsonl", max_file_size: 1000}
      }

      errors = described_class.validate_config(config)
      expect(errors).to be_empty
    end

    it "identifies invalid configuration" do
      config = {
        console: {output_stream: "not_a_stream"},
        file: {max_file_size: -1}
      }

      errors = described_class.validate_config(config)
      expect(errors).not_to be_empty
      expect(errors.join).to include("output_stream must respond to :puts")
      expect(errors.join).to include("max_file_size must be a positive integer")
    end
  end
end
