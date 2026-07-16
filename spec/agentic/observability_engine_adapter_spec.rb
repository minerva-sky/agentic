# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::ObservabilityEngine, "adapter functionality" do
  let(:engine) { described_class.new }
  let(:mock_adapter) { double("MockAdapter") }

  before do
    allow(mock_adapter).to receive(:enabled?).and_return(true)
    allow(mock_adapter).to receive(:adapter_type).and_return("mock")
    allow(mock_adapter).to receive(:handle_event)
    allow(mock_adapter).to receive(:shutdown)
    allow(mock_adapter).to receive(:status).and_return({
      enabled: true,
      type: "mock",
      statistics: {events_processed: 0}
    })
  end

  after do
    engine.shutdown
  end

  describe "#add_adapter" do
    it "adds an adapter to the engine" do
      expect {
        engine.add_adapter(mock_adapter)
      }.to change { engine.all_adapters.size }.by(1)
    end

    it "does not add duplicate adapters" do
      engine.add_adapter(mock_adapter)

      expect {
        engine.add_adapter(mock_adapter)
      }.not_to change { engine.all_adapters.size }
    end

    it "makes engine active when adapters are added" do
      expect(engine.active?).to be false

      engine.add_adapter(mock_adapter)

      expect(engine.active?).to be true
    end
  end

  describe "#remove_adapter" do
    before do
      engine.add_adapter(mock_adapter)
    end

    it "removes an adapter from the engine" do
      expect {
        engine.remove_adapter(mock_adapter)
      }.to change { engine.all_adapters.size }.by(-1)
    end

    it "handles removing non-existent adapter gracefully" do
      other_adapter = double("OtherAdapter")
      allow(other_adapter).to receive(:adapter_type).and_return("other")

      expect {
        engine.remove_adapter(other_adapter)
      }.not_to change { engine.all_adapters.size }
    end
  end

  describe "#clear_adapters" do
    before do
      engine.add_adapter(mock_adapter)
    end

    it "removes all adapters and calls shutdown on each" do
      expect(mock_adapter).to receive(:shutdown)

      engine.clear_adapters

      expect(engine.all_adapters).to be_empty
    end
  end

  describe "#find_adapters" do
    let(:console_adapter) do
      adapter = double("ConsoleAdapter")
      allow(adapter).to receive(:adapter_type).and_return("console")
      allow(adapter).to receive(:enabled?).and_return(true)
      allow(adapter).to receive(:shutdown)
      adapter
    end

    let(:file_adapter) do
      adapter = double("FileAdapter")
      allow(adapter).to receive(:adapter_type).and_return("file")
      allow(adapter).to receive(:enabled?).and_return(true)
      allow(adapter).to receive(:shutdown)
      adapter
    end

    before do
      engine.add_adapter(console_adapter)
      engine.add_adapter(file_adapter)
    end

    it "finds adapters by type" do
      console_adapters = engine.find_adapters(:console)
      file_adapters = engine.find_adapters("file")

      expect(console_adapters).to contain_exactly(console_adapter)
      expect(file_adapters).to contain_exactly(file_adapter)
    end

    it "returns empty array for unknown type" do
      unknown_adapters = engine.find_adapters(:unknown)

      expect(unknown_adapters).to be_empty
    end
  end

  describe "#configure_adapters" do
    it "clears existing adapters and creates new ones from config" do
      # Add an initial adapter
      engine.add_adapter(mock_adapter)
      expect(engine.all_adapters.size).to eq(1)

      # Configure with new adapters
      config = {
        console: {enabled: true, color: false},
        file: {enabled: true, log_path: "/tmp/test.jsonl"}
      }

      engine.configure_adapters(config)

      # Should have replaced the mock adapter with real ones
      expect(engine.all_adapters.size).to eq(2)
      expect(engine.find_adapters(:console)).not_to be_empty
      expect(engine.find_adapters(:file)).not_to be_empty
    end

    it "handles empty configuration" do
      engine.add_adapter(mock_adapter)

      engine.configure_adapters({})

      expect(engine.all_adapters).to be_empty
    end
  end

  describe "#enable_default_cli_adapters" do
    it "creates console and file adapters with CLI configuration" do
      cli_options = {
        quiet: false,
        verbose: true,
        color: false,
        enable_file_logging: true
      }

      engine.enable_default_cli_adapters(cli_options)

      expect(engine.find_adapters(:console).size).to eq(1)
      expect(engine.find_adapters(:file).size).to eq(1)

      console_adapter = engine.find_adapters(:console).first
      expect(console_adapter.enabled?).to be true
      expect(console_adapter.config[:verbose]).to be true
      expect(console_adapter.config[:color]).to be false
    end

    it "disables console adapter in quiet mode" do
      cli_options = {quiet: true}

      engine.enable_default_cli_adapters(cli_options)

      console_adapter = engine.find_adapters(:console).first
      expect(console_adapter.enabled?).to be false
    end
  end

  describe "#notify with adapters" do
    let(:adapter1) { double("Adapter1") }
    let(:adapter2) { double("Adapter2") }

    before do
      allow(adapter1).to receive(:enabled?).and_return(true)
      allow(adapter1).to receive(:adapter_type).and_return("adapter1")
      allow(adapter1).to receive(:handle_event)
      allow(adapter1).to receive(:shutdown)
      allow(adapter1).to receive(:status).and_return({enabled: true, type: "adapter1", statistics: {}})

      allow(adapter2).to receive(:enabled?).and_return(true)
      allow(adapter2).to receive(:adapter_type).and_return("adapter2")
      allow(adapter2).to receive(:handle_event)
      allow(adapter2).to receive(:shutdown)
      allow(adapter2).to receive(:status).and_return({enabled: true, type: "adapter2", statistics: {}})

      engine.add_adapter(adapter1)
      engine.add_adapter(adapter2)
    end

    it "notifies all enabled adapters" do
      expect(adapter1).to receive(:handle_event)
      expect(adapter2).to receive(:handle_event)

      engine.notify(:test_event, data: {message: "test"}, source: "spec")
    end

    it "skips disabled adapters" do
      allow(adapter1).to receive(:enabled?).and_return(false)

      expect(adapter1).not_to receive(:handle_event)
      expect(adapter2).to receive(:handle_event)

      engine.notify(:test_event, data: {message: "test"}, source: "spec")
    end

    it "handles adapter errors gracefully" do
      allow(adapter1).to receive(:handle_event).and_raise(StandardError, "Adapter error")

      expect(adapter2).to receive(:handle_event)

      expect {
        engine.notify(:test_event, data: {message: "test"}, source: "spec")
      }.not_to raise_error
    end

    it "updates adapter notification statistics" do
      engine.notify(:test_event, data: {message: "test"}, source: "spec")

      stats = engine.statistics
      expect(stats[:adapter_notifications]).to be > 0
    end
  end

  describe "#recent_events" do
    it "delegates to file adapter when available" do
      file_adapter = double("FileAdapter")
      allow(file_adapter).to receive(:adapter_type).and_return("file")
      allow(file_adapter).to receive(:enabled?).and_return(true)
      allow(file_adapter).to receive(:recent_events).with(limit: 10).and_return([
        {"type" => "test_event", "timestamp" => Time.now.iso8601}
      ])
      allow(file_adapter).to receive(:shutdown)

      engine.add_adapter(file_adapter)

      events = engine.recent_events(limit: 10)

      expect(events.size).to eq(1)
      expect(events.first["type"]).to eq("test_event")
    end

    it "returns empty array when no file adapters" do
      events = engine.recent_events

      expect(events).to be_empty
    end
  end

  describe "#events_since" do
    it "delegates to file adapter when available" do
      since_time = Time.now - 3600
      file_adapter = double("FileAdapter")
      allow(file_adapter).to receive(:adapter_type).and_return("file")
      allow(file_adapter).to receive(:enabled?).and_return(true)
      allow(file_adapter).to receive(:events_since).with(since_time).and_return([
        {"type" => "recent_event", "timestamp" => Time.now.iso8601}
      ])
      allow(file_adapter).to receive(:shutdown)

      engine.add_adapter(file_adapter)

      events = engine.events_since(since_time)

      expect(events.size).to eq(1)
      expect(events.first["type"]).to eq("recent_event")
    end

    it "returns empty array when no file adapters" do
      events = engine.events_since(Time.now - 3600)

      expect(events).to be_empty
    end
  end

  describe "#statistics with adapters" do
    before do
      allow(mock_adapter).to receive(:status).and_return({
        enabled: true,
        type: "mock",
        statistics: {events_processed: 5, errors: 0}
      })

      engine.add_adapter(mock_adapter)
    end

    it "includes adapter statistics" do
      stats = engine.statistics

      expect(stats[:adapters_count]).to eq(1)
      expect(stats[:adapters].size).to eq(1)
      expect(stats[:adapters].first[:type]).to eq("mock")
      expect(stats[:adapters].first[:statistics][:events_processed]).to eq(5)
    end
  end

  describe "#shutdown with adapters" do
    before do
      engine.add_adapter(mock_adapter)
    end

    it "calls shutdown on all adapters" do
      expect(mock_adapter).to receive(:shutdown)

      engine.shutdown
    end

    it "clears all adapters after shutdown" do
      engine.shutdown

      expect(engine.all_adapters).to be_empty
    end
  end
end
