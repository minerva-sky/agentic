# frozen_string_literal: true

module Agentic
  # Handles retrying operations with configurable backoff strategies
  class RetryHandler
    # @return [Integer] The maximum number of retry attempts
    attr_reader :max_retries

    # @return [Array<Class, String>] List of retryable error types/names
    attr_reader :retryable_errors

    # @return [Symbol] The backoff strategy to use
    attr_reader :backoff_strategy

    # @return [Proc, nil] Optional block to run before each retry
    attr_reader :before_retry

    # @return [Proc, nil] Optional block to run after each retry
    attr_reader :after_retry

    # Initializes a new RetryHandler
    # @param max_retries [Integer] The maximum number of retry attempts
    # @param retryable_errors [Array<Class, String>] List of retryable error types/names
    # @param backoff_strategy [Symbol] The backoff strategy (:constant, :linear, :exponential)
    # @param backoff_options [Hash] Options for the backoff strategy
    # @param before_retry [Proc, nil] Optional block to run before each retry
    # @param after_retry [Proc, nil] Optional block to run after each retry
    # @option backoff_options [Float] :base_delay The base delay in seconds
    # @option backoff_options [Float] :jitter_factor The jitter factor (0.0-1.0)
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

    # Executes the given block with retries
    # @param block [Proc] The block to execute with retries
    # @return [Object] The return value of the block
    # @raise [StandardError] If the block failed after all retries
    def with_retry(&block)
      attempt = 0

      begin
        attempt += 1
        block.call
      rescue => e
        error = e.is_a?(Errors::LlmError) ? e : Errors::LlmError.new(e.message, context: {original_error: e.class.name})

        if retryable?(error) && attempt <= max_retries
          delay = calculate_backoff_delay(attempt)
          Agentic.logger.info("Retry #{attempt}/#{max_retries} for error: #{error.message}. Waiting #{delay.round(2)}s before retrying.")

          @before_retry&.call(attempt: attempt, error: error, delay: delay)
          sleep(delay)
          @after_retry&.call(attempt: attempt, error: error, delay: delay)

          retry
        else
          if attempt > max_retries
            Agentic.logger.error("Max retries (#{max_retries}) exceeded for error: #{error.message}")
          else
            Agentic.logger.error("Non-retryable error: #{error.message}")
          end

          raise error
        end
      end
    end

    private

    # Determines if an error is retryable
    # @param error [StandardError] The error to check
    # @return [Boolean] True if the error is retryable
    def retryable?(error)
      return true if error.respond_to?(:retryable?) && error.retryable?

      @retryable_errors.any? do |retryable|
        if retryable.is_a?(Class)
          error.is_a?(retryable)
        else
          error.instance_of?(retryable).to_s
        end
      end
    end

    # Calculates the backoff delay for a given attempt
    # @param attempt [Integer] The current attempt number (1-based)
    # @return [Float] The delay in seconds
    def calculate_backoff_delay(attempt)
      base_delay = @backoff_options[:base_delay]

      delay = case @backoff_strategy
      when :constant
        base_delay
      when :linear
        base_delay * attempt
      when :exponential
        base_delay * (2**(attempt - 1))
      else
        base_delay
      end

      if @backoff_options[:jitter_factor] && @backoff_options[:jitter_factor] > 0
        jitter = rand(-delay * @backoff_options[:jitter_factor]..delay * @backoff_options[:jitter_factor])
        delay += jitter
      end

      [delay, 0].max # Ensure positive delay
    end
  end
end
