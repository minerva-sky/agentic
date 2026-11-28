# frozen_string_literal: true

require "json"

module Agentic
  # Speaks the same `chat(parameters:)` contract LlmClient uses with
  # ruby-openai, but sends the request through RubyLLM. Takes OpenAI-shaped
  # parameters and returns an OpenAI-shaped response hash, so LlmClient's
  # refusal, parse, and LlmResponse handling stay unchanged when the
  # transport swaps.
  #
  # RubyLLM and Faraday exceptions come back out as agentic's typed errors
  # (via RubyLlmErrorMap), which RetryHandler and the intervention pause
  # already branch on.
  class RubyLlmAdapter
    # Parameters with a dedicated RubyLLM setter. Everything else non-nil
    # rides through `with_provider_options`.
    HANDLED = %i[model messages temperature max_tokens response_format stream].freeze

    # Builds an adapter from agentic's runtime configuration: the access
    # token and base URL go into a private RubyLLM context (never the global
    # RubyLLM config), and a custom base URL means a local or proxy endpoint
    # whose model names RubyLLM's registry won't know.
    # @param configuration [LegacyConfiguration]
    # @return [RubyLlmAdapter]
    def self.from_configuration(configuration)
      require "ruby_llm"

      base_url = configuration.api_base_url
      context = RubyLLM.context do |c|
        # Local endpoints ignore the key but RubyLLM requires one
        c.openai_api_key = configuration.access_token || "local"
        c.openai_api_base = base_url if base_url
      end

      new(context: context, provider: :openai, assume_model_exists: !base_url.nil?)
    end

    # @param context [RubyLLM::Context, #chat] where chats are built; a
    #   context keeps per-client keys and base URLs off the global config
    # @param provider [Symbol, nil] force a provider (e.g. :ollama, :openai)
    # @param assume_model_exists [Boolean] skip RubyLLM's model registry
    #   lookup, needed for local and custom model names
    # @param tools [Array<RubyLLM::Tool, Class>] tools the chat may call. A
    #   tool declared with requires_approval, or one that calls Tool#ask,
    #   can pause the chat for a person (ADR-023 point 7)
    def initialize(context:, provider: nil, assume_model_exists: false, tools: [])
      @context = context
      @provider = provider
      @assume_model_exists = assume_model_exists
      @tools = Array(tools)
    end

    # @param parameters [Hash] OpenAI chat-completions parameters
    # @return [Hash] OpenAI chat-completions response shape
    # @raise [Errors::LlmError] typed error for any RubyLLM/Faraday failure
    def chat(parameters:)
      params = parameters.transform_keys(&:to_sym)
      state = JournalToolCallState.new unless @tools.empty?
      chat = build_chat(params, state)
      stream = params[:stream]

      message = if stream.respond_to?(:call)
        chat.complete { |chunk| forward_chunk(chunk, stream) }
      else
        chat.complete
      end

      raise_if_waiting_on_person(chat, state)
      to_openai_response(message)
    rescue Errors::LlmError, Errors::ToolInputRequiredError
      raise
    rescue => e
      typed = RubyLlmErrorMap.translate(e)
      raise(typed || e)
    end

    private

    def build_chat(params, state)
      chat = @context.chat(
        model: params[:model],
        provider: @provider,
        assume_model_exists: @assume_model_exists
      )

      Array(params[:messages]).each do |msg|
        msg = msg.transform_keys(&:to_sym)
        chat.add_message(role: msg[:role].to_sym, content: msg[:content])
      end

      chat.with_temperature(params[:temperature]) unless params[:temperature].nil?
      chat.with_max_output_tokens(params[:max_tokens]) if params[:max_tokens]

      schema = json_schema(params[:response_format])
      chat.with_schema(schema) if schema

      extra = params.except(*HANDLED).compact
      chat.with_provider_options(extra) unless extra.empty?

      attach_tools(chat, state)
      chat
    end

    # Tools get a journal-backed tool-call state, so a pause can carry it
    # out in the task_awaiting_human event and a resumed run can rebuild it.
    def attach_tools(chat, state)
      return unless state

      chat.with_tools(*@tools)
      chat.send(:tool_call_state=, state)
    end

    # A chat whose turn ended on tool calls that wait for an approval or an
    # answer has no final reply yet. Raise so the orchestrator pauses the
    # task instead of parsing a half-finished turn.
    def raise_if_waiting_on_person(chat, state)
      return unless state

      questions = chat.pending_questions
      return if questions.empty?

      raise Errors::ToolInputRequiredError.from_questions(questions, chat_state: chat_state(chat, state))
    end

    def chat_state(chat, state)
      {
        "messages" => chat.messages.map { |m| JSON.parse(JSON.generate(m.to_h)) },
        "tool_call_state" => state.to_h
      }
    end

    def json_schema(response_format)
      return nil unless response_format.is_a?(Hash)

      format = response_format.transform_keys(&:to_sym)
      (format[:type].to_s == "json_schema") ? format[:json_schema] : nil
    end

    # ruby-openai's stream proc receives (chunk_hash, bytesize)
    def forward_chunk(chunk, stream)
      content = chunk.respond_to?(:content) ? chunk.content : nil
      return if content.nil? || content == ""

      stream.call({"choices" => [{"delta" => {"content" => content}}]}, nil)
    end

    def to_openai_response(message)
      {
        "model" => message.model,
        "choices" => [{
          "index" => 0,
          "message" => {"role" => "assistant", "content" => serialize(message.content)},
          "finish_reason" => message.finish_reason&.to_s
        }],
        "usage" => usage(message.tokens)
      }
    end

    # ruby_llm 2.2.3 keeps Message#content a String (structured data lives on
    # #parsed); guard anyway, since LlmClient JSON-parses the content itself.
    def serialize(content)
      (content.is_a?(Hash) || content.is_a?(Array)) ? JSON.generate(content) : content
    end

    def usage(tokens)
      return nil unless tokens

      input = tokens.input
      output = tokens.output
      return nil if input.nil? && output.nil?

      {
        "prompt_tokens" => input,
        "completion_tokens" => output,
        "total_tokens" => input.to_i + output.to_i
      }.compact
    end
  end
end
