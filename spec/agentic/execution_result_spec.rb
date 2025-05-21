# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::ExecutionResult do
  let(:task_result1) do
    Agentic::TaskResult.new(
      task_id: "task-1",
      success: true,
      output: {"key" => "value"}
    )
  end

  let(:task_result2) do
    Agentic::TaskResult.new(
      task_id: "task-2",
      success: false,
      failure: Agentic::TaskFailure.new(
        message: "Task failed",
        type: "TestError"
      )
    )
  end

  let(:task1) { double("Task", id: "task-1", to_h: {"id" => "task-1", "description" => "Task 1"}) }
  let(:task2) { double("Task", id: "task-2", to_h: {"id" => "task-2", "description" => "Task 2"}) }

  let(:tasks) { {"task-1" => task1, "task-2" => task2} }
  let(:results) { {"task-1" => task_result1, "task-2" => task_result2} }

  let(:execution_result) do
    described_class.new(
      plan_id: "plan-123",
      status: :partial_failure,
      execution_time: 10.5,
      tasks: tasks,
      results: results
    )
  end

  describe "#initialize" do
    it "sets the plan_id, status, execution_time, tasks, and results" do
      expect(execution_result.plan_id).to eq("plan-123")
      expect(execution_result.status).to eq(:partial_failure)
      expect(execution_result.execution_time).to eq(10.5)
      expect(execution_result.tasks).to eq(tasks)
      expect(execution_result.results).to eq(results)
    end
  end

  describe "#task_result" do
    it "returns the result for a specific task" do
      expect(execution_result.task_result("task-1")).to eq(task_result1)
      expect(execution_result.task_result("task-2")).to eq(task_result2)
    end

    it "returns nil for a nonexistent task" do
      expect(execution_result.task_result("nonexistent")).to be_nil
    end
  end

  describe "#successful?" do
    it "returns true if the status is :completed" do
      result = described_class.new(
        plan_id: "plan-123",
        status: :completed,
        execution_time: 10.5,
        tasks: tasks,
        results: results
      )
      expect(result.successful?).to be true
    end

    it "returns false for other statuses" do
      expect(execution_result.successful?).to be false

      failed_result = described_class.new(
        plan_id: "plan-123",
        status: :failed,
        execution_time: 10.5,
        tasks: tasks,
        results: results
      )
      expect(failed_result.successful?).to be false
    end
  end

  describe "#partial_failure?" do
    it "returns true if the status is :partial_failure" do
      expect(execution_result.partial_failure?).to be true
    end

    it "returns false for other statuses" do
      completed_result = described_class.new(
        plan_id: "plan-123",
        status: :completed,
        execution_time: 10.5,
        tasks: tasks,
        results: results
      )
      expect(completed_result.partial_failure?).to be false

      failed_result = described_class.new(
        plan_id: "plan-123",
        status: :failed,
        execution_time: 10.5,
        tasks: tasks,
        results: results
      )
      expect(failed_result.partial_failure?).to be false
    end
  end

  describe "#failed?" do
    it "returns true if the status is :failed" do
      failed_result = described_class.new(
        plan_id: "plan-123",
        status: :failed,
        execution_time: 10.5,
        tasks: tasks,
        results: results
      )
      expect(failed_result.failed?).to be true
    end

    it "returns false for other statuses" do
      expect(execution_result.failed?).to be false

      completed_result = described_class.new(
        plan_id: "plan-123",
        status: :completed,
        execution_time: 10.5,
        tasks: tasks,
        results: results
      )
      expect(completed_result.failed?).to be false
    end
  end

  describe "#to_h" do
    it "returns a hash representation of the execution result" do
      allow(task1).to receive(:is_a?).with(Agentic::Task).and_return(true)
      allow(task2).to receive(:is_a?).with(Agentic::Task).and_return(true)

      allow(task_result1).to receive(:is_a?).with(Agentic::TaskResult).and_return(true)
      allow(task_result1).to receive(:to_h).and_return({"success" => true, "output" => {"key" => "value"}})

      allow(task_result2).to receive(:is_a?).with(Agentic::TaskResult).and_return(true)
      allow(task_result2).to receive(:to_h).and_return({"success" => false, "failure" => {"message" => "Task failed"}})

      expect(execution_result.to_h).to include(
        plan_id: "plan-123",
        status: :partial_failure,
        execution_time: 10.5
      )

      expect(execution_result.to_h[:tasks]).to include(
        "task-1" => {"id" => "task-1", "description" => "Task 1"},
        "task-2" => {"id" => "task-2", "description" => "Task 2"}
      )

      expect(execution_result.to_h[:results]).to include(
        "task-1" => {"success" => true, "output" => {"key" => "value"}},
        "task-2" => {"success" => false, "failure" => {"message" => "Task failed"}}
      )
    end
  end

  describe "#summary" do
    it "returns a summary of the execution result" do
      allow(task_result1).to receive(:successful?).and_return(true)
      allow(task_result2).to receive(:successful?).and_return(false)
      allow(task_result1).to receive(:failed?).and_return(false)
      allow(task_result2).to receive(:failed?).and_return(true)

      summary = execution_result.summary
      expect(summary[:plan_id]).to eq("plan-123")
      expect(summary[:status]).to eq(:partial_failure)
      expect(summary[:execution_time]).to eq(10.5)
      expect(summary[:task_counts][:total]).to eq(2)
      expect(summary[:task_counts][:successful]).to eq(1)
      expect(summary[:task_counts][:failed]).to eq(1)
    end
  end
end
