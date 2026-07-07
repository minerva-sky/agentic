# frozen_string_literal: true

# Fair Share: two tenants, one upstream. The global ceiling is fair to
# REQUESTS - first come, first served - but tenant A brings 6 workers
# and tenant B brings 2, so "fair to requests" quietly means "A gets
# triple". Per-tenant ceilings under the global door restore fairness
# to TENANTS; resize keeps the idle tenant's share from stranding.
#
#   bundle exec ruby examples/fair_share.rb
#
# Runs offline; watch B's number - it tells the whole story.

require_relative "../lib/agentic"
require "async"

GLOBAL = 4
JOB = 0.01
PHASE = 0.24
WORKERS = {a: 6, b: 2}.freeze # A is greedy; B just wants its two lanes

global = Agentic::RateLimit.new(GLOBAL)
share_a = Agentic::RateLimit.new(2)
share_b = Agentic::RateLimit.new(2)
tenant_a = share_a.and(global) # own share first, then the shared door
tenant_b = share_b.and(global)

served = Hash.new(0)

# A tenant is N worker fibers, each pushing as hard as its limiter allows
def run_tenants(served, plan)
  Sync do
    plan.flat_map { |key, (limit, workers)|
      workers.times.map {
        Async do
          deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + PHASE
          while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
            limit.acquire {
              sleep(JOB)
              served[key] += 1
            }
          end
        end
      }
    }.each(&:wait)
  end
end

def phase(title, served, shares)
  before = served.dup
  yield
  puts format("  %-36s A: %-4d B: %-4d (shares %s)",
    title, served[:a] - before[:a], served[:b] - before[:b], shares)
end

puts "FAIR SHARE (global ceiling #{GLOBAL}; A brings #{WORKERS[:a]} workers, B brings #{WORKERS[:b]})"
puts

# Phase 1 - no shares: the door is fair to requests, so the tenant
# with more workers takes proportionally more. B wants 2 lanes' worth
# and gets half of it.
phase("no shares, one door for all", served, "-/-") do
  run_tenants(served, {a: [global, WORKERS[:a]], b: [global, WORKERS[:b]]})
end

# Phase 2 - 2/2 shares under the door: B reaches its full demand no
# matter how many workers A hires
phase("2/2 shares, same greedy A", served, "2/2") do
  run_tenants(served, {a: [tenant_a, WORKERS[:a]], b: [tenant_b, WORKERS[:b]]})
end

# Phase 3 - B goes idle; static shares strand B's lanes
phase("B idle, static 2/2 shares", served, "2/2") do
  run_tenants(served, {a: [tenant_a, WORKERS[:a]], b: [tenant_b, 0]})
end

# Phase 4 - same idle B, but the spare share is lent to A, live
share_a.resize(4)
share_b.resize(1)
phase("B idle, shares rebalanced 4/1", served, "4/1") do
  run_tenants(served, {a: [tenant_a, WORKERS[:a]], b: [tenant_b, 0]})
end

# Phase 5 - B returns; the share comes back, live
share_a.resize(2)
share_b.resize(2)
phase("B returns, shares back to 2/2", served, "2/2") do
  run_tenants(served, {a: [tenant_a, WORKERS[:a]], b: [tenant_b, WORKERS[:b]]})
end

puts
puts "  phase 1 is the quiet outage: nothing errored, nothing paged - B"
puts "  simply got half its lanes because the door counts requests, not"
puts "  tenants. phase 2 buys tenant-fairness by composition: own share"
puts "  first, then the door. phase 3 is the tax static shares charge -"
puts "  B's idle lanes served nobody - and phases 4-5 are the round-9"
puts "  payoff: resize lends the idle share and takes it back, live,"
puts "  while the composition never changes shape. fairness is a policy;"
puts "  make it an object and it becomes an adjustable one."
