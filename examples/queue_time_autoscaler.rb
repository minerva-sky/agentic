# frozen_string_literal: true

# The Queue-Time Autoscaler: the Speedshop rule, closed-loop. Most
# autoscalers trigger on utilization, which is a lie with a
# dashboard - a healthy busy server and a drowning one can post the
# same number. The metric with a user attached is QUEUE TIME: how
# long work sat waiting for a worker. This scaler measures it at the
# only honest place (around the acquire), scales by Little's law
# (workers = arrival rate x service time, plus headroom), resizes
# the live pool, and lets the next wave prove the math.
#
#   bundle exec ruby examples/queue_time_autoscaler.rb
#
# Runs offline; exits 1 unless scaling collapses the queue.

require_relative "../lib/agentic"

Agentic.logger.level = :fatal

SERVICE = 0.02 # seconds per request - measured, not guessed
QUEUE_BUDGET = 0.25 # queue time may cost at most 25% of service time

def mono = Process.clock_gettime(Process::CLOCK_MONOTONIC)

# A wave of requests hits the plan; the worker pool (a resizable
# RateLimit) is the real constraint, exactly like processes behind a
# proxy. Queue time is measured around the acquire - nowhere else.
def wave(pool, arrivals:, spacing:)
  orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 64)
  queue_times = []
  busy = 0.0
  arrivals.times do |i|
    task = Agentic::Task.new(description: "req #{i}", agent_spec: {"name" => "r", "instructions" => "serve"})
    orchestrator.add_task(task, agent: ->(_t) {
      sleep(i * spacing) # arrival schedule
      ready = mono
      pool.acquire do
        queue_times << mono - ready
        sleep(SERVICE)
        busy += SERVICE
      end
      :served
    })
  end
  started = mono
  orchestrator.execute_plan
  {queue: queue_times, wall: mono - started, busy: busy}
end

def p95(samples) = samples.sort[(samples.size * 0.95).floor.clamp(0, samples.size - 1)]

pool = Agentic::RateLimit.new(1)
workers = 1

puts "THE QUEUE-TIME AUTOSCALER (scale on queue time, never utilization)"
puts
puts format("  %-26s %-8s %-12s %-12s %s", "wave", "workers", "p95 queue", "utilization", "autoscaler verdict")

results = {}
calm_utilization = nil
[[:calm, 10, 0.030], [:spike, 40, 0.004], [:spike_again, 40, 0.004]].each do |name, arrivals, spacing|
  workers_during = workers
  stats = wave(pool, arrivals: arrivals, spacing: spacing)
  q95 = p95(stats[:queue])
  utilization = stats[:busy] / (stats[:wall] * workers_during)
  calm_utilization ||= utilization
  results[name] = q95

  verdict = if q95 <= SERVICE * QUEUE_BUDGET
    "healthy - queue is #{(q95 / SERVICE * 100).round}% of service time"
  else
    # Little's law: keep up with the offered load, plus one for luck
    needed = (SERVICE / spacing).ceil + 1
    pool.resize(needed)
    workers = needed
    "queue is #{(q95 / SERVICE).round}x service time -> resize #{workers_during} -> #{needed}"
  end
  puts format("  %-28s %-8d %-12s %-12s %s",
    "#{name} (#{arrivals} req @ #{(1 / spacing).round}/s)", workers_during,
    "#{(q95 * 1000).round(1)}ms", "#{(utilization * 100).round}%", verdict)
end

puts
collapsed = results[:spike_again] < results[:spike] / 10
puts "  the calm wave ran its single worker at #{(calm_utilization * 100).round}% utilization and"
puts "  nobody suffered - utilization without queue time is just a machine"
puts "  earning its keep. the spike buried the same worker: p95 queue hit"
puts "  #{(results[:spike] * 1000).round}ms against a #{(SERVICE * 1000).round}ms service time. the scaler didn't panic or"
puts "  guess - Little's law says workers = arrival rate x service time,"
puts "  so it resized the live pool (no restart; RateLimit#resize) and the"
puts "  identical spike re-ran with p95 queue at #{(results[:spike_again] * 1000).round(1)}ms. scale on the number"
puts "  that has a user attached to it."
exit(collapsed ? 0 : 1)
