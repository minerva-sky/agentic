# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "json"

RSpec.describe "Observability Adapter Integration", type: :integration do
  let(:temp_file) { Tempfile.new(["integration_events", ".jsonl"]) }
  let(:log_path) { temp_file.path }
  let(:output_stream) { StringIO.new }
  let(:engine) { Agentic::ObservabilityEngine.new }

  after do
    temp_file.close
    temp_file.unlink
    engine.shutdown
  end

  describe "End-to-End Adapter System" do
    it "processes events through multiple adapters simultaneously" do
      # Setup multiple adapters
      console_adapter = Agentic::Observability::AdapterFactory.create(:console,
        output_stream: output_stream,
        color: false,
        verbose: true)

      file_adapter = Agentic::Observability::AdapterFactory.create(:file,
        log_path: log_path)

      engine.add_adapter(console_adapter)
      engine.add_adapter(file_adapter)

      # Send events that simulate real CLI execution
      test_events = [
        {type: :plan_started, data: {goal: "Integration test goal"}, source: "task_planner"},
        {type: :agent_build_started, data: {agent_name: "test_agent"}, source: "agent_builder"},
        {type: :agent_build_completed, data: {agent_name: "test_agent", duration: 1.5}, source: "agent_builder"},
        {type: :task_started, data: {task_id: "task-1", task_description: "Execute integration test"}, source: "task_executor"},
        {type: :task_completed, data: {task_id: "task-1", duration: 2.3, success: true}, source: "task_executor"},
        {type: :plan_completed, data: {goal: "Integration test goal", task_count: 1, total_duration: 3.8}, source: "plan_orchestrator"}
      ]

      # Process events
      test_events.each do |event|
        engine.notify(event[:type], data: event[:data], source: event[:source])
      end

      # Verify console output
      console_output = output_stream.string
      expect(console_output).to include("Plan started: Integration test goal")
      expect(console_output).to include("Building agent: test_agent")
      expect(console_output).to include("Agent built: test_agent")
      expect(console_output).to include("Task started: Execute integration test")
      expect(console_output).to include("Task completed: task-1 (2.3s)")
      expect(console_output).to include("Plan completed: Integration test goal (1 tasks)")

      # Verify file output
      file_content = File.read(log_path)
      file_lines = file_content.strip.split("\n")
      expect(file_lines.size).to eq(6)

      # Parse and verify JSON structure
      parsed_events = file_lines.map { |line| JSON.parse(line) }

      expect(parsed_events[0]["type"]).to eq("plan_started")
      expect(parsed_events[0]["data"]["goal"]).to eq("Integration test goal")
      expect(parsed_events[0]["source"]).to eq("task_planner")
      expect(parsed_events[0]["timestamp"]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)

      expect(parsed_events.last["type"]).to eq("plan_completed")
      expect(parsed_events.last["data"]["task_count"]).to eq(1)

      # Verify statistics
      stats = engine.statistics
      expect(stats[:events_processed]).to eq(6)
      expect(stats[:adapter_notifications]).to eq(12) # 6 events × 2 adapters
      expect(stats[:adapters_count]).to eq(2)
    end

    it "handles adapter failures gracefully without affecting other adapters" do
      # Setup one good adapter and one that will fail
      good_adapter = Agentic::Observability::AdapterFactory.create(:console,
        output_stream: output_stream,
        color: false)

      # Create a file adapter with invalid path to force failure
      bad_adapter = Agentic::Observability::AdapterFactory.create(:file,
        log_path: "/root/invalid_path/events.jsonl") # Should fail on most systems

      engine.add_adapter(good_adapter)
      engine.add_adapter(bad_adapter)

      # Send an event
      engine.notify(:test_event, data: {message: "Testing error isolation"}, source: "test")

      # Good adapter should still work
      expect(output_stream.string).to include("test_event")
      expect(output_stream.string).to include("Testing error isolation")

      # Engine should continue working
      expect(engine.active?).to be true

      # Statistics should show the error
      stats = engine.statistics
      expect(stats[:events_processed]).to eq(1)
      # One successful notification, one failed
      expect(stats[:adapter_notifications]).to be > 0
    end
  end

  describe "Configuration-Based Adapter Setup" do
    it "creates and configures adapters from configuration hash" do
      config = {
        console: {
          enabled: true,
          color: false,
          verbose: true
        },
        file: {
          enabled: true,
          log_path: log_path,
          max_file_size: 1024
        }
      }

      engine.configure_adapters(config)

      # Verify adapters were created
      expect(engine.all_adapters.size).to eq(2)
      expect(engine.find_adapters(:console).size).to eq(1)
      expect(engine.find_adapters(:file).size).to eq(1)

      # Test functionality
      engine.notify(:config_test, data: {message: "Configuration test"}, source: "test")

      # Verify both adapters received the event
      console_adapter = engine.find_adapters(:console).first
      file_adapter = engine.find_adapters(:file).first

      expect(console_adapter.statistics[:events_processed]).to eq(1)
      expect(file_adapter.statistics[:events_processed]).to eq(1)
    end

    it "uses default CLI configuration appropriately" do
      cli_options = {
        quiet: false,
        verbose: true,
        color: false,
        enable_file_logging: true,
        log_path: log_path
      }

      engine.enable_default_cli_adapters(cli_options)

      adapters = engine.all_adapters
      expect(adapters.size).to eq(2)

      console_adapter = engine.find_adapters(:console).first
      file_adapter = engine.find_adapters(:file).first

      expect(console_adapter.config[:verbose]).to be true
      expect(console_adapter.config[:color]).to be false
      expect(file_adapter.config[:log_path]).to eq(log_path)
    end

    it "disables console adapter in quiet mode" do
      cli_options = {quiet: true}

      engine.enable_default_cli_adapters(cli_options)

      console_adapters = engine.find_adapters(:console)
      expect(console_adapters.size).to eq(1)
      expect(console_adapters.first.enabled?).to be false
    end
  end

  describe "Real-World Execution Simulation" do
    it "simulates complete CLI execution workflow with observability" do
      # Setup adapters like real CLI execution
      engine.enable_default_cli_adapters({
        quiet: false,
        verbose: false,
        color: false,
        enable_file_logging: true,
        log_path: log_path
      })

      # Simulate complete execution workflow
      workflow_events = [
        # Planning phase
        {type: :plan_started, data: {goal: "Complete workflow simulation"}, source: "task_planner"},

        # Agent building phase
        {type: :agent_build_started, data: {agent_name: "workflow_agent", capabilities: ["analyze", "execute"]}, source: "agent_builder"},
        {type: :agent_build_completed, data: {agent_name: "workflow_agent", duration: 0.8}, source: "agent_builder"},

        # Task execution phase
        {type: :task_started, data: {task_id: "wf-task-1", task_description: "Analyze requirements"}, source: "task_executor"},
        {type: :task_completed, data: {task_id: "wf-task-1", duration: 2.1, success: true}, source: "task_executor"},

        {type: :task_started, data: {task_id: "wf-task-2", task_description: "Execute implementation"}, source: "task_executor"},
        {type: :task_completed, data: {task_id: "wf-task-2", duration: 3.5, success: true}, source: "task_executor"},

        # Plan completion
        {type: :plan_completed, data: {goal: "Complete workflow simulation", task_count: 2, total_duration: 6.4}, source: "plan_orchestrator"}
      ]

      workflow_events.each do |event|
        engine.notify(event[:type], data: event[:data], source: event[:source])
        sleep(0.01) # Small delay to simulate real timing
      end

      # Verify complete workflow was captured
      file_adapter = engine.find_adapters(:file).first
      captured_events = file_adapter.recent_events

      expect(captured_events.size).to eq(8)

      # Verify event sequence
      event_types = captured_events.map { |e| e["type"] }
      expect(event_types).to eq([
        "plan_started",
        "agent_build_started",
        "agent_build_completed",
        "task_started",
        "task_completed",
        "task_started",
        "task_completed",
        "plan_completed"
      ])

      # Verify timing information is preserved
      timestamps = captured_events.map { |e| Time.parse(e["timestamp"]) }
      expect(timestamps).to eq(timestamps.sort) # Should be in chronological order

      # Verify data integrity
      plan_start = captured_events.first
      plan_end = captured_events.last
      expect(plan_start["data"]["goal"]).to eq(plan_end["data"]["goal"])
      expect(plan_end["data"]["task_count"]).to eq(2)

      # Verify statistics reflect complete workflow
      stats = engine.statistics
      expect(stats[:events_processed]).to eq(8)
      expect(stats[:adapters_count]).to eq(2) # console + file
    end
  end
end
