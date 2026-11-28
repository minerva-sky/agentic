# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "json"
require "ruby_llm"

# ADR-023 point 7, 1b-b: when a tool inside an agent's chat waits on a
# person, the pause event carries the questions and the chat state so
# another process can answer and resume.
RSpec.describe "tool-level pause" do
  let(:call_class) { Struct.new(:id, :name, :namespace, keyword_init: true) }
  let(:choice_question) { RubyLLM::Question.asked(0, "Which colour?", choices: %w[red blue]) }
  let(:approval) { RubyLLM::Question.approval(call_class.new(id: "call_w", name: "write_file"), chat: nil) }
  let(:form_question) do
    RubyLLM::Question.asked(1, "Ship it?", schema: {
      "type" => "object",
      "properties" => {"size" => {"type" => "string", "enum" => %w[s l]}, "note" => {"type" => "string"}},
      "required" => ["size"]
    })
  end
  let(:chat_state) { {"messages" => [{"role" => "user", "content" => "paint it"}], "tool_call_state" => {"version" => 1}} }

  describe Agentic::Errors::ToolInputRequiredError do
    it "serializes a question with choices" do
      entry = described_class.serialize_question(choice_question)

      expect(entry).to eq("id" => choice_question.id, "kind" => "input", "message" => "Which colour?",
        "choices" => %w[red blue])
    end

    it "serializes an approval with its tool call id and a default message" do
      expect(described_class.serialize_question(approval))
        .to eq("id" => "call_w", "kind" => "approval", "message" => "Allow write_file to run?")
    end

    it "lists fields for a question that asks for several values" do
      entry = described_class.serialize_question(form_question)

      expect(entry["kind"]).to eq("input")
      expect(entry).not_to have_key("choices")
      expect(entry["fields"].map { |f| f["name"] }).to eq(%i[size note])
      expect(entry["fields"].first).to include("required" => true, "choices" => %w[s l])
    end

    it "builds from pending questions, summarizes them in its message, and does not retry" do
      error = described_class.from_questions([choice_question, approval], chat_state: chat_state)

      expect(error.questions.map { |q| q["kind"] }).to eq(%w[input approval])
      expect(error.chat_state).to eq(chat_state)
      expect(error.message).to eq("tool needs input from a person: Which colour?; Allow write_file to run?")
      expect(error.retryable?).to be(false)
    end

    it "produces JSON-safe questions" do
      error = described_class.from_questions([choice_question, approval, form_question], chat_state: chat_state)

      expect { JSON.generate(error.questions) }.not_to raise_error
    end
  end

  describe Agentic::TaskFailure do
    it "carries the pause outside the sanitized context" do
      error = Agentic::Errors::ToolInputRequiredError.from_questions([choice_question], chat_state: chat_state)
      failure = described_class.from_exception(error)

      expect(failure.type).to eq("Agentic::Errors::ToolInputRequiredError")
      expect(failure.pause[:chat_state]).to eq(chat_state)
      expect(failure.pause[:questions].first["message"]).to eq("Which colour?")
      expect(failure.context).not_to have_key(:chat_state)
    end

    it "has no pause for an ordinary failure" do
      expect(described_class.from_exception(RuntimeError.new("boom")).pause).to be_nil
    end
  end

  describe "orchestrator" do
    it "treats a tool-level pause as needing a human" do
      orchestrator = Agentic::PlanOrchestrator.new
      failure = Agentic::TaskFailure.new(message: "x", type: "Agentic::Errors::ToolInputRequiredError")

      expect(orchestrator.send(:requires_intervention?, failure: failure)).to be(true)
    end
  end

  describe Agentic::ExecutionJournal do
    let(:dir) { Dir.mktmpdir("agentic_tool_pause") }
    let(:path) { File.join(dir, "plan.journal.jsonl") }
    let(:journal) { described_class.new(path: path) }
    let(:task) { Struct.new(:description).new("paint the fence") }

    after { FileUtils.remove_entry(dir) }

    def pause_with(failure)
      journal.lifecycle_hooks[:task_awaiting_human].call(task_id: "t-1", task: task, failure: failure)
    end

    it "records questions and chat_state on the pause event and replays them" do
      error = Agentic::Errors::ToolInputRequiredError.from_questions([choice_question, approval], chat_state: chat_state)
      pause_with(Agentic::TaskFailure.from_exception(error))

      entry = described_class.replay(path: path).awaiting_human["t-1"]
      expect(entry[:question]).to start_with("tool needs input from a person: Which colour?")
      expect(entry[:questions].map { |q| q[:kind] }).to eq(%w[input approval])
      expect(entry[:questions].first[:choices]).to eq(%w[red blue])
      expect(entry[:chat_state][:messages].first[:content]).to eq("paint it")
    end

    it "round-trips a JournalToolCallState through the pause event" do
      state = Agentic::JournalToolCallState.new
      state.record_decision("call_w", true)
      error = Agentic::Errors::ToolInputRequiredError.from_questions([approval],
        chat_state: {"tool_call_state" => state.to_h})
      pause_with(Agentic::TaskFailure.from_exception(error))

      replayed = described_class.replay(path: path).awaiting_human["t-1"][:chat_state][:tool_call_state]
      restored = Agentic::JournalToolCallState.from_h(replayed)
      expect(restored.decision(call_class.new(id: "call_w", name: "write_file"))).to be(true)
    end

    it "keeps the old shape for a task-level pause" do
      pause_with(Agentic::TaskFailure.new(message: "401 from provider", type: "AuthenticationError"))

      entry = described_class.replay(path: path).awaiting_human["t-1"]
      expect(entry).not_to have_key(:questions)
      expect(entry).not_to have_key(:chat_state)
      expect(File.read(path)).not_to include("questions")
    end
  end
end
