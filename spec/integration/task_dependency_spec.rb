# frozen_string_literal: true

require "spec_helper"

# Simple dependency-aware orchestrator
class DependencyOrchestrator
  attr_reader :tasks, :execution_order, :dependency_map

  def initialize
    @tasks = {}
    @dependency_map = {}
    @execution_order = []
    @completed_tasks = Set.new
  end

  def update(event_type, task, *args)
    if event_type == :status_change
      _, new_status = args

      if new_status == :completed
        @completed_tasks.add(task.id)
        @execution_order << task.id

        # Execute any tasks that depend on this one
        execute_dependent_tasks(task.id)
      end
    end
  end

  def add_task(task, dependencies = [])
    task.add_observer(self)
    @tasks[task.id] = task
    @dependency_map[task.id] = dependencies
  end

  def execute_eligible_tasks(agent)
    # Find tasks with no dependencies or all dependencies satisfied
    eligible_tasks = @tasks.keys.select do |task_id|
      deps = @dependency_map[task_id]
      deps.empty? || deps.all? { |dep_id| @completed_tasks.include?(dep_id) }
    end

    # Execute all eligible tasks that haven't been completed yet
    eligible_tasks.each do |task_id|
      next if @completed_tasks.include?(task_id)

      @tasks[task_id].perform(agent)
    end
  end

  private

  def execute_dependent_tasks(completed_task_id)
    # Find tasks that depend directly on the completed task
    dependent_tasks = @dependency_map.select do |task_id, deps|
      deps.include?(completed_task_id) && deps.all? { |dep_id| @completed_tasks.include?(dep_id) }
    end.keys

    # These tasks are now eligible to execute
    dependent_tasks.each do |task_id|
      next if @completed_tasks.include?(task_id)

      task = @tasks[task_id]

      # In a real implementation, we would queue these for execution
      # For our test, we'll just note that they're ready
      task.instance_variable_set(:@ready_to_execute, true)
    end
  end
end

RSpec.describe "Task Dependencies" do
  let(:agent) { double("Agent", id: "agent-123") }
  let(:orchestrator) { DependencyOrchestrator.new }

  let(:task_a) do
    Agentic::Task.new(
      description: "Task A",
      agent_spec: {"instructions" => "You are a test agent"},
      input: {"name" => "A"}
    )
  end

  let(:task_b) do
    Agentic::Task.new(
      description: "Task B",
      agent_spec: {"instructions" => "You are a test agent"},
      input: {"name" => "B"}
    )
  end

  let(:task_c) do
    Agentic::Task.new(
      description: "Task C",
      agent_spec: {"instructions" => "You are a test agent"},
      input: {"name" => "C"}
    )
  end

  let(:task_d) do
    Agentic::Task.new(
      description: "Task D",
      agent_spec: {"instructions" => "You are a test agent"},
      input: {"name" => "D"}
    )
  end

  before do
    # Mock the agent execution
    allow(agent).to receive(:execute).and_return({"result" => "Success"})

    # Set up task dependencies: A -> B,C -> D
    orchestrator.add_task(task_a, [])           # A has no dependencies
    orchestrator.add_task(task_b, [task_a.id])  # B depends on A
    orchestrator.add_task(task_c, [task_a.id])  # C depends on A
    orchestrator.add_task(task_d, [task_b.id, task_c.id]) # D depends on B and C
  end

  it "executes tasks in dependency order" do
    # Execute initial eligible tasks (only A is eligible)
    orchestrator.execute_eligible_tasks(agent)

    # Task A should be executed and completed
    expect(task_a.status).to eq(:completed)

    # Now B and C should be eligible
    orchestrator.execute_eligible_tasks(agent)

    # Tasks B and C should be executed and completed
    expect(task_b.status).to eq(:completed)
    expect(task_c.status).to eq(:completed)

    # Now D should be eligible
    orchestrator.execute_eligible_tasks(agent)

    # Task D should be executed and completed
    expect(task_d.status).to eq(:completed)

    # The execution order should respect dependencies
    # A must come before B and C, and B and C must come before D
    a_index = orchestrator.execution_order.index(task_a.id)
    b_index = orchestrator.execution_order.index(task_b.id)
    c_index = orchestrator.execution_order.index(task_c.id)
    d_index = orchestrator.execution_order.index(task_d.id)

    expect(a_index).to be < b_index
    expect(a_index).to be < c_index
    expect(b_index).to be < d_index
    expect(c_index).to be < d_index
  end

  it "handles tasks with multiple dependencies" do
    # Mark tasks A, B, and C as completed
    [task_a, task_b, task_c].each do |task|
      task.instance_variable_set(:@status, :completed)
      orchestrator.instance_variable_get(:@completed_tasks).add(task.id)
      orchestrator.execution_order << task.id
    end

    # D should now be eligible
    orchestrator.execute_eligible_tasks(agent)

    # Task D should be executed and completed
    expect(task_d.status).to eq(:completed)
  end

  it "does not execute tasks with unsatisfied dependencies" do
    # Only execute task A
    task_a.perform(agent)

    # Task B and C should still be pending (until we call execute_eligible_tasks)
    expect(task_b.status).to eq(:pending)
    expect(task_c.status).to eq(:pending)

    # D should definitely not be ready
    expect(task_d.ready_to_execute).to be_nil

    # Now execute eligible tasks (B and C)
    orchestrator.execute_eligible_tasks(agent)

    # Task D should now be ready to execute
    expect(task_d.instance_variable_get(:@ready_to_execute)).to be true
  end
end
