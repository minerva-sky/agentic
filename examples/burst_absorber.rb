# frozen_string_literal: true

# The Burst Absorber: three waves of requests slam a credential with a
# ceiling of 3 (Agentic::RateLimit - this round's release). The ceiling
# holds, the queue absorbs, and the per-request wait times show exactly
# what "absorbed" costs. Capacity planning is reading this table.
#
#   bundle exec ruby examples/burst_absorber.rb
#
# Runs offline; the upstream is sleep.

require_relative "../lib/agentic"
require "async"

CEILING = 3
CALL_TIME = 0.05
WAVES = [6, 2, 9].freeze # requests arriving together, 120ms apart

limit = Agentic::RateLimit.new(CEILING)
waits = Hash.new { |h, k| h[k] = [] }

puts "BURST ABSORBER: ceiling #{CEILING}, calls take #{(CALL_TIME * 1000).round}ms"
puts

Sync do |task|
  arrivals = []
  WAVES.each_with_index do |count, wave|
    arrivals << task.async do
      sleep(wave * 0.12) # the wave arrives
      count.times.map { |i|
        task.async do
          arrived = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          limit.acquire do
            waits[wave] << Process.clock_gettime(Process::CLOCK_MONOTONIC) - arrived
            sleep(CALL_TIME)
          end
        end
      }.each(&:wait)
    end
  end
  arrivals.each(&:wait)
end

WAVES.each_with_index do |count, wave|
  wave_waits = waits[wave].sort
  puts format("  wave %d: %d requests   wait p50 %3dms   worst %3dms",
    wave + 1, count, wave_waits[wave_waits.size / 2] * 1000, wave_waits.last * 1000)
end

puts
puts format("  high-water mark: %d of %d - the ceiling held through every burst", limit.high_water, CEILING)
puts
puts "wave 1 (6 into 3 slots) queues; wave 2 (2 requests) sails through;"
puts "wave 3 (9 at once) pays the real price. the ceiling converts"
puts "provider 429s into local queueing - visible, measurable, bounded."
