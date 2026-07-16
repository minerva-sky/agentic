# frozen_string_literal: true

module Agentic
  # Value object representing a response from an LLM
  class LlmResponse
    # @return [Hash, String, nil] The parsed content from the LLM response
    attr_reader :content

    # @return [String, nil] The refusal message, if the LLM refused the request
    attr_reader :refusal
    alias_method :refusal_reason, :refusal

    # @return [Hash] The raw response from the LLM API
    attr_reader :raw_response

    # @return [Agentic::Errors::LlmError, nil] The error object, if an error occurred
    attr_reader :error

    # @return [Agentic::Errors::LlmRefusalError, nil] The refusal error object, if the LLM refused the request
    attr_reader :refusal_error

    # @return [GenerationStats, nil] Statistics about the generation
    attr_reader :stats

    # Initializes a new LlmResponse
    # @param raw_response [Hash] The raw response from the LLM API
    # @param parsed_content [Hash, String, nil] Optional pre-parsed content
    # @param error [Agentic::Errors::LlmError, nil] Optional error object
    def initialize(raw_response, parsed_content: nil, error: nil, refusal_error: nil)
      @raw_response = raw_response
      @refusal = raw_response&.dig("choices", 0, "message", "refusal")
      @content = parsed_content || parse_content(raw_response)
      @error = error
      @refusal_error = refusal_error
      @stats = raw_response ? GenerationStats.from_response(raw_response) : nil
    end

    # Creates a successful response
    # @param raw_response [Hash] The raw response from the LLM API
    # @param content [Hash, String] The parsed content
    # @return [LlmResponse] A successful response
    def self.success(raw_response, content)
      new(raw_response, parsed_content: content)
    end

    # Creates a refusal response
    # @param raw_response [Hash] The raw response from the LLM API
    # @param refusal [String] The refusal message
    # @param refusal_error [Agentic::Errors::LlmRefusalError, nil] The refusal error object
    # @return [LlmResponse] A refusal response
    def self.refusal(raw_response, refusal, refusal_error = nil)
      new(
        raw_response,
        parsed_content: nil,
        refusal_error: refusal_error
      )
    end

    # Creates an error response
    # @param error [Agentic::Errors::LlmError] The error that occurred
    # @param raw_response [Hash, nil] The raw response from the LLM API, if available
    # @return [LlmResponse] An error response
    def self.error(error, raw_response = nil)
      new(raw_response, error: error)
    end

    # Checks if the response was successful
    # @return [Boolean] True if the response was successful
    def successful?
      !refused? && !error?
    end
    alias_method :success?, :successful?

    # Checks if the request was refused
    # @return [Boolean] True if the request was refused
    def refused?
      !@refusal.nil? || !@refusal_error.nil?
    end
    alias_method :refusal?, :refused?

    # Gets the refusal category if available
    # @return [Symbol, nil] The refusal category, or nil if not refused
    def refusal_category
      @refusal_error&.refusal_category
    end

    # Checks if the refusal can be retried with modifications
    # @return [Boolean] True if the refusal can be retried with modifications, false otherwise
    def retryable_refusal?
      @refusal_error&.retryable_with_modifications? || false
    end

    # Checks if an error occurred
    # @return [Boolean] True if an error occurred
    def error?
      !@error.nil?
    end

    # Raises the error if one occurred
    # @return [void]
    # @raise [Agentic::Errors::LlmError] If an error occurred
    def raise_if_error!
      raise @error if error?
    end

    # Converts the response to a hash
    # @return [Hash] The response as a hash
    def to_h
      base = {stats: @stats&.to_h}

      if error?
        base.merge({
          error: {
            message: @error.message,
            type: @error.class.name
          },
          content: nil,
          refusal: nil,
          refusal_category: nil
        })
      elsif refused?
        refusal_info = {
          refusal: @refusal,
          content: nil,
          error: nil
        }

        # Add refusal category if available
        if @refusal_error
          refusal_info[:refusal_category] = @refusal_error.refusal_category
          refusal_info[:retryable] = @refusal_error.retryable_with_modifications?
        end

        base.merge(refusal_info)
      else
        base.merge({
          content: @content,
          refusal: nil,
          error: nil,
          refusal_category: nil
        })
      end
    end

    private

    # Parses the content from the raw response
    # @param response [Hash] The raw response from the LLM API
    # @return [Hash, String, nil] The parsed content
    def parse_content(response)
      return nil if response.nil?

      content_text = response.dig("choices", 0, "message", "content")
      return nil if content_text.nil?

      begin
        JSON.parse(content_text)
      rescue JSON::ParserError
        content_text
      end
    end
  end
end
