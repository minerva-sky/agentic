# frozen_string_literal: true

module Agentic
  # Configuration object for the PlanOrchestrator
  class PlanOrchestratorConfig
    # @return [Integer] Maximum number of concurrent tasks
    attr_accessor :concurrency_limit
    
    # @return [Hash] Lifecycle hooks for the orchestrator
    attr_accessor :lifecycle_hooks
    
    # @return [Boolean] Whether to continue execution after a task failure
    attr_accessor :continue_on_failure
    
    # @return [RetryConfig] Retry configuration for tasks
    attr_accessor :retry_config
    
    # @return [Boolean] Whether to execute tasks asynchronously
    attr_accessor :async
    
    # Initializes a new plan orchestrator configuration
    # @param concurrency_limit [Integer] Maximum number of concurrent tasks
    # @param lifecycle_hooks [Hash] Lifecycle hooks for the orchestrator
    # @param continue_on_failure [Boolean] Whether to continue execution after a task failure
    # @param retry_config [RetryConfig, nil] Retry configuration for tasks
    # @param async [Boolean] Whether to execute tasks asynchronously
    def initialize(
      concurrency_limit: 10,
      lifecycle_hooks: {},
      continue_on_failure: true,
      retry_config: nil,
      async: true
    )
      @concurrency_limit = concurrency_limit
      @lifecycle_hooks = lifecycle_hooks
      @continue_on_failure = continue_on_failure
      @retry_config = retry_config || RetryConfig.new
      @async = async
    end
    
    # Returns a hash of configuration options
    # @return [Hash] The configuration options
    def to_h
      {
        concurrency_limit: @concurrency_limit,
        lifecycle_hooks: @lifecycle_hooks,
        continue_on_failure: @continue_on_failure,
        retry_config: {
          max_retries: @retry_config.max_retries,
          backoff_strategy: @retry_config.backoff_strategy,
          backoff_options: @retry_config.backoff_options
        },
        async: @async
      }
    end
  end
end