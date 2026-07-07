# frozen_string_literal: true

# The Resize Torture Test: a feature that changes a limiter's ceiling
# while fibers are waiting on it had better say exactly what it
# guarantees - and then survive an attempt to break the guarantee.
# Three assaults: per-epoch ceilings under load, a mid-flight shrink,
# and a grow that must actually wake the waiters.
#
#   bundle exec ruby examples/resize_torture.rb
#
# Runs offline; exits 1 if any guarantee cracks.

require_relative "../lib/agentic"
require "async"

violations = []

# --- assault 1: every epoch's ceiling holds under saturating load -------------
# Resize through jagged ceilings; within each epoch, run far more jobs
# than lanes and record the max observed concurrency ourselves - we
# don't trust high_water, we recompute it.
limiter = Agentic::RateLimit.new(1)
EPOCHS = [1, 5, 2, 4, 1, 3].freeze

Sync do
  EPOCHS.each do |ceiling|
    limiter.resize(ceiling)
    concurrent = 0
    observed_max = 0

    (ceiling * 4).times.map {
      Async do
        limiter.acquire do
          concurrent += 1
          observed_max = [observed_max, concurrent].max
          sleep(0.003)
          concurrent -= 1
        end
      end
    }.each(&:wait)

    if observed_max > ceiling
      violations << "epoch ceiling #{ceiling}: observed #{observed_max} concurrent"
    end
    puts format("  epoch ceiling %-3d observed max %-3d %s",
      ceiling, observed_max, (observed_max > ceiling) ? "VIOLATED" : "held")
  end
end

# --- assault 2: shrink mid-flight admits nobody above the new mark ------------
# Fill 5 lanes, shrink to 2 while all 5 are running, then submit a
# second wave. Every wave-2 admission must see <= 2 concurrent
# (in-flight holders from wave 1 drain; nothing new joins them).
puts
shrinker = Agentic::RateLimit.new(5)
wave2_snapshots = []

Sync do
  concurrent = 0
  wave1 = 5.times.map {
    Async do
      shrinker.acquire do
        concurrent += 1
        sleep(0.03)
        concurrent -= 1
      end
    end
  }
  Async do
    sleep(0.005) # let wave 1 occupy all 5 lanes
    shrinker.resize(2)
  end.wait

  wave2 = 5.times.map {
    Async do
      shrinker.acquire do
        concurrent += 1
        wave2_snapshots << concurrent
        sleep(0.003)
        concurrent -= 1
      end
    end
  }
  (wave1 + wave2).each(&:wait)
end

if wave2_snapshots.any? { |snapshot| snapshot > 2 }
  violations << "post-shrink admission saw #{wave2_snapshots.max} concurrent"
end
puts format("  shrink 5->2 mid-flight: wave-2 admissions saw max %d concurrent %s",
  wave2_snapshots.max, (wave2_snapshots.any? { |s| s > 2 }) ? "VIOLATED" : "(<= 2, held)")

# --- assault 3: grow must wake the already-waiting -----------------------------
# One lane, three long jobs queued behind it. Grow to 3; the queued
# jobs must be admitted promptly, not on the old schedule.
grower = Agentic::RateLimit.new(1)
admissions = []

Sync do
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  jobs = 3.times.map {
    Async do
      grower.acquire do
        admissions << Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
        sleep(0.05)
      end
    end
  }
  Async do
    sleep(0.01)
    grower.resize(3)
  end.wait
  jobs.each(&:wait)
end

# Serial schedule would admit job 3 at ~0.10s; waking on grow admits it ~0.01s
late = admissions.max
if late > 0.04
  violations << "grow did not wake waiters (last admission at #{(late * 1000).round}ms)"
end
puts format("  grow 1->3 with 2 queued: last admission at %.0fms %s",
  late * 1000, (late > 0.04) ? "VIOLATED (serial schedule)" : "(woken by resize, held)")

puts
if violations.empty?
  puts "  3 assaults, 0 cracks. the guarantees, as proven: an epoch's"
  puts "  ceiling binds every admission inside it; shrinking drains rather"
  puts "  than evicts, and nothing new is admitted above the new mark;"
  puts "  growing wakes waiters immediately instead of leaving them on"
  puts "  the old schedule. resize without these proofs is a data race"
  puts "  with a friendly method name."
else
  puts "  CRACKED: #{violations.join("; ")}"
end
exit(violations.empty? ? 0 : 1)
