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
      expect(observer.instance_variable_get(:@task_spinners)).to eq({})
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
    let(:task) { double("Task", description: "Test task") }
    let(:spinner) { double("TTY::Spinner", auto_spin: nil) }

    before do
      allow(TTY::Spinner).to receive(:new).and_return(spinner)
      allow(Agentic::UI).to receive(:colorize).and_return("colored-text")
    end

    it "creates a spinner for the task" do
      observer.before_task_execution(task_id: task_id, task: task)

      expect(observer.instance_variable_get(:@total_tasks)).to eq(1)
      spinners = observer.instance_variable_get(:@task_spinners)
      expect(spinners).to include(task_id)
      expect(spinners[task_id][:spinner]).to eq(spinner)
      expect(spinners[task_id][:task]).to eq(task)
      expect(spinner).to have_received(:auto_spin)
    end

    it "does nothing when quiet mode is enabled" do
      observer = described_class.new(quiet: true)
      observer.before_task_execution(task_id: task_id, task: task)

      spinners = observer.instance_variable_get(:@task_spinners)
      expect(spinners).to be_empty
      expect(TTY::Spinner).not_to have_received(:new)
    end
  end

  describe "#after_task_success" do
    let(:task_id) { "task-123" }
    let(:task) { double("Task", description: "Test task") }
    let(:result) { double("TaskResult", output: "Test output") }
    let(:duration) { 5.0 }
    let(:spinner) { double("TTY::Spinner", success: nil) }

    before do
      allow(Agentic::UI).to receive(:colorize).and_return("colored-text")
      allow(Agentic::UI).to receive(:format_duration).and_return("5s")

      # Set up the spinner
      observer.instance_variable_set(:@task_spinners, {
        task_id => {spinner: spinner, task: task, start_time: Time.now - duration}
      })

      # Stub display_progress to avoid testing it here
      allow(observer).to receive(:display_progress)
    end

    it "updates the completed tasks count and marks the spinner as successful" do
      observer.after_task_success(task_id: task_id, task: task, result: result, duration: duration)

      expect(observer.instance_variable_get(:@completed_tasks)).to eq(1)
      expect(spinner).to have_received(:success).with(a_string_including("Test task"))
      expect(observer).to have_received(:display_progress)
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
    let(:failure) { double("TaskFailure", message: "Test failure") }
    let(:duration) { 3.0 }
    let(:spinner) { double("TTY::Spinner", error: nil) }

    before do
      allow(Agentic::UI).to receive(:colorize).and_return("colored-text")
      allow(Agentic::UI).to receive(:format_duration).and_return("3s")

      # Set up the spinner
      observer.instance_variable_set(:@task_spinners, {
        task_id => {spinner: spinner, task: task, start_time: Time.now - duration}
      })

      # Stub display_progress to avoid testing it here
      allow(observer).to receive(:display_progress)
    end

    it "updates the failed tasks count and marks the spinner as failed" do
      observer.after_task_failure(task_id: task_id, task: task, failure: failure, duration: duration)

      expect(observer.instance_variable_get(:@failed_tasks)).to eq(1)
      expect(spinner).to have_received(:error).with(a_string_including("Test task"))
      expect(spinner).to have_received(:error).with(a_string_including("Test failure"))
      expect(observer).to have_received(:display_progress)
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

    before do
      allow(Agentic::UI).to receive(:format_duration).and_return("10s")
      allow(Agentic::UI).to receive(:status_text).and_return("colored-status")
      allow(Agentic::UI).to receive(:colorize).and_return("colored-text")
      allow(Agentic::UI).to receive(:box).and_return("result-box")

      # Set up the observer with some tasks
      observer.instance_variable_set(:@total_tasks, 1)
      observer.instance_variable_set(:@completed_tasks, 1)
      observer.instance_variable_set(:@failed_tasks, 0)
    end

    it "displays a summary box of the execution results" do
      expect {
        observer.plan_completed(
          plan_id: plan_id,
          status: status,
          execution_time: execution_time,
          tasks: tasks,
          results: results
        )
      }.to output(/result-box/).to_stdout

      # Expect two calls to box - initial and final
      expect(Agentic::UI).to have_received(:box).with(
        "Execution Summary",
        a_string_including("Status:"),
        hash_including(style: {border: {fg: :green}})
      ).twice
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
        "Execution Summary",
        anything,
        hash_including(style: {border: {fg: :yellow}})
      ).twice

      # Test failure status
      observer.plan_completed(
        plan_id: plan_id,
        status: :failed,
        execution_time: execution_time,
        tasks: tasks,
        results: results
      )

      expect(Agentic::UI).to have_received(:box).with(
        "Execution Summary",
        anything,
        hash_including(style: {border: {fg: :red}})
      ).twice
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

  describe "#display_progress" do
    before do
      allow(Agentic::UI).to receive(:colorize).and_return("colored-text")
      allow(Agentic::UI).to receive(:format_duration).and_return("5s")

      # Set up the observer with some tasks
      observer.instance_variable_set(:@total_tasks, 5)
      observer.instance_variable_set(:@completed_tasks, 2)
      observer.instance_variable_set(:@failed_tasks, 0)
      observer.instance_variable_set(:@start_time, Time.now - 5)
    end

    it "displays progress information" do
      # Create a test implementation of the display_progress method that we can verify
      result = nil
      allow(Agentic::UI).to receive(:colorize) do |text, _color|
        result = text
        "colored-text"
      end

      observer.send(:display_progress)

      # Verify that the text passed to colorize contains the progress information
      expect(result).to include("Progress: 40%")
      expect(result).to include("(2/5)")
      expect(result).to include("Elapsed:")
    end

    it "prints a newline when all tasks are completed" do
      observer.instance_variable_set(:@completed_tasks, 5)

      expect {
        observer.send(:display_progress)
      }.to output("\n").to_stdout
    end

    it "does not display progress when no tasks have been completed" do
      observer.instance_variable_set(:@completed_tasks, 0)
      observer.instance_variable_set(:@failed_tasks, 0)

      expect {
        observer.send(:display_progress)
      }.not_to output.to_stdout
    end

    it "does nothing when quiet mode is enabled" do
      observer = described_class.new(quiet: true)
      observer.instance_variable_set(:@total_tasks, 5)
      observer.instance_variable_set(:@completed_tasks, 2)

      expect {
        observer.send(:display_progress)
      }.not_to output.to_stdout
    end
  end

  describe "agent information in task table" do
    let(:task_id) { "task-123" }
    let(:task) { double("Task", description: "Test task") }
    let(:agent) { double("Agent", role: "Test Agent") }

    before do
      # Enable holistic display
      observer.instance_variable_set(:@holistic_display, true)
      observer.instance_variable_set(:@task_states, {})

      # Mock UI methods
      allow(Agentic::UI).to receive(:colorize).and_return("colored-text")
      allow(Agentic::UI).to receive(:format_duration).and_return("1.5s")
      allow(Agentic::UI).to receive(:box).and_return("agent-box")
      allow(Agentic::UI).to receive(:task_display_table).and_return("task-table")
      allow(Agentic::UI).to receive(:clear_and_reposition)
      allow(Agentic::UI).to receive(:truncate_text) { |text, length| text[0...length] }
    end

    # Helper method to capture stdout including escape sequences
    def capture_stdout
      old_stdout = $stdout
      $stdout = StringIO.new
      yield
      $stdout.string
    ensure
      $stdout = old_stdout
    end

    it "displays agent information in task table when agents are built" do
      # Simulate agent building and task execution
      observer.before_agent_build(task_id: task_id, task: task)
      observer.after_agent_build(task_id: task_id, task: task, agent: agent, build_duration: 1.5)
      observer.before_task_execution(task_id: task_id, task: task)

      output = capture_stdout do
        observer.send(:update_holistic_display)
      end

      # Verify that the table content is displayed and includes agent info
      expect(output).to include("task-table")

      # Verify that agent information is tracked
      built_agents = observer.instance_variable_get(:@built_agents)
      expect(built_agents[task_id]).to include(
        role: "Test Agent",
        build_duration: 1.5,
        task_description: "Test task"
      )

      # Verify that no separate agent box is created
      expect(Agentic::UI).not_to have_received(:box).with(
        "Agent Summary",
        anything,
        anything
      )
    end

    it "displays task table with agent column even when no agents are built" do
      observer.before_task_execution(task_id: task_id, task: task)

      output = capture_stdout do
        observer.send(:update_holistic_display)
      end

      # Verify that the table content is displayed
      expect(output).to include("task-table")

      # Verify that no agent information is tracked yet
      built_agents = observer.instance_variable_get(:@built_agents)
      expect(built_agents[task_id]).to be_nil

      # Verify that no agent box is created
      expect(Agentic::UI).not_to have_received(:box).with(
        "Agent Summary",
        anything,
        anything
      )
    end

    it "handles agent reuse across multiple tasks correctly" do
      # Create multiple tasks that will use the same agent
      task_id_1 = "task-1"
      task_id_2 = "task-2"
      task_1 = double("Task", description: "First task")
      task_2 = double("Task", description: "Second task")
      shared_agent = double("Agent", role: "Shared Agent")

      # Simulate the same agent being built for multiple tasks
      observer.before_agent_build(task_id: task_id_1, task: task_1)
      observer.after_agent_build(task_id: task_id_1, task: task_1, agent: shared_agent, build_duration: 1.0)
      observer.before_task_execution(task_id: task_id_1, task: task_1)

      observer.before_agent_build(task_id: task_id_2, task: task_2)
      observer.after_agent_build(task_id: task_id_2, task: task_2, agent: shared_agent, build_duration: 0.1) # Reused agent builds faster
      observer.before_task_execution(task_id: task_id_2, task: task_2)

      # Verify that both tasks show their agent assignments
      built_agents = observer.instance_variable_get(:@built_agents)
      expect(built_agents[task_id_1][:role]).to eq("Shared Agent")
      expect(built_agents[task_id_2][:role]).to eq("Shared Agent")
      expect(built_agents[task_id_1][:build_duration]).to eq(1.0)
      expect(built_agents[task_id_2][:build_duration]).to eq(0.1)

      output = capture_stdout do
        observer.send(:update_holistic_display)
      end

      # Verify that the table content is displayed
      expect(output).to include("task-table")
    end
  end
end
