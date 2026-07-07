# frozen_string_literal: true

# The Jitter Shootout: none vs equal (+/-25%, the default) vs full
# (uniform over [0, delay], new this round) - same forty workers, same
# synchronized failure, three retry-arrival histograms. Pick your
# herd size with your eyes open.
#
#   bundle exec ruby examples/jitter_shootout.rb [seed]
#
# Runs offline and deterministically.

require_relative "../lib/agentic"

Agentic.logger.level = :fatal

WORKERS = 40
BACKOFF = 0.15
BUCKET_MS = 25

def run_mode(jitter, seed)
  srand(seed)
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  arrivals = []
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
    orchestrator.add_task(Agentic::Task.new(
      description: "worker-#{i}",
      agent_spec: {"name" => "worker", "instructions" => "call"}
    ), agent: ->(t) {
      attempts[t.description] += 1
      raise "hiccup" if attempts[t.description] == 1

      arrivals << Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      :ok
    })
  end
  orchestrator.execute_plan
  arrivals
end

def report(label, arrivals)
  buckets = arrivals.group_by { |t| (t * 1000 / BUCKET_MS).floor }
  peak = buckets.values.map(&:size).max
  spread = ((arrivals.max - arrivals.min) * 1000).round

  puts "  #{label}:"
  buckets.sort.each do |bucket, hits|
    puts format("    %4d-%4dms  %-40s %d", bucket * BUCKET_MS, (bucket + 1) * BUCKET_MS,
      "#" * hits.size, hits.size)
  end
  puts format("    peak %d workers per bucket, spread %dms", peak, spread)
  puts
  peak
end

seed = (ARGV.first || 20260707).to_i
puts "JITTER SHOOTOUT: #{WORKERS} workers, synchronized failure, " \
  "#{(BACKOFF * 1000).round}ms base backoff (seed #{seed})"
puts

peaks = {
  "none (jitter: false)" => run_mode(false, seed),
  "equal +/-25% (the default)" => run_mode(true, seed),
  "full [0, delay] (jitter: :full)" => run_mode(:full, seed)
}.map { |label, arrivals| [label, report(label, arrivals)] }

puts "scoreboard (peak herd, smaller is safer):"
peaks.each { |label, peak| puts format("  %-32s %2d of %d", label, peak, WORKERS) }
puts
puts "full jitter trades punctuality for survival: retries land anywhere"
puts "in [0, delay], so some come back early and few come back TOGETHER."
puts "when the upstream is already hurting, together is the only wrong time."
