# frozen_string_literal: true

# The Quota Keeper: the same 20 requests through two different laws.
# A concurrency ceiling ("3 in flight") models connection limits; a
# windowed quota ("5 per 200ms") models what providers actually bill.
# They are different physics, and the admission timeline proves it.
#
#   bundle exec ruby examples/quota_keeper.rb
#
# Runs offline; calls are 10ms of simulated IO.

require_relative "../lib/agentic"
require "async"

REQUESTS = 20
CALL_TIME = 0.01

def fire_through(limit)
  admissions = []
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  Sync do
    REQUESTS.times.map {
      Async do
        limit.acquire do
          admissions << Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
          sleep(CALL_TIME)
        end
      end
    }.each(&:wait)
  end

  admissions.sort
end

def admission_chart(admissions, bucket = 0.2)
  buckets = admissions.group_by { |t| (t / bucket).floor }
  (0..admissions.max / bucket).map { |i|
    format("    %3d-%3dms  %-22s %d",
      i * bucket * 1000, (i + 1) * bucket * 1000, "#" * (buckets[i]&.size || 0), buckets[i]&.size || 0)
  }.join("\n")
end

puts "QUOTA KEEPER: #{REQUESTS} requests, #{(CALL_TIME * 1000).round}ms each, fired simultaneously"
puts

concurrent = fire_through(Agentic::RateLimit.new(3))
puts "  law 1 - concurrency ceiling (3 in flight):"
puts admission_chart(concurrent)
puts format("    all admitted by %dms - completion frees a slot, so short", concurrent.last * 1000)
puts "    calls drain the queue as fast as they finish"
puts

windowed = fire_through(Agentic::RateLimit.new(5, per: 0.2))
puts "  law 2 - windowed quota (5 per 200ms):"
puts admission_chart(windowed)
puts format("    last admitted at %dms - finishing early buys NOTHING;", windowed.last * 1000)
puts "    the window admits five per period no matter how quick the calls"
puts

puts "same requests, ~#{(concurrent.last * 1000).round}ms versus ~#{(windowed.last * 1000).round}ms: pick the law your"
puts "provider actually enforces. connection pools are ceilings; billed"
puts "quotas are windows; production APIs are usually both at once -"
puts "which is why RateLimit lets you hold one of each."
