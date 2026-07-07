# frozen_string_literal: true

# The Concurrency Key: "at most one sync per TENANT, any number of
# tenants at once" is the concurrency control every multi-tenant job
# system eventually needs - global limits are too blunt (one tenant's
# backlog throttles everyone) and no limits are too sharp (two syncs
# for the same tenant race each other's writes). SolidQueue spells it
# concurrency_key; here it's one Mutex-guarded registry of per-key
# RateLimits, and the overflow policy is EXPLICIT: block, or skip.
#
#   bundle exec ruby examples/concurrency_key.rb
#
# Runs offline; interleavings are recorded and judged.

require_relative "../lib/agentic"
require "async"

Agentic.logger.level = :fatal

# Per-key serialization: limit(key) is a RateLimit.new(1), created
# once per key under a lock (two fibers discovering a new tenant at
# the same instant must agree on THE limiter, not each mint their own)
class ConcurrencyKeys
  def initialize
    @limits = {}
    @lock = Mutex.new
  end

  def limit(key)
    @lock.synchronize { @limits[key] ||= Agentic::RateLimit.new(1) }
  end

  # SolidQueue's two overflow postures, made explicit at the call site
  def serialized(key, &work) = limit(key).acquire(&work)

  def skip_if_running(key, &work)
    limit(key).try_acquire(&work) ? :ran : :skipped
  end
end

KEYS = ConcurrencyKeys.new
TIMELINE = []
T0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)

def sync_tenant(tenant, run_id)
  orchestrator = Agentic::PlanOrchestrator.new
  task = Agentic::Task.new(description: "sync:#{tenant}:#{run_id}", agent_spec: {"name" => "s", "instructions" => "w"})
  orchestrator.add_task(task, agent: ->(_t) {
    TIMELINE << [tenant, run_id, :start, Process.clock_gettime(Process::CLOCK_MONOTONIC) - T0]
    sleep(0.04)
    TIMELINE << [tenant, run_id, :end, Process.clock_gettime(Process::CLOCK_MONOTONIC) - T0]
    :ok
  })
  orchestrator.execute_plan
end

puts "THE CONCURRENCY KEY (at most one sync per tenant; tenants in parallel)"
puts

# Six sync requests: two tenants, three requests each, all at once
Sync do
  requests = [["acme", 1], ["acme", 2], ["globex", 1], ["acme", 3], ["globex", 2], ["globex", 3]]
  requests.map { |tenant, run_id|
    Async do
      KEYS.serialized("sync/#{tenant}") { sync_tenant(tenant, run_id) }
    end
  }.each(&:wait)
end

# Judge the interleaving: per tenant, runs must not overlap; across
# tenants, they MUST have overlapped (or the key was too blunt)
overlaps = ->(events) {
  spans = events.group_by { |t, r, _, _| [t, r] }.values.map { |es|
    [es.find { |e| e[2] == :start }[3], es.find { |e| e[2] == :end }[3]]
  }
  spans.combination(2).count { |(s1, e1), (s2, e2)| s1 < e2 && s2 < e1 }
}
acme = TIMELINE.select { |t, _, _, _| t == "acme" }
globex = TIMELINE.select { |t, _, _, _| t == "globex" }
cross = overlaps.call(TIMELINE)

puts "  six concurrent requests (3 per tenant):"
puts format("    acme runs overlapping each other:    %d (must be 0)", overlaps.call(acme))
puts format("    globex runs overlapping each other:  %d (must be 0)", overlaps.call(globex))
puts format("    cross-tenant overlaps:               %d (must be > 0 - parallelism preserved)", cross - overlaps.call(acme) - overlaps.call(globex))
puts

# The other posture: a cron fires while a sync is already running
verdicts = nil
Sync do
  holder = Async { KEYS.serialized("sync/acme") { sleep(0.03) } }
  sleep(0.005)
  verdicts = 2.times.map { KEYS.skip_if_running("sync/acme") { sync_tenant("acme", 99) } }
  holder.wait
end
puts "  cron fires twice while acme's sync is already running:"
puts "    verdicts: #{verdicts.inspect} - skipped, not queued."
puts
puts "  the two postures are different PROMISES and the call site names"
puts "  which one it makes: serialized() means every request eventually"
puts "  runs, in order, alone (backfills); skip_if_running() means"
puts "  running-now is proof enough (crons - a second sync would do the"
puts "  same work twice). the registry hands out ONE limiter per key"
puts "  under a lock, because two fibers discovering tenant 'initech'"
puts "  simultaneously must agree on THE mutex, not mint rivals. global"
puts "  limits ration CAPACITY; keyed limits enforce CORRECTNESS - most"
puts "  incidents blamed on load are actually two workers holding the"
puts "  same tenant."
