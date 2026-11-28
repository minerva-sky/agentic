# frozen_string_literal: true

require "spec_helper"

# ADR-023 point 7, 1b-c: answers to a tool-level pause are checked against
# the recorded questions, and approvals land in the chat's tool-call state.
RSpec.describe Agentic::ToolAnswers do
  let(:call_class) { Struct.new(:id, :name, :namespace, keyword_init: true) }
  let(:pause) do
    {questions: [{id: "q1", kind: "input", message: "Which colour?", choices: %w[red blue]},
      {id: "call_w", kind: "approval", message: "Allow write_file to run?"},
      {id: "q2", kind: "input", message: "Why?"}],
     chat_state: {messages: [{role: "user"}], tool_call_state: {version: 1, decisions: {}}}}
  end

  it "keys answers by question id and records approvals as decisions" do
    resolved = described_class.resolve(pause, "q1" => "red", :call_w => "No", "q2" => "because")

    expect(resolved["answers"]).to eq("q1" => "red", "call_w" => false, "q2" => "because")
    state = Agentic::JournalToolCallState.from_h(resolved["chat_state"]["tool_call_state"])
    expect(state.decision(call_class.new(id: "call_w", name: "write_file"))).to be(false)
    expect(resolved["chat_state"]["messages"]).to eq([{role: "user"}])
  end

  it "takes a plain answer when one question is open" do
    one = {questions: [{id: "q2", kind: "input", message: "Why?"}], chat_state: nil}

    expect(described_class.resolve(one, "because")).to eq("answers" => {"q2" => "because"}, "chat_state" => {})
  end

  it "accepts a partial answer, leaving the rest for the chat to ask again" do
    expect(described_class.resolve(pause, "q2" => "x")["answers"]).to eq("q2" => "x")
  end

  it "refuses unknown ids, values outside the choices, unclear approvals, and empty or bare answers" do
    expect { described_class.resolve(pause, "nope" => "x") }.to raise_error(ArgumentError, /no open question nope/)
    expect { described_class.resolve(pause, "q1" => "green") }.to raise_error(ArgumentError, /one of red, blue/)
    expect { described_class.resolve(pause, "call_w" => "maybe") }.to raise_error(ArgumentError, /yes or no/)
    expect { described_class.resolve(pause, {}) }.to raise_error(ArgumentError, /no answers/)
    expect { described_class.resolve(pause, "red") }.to raise_error(ArgumentError, /3 questions are open/)
  end

  it "refuses a chat state from an unknown format version" do
    bad = pause.merge(chat_state: {tool_call_state: {version: 9}})

    expect { described_class.resolve(bad, "call_w" => "yes") }.to raise_error(ArgumentError, /unknown chat_state version/)
  end

  describe "through the orchestrator" do
    it "names the task when an answer does not fit, and journals nothing" do
      orchestrator = Agentic::PlanOrchestrator.new
      task = Agentic::Task.new(description: "paint", agent_spec: {"name" => "Painter"})
      orchestrator.add_task(task)
      state = Agentic::ExecutionJournal::ReplayedState.new(
        awaiting_human: {task.id => pause}, human_answers: {}, descriptions: {}, path: "x"
      )
      answered = []
      orchestrator.instance_variable_get(:@lifecycle_hooks)[:task_human_answered] = ->(**kw) { answered << kw }

      expect { orchestrator.send(:deliver_human_answers, state, {task.id => {"q1" => "green"}}) }
        .to raise_error(ArgumentError, /task #{task.id}: question q1 takes one of red, blue/)
      expect(answered).to be_empty

      orchestrator.send(:deliver_human_answers, state, {task.id => {"q1" => "blue"}})
      expect(task.input[:human_answer]).to eq("q1" => "blue")
      expect(task.input[:tool_resume]["answers"]).to eq("q1" => "blue")
    end
  end
end
