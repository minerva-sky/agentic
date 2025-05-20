# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::PlanOrchestrator, "lifecycle hooks" do
  let(:task) do
    Agentic::Task.new(
      description: "Test task",
      agent_spec: {"instructions" => "You are a test agent"},
      input: {"test" => true}
    )
  end
  
  let(:agent) { double("Agent", id: "test-agent") }
  let(:agent_provider) do
    provider = double("AgentProvider")
    allow(provider).to receive(:get_agent_for_task).and_return(agent)
    provider
  end
  
  describe "lifecycle hooks" do
    it "calls the before_task_execution hook" do
      hook_called = false
      task_id_in_hook = nil
      
      hooks = {
        before_task_execution: ->(task_id:, task:) {
          hook_called = true
          task_id_in_hook = task_id
        }
      }
      
      orchestrator = described_class.new(lifecycle_hooks: hooks)
      orchestrator.add_task(task)
      
      # Set up successful execution
      result = double("TaskResult", successful?: true, output: {"result" => "success"})
      allow(task).to receive(:perform).and_return(result)
      
      orchestrator.execute_plan(agent_provider)
      
      expect(hook_called).to be true
      expect(task_id_in_hook).to eq(task.id)
    end
    
    it "calls the after_task_success hook on successful completion" do
      hook_called = false
      duration_in_hook = nil
      
      hooks = {
        after_task_success: ->(task_id:, task:, result:, duration:) {
          hook_called = true
          duration_in_hook = duration
        }
      }
      
      orchestrator = described_class.new(lifecycle_hooks: hooks)
      orchestrator.add_task(task)
      
      # Set up successful execution
      result = double("TaskResult", successful?: true, output: {"result" => "success"})
      allow(task).to receive(:perform).and_return(result)
      
      orchestrator.execute_plan(agent_provider)
      
      expect(hook_called).to be true
      expect(duration_in_hook).to be_a(Float)
      expect(duration_in_hook).to be >= 0
    end
    
    it "calls the after_task_failure hook on task failure" do
      hook_called = false
      failure_in_hook = nil
      
      hooks = {
        after_task_failure: ->(task_id:, task:, failure:, duration:) {
          hook_called = true
          failure_in_hook = failure
        }
      }
      
      orchestrator = described_class.new(lifecycle_hooks: hooks)
      orchestrator.add_task(task)
      
      # Set up failed execution
      failure = Agentic::TaskFailure.new(
        message: "Test failure",
        type: "TestError"
      )
      result = double("TaskResult", successful?: false, failure: failure)
      allow(task).to receive(:perform).and_return(result)
      
      orchestrator.execute_plan(agent_provider)
      
      expect(hook_called).to be true
      expect(failure_in_hook).to eq(failure)
    end
    
    it "calls the plan_completed hook when the plan finishes" do
      hook_called = false
      status_in_hook = nil
      execution_time_in_hook = nil
      
      hooks = {
        plan_completed: ->(plan_id:, status:, execution_time:, tasks:, results:) {
          hook_called = true
          status_in_hook = status
          execution_time_in_hook = execution_time
        }
      }
      
      orchestrator = described_class.new(lifecycle_hooks: hooks)
      orchestrator.add_task(task)
      
      # Set up successful execution
      result = double("TaskResult", successful?: true, output: {"result" => "success"})
      allow(task).to receive(:perform).and_return(result)
      
      orchestrator.execute_plan(agent_provider)
      
      expect(hook_called).to be true
      expect(status_in_hook).to eq(:completed)
      expect(execution_time_in_hook).to be_a(Float)
      expect(execution_time_in_hook).to be >= 0
    end
  end
  
  describe "task cancellation" do
    it "cancels a pending task" do
      orchestrator = described_class.new
      orchestrator.add_task(task)
      
      # Task should be in pending state
      expect(orchestrator.execution_state[:pending]).to include(task.id)
      
      # Cancel the task
      result = orchestrator.cancel_task(task.id)
      
      expect(result).to be true
      expect(orchestrator.execution_state[:pending]).not_to include(task.id)
      expect(orchestrator.execution_state[:canceled]).to include(task.id)
    end
    
    it "returns false when trying to cancel a non-existent task" do
      orchestrator = described_class.new
      result = orchestrator.cancel_task("non-existent-task")
      expect(result).to be false
    end
    
    it "cancels all tasks in the plan" do
      orchestrator = described_class.new
      
      # Add multiple tasks
      task1 = Agentic::Task.new(
        description: "Task 1",
        agent_spec: {"instructions" => "You are a test agent"}
      )
      
      task2 = Agentic::Task.new(
        description: "Task 2",
        agent_spec: {"instructions" => "You are a test agent"}
      )
      
      orchestrator.add_task(task1)
      orchestrator.add_task(task2)
      
      # Both tasks should be in pending state
      expect(orchestrator.execution_state[:pending]).to include(task1.id)
      expect(orchestrator.execution_state[:pending]).to include(task2.id)
      
      # Cancel all tasks
      orchestrator.cancel_plan
      
      # Tasks should be in canceled state
      expect(orchestrator.execution_state[:pending]).not_to include(task1.id)
      expect(orchestrator.execution_state[:pending]).not_to include(task2.id)
      expect(orchestrator.execution_state[:canceled]).to include(task1.id)
      expect(orchestrator.execution_state[:canceled]).to include(task2.id)
    end
  end
end