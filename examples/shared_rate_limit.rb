# frozen_string_literal: true

# The Shared Rate Limit: two plans run concurrently in one reactor, but
# the API key they share allows only 3 requests in flight. A single
# Async::Semaphore, passed to both, enforces the provider's ceiling
# across plan boundaries - because rate limits belong to credentials,
# not to orchestrators.
#
#   bundle exec ruby examples/shared_rate_limit.rb
#
# Runs offline; the proof is the high-water mark.

require_relative "../lib/agentic"
require "async"
require "async/semaphore"

API_CEILING = 3

# The shared credential: a semaphore plus a high-water-mark counter
class RateLimitedApi
  attr_reader :high_water

  def initialize(ceiling)
    @semaphore = Async::Semaphore.new(ceiling)
    @in_flight = 0
    @high_water = 0
    @calls = []
  end

  def call(plan, name, latency)
    @semaphore.acquire do
      @in_flight += 1
      @high_water = [@high_water, @in_flight].max
      @calls << "#{plan}/#{name}"
      sleep(latency)
      @in_flight -= 1
      "#{name}:ok"
    end
  end

  def interleaved?
    plans = @calls.map { |c| c.split("/").first }
    plans.uniq.size > 1 && plans != plans.sort
  end
end

def build_plan(label, task_count, api)
  orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 10)
  task_count.times do |i|
    orchestrator.add_task(Agentic::Task.new(
      description: "#{label}-#{i}",
      agent_spec: {"name" => label, "instructions" => "call the API"},
      payload: 0.04 + (i % 3) * 0.02
    ), agent: ->(t) { api.call(label, t.description, t.payload) })
  end
  orchestrator
end

api = RateLimitedApi.new(API_CEILING)

puts "SHARED RATE LIMIT: two plans, one credential, ceiling #{API_CEILING}"
puts

wall = nil
Sync do
  ingest = build_plan("ingest", 8, api)
  enrich = build_plan("enrich", 8, api)

  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  # Both plans run as siblings in this reactor; each would happily use
  # 10 slots, but the shared semaphore is the credential's law
  plans = [ingest, enrich].map do |orchestrator|
    Async { orchestrator.execute_plan }
  end
  results = plans.map(&:wait)
  wall = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

  results.each_with_index do |result, i|
    puts format("  plan %d: %s, %d tasks", i + 1, result.status,
      result.results.count { |_, r| r.successful? })
  end
end

puts
puts format("  wall time: %dms for 16 calls of ~60ms each", wall * 1000)
puts format("  in-flight high-water mark: %d (ceiling %d) %s",
  api.high_water, API_CEILING, (api.high_water <= API_CEILING) ? "- held" : "- BREACHED")
puts "  calls interleaved across plans: #{api.interleaved? ? "yes" : "no"}"
puts
puts "each orchestrator had concurrency_limit 10; the credential said 3."
puts "the credential won, across both plans, because the semaphore lives"
puts "with the resource it protects - not with either scheduler."
