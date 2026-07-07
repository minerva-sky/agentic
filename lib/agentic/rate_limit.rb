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

    # @return [Numeric, nil] The rolling window in seconds, when windowed
    attr_reader :per

    # @param ceiling [Integer] Maximum acquisitions - concurrent when
    #   per: is nil, per rolling window when per: is given
    # @param per [Numeric, nil] Window length in seconds. A concurrency
    #   ceiling models connection limits (3 requests in flight); a
    #   windowed ceiling models quota (30 requests per minute). They are
    #   different physics; pick the one your provider enforces.
    def initialize(ceiling, per: nil)
      @ceiling = ceiling
      @per = per
      @semaphore = Async::Semaphore.new(ceiling) unless per
      @stamps = []
      @in_flight = 0
      @high_water = 0
    end

    # Runs the block inside the ceiling, waiting for a slot if necessary
    # @yield The rate-limited work
    # @return [Object] The block's return value
    def acquire
      return windowed_acquire { yield } if @per

      @semaphore.acquire do
        track { yield }
      end
    end

    # @return [Integer] Acquisitions currently inside the ceiling
    attr_reader :in_flight

    private

    def track
      @in_flight += 1
      @high_water = [@high_water, @in_flight].max
      yield
    ensure
      @in_flight -= 1
    end

    # Rolling-window admission: wait until fewer than ceiling
    # acquisitions have started within the last `per` seconds
    def windowed_acquire
      loop do
        now = clock
        @stamps.reject! { |stamp| stamp <= now - @per }
        break if @stamps.size < @ceiling

        sleep(@stamps.first + @per - now)
      end

      @stamps << clock
      track { yield }
    end

    def clock
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
