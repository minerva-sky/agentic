# frozen_string_literal: true

module Agentic
  module Errors
    # Base class for all LLM-related errors
    class LlmError < StandardError
      # @return [Hash, nil] The raw response from the LLM API, if available
      attr_reader :response
      
      # @return [Hash, nil] Additional context about the error
      attr_reader :context
      
      # @param message [String] The error message
      # @param response [Hash, nil] The raw response from the LLM API
      # @param context [Hash, nil] Additional context about the error
      def initialize(message, response: nil, context: nil)
        super(message)
        @response = response
        @context = context || {}
      end
    end
    
    # Error raised when the LLM refuses to respond
    class LlmRefusalError < LlmError
      # @return [String] The refusal message from the LLM
      attr_reader :refusal_message
      
      # @return [Symbol] The category of refusal
      attr_reader :refusal_category
      
      # @param refusal_message [String] The refusal message from the LLM
      # @param refusal_category [Symbol, nil] The category of refusal
      # @param response [Hash, nil] The raw response from the LLM API
      # @param context [Hash, nil] Additional context about the error
      def initialize(refusal_message, refusal_category: nil, response: nil, context: nil)
        super("LLM refused to respond: #{refusal_message}", response: response, context: context)
        @refusal_message = refusal_message
        @refusal_category = refusal_category || determine_refusal_category(refusal_message)
      end
      
      # Determines whether this refusal is retryable with modifications
      # @return [Boolean] True if the refusal can be retried with modifications
      def retryable_with_modifications?
        [:unclear_instructions, :needs_clarification, :ambiguous_request, :format_error].include?(@refusal_category)
      end
      
      private
      
      # Determines the category of refusal from the message
      # @param message [String] The refusal message
      # @return [Symbol] The category of refusal
      def determine_refusal_category(message)
        message = message.to_s.downcase
        
        if message.include?("harmful") || message.include?("offensive") || message.include?("illegal")
          :harmful_content
        elsif message.include?("clarif") || message.include?("ambiguous")
          :needs_clarification
        elsif message.include?("format") || message.include?("structure")
          :format_error
        elsif message.include?("unclear") || message.include?("specific")
          :unclear_instructions
        elsif message.include?("capability") || message.include?("unable")
          :capability_limitation
        else
          :general_refusal
        end
      end
    end
    
    # Error raised when the LLM response cannot be parsed
    class LlmParseError < LlmError
      # @return [Exception] The original parsing exception
      attr_reader :parse_exception
      
      # @param message [String] The error message
      # @param parse_exception [Exception] The original parsing exception
      # @param response [Hash, nil] The raw response from the LLM API
      # @param context [Hash, nil] Additional context about the error
      def initialize(message, parse_exception: nil, response: nil, context: nil)
        super(message, response: response, context: context)
        @parse_exception = parse_exception
      end
    end
    
    # Error raised when there's a connection or network issue
    class LlmNetworkError < LlmError
      # @return [Exception] The original network exception
      attr_reader :network_exception
      
      # @param message [String] The error message
      # @param network_exception [Exception] The original network exception
      # @param context [Hash, nil] Additional context about the error
      def initialize(message, network_exception: nil, context: nil)
        super(message, context: context)
        @network_exception = network_exception
      end
      
      # @return [Boolean] Whether this error is retryable
      def retryable?
        true
      end
    end
    
    # Error raised when the API returns a rate limit error
    class LlmRateLimitError < LlmError
      # @return [Integer, nil] The number of seconds to wait before retrying
      attr_reader :retry_after
      
      # @param message [String] The error message
      # @param retry_after [Integer, nil] The number of seconds to wait before retrying
      # @param response [Hash, nil] The raw response from the LLM API
      # @param context [Hash, nil] Additional context about the error
      def initialize(message, retry_after: nil, response: nil, context: nil)
        super(message, response: response, context: context)
        @retry_after = retry_after
      end
      
      # @return [Boolean] Whether this error is retryable
      def retryable?
        true
      end
    end
    
    # Error raised when the API returns an authentication error
    class LlmAuthenticationError < LlmError
      # @param message [String] The error message
      # @param response [Hash, nil] The raw response from the LLM API
      # @param context [Hash, nil] Additional context about the error
      def initialize(message, response: nil, context: nil)
        super(message, response: response, context: context)
      end
      
      # @return [Boolean] Whether this error is retryable
      def retryable?
        false
      end
    end
    
    # Error raised when the API returns a server error
    class LlmServerError < LlmError
      # @param message [String] The error message
      # @param response [Hash, nil] The raw response from the LLM API
      # @param context [Hash, nil] Additional context about the error
      def initialize(message, response: nil, context: nil)
        super(message, response: response, context: context)
      end
      
      # @return [Boolean] Whether this error is retryable
      def retryable?
        true
      end
    end
    
    # Error raised when the request to the LLM times out
    class LlmTimeoutError < LlmError
      # @param message [String] The error message
      # @param context [Hash, nil] Additional context about the error
      def initialize(message, context: nil)
        super(message, context: context)
      end
      
      # @return [Boolean] Whether this error is retryable
      def retryable?
        true
      end
    end
    
    # Error raised when an invalid request is made to the LLM API
    class LlmInvalidRequestError < LlmError
      # @param message [String] The error message
      # @param response [Hash, nil] The raw response from the LLM API
      # @param context [Hash, nil] Additional context about the error
      def initialize(message, response: nil, context: nil)
        super(message, response: response, context: context)
      end
      
      # @return [Boolean] Whether this error is retryable
      def retryable?
        false
      end
    end
  end
end