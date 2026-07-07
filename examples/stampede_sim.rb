# frozen_string_literal: true

# The Stampede Simulator: twenty workers hit a hiccuping upstream, all
# fail at once, all retry. With jitter OFF they come back as a single
# synchronized herd - the second outage. With jitter ON (the default,
# as of this round) the herd spreads. The histogram is the argument.
#
#   bundle exec ruby examples/stampede_sim.rb [seed]
#
# Runs offline; the upstream is a shared counter with feelings.

require_relative "../lib/agentic"

# 40 scripted failures are the point, not news
Agentic.logger.level = :fatal

WORKERS = 20
BACKOFF = 0.12
BUCKET_MS = 20

def run_stampede(jitter:, seed:)
  srand(seed) # jitter uses Kernel#rand; seed it for a fair comparison
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  retry_arrivals = []
  attempts = Hash.new(0)

  orchestrator = Agentic::PlanOrchestrator.new(
    concurrency_limit: WORKERS,
    retry_policy: {
      max_retries: 2,
      retryable_errors: ["RuntimeError"],
      backoff_strategy: :constant,
      backoff_constant: BACKOFF,
      backoff_jitter: jitter
    }
  )

  WORKERS.times do |i|
    task = Agentic::Task.new(
      description: "worker-#{i}",
      agent_spec: {"name" => "worker", "instructions" => "call upstream"}
    )
    orchestrator.add_task(task, agent: ->(t) {
      attempts[t.description] += 1
      if attempts[t.description] == 1
        raise "upstream hiccup" # everyone fails together at t=0
      end

      retry_arrivals << Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      :ok
    })
  end

  orchestrator.execute_plan
  retry_arrivals
end

def histogram(arrivals)
  buckets = Hash.new(0)
  arrivals.each { |t| buckets[(t * 1000 / BUCKET_MS).floor * BUCKET_MS] += 1 }
  buckets.sort.map { |bucket_ms, count|
    format("    %4d-%4dms  %-20s %d", bucket_ms, bucket_ms + BUCKET_MS, "#" * count, count)
  }.join("\n")
end

seed = (ARGV.first || 20260707).to_i

puts "STAMPEDE SIMULATOR: #{WORKERS} workers, all failing at t=0, " \
  "#{(BACKOFF * 1000).round}ms constant backoff"
puts

herd = run_stampede(jitter: false, seed: seed)
puts "  jitter OFF (retry arrivals per #{BUCKET_MS}ms bucket):"
puts histogram(herd)
peak_off = herd.group_by { |t| (t * 1000 / BUCKET_MS).floor }.values.map(&:size).max

spread = run_stampede(jitter: true, seed: seed)
puts
puts "  jitter ON - the default (same workers, same failure, same seed):"
puts histogram(spread)
peak_on = spread.group_by { |t| (t * 1000 / BUCKET_MS).floor }.values.map(&:size).max

puts
puts format("  peak herd size per bucket:  %d without jitter  ->  %d with", peak_off, peak_on)
puts
puts "twenty synchronized retries is a second outage wearing a recovery"
puts "costume. jitter is on by default now; the upstream sends its thanks."
