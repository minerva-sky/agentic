# frozen_string_literal: true

# Composed Limits: a real provider enforces BOTH a billed quota and a
# connection ceiling. quota.and(pool) - new this round - holds the two
# laws in one limiter, and the run proves each law bound the traffic
# in its own dimension: admissions per window AND concurrent in-flight.
#
#   bundle exec ruby examples/composed_limits.rb
#
# Runs offline; 12 slow calls against quota 6/200ms and pool of 2.

require_relative "../lib/agentic"
require "async"

REQUESTS = 12
CALL_TIME = 0.05

quota = Agentic::RateLimit.new(6, per: 0.2) # billing law: 6 per 200ms
pool = Agentic::RateLimit.new(2)            # socket law: 2 in flight
limit = quota.and(pool)                     # both, in that order

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

puts "COMPOSED LIMITS: #{REQUESTS} calls x #{(CALL_TIME * 1000).round}ms, " \
  "quota 6/200ms AND pool of 2"
puts

buckets = admissions.group_by { |t| (t / 0.2).floor }
buckets.sort.each do |window, hits|
  puts format("  window %d (%3d-%3dms): %-8s %d admitted (quota allows 6)",
    window + 1, window * 200, (window + 1) * 200, "#" * hits.size, hits.size)
end

puts
puts format("  pool high-water:  %d of %d - the socket law held", pool.high_water, pool.ceiling)
puts format("  quota high-water: %d concurrent (window law measures admissions, not flight)", quota.high_water)
puts
puts "which law binds? the pool could clear ~8 per window (2 lanes x 4"
puts "service times) but the quota admits only 6 - so the QUOTA is the"
puts "binding constraint, and the chart shows it: exactly 6 per window."
puts "raise the quota and the pool becomes the wall. composition enforces"
puts "both laws and the windows tell you which one is throttling you."
puts
puts "ordering note: quota.and(pool) spends quota BEFORE waiting for a"
puts "socket - correct, because sockets are scarce and quota refills on a"
puts "clock. the reverse order would hold a connection hostage while"
puts "waiting for the meter."
