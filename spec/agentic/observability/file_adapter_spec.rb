# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "json"

RSpec.describe Agentic::Observability::FileAdapter do
  let(:temp_file) { Tempfile.new(["test_events", ".jsonl"]) }
  let(:log_path) { temp_file.path }
  let(:config) { {log_path: log_path, max_file_size: 1024, max_files: 3} }
  let(:adapter) { described_class.new(config) }
  let(:event_data) do
    Agentic::Observability::EventData.new(
      type: :test_event,
      data: {message: "Test message", task_id: "123"},
      source: "test_source"
    )
  end

  after do
    temp_file.close
    temp_file.unlink
    # Clean up any rotated files
    Dir.glob("#{log_path}.*").each { |f|
      begin
        File.delete(f)
      rescue
        nil
      end
    }
  end

  describe "#initialize" do
    it "sets up file adapter with custom configuration" do
      expect(adapter.config[:log_path]).to eq(log_path)
      expect(adapter.config[:max_file_size]).to eq(1024)
      expect(adapter.config[:max_files]).to eq(3)
      expect(adapter.enabled?).to be true
    end

    it "uses default configuration when none provided" do
      default_adapter = described_class.new

      expect(default_adapter.config[:log_path]).to include(".agentic/observability/events.jsonl")
      expect(default_adapter.config[:max_file_size]).to eq(10 * 1024 * 1024)
      expect(default_adapter.config[:max_files]).to eq(5)
    end

    it "creates log directory if it doesn't exist" do
      non_existent_dir = "/tmp/test_agentic_#{Time.now.to_i}"
      test_log_path = File.join(non_existent_dir, "events.jsonl")

      adapter = described_class.new(log_path: test_log_path)
      adapter.handle_event(event_data)

      expect(File.exist?(test_log_path)).to be true

      # Cleanup
      FileUtils.rm_rf(non_existent_dir)
    end
  end

  describe "#handle_event" do
    context "when adapter is enabled" do
      it "writes event to file in JSON Lines format" do
        adapter.handle_event(event_data)

        content = File.read(log_path)
        expect(content).not_to be_empty

        # Parse the JSON line
        json_data = JSON.parse(content.strip)
        expect(json_data["type"]).to eq("test_event")
        expect(json_data["data"]["message"]).to eq("Test message")
        expect(json_data["source"]).to eq("test_source")
        expect(json_data["timestamp"]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
      end

      it "appends multiple events to the same file" do
        event1 = Agentic::Observability::EventData.new(
          type: :event_1, data: {id: 1}, source: "test"
        )
        event2 = Agentic::Observability::EventData.new(
          type: :event_2, data: {id: 2}, source: "test"
        )

        adapter.handle_event(event1)
        adapter.handle_event(event2)

        lines = File.readlines(log_path)
        expect(lines.size).to eq(2)

        json1 = JSON.parse(lines[0])
        json2 = JSON.parse(lines[1])

        expect(json1["type"]).to eq("event_1")
        expect(json2["type"]).to eq("event_2")
      end

      it "updates statistics on successful write" do
        expect {
          adapter.handle_event(event_data)
        }.to change { adapter.statistics[:events_processed] }.by(1)
      end
    end

    context "when adapter is disabled" do
      before { adapter.disable! }

      it "does not write to file" do
        original_size = File.size(log_path)

        adapter.handle_event(event_data)

        expect(File.size(log_path)).to eq(original_size)
      end
    end
  end

  describe "#recent_events" do
    before do
      # Add some test events
      5.times do |i|
        event = Agentic::Observability::EventData.new(
          type: :"event_#{i}",
          data: {index: i},
          source: "test"
        )
        adapter.handle_event(event)
      end
    end

    it "returns recent events from file" do
      events = adapter.recent_events(limit: 3)

      expect(events.size).to eq(3)
      expect(events.last["type"]).to eq("event_4") # Most recent
      expect(events.first["type"]).to eq("event_2") # Limit of 3
    end

    it "returns all events if limit is larger than file" do
      events = adapter.recent_events(limit: 10)

      expect(events.size).to eq(5)
    end

    it "handles empty file gracefully" do
      empty_adapter = described_class.new(log_path: "/tmp/empty_test.jsonl")
      events = empty_adapter.recent_events

      expect(events).to be_empty

      begin
        File.delete("/tmp/empty_test.jsonl")
      rescue
        nil
      end
    end
  end

  describe "#events_since" do
    let(:base_time) { Time.parse("2025-01-01 12:00:00") }

    before do
      # Mock Time.now to control timestamps
      allow(Time).to receive(:now).and_return(base_time, base_time + 1, base_time + 2)

      3.times do |i|
        event = Agentic::Observability::EventData.new(
          type: :"event_#{i}",
          data: {index: i},
          source: "test"
        )
        adapter.handle_event(event)
      end
    end

    it "returns events since a specific timestamp" do
      since_time = base_time + 0.5 # Between first and second event

      events = adapter.events_since(since_time)

      expect(events.size).to eq(2)
      expect(events.map { |e| e["type"] }).to eq(["event_1", "event_2"])
    end

    it "handles string timestamp input" do
      since_string = (base_time + 0.5).iso8601

      events = adapter.events_since(since_string)

      expect(events.size).to eq(2)
    end
  end

  describe "file rotation" do
    let(:small_config) { {log_path: log_path, max_file_size: 100, max_files: 2} }
    let(:small_adapter) { described_class.new(small_config) }

    it "rotates file when max size is exceeded" do
      # Write enough events to exceed file size limit
      20.times do |i|
        event = Agentic::Observability::EventData.new(
          type: :large_event,
          data: {message: "x" * 50, index: i}, # Large message
          source: "test"
        )
        small_adapter.handle_event(event)
      end

      # Check that rotation occurred
      rotated_files = Dir.glob("#{log_path}.*")
      expect(rotated_files).not_to be_empty

      # Check that new file was created
      expect(File.exist?(log_path)).to be true
    end

    it "limits number of rotated files" do
      # Force multiple rotations
      50.times do |i|
        event = Agentic::Observability::EventData.new(
          type: :rotation_test,
          data: {message: "x" * 100, index: i},
          source: "test"
        )
        small_adapter.handle_event(event)
      end

      # Should not exceed max_files limit
      all_files = Dir.glob("#{log_path}*")
      expect(all_files.length).to be <= small_config[:max_files]
    end
  end

  describe "#file_statistics" do
    before do
      3.times do |i|
        event = Agentic::Observability::EventData.new(
          type: :"stats_event_#{i}",
          data: {index: i},
          source: "test"
        )
        adapter.handle_event(event)
      end
    end

    it "returns file-specific statistics" do
      stats = adapter.file_statistics

      expect(stats[:total_events]).to eq(3)
      expect(stats[:file_size]).to be > 0
      expect(stats[:log_path]).to eq(log_path)
      expect(stats[:first_event_at]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
      expect(stats[:last_event_at]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    end
  end

  describe "#status" do
    it "includes file adapter specific information" do
      status = adapter.status

      expect(status[:enabled]).to be true
      expect(status[:type]).to eq("file")
      expect(status[:log_path]).to eq(log_path)
      expect(status[:file_size]).to be_a(Integer)
      expect(status[:total_events]).to be_a(Integer)
    end
  end

  describe "error handling" do
    it "handles file write errors gracefully" do
      # Make file read-only to cause write error
      File.chmod(0o444, log_path)

      expect {
        adapter.handle_event(event_data)
      }.not_to raise_error

      expect(adapter.statistics[:errors]).to be > 0

      # Restore permissions for cleanup
      File.chmod(0o644, log_path)
    end

    it "handles invalid JSON gracefully in recent_events" do
      # Write invalid JSON to file
      File.write(log_path, "invalid json\n")

      events = adapter.recent_events
      expect(events).to be_empty
    end
  end
end
