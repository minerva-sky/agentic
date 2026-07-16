# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::CLI::ExecutionObserver do
  let(:options) { {} }
  let(:observer) { described_class.new(options) }

  describe "#initialize" do
    it "initializes with default values" do
      expect(observer.instance_variable_get(:@completed_tasks)).to eq(0)
      expect(observer.instance_variable_get(:@failed_tasks)).to eq(0)
      expect(observer.instance_variable_get(:@total_tasks)).to eq(0)
      expect(observer.instance_variable_get(:@progress_tracker)).to be_a(Agentic::CLI::ProgressTracker)
    end
  end

  describe "#lifecycle_hooks" do
    it "returns a hash of lifecycle hooks" do
      hooks = observer.lifecycle_hooks

      expect(hooks).to be_a(Hash)
      expect(hooks).to include(
        :before_task_execution,
        :after_task_success,
        :after_task_failure,
        :plan_completed
      )
    end
  end

  describe "#before_task_execution" do
    let(:task_id) { "task-123" }
    let(:task) { double("Task", description: "Test task", agent_spec: double("AgentSpec", to_h: {}), input: {}) }
    let(:progress_tracker) { double("ProgressTracker") }

    before do
      observer.instance_variable_set(:@progress_tracker, progress_tracker)
      allow(progress_tracker).to receive(:create_section)
      allow(progress_tracker).to receive(:start_process)
    end

    it "starts a progress tracking process for the task" do
      observer.before_task_execution(task_id: task_id, task: task)

      expect(observer.instance_variable_get(:@total_tasks)).to eq(1)
      expect(progress_tracker).to have_received(:create_section).with("task_execution", "Task Execution", "Running tasks with assembled agents")
      expect(progress_tracker).to have_received(:start_process).with("task_execution", "task_#{task_id}", "Test task", hash_including(task_id: task_id))
    end

    it "does nothing when quiet mode is enabled" do
      observer = described_class.new(quiet: true)
      observer.before_task_execution(task_id: task_id, task: task)

      expect(observer.instance_variable_get(:@total_tasks)).to eq(0)
    end
  end

  describe "#after_task_success" do
    let(:task_id) { "task-123" }
    let(:task) { double("Task", description: "Test task") }
    let(:result) { double("TaskResult", output: "Test output") }
    let(:duration) { 5.0 }
    let(:progress_tracker) { double("ProgressTracker") }

    before do
      observer.instance_variable_set(:@progress_tracker, progress_tracker)
      allow(progress_tracker).to receive(:complete_process)
      allow(progress_tracker).to receive(:fail_process)
    end

    it "updates the completed tasks count and completes the progress tracker process" do
      observer.after_task_success(task_id: task_id, task: task, result: result, duration: duration)

      expect(observer.instance_variable_get(:@completed_tasks)).to eq(1)
      expect(progress_tracker).to have_received(:complete_process).with("task_#{task_id}", "Test output", duration)
    end

    it "does nothing when quiet mode is enabled" do
      observer = described_class.new(quiet: true)
      observer.after_task_success(task_id: task_id, task: task, result: result, duration: duration)

      expect(observer.instance_variable_get(:@completed_tasks)).to eq(0)
    end
  end

  describe "#after_task_failure" do
    let(:task_id) { "task-123" }
    let(:task) { double("Task", description: "Test task") }
    let(:failure) { double("TaskFailure", message: "Test failure", type: "error") }
    let(:duration) { 3.0 }
    let(:progress_tracker) { double("ProgressTracker") }

    before do
      observer.instance_variable_set(:@progress_tracker, progress_tracker)
      allow(progress_tracker).to receive(:fail_process)
    end

    it "updates the failed tasks count and fails the progress tracker process" do
      observer.after_task_failure(task_id: task_id, task: task, failure: failure, duration: duration)

      expect(observer.instance_variable_get(:@failed_tasks)).to eq(1)
      expect(progress_tracker).to have_received(:fail_process).with("task_#{task_id}", "Test failure", duration)
    end

    it "does nothing when quiet mode is enabled" do
      observer = described_class.new(quiet: true)
      observer.after_task_failure(task_id: task_id, task: task, failure: failure, duration: duration)

      expect(observer.instance_variable_get(:@failed_tasks)).to eq(0)
    end
  end

  describe "#plan_completed" do
    let(:plan_id) { "plan-123" }
    let(:status) { :completed }
    let(:execution_time) { 10.0 }
    let(:tasks) { {"task-1" => {description: "Task 1"}} }
    let(:results) { {"task-1" => double("TaskResult", successful?: true, output: "Test output")} }
    let(:progress_tracker) { double("ProgressTracker") }

    before do
      observer.instance_variable_set(:@progress_tracker, progress_tracker)
      allow(progress_tracker).to receive(:display_summary)
      allow(progress_tracker).to receive(:sections).and_return({
        "test_section" => {
          title: "Test Section",
          process_count: 1,
          completed_count: 1,
          failed_count: 0,
          status: :completed
        }
      })
      allow(progress_tracker).to receive(:section_status_symbol).and_return("✓")
      allow(Agentic::UI).to receive(:colorize).and_return("colored-text")
      allow(Agentic::UI).to receive(:box).and_return("result-box")

      # Set up the observer with some tasks
      observer.instance_variable_set(:@total_tasks, 1)
      observer.instance_variable_set(:@completed_tasks, 1)
      observer.instance_variable_set(:@failed_tasks, 0)
    end

    it "displays consolidated summary and execution results" do
      expect {
        observer.plan_completed(
          plan_id: plan_id,
          status: status,
          execution_time: execution_time,
          tasks: tasks,
          results: results
        )
      }.to output(/result-box/).to_stdout

      expect(Agentic::UI).to have_received(:box).with(
        "Execution Complete",
        a_string_including("Status:"),
        hash_including(style: {border: {fg: :green}})
      )
    end

    it "uses different colors for different statuses" do
      # Test partial_failure status
      observer.plan_completed(
        plan_id: plan_id,
        status: :partial_failure,
        execution_time: execution_time,
        tasks: tasks,
        results: results
      )

      expect(Agentic::UI).to have_received(:box).with(
        "Execution Complete",
        anything,
        hash_including(style: {border: {fg: :yellow}})
      )

      # Test failure status
      observer.plan_completed(
        plan_id: plan_id,
        status: :failed,
        execution_time: execution_time,
        tasks: tasks,
        results: results
      )

      expect(Agentic::UI).to have_received(:box).with(
        "Execution Complete",
        anything,
        hash_including(style: {border: {fg: :red}})
      )
    end

    it "does nothing when quiet mode is enabled" do
      observer = described_class.new(quiet: true)

      expect {
        observer.plan_completed(
          plan_id: plan_id,
          status: status,
          execution_time: execution_time,
          tasks: tasks,
          results: results
        )
      }.not_to output.to_stdout

      expect(Agentic::UI).not_to have_received(:box)
    end
  end

  describe "#before_agent_build" do
    let(:task_id) { "task-123" }
    let(:task) { double("Task", description: "Test task", agent_spec: double("AgentSpec", to_h: {})) }
    let(:progress_tracker) { double("ProgressTracker") }

    before do
      observer.instance_variable_set(:@progress_tracker, progress_tracker)
      allow(progress_tracker).to receive(:create_section)
      allow(progress_tracker).to receive(:start_process)
    end

    it "starts a progress tracking process for agent building" do
      observer.before_agent_build(task_id: task_id, task: task)

      expect(progress_tracker).to have_received(:create_section).with("agent_building", "Agent Assembly", "Building specialized agents for tasks")
      expect(progress_tracker).to have_received(:start_process).with("agent_building", "agent_#{task_id}", "Building agent for: Test task", hash_including(task_id: task_id))
    end

    it "does nothing when quiet mode is enabled" do
      observer = described_class.new(quiet: true)
      observer.before_agent_build(task_id: task_id, task: task)

      expect(progress_tracker).not_to have_received(:create_section)
      expect(progress_tracker).not_to have_received(:start_process)
    end
  end

  describe "#after_agent_build" do
    let(:task_id) { "task-123" }
    let(:task) { double("Task", description: "Test task") }
    let(:agent) { double("Agent", role: "Test Agent", purpose: "Testing") }
    let(:duration) { 1.5 }
    let(:progress_tracker) { double("ProgressTracker") }

    before do
      observer.instance_variable_set(:@progress_tracker, progress_tracker)
      allow(progress_tracker).to receive(:complete_process)
      allow(progress_tracker).to receive(:fail_process)
    end

    it "completes the agent building process" do
      observer.after_agent_build(task_id: task_id, task: task, agent: agent, build_duration: duration)

      expect(progress_tracker).to have_received(:complete_process).with("agent_#{task_id}", "Test Agent agent ready", duration)
    end

    it "does nothing when quiet mode is enabled" do
      observer = described_class.new(quiet: true)
      observer.after_agent_build(task_id: task_id, task: task, agent: agent, build_duration: duration)

      expect(progress_tracker).not_to have_received(:complete_process)
    end
  end

  describe "agent tracking" do
    let(:task_id) { "task-123" }
    let(:task) { double("Task", description: "Test task", agent_spec: double("AgentSpec", to_h: {}), input: {}) }
    let(:agent) { double("Agent", role: "Test Agent", purpose: "Testing") }

    it "tracks built agents for compatibility" do
      observer.after_agent_build(task_id: task_id, task: task, agent: agent, build_duration: 1.5)

      built_agents = observer.instance_variable_get(:@built_agents)
      expect(built_agents[task_id]).to include(
        role: "Test Agent",
        build_duration: 1.5,
        task_description: "Test task"
      )
    end

    it "tracks task states for compatibility" do
      observer.before_task_execution(task_id: task_id, task: task)

      task_states = observer.instance_variable_get(:@task_states)
      expect(task_states[task_id]).to include(
        status: :in_progress,
        description: "Test task"
      )
    end
  end
end
