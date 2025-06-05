# frozen_string_literal: true

require "openai"
require "net/http"
require_relative "llm_response"
require_relative "errors/llm_error"
require_relative "retry_handler"
require_relative "retry_config"

module Agentic
  # Generic wrapper for LLM API clients
  class LlmClient
    # @return [OpenAI::Client] The underlying LLM client instance
    attr_reader :client, :last_response

    # @return [RetryHandler] The retry handler for transient errors
    attr_reader :retry_handler

    # Initializes a new LlmClient
    # @param config [LlmConfig] The configuration for the LLM
    # @param retry_config [RetryConfig, Hash] Configuration for the retry handler
    def initialize(config, retry_config = {})
      client_options = {access_token: Agentic.configuration.access_token}

      # Add custom base URL if configured (for Ollama, etc.)
      if Agentic.configuration.api_base_url
        client_options[:uri_base] = Agentic.configuration.api_base_url
      end

      @client = OpenAI::Client.new(client_options)
      @config = config
      @last_response = nil

      # Convert retry_config to RetryConfig if it's a hash
      @retry_handler = if retry_config.is_a?(RetryConfig)
        retry_config.to_handler
      else
        RetryHandler.new(**retry_config)
      end
    end

    # Sends a completion request to the LLM
    # @param messages [Array<Hash>] The messages to send
    # @param output_schema [Agentic::StructuredOutputs::Schema, nil] Optional schema for structured output
    # @param fail_on_error [Boolean] Whether to raise errors or return them as part of the response
    # @param use_retries [Boolean] Whether to retry on transient errors
    # @param options [Hash] Additional options to override the config
    # @return [LlmResponse] The structured response from the LLM
    def complete(messages, output_schema: nil, fail_on_error: false, use_retries: true, options: {})
      # Start with base parameters from the config
      parameters = @config.to_api_parameters({messages: messages})

      # Add response format if schema is provided
      if output_schema
        parameters[:response_format] = {
          type: "json_schema",
          json_schema: output_schema.to_hash
        }
      end

      # Override with any additional options
      parameters.merge!(options)

      execution_method = use_retries ? method(:with_retry) : method(:without_retry)
      execution_method.call(messages, parameters, output_schema, fail_on_error)
    end

    # Executes the API call with retries for transient errors
    # @param messages [Array<Hash>] The messages being sent
    # @param parameters [Hash] The request parameters
    # @param output_schema [Agentic::StructuredOutputs::Schema, nil] Optional schema for structured output
    # @param fail_on_error [Boolean] Whether to raise errors or return them as part of the response
    # @return [LlmResponse] The structured response from the LLM
    def with_retry(messages, parameters, output_schema, fail_on_error)
      retry_handler.with_retry do
        without_retry(messages, parameters, output_schema, fail_on_error)
      end
    rescue Errors::LlmError => e
      # If we get here, we've exhausted retries or hit a non-retryable error
      Agentic.logger.error("Failed after retries: #{e.message}")
      handle_error(e, fail_on_error)
    end

    # Executes the API call without retries
    # @param messages [Array<Hash>] The messages being sent
    # @param parameters [Hash] The request parameters
    # @param output_schema [Agentic::StructuredOutputs::Schema, nil] Optional schema for structured output
    # @param fail_on_error [Boolean] Whether to raise errors or return them as part of the response
    # @return [LlmResponse] The structured response from the LLM
    def without_retry(messages, parameters, output_schema, fail_on_error)
      @last_response = client.chat(parameters: parameters)

      # Check for API-level refusal
      if (refusal = @last_response.dig("choices", 0, "message", "refusal"))
        refusal_error = Errors::LlmRefusalError.new(
          refusal,
          response: @last_response,
          context: {input_messages: extract_message_content(messages)}
        )

        Agentic.logger.warn("LLM refused the request: #{refusal} (Category: #{refusal_error.refusal_category})")

        if fail_on_error
          raise refusal_error
        else
          return LlmResponse.refusal(@last_response, refusal, refusal_error)
        end
      end

      # Process the response based on whether we expect structured output
      if output_schema
        begin
          content_text = @last_response.dig("choices", 0, "message", "content")
          if content_text.nil? || content_text.empty?
            error = Errors::LlmParseError.new("Empty content returned from LLM", response: @last_response)
            Agentic.logger.error(error.message)
            return handle_error(error, fail_on_error)
          end

          content = JSON.parse(content_text)
          LlmResponse.success(@last_response, content)
        rescue JSON::ParserError => e
          error = Errors::LlmParseError.new(
            "Failed to parse JSON response: #{e.message}",
            parse_exception: e,
            response: @last_response
          )
          Agentic.logger.error(error.message)
          handle_error(error, fail_on_error)
        end
      else
        content = @last_response.dig("choices", 0, "message", "content")
        LlmResponse.success(@last_response, content)
      end
    rescue OpenAI::Error => e
      error = map_openai_error(e)
      Agentic.logger.error("OpenAI API error: #{error.message}")
      handle_error(error, fail_on_error)
    rescue Net::ReadTimeout, Net::OpenTimeout => e
      error = Errors::LlmTimeoutError.new("Request to LLM timed out: #{e.message}", context: {timeout_type: e.class.name})
      Agentic.logger.error(error.message)
      handle_error(error, fail_on_error)
    rescue JSON::ParserError => e
      error = Errors::LlmParseError.new("Failed to parse LLM response: #{e.message}", parse_exception: e)
      Agentic.logger.error(error.message)
      handle_error(error, fail_on_error)
    rescue => e
      error = Errors::LlmError.new("Unexpected error in LLM request: #{e.message}", context: {error_class: e.class.name})
      Agentic.logger.error("#{error.message}\n#{e.backtrace.join("\n")}")
      handle_error(error, fail_on_error)
    end

    # Fetches available models from the LLM provider
    # @param fail_on_error [Boolean] Whether to raise errors or return nil on error
    # @return [Array<Hash>, nil] The list of available models, or nil if an error occurred and fail_on_error is false
    # @raise [Agentic::Errors::LlmError] If an error occurred and fail_on_error is true
    def models(fail_on_error: false)
      client.models.list&.dig("data")
    rescue OpenAI::Error => e
      error = map_openai_error(e)
      Agentic.logger.error("OpenAI API error when listing models: #{error.message}")
      handle_error(error, fail_on_error)
      nil
    rescue => e
      error = Errors::LlmError.new("Unexpected error listing models: #{e.message}")
      Agentic.logger.error("#{error.message}\n#{e.backtrace.join("\n")}")
      handle_error(error, fail_on_error)
      nil
    end

    # Queries generation stats for a given generation ID
    # @param generation_id [String] The ID of the generation
    # @param fail_on_error [Boolean] Whether to raise errors or return nil on error
    # @return [Hash, nil] The generation stats, or nil if an error occurred and fail_on_error is false
    # @raise [Agentic::Errors::LlmError] If an error occurred and fail_on_error is true
    def query_generation_stats(generation_id, fail_on_error: false)
      client.query_generation_stats(generation_id)
    rescue OpenAI::Error => e
      error = map_openai_error(e)
      Agentic.logger.error("OpenAI API error when querying generation stats: #{error.message}")
      handle_error(error, fail_on_error)
      nil
    rescue => e
      error = Errors::LlmError.new("Unexpected error querying generation stats: #{e.message}")
      Agentic.logger.error("#{error.message}\n#{e.backtrace.join("\n")}")
      handle_error(error, fail_on_error)
      nil
    end

    private

    # Extracts content from messages for logging purposes
    # @param messages [Array<Hash>] The messages
    # @return [Array<String>] The extracted content
    def extract_message_content(messages)
      messages.map do |msg|
        content = msg[:content] || msg["content"]
        role = msg[:role] || msg["role"]
        "#{role}: #{if content
                      content[0..100] + ((content.length > 100) ? "..." : "")
                    else
                      "[no content]"
                    end}"
      end
    end

    # Maps OpenAI error types to our custom error classes
    # @param error [OpenAI::Error] The original error from the OpenAI gem
    # @return [Agentic::Errors::LlmError] A mapped error
    def map_openai_error(error)
      case error
      when OpenAI::Timeout
        Errors::LlmTimeoutError.new("OpenAI API request timed out: #{error.message}")
      when OpenAI::RateLimitError
        retry_after = error.response&.headers&.[]("retry-after")&.to_i
        Errors::LlmRateLimitError.new(
          "OpenAI API rate limit exceeded: #{error.message}",
          retry_after: retry_after,
          response: error.response&.to_h
        )
      when OpenAI::AuthenticationError
        Errors::LlmAuthenticationError.new(
          "OpenAI API authentication error: #{error.message}",
          response: error.response&.to_h
        )
      when OpenAI::APIConnectionError
        Errors::LlmNetworkError.new(
          "OpenAI API connection error: #{error.message}",
          network_exception: error
        )
      when OpenAI::InvalidRequestError
        Errors::LlmInvalidRequestError.new(
          "Invalid request to OpenAI API: #{error.message}",
          response: error.response&.to_h
        )
      when OpenAI::APIError
        Errors::LlmServerError.new(
          "OpenAI API server error: #{error.message}",
          response: error.response&.to_h
        )
      else
        Errors::LlmError.new(
          "Unexpected OpenAI API error: #{error.message}",
          response: error.response&.to_h
        )
      end
    end

    # Handles an error based on whether to fail or return it in the response
    # @param error [Agentic::Errors::LlmError] The error to handle
    # @param fail_on_error [Boolean] Whether to raise the error
    # @return [LlmResponse] An error response if fail_on_error is false
    # @raise [Agentic::Errors::LlmError] If fail_on_error is true
    def handle_error(error, fail_on_error)
      raise error if fail_on_error
      LlmResponse.error(error, @last_response)
    end
  end
end
