# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::Task do
  let(:description) { "Test task description" }
  let(:agent_spec) { {"instructions" => "You are a test agent"} }
  let(:input) { {"test_key" => "test_value"} }
  let(:task) { described_class.new(description: description, agent_spec: agent_spec, input: input) }

  describe "#initialize" do
    it "sets the basic attributes" do
      expect(task.id).not_to be_nil
      expect(task.description).to eq(description)
      expect(task.agent_spec).to eq(agent_spec)
      expect(task.input).to eq(input)
      expect(task.status).to eq(:pending)
      expect(task.output).to be_nil
      expect(task.failure).to be_nil
    end
  end

  describe "#perform" do
    let(:agent) { double("Agent") }
    let(:output) { {"result" => "test_result"} }

    context "when execution succeeds" do
      before do
        allow(agent).to receive(:execute).and_return(output)
      end

      it "updates the task status to completed" do
        task.perform(agent)
        expect(task.status).to eq(:completed)
      end

      it "sets the output" do
        task.perform(agent)
        expect(task.output).to eq(output)
      end

      it "returns a successful TaskResult" do
        result = task.perform(agent)
        expect(result).to be_a(Agentic::TaskResult)
        expect(result.successful?).to be true
        expect(result.output).to eq(output)
      end

      it "notifies observers of status changes" do
        observer = double("Observer")
        allow(observer).to receive(:update)

        task.add_observer(observer)

        expect(observer).to receive(:update).with(:status_change, task, :pending, :in_progress)
        expect(observer).to receive(:update).with(:status_change, task, :in_progress, :completed)

        task.perform(agent)
      end
    end

    context "when execution fails" do
      let(:error) { StandardError.new("Test error") }

      before do
        allow(error).to receive(:backtrace).and_return(["line1", "line2"])
        allow(agent).to receive(:execute).and_raise(error)
        allow(agent).to receive(:id).and_return("agent-123")
        allow(Agentic.logger).to receive(:error)
      end

      it "updates the task status to failed" do
        task.perform(agent)
        expect(task.status).to eq(:failed)
      end

      it "sets the failure" do
        task.perform(agent)
        expect(task.failure).to be_a(Agentic::TaskFailure)
        expect(task.failure.message).to eq("Test error")
        expect(task.failure.type).to eq("StandardError")
      end

      it "returns a failed TaskResult" do
        result = task.perform(agent)
        expect(result).to be_a(Agentic::TaskResult)
        expect(result.failed?).to be true
        expect(result.failure).to be_a(Agentic::TaskFailure)
      end

      it "logs the error" do
        expect(Agentic.logger).to receive(:error).with("Task execution failed: Test error")
        task.perform(agent)
      end

      it "notifies observers of status changes and failure" do
        observer = double("Observer")
        allow(observer).to receive(:update)

        task.add_observer(observer)

        expect(observer).to receive(:update).with(:status_change, task, :pending, :in_progress)
        expect(observer).to receive(:update).with(:status_change, task, :in_progress, :failed)
        expect(observer).to receive(:update).with(:failure_occurred, task, kind_of(Agentic::TaskFailure))

        task.perform(agent)
      end
    end
  end

  describe "#retry" do
    let(:agent) { double("Agent") }
    let(:output) { {"result" => "test_result"} }

    context "when task is in failed state" do
      before do
        allow(agent).to receive(:execute).and_return(output)
        task.instance_variable_set(:@status, :failed)
      end

      it "updates the task status to retrying then completed" do
        observer = double("Observer")
        allow(observer).to receive(:update)

        task.add_observer(observer)

        expect(observer).to receive(:update).with(:status_change, task, :failed, :retrying)
        expect(observer).to receive(:update).with(:status_change, task, :retrying, :in_progress)
        expect(observer).to receive(:update).with(:status_change, task, :in_progress, :completed)

        task.retry(agent)
        expect(task.status).to eq(:completed)
      end

      it "returns a successful TaskResult" do
        result = task.retry(agent)
        expect(result).to be_a(Agentic::TaskResult)
        expect(result.successful?).to be true
      end
    end

    context "when task is not in failed state" do
      it "raises an error" do
        expect { task.retry(agent) }.to raise_error("Cannot retry a task that is not in a failed state")
      end
    end
  end

  describe "#to_h" do
    it "returns a hash representation" do
      hash = task.to_h
      expect(hash).to be_a(Hash)
      expect(hash[:id]).to eq(task.id)
      expect(hash[:description]).to eq(task.description)
      expect(hash[:agent_spec]).to eq(task.agent_spec)
      expect(hash[:input]).to eq(task.input)
      expect(hash[:status]).to eq(task.status)
    end

    context "when task has failed" do
      before do
        failure = Agentic::TaskFailure.new(
          message: "Test failure",
          type: "TestError"
        )
        task.instance_variable_set(:@failure, failure)
      end

      it "includes failure information" do
        hash = task.to_h
        expect(hash[:failure]).to be_a(Hash)
        expect(hash[:failure][:message]).to eq("Test failure")
        expect(hash[:failure][:type]).to eq("TestError")
      end
    end
  end

  describe "#build_prompt" do
    it "formats the prompt correctly" do
      prompt = task.send(:build_prompt)
      expect(prompt).to include("[System Instructions]")
      expect(prompt).to include("You are a test agent")
      expect(prompt).to include("[Task Description]")
      expect(prompt).to include("Test task description")
      expect(prompt).to include("[Input Parameters]")
      expect(prompt).to include("test_key")
      expect(prompt).to include("test_value")
      expect(prompt).to include("[Output Requirements]")
    end
  end
end
