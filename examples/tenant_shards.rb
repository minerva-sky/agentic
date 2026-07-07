# frozen_string_literal: true

# Tenant Shards: at scale, "the plan" becomes "the plan, per shard" -
# same pipeline, isolated blast radius. Each shard gets its own
# journal (its own recovery story) and its own rate limit (its own
# noisy neighbor containment), under one control plane. Shard 2
# crashes mid-run; the rerun resumes ONLY what shard 2 didn't finish,
# because recovery, like everything at scale, must be per-shard.
#
#   bundle exec ruby examples/tenant_shards.rb
#
# Runs offline; the crash is scripted, the resume is real.

require_relative "../lib/agentic"
require "tmpdir"

Agentic.logger.level = :fatal

SHARDS = {
  "shard_1" => %w[acme globex],
  "shard_2" => %w[initech umbrella hooli],
  "shard_3" => %w[wonka]
}.freeze
PIPELINE = %w[extract transform load].freeze

def journal_path(shard) = File.join(Dir.tmpdir, "agentic_#{shard}.journal.jsonl")

# One shard's run: its own journal, its own limiter, resume-aware
def run_shard(shard, tenants, crash_at: nil)
  journal = Agentic::ExecutionJournal.new(path: journal_path(shard))
  done = Agentic::ExecutionJournal.replay(path: journal_path(shard))
  limiter = Agentic::RateLimit.new(2) # per-shard: a hot shard can't starve the others

  orchestrator = Agentic::PlanOrchestrator.new(
    concurrency_limit: 2, lifecycle_hooks: journal.lifecycle_hooks,
    retry_policy: {max_retries: 0, retryable_errors: []}
  )
  ran = 0
  skipped = 0
  tenants.each do |tenant|
    previous = nil
    PIPELINE.each do |step|
      name = "#{tenant}:#{step}"
      if done.completed?(name)
        skipped += 1
        next
      end

      task = Agentic::Task.new(description: name, agent_spec: {"name" => name, "instructions" => "run"})
      orchestrator.add_task(task, previous ? [previous] : [], agent: ->(t) {
        raise "power cut" if crash_at == t.description

        limiter.acquire { sleep(0.002) }
        ran += 1
        :ok
      })
      previous = task
    end
  end
  status = orchestrator.execute_plan.status
  [status, ran, skipped]
end

puts "TENANT SHARDS (#{SHARDS.size} shards, #{SHARDS.values.sum(&:size)} tenants, pipeline: #{PIPELINE.join(" -> ")})"
puts
SHARDS.each_key { |shard| File.delete(journal_path(shard)) if File.exist?(journal_path(shard)) }

puts "  run 1 - shard_2 loses power mid-tenant:"
SHARDS.each do |shard, tenants|
  crash = (shard == "shard_2") ? "umbrella:transform" : nil
  status, ran, = run_shard(shard, tenants, crash_at: crash)
  puts format("    %-9s %-16s %2d steps ran%s", shard, status, ran,
    crash ? "  <- crashed at #{crash}" : "")
end
puts

puts "  run 2 - control plane reruns everything; journals decide what that means:"
SHARDS.each do |shard, tenants|
  status, ran, skipped = run_shard(shard, tenants)
  puts format("    %-9s %-16s %2d steps ran, %2d skipped (already journaled)", shard, status, ran, skipped)
end
puts
puts "  the rerun was issued fleet-wide - the control plane doesn't"
puts "  track which shard crashed, and shouldn't have to. shard 1 and 3"
puts "  skipped everything (their journals proved completion); shard 2"
puts "  re-ran only from the crash point. that's the sharding contract:"
puts "  one plan definition, N isolated executions, N recovery stories,"
puts "  N rate limits - and a blast radius that ends at the shard"
puts "  boundary. scale isn't a bigger machine; it's smaller failures."
