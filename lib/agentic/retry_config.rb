# frozen_string_literal: true

module Agentic
  # Configuration object for the RetryHandler
  class RetryConfig
    # @return [Integer] The maximum number of retry attempts
    attr_accessor :max_retries
    
    # @return [Array<Class, String>] List of retryable error types/names
    attr_accessor :retryable_errors
    
    # @return [Symbol] The backoff strategy to use
    attr_accessor :backoff_strategy
    
    # @return [Hash] Options for the backoff strategy
    attr_accessor :backoff_options
    
    # @return [Proc, nil] Optional block to run before each retry
    attr_accessor :before_retry
    
    # @return [Proc, nil] Optional block to run after each retry
    attr_accessor :after_retry
    
    # Initializes a new retry configuration
    # @param max_retries [Integer] The maximum number of retry attempts
    # @param retryable_errors [Array<Class, String>] List of retryable error types/names
    # @param backoff_strategy [Symbol] The backoff strategy (:constant, :linear, :exponential)
    # @param backoff_options [Hash] Options for the backoff strategy
    # @param before_retry [Proc, nil] Optional block to run before each retry
    # @param after_retry [Proc, nil] Optional block to run after each retry
    def initialize(
      max_retries: 3,
      retryable_errors: [Errors::LlmTimeoutError, Errors::LlmRateLimitError, Errors::LlmServerError, Errors::LlmNetworkError],
      backoff_strategy: :exponential,
      backoff_options: {},
      before_retry: nil,
      after_retry: nil
    )
      @max_retries = max_retries
      @retryable_errors = retryable_errors
      @backoff_strategy = backoff_strategy
      @backoff_options = {
        base_delay: 1.0,
        jitter_factor: 0.25
      }.merge(backoff_options)
      @before_retry = before_retry
      @after_retry = after_retry
    end
    
    # Creates a RetryHandler from this configuration
    # @return [RetryHandler] A new retry handler
    def to_handler
      RetryHandler.new(
        max_retries: @max_retries,
        retryable_errors: @retryable_errors,
        backoff_strategy: @backoff_strategy,
        backoff_options: @backoff_options,
        before_retry: @before_retry,
        after_retry: @after_retry
      )
    end
  end
end