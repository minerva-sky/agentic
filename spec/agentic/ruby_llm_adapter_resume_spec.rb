# frozen_string_literal: true

require "spec_helper"
require "json"

# A tool-level pause and its resume on real RubyLLM chats (ADR-023 point 7,
# 1b-b2b). Only Chat#complete is stubbed, standing in for the model: the
# first turn asks for a tool call that needs approval, the resumed turn runs
# the approved tool and answers. Everything between (pause questions, the
# chat_state JSON trip, ToolAnswers, the rebuilt chat) is the real thing.
RSpec.describe Agentic::RubyLlmAdapter, "resuming a tool-level pause" do
  before(:all) { require "ruby_llm" }

  let(:paint_tool) do
    Class.new(RubyLLM::Tool) do
      def self.name = "PaintTool"

      description "Paints the fence"
      parameter :colour, description: "Paint colour"
      requires_approval

      def execute(colour:) = "painted #{colour}"
    end
  end

  let(:context) { RubyLLM.context { |c| c.openai_api_key = "test" } }
  let(:chats) { [] }
  let(:spy_context) do
    ctx = context
    built = chats
    double("RubyLLM::Context").tap do |d|
      allow(d).to receive(:chat) { |**kw| ctx.chat(**kw).tap { |c| built << c } }
    end
  end
  let(:adapter) { described_class.new(context: spy_context, provider: :openai, assume_model_exists: true, tools: [paint_tool]) }
  let(:parameters) { {model: "test-model", messages: [{role: "user", content: "paint the fence red"}]} }

  def model_asks_for_paint(chat)
    chat.define_singleton_method(:complete) do
      add_message(role: :assistant, content: "", tool_calls: {
        "call_1" => RubyLLM::ToolCall.new(id: "call_1", name: tools.values.first.name, arguments: {colour: "red"})
      })
      messages.last
    end
  end

  def model_finishes(chat)
    chat.define_singleton_method(:complete) do
      run_tools
      add_message(role: :assistant, content: "The fence is red.")
      messages.last
    end
  end

  def pause_then_journal
    allow(spy_context).to receive(:chat) { |**kw| context.chat(**kw).tap { |c| model_asks_for_paint(c) && chats << c } }
    adapter.chat(parameters: parameters)
  rescue Agentic::Errors::ToolInputRequiredError => e
    # What the journal stores and replays: JSON, symbol keys at the top
    JSON.parse(JSON.generate(questions: e.questions, chat_state: e.chat_state), symbolize_names: true)
      .then { |h| {questions: h[:questions], chat_state: JSON.parse(JSON.generate(e.chat_state))} }
  end

  def resume_with(pause, answer)
    allow(spy_context).to receive(:chat) { |**kw| context.chat(**kw).tap { |c| model_finishes(c) && chats << c } }
    adapter.chat(parameters: parameters, tool_resume: Agentic::ToolAnswers.resolve(pause, answer))
  end

  it "pauses on the approval, then runs the approved tool and returns the reply on resume" do
    pause = pause_then_journal
    expect(pause[:questions].map { |q| q[:kind] }).to eq(["approval"])

    result = resume_with(pause, "yes")

    expect(result.dig("choices", 0, "message", "content")).to eq("The fence is red.")
    tool_result = chats.last.messages.find(&:tool_result?)
    expect(tool_result.content).to eq("painted red")
    expect(chats.last.messages.first.content).to eq("paint the fence red")
  end

  it "gives the model a refusal instead of running a declined tool" do
    result = resume_with(pause_then_journal, "no")

    expect(result.dig("choices", 0, "message", "content")).to eq("The fence is red.")
    expect(chats.last.messages.find(&:tool_result?).content.to_s).not_to include("painted")
  end

  it "rebuilds the conversation from chat_state, not from the new request's messages" do
    pause = pause_then_journal
    resume_with(pause, "yes")

    expect(chats.last.messages.map(&:role).first(2)).to eq(%i[user assistant])
    expect(chats.last.messages.first.content).to eq("paint the fence red")
  end

  it "refuses a resume on an adapter with no tools" do
    bare = described_class.new(context: spy_context)

    expect { bare.chat(parameters: parameters, tool_resume: {"answers" => {}, "chat_state" => {}}) }
      .to raise_error(ArgumentError, /no tools/)
  end

  it "refuses a resume whose chat_state has no messages" do
    expect { adapter.chat(parameters: parameters, tool_resume: {"answers" => {}, "chat_state" => {"tool_call_state" => {"version" => 1}}}) }
      .to raise_error(ArgumentError, /no chat_state messages/)
  end
end
