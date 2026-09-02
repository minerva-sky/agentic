# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::Observability::ConsoleAdapter do
  let(:output_stream) { StringIO.new }
  let(:config) { {output_stream: output_stream, color: false} }
  let(:adapter) { described_class.new(config) }
  let(:event_data) do
    Agentic::Observability::EventData.new(
      type: :test_event,
      data: {message: "Test message"},
      source: "test_source"
    )
  end

  describe "#initialize" do
    it "sets up default configuration" do
      adapter = described_class.new

      expect(adapter.enabled?).to be true
      expect(adapter.adapter_type).to eq("console")
    end

    it "accepts custom configuration" do
      custom_adapter = described_class.new(
        color: false,
        verbose: true,
        timestamp_format: "%Y-%m-%d"
      )

      expect(custom_adapter.config[:color]).to be false
      expect(custom_adapter.config[:verbose]).to be true
      expect(custom_adapter.config[:timestamp_format]).to eq("%Y-%m-%d")
    end
  end

  describe "#handle_event" do
    context "when adapter is enabled" do
      it "outputs formatted event to stream" do
        adapter.handle_event(event_data)

        output = output_stream.string
        expect(output).to include("test_event")
        expect(output).to include("Test message")
        expect(output).to end_with("\n")
      end

      it "updates statistics on successful output" do
        expect {
          adapter.handle_event(event_data)
        }.to change { adapter.statistics[:events_processed] }.by(1)
      end

      it "includes timestamp in output" do
        adapter.handle_event(event_data)

        output = output_stream.string
        expect(output).to match(/\[\d{2}:\d{2}:\d{2}\]/)
      end
    end

    context "when adapter is disabled" do
      before { adapter.disable! }

      it "does not output anything" do
        adapter.handle_event(event_data)

        expect(output_stream.string).to be_empty
      end

      it "does not update statistics" do
        expect {
          adapter.handle_event(event_data)
        }.not_to change { adapter.statistics[:events_processed] }
      end
    end

    context "with specific event types" do
      it "formats task_started events meaningfully" do
        task_event = Agentic::Observability::EventData.new(
          type: :task_started,
          data: {task_description: "Initialize system", task_id: "task-123"},
          source: "task_executor"
        )

        adapter.handle_event(task_event)

        output = output_stream.string
        expect(output).to include("Task started: Initialize system")
      end

      it "formats task_completed events with duration" do
        task_event = Agentic::Observability::EventData.new(
          type: :task_completed,
          data: {task_description: "Initialize system", duration: 2.5},
          source: "task_executor"
        )

        adapter.handle_event(task_event)

        output = output_stream.string
        expect(output).to include("Task completed: Initialize system (2.5s)")
      end

      it "formats agent_build_started events" do
        agent_event = Agentic::Observability::EventData.new(
          type: :agent_build_started,
          data: {agent_name: "test_agent"},
          source: "agent_builder"
        )

        adapter.handle_event(agent_event)

        output = output_stream.string
        expect(output).to include("Building agent: test_agent")
      end

      it "formats plan_completed events with task count" do
        plan_event = Agentic::Observability::EventData.new(
          type: :plan_completed,
          data: {goal: "Test system", task_count: 5},
          source: "plan_orchestrator"
        )

        adapter.handle_event(plan_event)

        output = output_stream.string
        expect(output).to include("Plan completed: Test system (5 tasks)")
      end
    end

    context "with verbose mode" do
      let(:config) { {output_stream: output_stream, verbose: true, color: false} }

      it "includes detailed data in verbose mode" do
        generic_event = Agentic::Observability::EventData.new(
          type: :custom_event,
          data: {key1: "value1", key2: "value2"},
          source: "test"
        )

        adapter.handle_event(generic_event)

        output = output_stream.string
        expect(output).to include("key1")
        expect(output).to include("value1")
      end
    end

    context "with color enabled" do
      let(:config) { {output_stream: output_stream, color: true} }

      it "applies color codes to task events" do
        task_event = Agentic::Observability::EventData.new(
          type: :task_completed,
          data: {message: "Success!"},
          source: "test"
        )

        adapter.handle_event(task_event)

        output = output_stream.string
        expect(output).to include("\e[32m") # Green color for completed
        expect(output).to include("\e[0m")   # Reset color
      end
    end
  end

  describe "#enable! and #disable!" do
    it "can be enabled and disabled" do
      adapter.disable!
      expect(adapter.enabled?).to be false

      adapter.enable!
      expect(adapter.enabled?).to be true
    end
  end

  describe "#status" do
    it "returns comprehensive status information" do
      status = adapter.status

      expect(status[:enabled]).to be true
      expect(status[:type]).to eq("console")
      expect(status[:statistics]).to include(:events_processed, :errors)
      expect(status[:color_enabled]).to be false
      expect(status[:verbose]).to be_falsy
    end
  end

  describe "error handling" do
    let(:faulty_stream) { double("stream") }
    let(:faulty_config) { {output_stream: faulty_stream, color: false} }
    let(:faulty_adapter) { described_class.new(faulty_config) }

    it "handles output errors gracefully" do
      allow(faulty_stream).to receive(:puts).and_raise(StandardError, "Stream error")
      allow(faulty_stream).to receive(:flush)

      expect {
        faulty_adapter.handle_event(event_data)
      }.not_to raise_error

      expect(faulty_adapter.statistics[:errors]).to eq(1)
    end
  end
end
