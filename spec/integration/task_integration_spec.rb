# frozen_string_literal: true

require "spec_helper"

# Simple mock agent for testing purposes
class MockAgent
  attr_reader :id, :prompt_history

  def initialize(id = "mock-agent-123")
    @id = id
    @prompt_history = []
    @should_fail = false
  end

  def execute(prompt)
    @prompt_history << prompt

    if @should_fail
      raise StandardError, "Mock agent execution failed"
    end

    {"result" => "Mock agent response"}
  end

  def set_failure_mode(should_fail)
    @should_fail = should_fail
  end
end

# Simple mock orchestrator that observes tasks
class MockOrchestrator
  attr_reader :events, :tasks, :results

  def initialize
    @events = []
    @tasks = {}
    @results = {}
  end

  def update(event_type, task, *args)
    @events << {
      type: event_type,
      task_id: task.id,
      args: args,
      timestamp: Time.now
    }

    if event_type == :status_change
      _, new_status = args

      # Store task by status
      @tasks[task.id] = {
        task: task,
        status: new_status
      }

      # If task completed or failed, store its result
      if new_status == :completed || new_status == :failed
        @results[task.id] = {
          status: new_status,
          output: task.output,
          failure: task.failure
        }
      end
    end
  end

  def completed_tasks
    @tasks.select { |_, data| data[:status] == :completed }.values.map { |data| data[:task] }
  end

  def failed_tasks
    @tasks.select { |_, data| data[:status] == :failed }.values.map { |data| data[:task] }
  end

  def add_task(task)
    task.add_observer(self)
    @tasks[task.id] = {
      task: task,
      status: task.status
    }
  end
end

# Integration tests for task components
RSpec.describe "Task Integration" do
  let(:agent) { MockAgent.new }
  let(:orchestrator) { MockOrchestrator.new }
  let(:task) do
    Agentic::Task.new(
      description: "Integration test task",
      agent_spec: {"instructions" => "You are a test agent"},
      input: {"test_key" => "test_value"}
    )
  end

  before do
    # Add the orchestrator as an observer
    task.add_observer(orchestrator)
  end

  describe "Task-Agent-Orchestrator interaction" do
    it "successfully completes task execution flow" do
      # Execute the task
      result = task.perform(agent)

      # Verify the agent received the prompt
      expect(agent.prompt_history.size).to eq(1)
      expect(agent.prompt_history.first).to include("Integration test task")

      # Verify the task status changed correctly
      expect(task.status).to eq(:completed)

      # Verify the orchestrator received status change notifications
      status_events = orchestrator.events.select { |e| e[:type] == :status_change }
      expect(status_events.size).to eq(2) # pending -> in_progress -> completed

      # Verify the orchestrator tracked the task correctly
      expect(orchestrator.completed_tasks).to include(task)

      # Verify the task result was properly formed
      expect(result).to be_a(Agentic::TaskResult)
      expect(result.successful?).to be true
      expect(result.output).to eq({"result" => "Mock agent response"})
    end

    it "handles task failure correctly" do
      # Configure agent to fail
      agent.set_failure_mode(true)

      # Execute the task, which should fail
      result = task.perform(agent)

      # Verify the task status changed correctly
      expect(task.status).to eq(:failed)

      # Verify the orchestrator received status change notifications
      status_events = orchestrator.events.select { |e| e[:type] == :status_change }
      expect(status_events.size).to eq(2) # pending -> in_progress -> failed

      # Verify the orchestrator received failure notification
      failure_events = orchestrator.events.select { |e| e[:type] == :failure_occurred }
      expect(failure_events.size).to eq(1)

      # Verify the orchestrator tracked the task correctly
      expect(orchestrator.failed_tasks).to include(task)

      # Verify the failure was captured properly
      expect(task.failure).to be_a(Agentic::TaskFailure)
      expect(task.failure.message).to eq("Mock agent execution failed")

      # Verify the task result was properly formed
      expect(result).to be_a(Agentic::TaskResult)
      expect(result.failed?).to be true
      expect(result.failure).to be_a(Agentic::TaskFailure)
    end
  end

  describe "Task retry mechanism" do
    it "successfully retries a failed task" do
      # Configure agent to fail
      agent.set_failure_mode(true)

      # Execute the task, which should fail
      task.perform(agent)
      expect(task.status).to eq(:failed)

      # Configure agent to succeed for retry
      agent.set_failure_mode(false)

      # Retry the task
      result = task.retry(agent)

      # Verify the task status changed correctly
      expect(task.status).to eq(:completed)

      # Verify the orchestrator received status change notifications
      status_events = orchestrator.events.select { |e| e[:type] == :status_change }
      expect(status_events.size).to eq(5) # pending -> in_progress -> failed -> retrying -> in_progress -> completed

      # Verify the task result was properly formed
      expect(result).to be_a(Agentic::TaskResult)
      expect(result.successful?).to be true
    end

    it "raises an error when retrying a non-failed task" do
      # Execute the task successfully
      task.perform(agent)
      expect(task.status).to eq(:completed)

      # Attempt to retry the completed task
      expect { task.retry(agent) }.to raise_error("Cannot retry a task that is not in a failed state")
    end
  end

  describe "Multi-task orchestration" do
    let(:task1) do
      Agentic::Task.new(
        description: "First task",
        agent_spec: {"instructions" => "You are a test agent"},
        input: {"position" => 1}
      )
    end

    let(:task2) do
      Agentic::Task.new(
        description: "Second task",
        agent_spec: {"instructions" => "You are a test agent"},
        input: {"position" => 2}
      )
    end

    let(:task3) do
      Agentic::Task.new(
        description: "Third task",
        agent_spec: {"instructions" => "You are a test agent"},
        input: {"position" => 3}
      )
    end

    it "handles multiple tasks with different outcomes" do
      # Configure the orchestrator with multiple tasks
      orchestrator.add_task(task1)
      orchestrator.add_task(task2)
      orchestrator.add_task(task3)

      # Configure one task to fail
      agent.set_failure_mode(false)
      task1.perform(agent)

      agent.set_failure_mode(true)
      task2.perform(agent)

      agent.set_failure_mode(false)
      task3.perform(agent)

      # Verify the orchestrator tracked the tasks correctly
      expect(orchestrator.completed_tasks).to contain_exactly(task1, task3)
      expect(orchestrator.failed_tasks).to contain_exactly(task2)

      # Verify orchestrator captured all events
      expect(orchestrator.events.size).to eq(7) # 2 status changes per task, plus a failure event

      # Verify the task results were stored
      expect(orchestrator.results.size).to eq(3)
      expect(orchestrator.results[task1.id][:status]).to eq(:completed)
      expect(orchestrator.results[task2.id][:status]).to eq(:failed)
      expect(orchestrator.results[task3.id][:status]).to eq(:completed)
    end
  end
end
