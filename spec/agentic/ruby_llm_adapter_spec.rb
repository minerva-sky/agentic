# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::RubyLlmAdapter do
  # Records every setter call so specs can assert the translation without
  # loading ruby_llm or touching the network.
  let(:fake_chat_class) do
    Class.new do
      attr_reader :calls, :reply, :chunks
      attr_accessor :error

      def initialize(reply, chunks = [])
        @reply = reply
        @chunks = chunks
        @calls = []
      end

      %i[add_message with_temperature with_max_output_tokens with_schema with_provider_options].each do |name|
        define_method(name) do |*args, **kwargs|
          @calls << [name, kwargs.empty? ? args.first : kwargs]
          self
        end
      end

      def complete
        raise error if error
        chunks.each { |c| yield c } if block_given?
        reply
      end
    end
  end

  let(:tokens) { Struct.new(:input, :output).new(12, 5) }
  let(:reply) do
    Struct.new(:content, :model, :finish_reason, :tokens).new("hi there", "gpt-4o-mini", :stop, tokens)
  end
  let(:chat) { fake_chat_class.new(reply) }
  let(:context) { double("RubyLLM::Context", chat: chat) }
  let(:adapter) { described_class.new(context: context, provider: :openai, assume_model_exists: true) }

  let(:parameters) do
    {
      model: "gpt-4o-mini",
      messages: [{role: "system", content: "be terse"}, {"role" => "user", "content" => "hello"}],
      temperature: 0.2,
      top_p: nil,
      max_tokens: 50
    }
  end

  it "builds the chat with model, provider, and registry bypass" do
    adapter.chat(parameters: parameters)

    expect(context).to have_received(:chat).with(model: "gpt-4o-mini", provider: :openai, assume_model_exists: true)
  end

  it "adds every message in order, with symbol roles" do
    adapter.chat(parameters: parameters)

    added = chat.calls.filter_map { |name, arg| arg if name == :add_message }
    expect(added).to eq([{role: :system, content: "be terse"}, {role: :user, content: "hello"}])
  end

  it "maps temperature and max_tokens onto RubyLLM setters and drops nil extras" do
    adapter.chat(parameters: parameters)

    expect(chat.calls).to include([:with_temperature, 0.2], [:with_max_output_tokens, 50])
    expect(chat.calls.map(&:first)).not_to include(:with_provider_options)
  end

  it "passes unmapped parameters through provider options" do
    adapter.chat(parameters: parameters.merge(top_p: 0.9, presence_penalty: 0.1))

    expect(chat.calls).to include([:with_provider_options, {top_p: 0.9, presence_penalty: 0.1}])
  end

  it "hands a json_schema response_format to with_schema" do
    schema = {name: "answer", schema: {type: "object", properties: {}}}
    adapter.chat(parameters: parameters.merge(response_format: {type: "json_schema", json_schema: schema}))

    expect(chat.calls).to include([:with_schema, schema])
  end

  it "returns an OpenAI-shaped response LlmClient already reads" do
    response = adapter.chat(parameters: parameters)

    expect(response.dig("choices", 0, "message", "content")).to eq("hi there")
    expect(response.dig("choices", 0, "message", "refusal")).to be_nil
    expect(response.dig("choices", 0, "finish_reason")).to eq("stop")
    expect(response["model"]).to eq("gpt-4o-mini")
    expect(response["usage"]).to eq("prompt_tokens" => 12, "completion_tokens" => 5, "total_tokens" => 17)
  end

  it "re-serializes parsed structured content to a JSON string" do
    reply.content = {"answer" => 42}

    response = adapter.chat(parameters: parameters)

    expect(JSON.parse(response.dig("choices", 0, "message", "content"))).to eq("answer" => 42)
  end

  it "forwards streamed chunks in ruby-openai's delta shape, skipping empty ones" do
    chunk = Struct.new(:content)
    streaming_chat = fake_chat_class.new(reply, [chunk.new("hi "), chunk.new(nil), chunk.new("there")])
    allow(context).to receive(:chat).and_return(streaming_chat)
    seen = []

    adapter.chat(parameters: parameters.merge(stream: proc { |c, _bytes| seen << c.dig("choices", 0, "delta", "content") }))

    expect(seen).to eq(["hi ", "there"])
    expect(streaming_chat.calls.map(&:first)).not_to include(:with_provider_options)
  end

  context "when RubyLLM raises" do
    before do
      stub_const("RubyLLM::Error", Class.new(StandardError))
      stub_const("RubyLLM::UnauthorizedError", Class.new(RubyLLM::Error))
    end

    it "raises the typed agentic error" do
      chat.error = RubyLLM::UnauthorizedError.new("bad key")

      expect { adapter.chat(parameters: parameters) }
        .to raise_error(Agentic::Errors::LlmAuthenticationError, /bad key/)
    end

    it "lets unknown exceptions through unchanged" do
      chat.error = ArgumentError.new("nope")

      expect { adapter.chat(parameters: parameters) }.to raise_error(ArgumentError, "nope")
    end
  end

  describe "tools that pause for a person (ADR-023 point 7)" do
    # JournalToolCallState subclasses RubyLLM's state, so these load it
    before(:all) { require "ruby_llm" }

    let(:tool) { Class.new }
    let(:message) { Struct.new(:role, :content).new(:user, "paint it") }
    let(:tool_chat) do
      msg = message
      fake_chat_class.new(reply).tap do |c|
        c.define_singleton_method(:with_tools) { |*tools| (@tools = tools) && self }
        c.define_singleton_method(:tools) { @tools }
        c.define_singleton_method(:tool_call_state=) { |s| @state = s }
        c.define_singleton_method(:state) { @state }
        c.define_singleton_method(:pending_questions) { @pending || [] }
        c.define_singleton_method(:pending=) { |q| @pending = q }
        c.define_singleton_method(:messages) { [msg] }
        message.define_singleton_method(:to_h) { {role: role, content: content} }
      end
    end
    let(:tool_context) { double("RubyLLM::Context", chat: tool_chat) }
    let(:tool_adapter) { described_class.new(context: tool_context, tools: [tool]) }

    it "registers the tools and swaps in a journal-backed tool-call state" do
      tool_adapter.chat(parameters: parameters)

      expect(tool_chat.tools).to eq([tool])
      expect(tool_chat.state).to be_a(Agentic::JournalToolCallState)
    end

    it "returns the reply when nothing waits on a person" do
      result = tool_adapter.chat(parameters: parameters)

      expect(result.dig("choices", 0, "message", "content")).to eq("hi there")
    end

    it "raises ToolInputRequiredError with the questions and chat_state when the turn pauses" do
      tool_chat.pending = [RubyLLM::Question.asked(0, "Which colour?", choices: %w[red blue])]

      expect { tool_adapter.chat(parameters: parameters) }.to raise_error(Agentic::Errors::ToolInputRequiredError) { |error|
        expect(error.questions.first).to include("kind" => "input", "message" => "Which colour?", "choices" => %w[red blue])
        expect(error.chat_state["messages"]).to eq([{"role" => "user", "content" => "paint it"}])
        expect(error.chat_state["tool_call_state"]).to include("version" => 1)
        expect(JSON.parse(JSON.generate(error.chat_state))).to eq(error.chat_state)
      }
    end

    it "leaves chats without tools alone" do
      adapter.chat(parameters: parameters)

      expect(chat).not_to respond_to(:with_tools)
    end
  end
end
