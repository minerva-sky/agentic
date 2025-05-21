# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::PlanExecutionResult do
  let(:plan_id) { "plan-123" }
  let(:status) { :completed }
  let(:execution_time) { 10.5 }

  let(:tasks) do
    {
      "task-1" => {id: "task-1", description: "Task 1", status: :completed},
      "task-2" => {id: "task-2", description: "Task 2", status: :completed},
      "task-3" => {id: "task-3", description: "Task 3", status: :failed}
    }
  end

  let(:results) do
    {
      "task-1" => {status: :completed, output: {result: "success"}, failure: nil},
      "task-2" => {status: :completed, output: {result: "success"}, failure: nil},
      "task-3" => {status: :failed, output: nil, failure: {message: "Error", type: "ErrorType"}}
    }
  end

  let(:plan_result) { described_class.new(plan_id: plan_id, status: status, execution_time: execution_time, tasks: tasks, results: results) }

  describe "#initialize" do
    it "initializes with the provided attributes" do
      expect(plan_result.plan_id).to eq(plan_id)
      expect(plan_result.status).to eq(status)
      expect(plan_result.execution_time).to eq(execution_time)
      expect(plan_result.tasks).to eq(tasks)
      expect(plan_result.results).to be_a(Hash)
      expect(plan_result.results.values.all? { |r| r.is_a?(Agentic::TaskExecutionResult) }).to be true
    end
  end

  describe ".from_hash" do
    it "creates a result from a hash" do
      hash = {
        plan_id: plan_id,
        status: status,
        execution_time: execution_time,
        tasks: tasks,
        results: results
      }

      result = described_class.from_hash(hash)
      expect(result).to be_a(described_class)
      expect(result.plan_id).to eq(plan_id)
      expect(result.status).to eq(status)
      expect(result.execution_time).to eq(execution_time)
    end
  end

  describe "#successful?" do
    it "returns true when status is :completed" do
      expect(plan_result.successful?).to be true
    end

    it "returns false when status is not :completed" do
      result = described_class.new(
        plan_id: plan_id,
        status: :partial_failure,
        execution_time: execution_time,
        tasks: tasks,
        results: results
      )
      expect(result.successful?).to be false
    end
  end

  describe "#partial_failure?" do
    it "returns true when status is :partial_failure" do
      result = described_class.new(
        plan_id: plan_id,
        status: :partial_failure,
        execution_time: execution_time,
        tasks: tasks,
        results: results
      )
      expect(result.partial_failure?).to be true
    end

    it "returns false when status is not :partial_failure" do
      expect(plan_result.partial_failure?).to be false
    end
  end

  describe "#in_progress?" do
    it "returns true when status is :in_progress" do
      result = described_class.new(
        plan_id: plan_id,
        status: :in_progress,
        execution_time: execution_time,
        tasks: tasks,
        results: results
      )
      expect(result.in_progress?).to be true
    end

    it "returns false when status is not :in_progress" do
      expect(plan_result.in_progress?).to be false
    end
  end

  describe "#task_result" do
    it "returns the result for a specific task" do
      result = plan_result.task_result("task-1")
      expect(result).to be_a(Agentic::TaskExecutionResult)
      expect(result.status).to eq(:completed)
      expect(result.output).to eq({result: "success"})
    end

    it "returns nil for a non-existent task" do
      expect(plan_result.task_result("non-existent")).to be_nil
    end
  end

  describe "#task_data" do
    it "returns the task data for a specific task" do
      data = plan_result.task_data("task-1")
      expect(data).to eq(tasks["task-1"])
    end

    it "returns nil for a non-existent task" do
      expect(plan_result.task_data("non-existent")).to be_nil
    end
  end

  describe "#completed_tasks_count" do
    it "returns the number of completed tasks" do
      expect(plan_result.completed_tasks_count).to eq(2)
    end
  end

  describe "#failed_tasks_count" do
    it "returns the number of failed tasks" do
      expect(plan_result.failed_tasks_count).to eq(1)
    end
  end

  describe "#successful_task_results" do
    it "returns the successful task results" do
      successful = plan_result.successful_task_results
      expect(successful.size).to eq(2)
      expect(successful.keys).to contain_exactly("task-1", "task-2")
    end
  end

  describe "#failed_task_results" do
    it "returns the failed task results" do
      failed = plan_result.failed_task_results
      expect(failed.size).to eq(1)
      expect(failed.keys).to contain_exactly("task-3")
    end
  end

  describe "#to_h" do
    it "returns a hash representation" do
      hash = plan_result.to_h
      expect(hash[:plan_id]).to eq(plan_id)
      expect(hash[:status]).to eq(status)
      expect(hash[:execution_time]).to eq(execution_time)
      expect(hash[:tasks]).to eq(tasks)
      expect(hash[:results]).to be_a(Hash)
    end
  end
end
