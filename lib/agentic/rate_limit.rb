# frozen_string_literal: true

require "async/semaphore"

module Agentic
  # A credential-scoped concurrency ceiling, shareable across plans,
  # clients, and agents in one process. Rate limits belong to the
  # resource they protect - one API key means one ceiling, no matter
  # how many orchestrators are running:
  #
  #   limit = Agentic::RateLimit.new(3)
  #   client_a = Agentic::LlmClient.new(config, limiter: limit)
  #   client_b = Agentic::LlmClient.new(config, limiter: limit)
  #   # combined in-flight requests never exceed 3
  #
  # The high-water mark records the most concurrent acquisitions ever
  # observed, so tests and dashboards can verify the ceiling held.
  class RateLimit
    # @return [Integer] The maximum concurrent acquisitions allowed
    attr_reader :ceiling

    # @return [Integer] The most concurrent acquisitions observed
    attr_reader :high_water

    # @param ceiling [Integer] Maximum concurrent acquisitions
    def initialize(ceiling)
      @ceiling = ceiling
      @semaphore = Async::Semaphore.new(ceiling)
      @in_flight = 0
      @high_water = 0
    end

    # Runs the block inside the ceiling, waiting for a slot if necessary
    # @yield The rate-limited work
    # @return [Object] The block's return value
    def acquire
      @semaphore.acquire do
        @in_flight += 1
        @high_water = [@high_water, @in_flight].max
        begin
          yield
        ensure
          @in_flight -= 1
        end
      end
    end

    # @return [Integer] Acquisitions currently inside the ceiling
    attr_reader :in_flight
  end
end
