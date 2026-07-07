# frozen_string_literal: true

# The Retry Budget: a retry storm is a self-inflicted DDoS - every
# job politely retrying 3x turns one outage into four. Retries are a
# SHARED resource, so give the fleet one wallet: transient failures
# spend from it, hopeless failures spend nothing (they get no retry
# at all), and when the wallet is empty the kindest thing left is
# failing fast - the fleet already knows the upstream is down.
#
#   bundle exec ruby examples/retry_budget.rb
#
# Runs offline; the upstream is dead for the whole run.

require_relative "../lib/agentic"
require "tmpdir"

Agentic.logger.level = :fatal

MAX_RETRIES = 3
JOBS = 12

# The wallet is a windowed RateLimit asked politely: try_acquire
# (round 11) answers false RIGHT NOW instead of making the caller
# wait for capacity - and waiting for retry capacity during an
# outage would just be the storm with extra steps. The custom
# budget class this example shipped with has retired.
class RetryBudget
  def initialize(allowance, per: 60)
    @wallet = Agentic::RateLimit.new(allowance, per: per)
    @spent = 0
  end

  attr_reader :spent

  def spend?
    admitted = @wallet.try_acquire
    @spent += 1 if admitted
    admitted
  end
end

def run_job(name, error, journal)
  orchestrator = Agentic::PlanOrchestrator.new(
    lifecycle_hooks: journal.lifecycle_hooks,
    retry_policy: {max_retries: 0, retryable_errors: []}
  )
  orchestrator.add_task(Agentic::Task.new(
    description: name, agent_spec: {"name" => "w", "instructions" => "sync"}
  ), agent: ->(_t) { raise error })
  orchestrator.execute_plan
end

def drill(strategy, budget: nil)
  path = File.join(Dir.tmpdir, "agentic_budget_#{strategy}.jsonl")
  File.delete(path) if File.exist?(path)
  journal = Agentic::ExecutionJournal.new(path: path)

  calls = 0
  fast_failed = 0
  JOBS.times do |i|
    # Job 7 hits a revoked key; everyone else hits the dead upstream
    error = (i == 7) ? Agentic::Errors::LlmAuthenticationError.new("401") : Agentic::Errors::LlmServerError.new("503")
    attempts = 0
    loop do
      run_job("job#{i}", error, journal)
      calls += 1
      attempts += 1

      verdict = Agentic::ExecutionJournal.replay(path: path).events
        .reverse.find { |e| e[:event] == "task_failed" }[:retryable]
      break if verdict == false # hopeless: no retry spends anything, ever
      break if attempts > MAX_RETRIES

      if budget
        unless budget.spend?
          fast_failed += 1
          break
        end
      end
    end
  end
  [calls, fast_failed, budget&.spent]
end

puts "RETRY BUDGET (#{JOBS} jobs, upstream dead, max #{MAX_RETRIES} retries each)"
puts

calls_a, = drill("naive")
puts "  strategy A - every job for itself:"
puts "    #{calls_a} calls fired at a host that was down for all of them."
puts "    11 transient jobs x (1 + #{MAX_RETRIES} retries) + 1 auth job x 1 = #{calls_a}:"
puts "    the outage was 1 incident; the fleet made it #{calls_a} requests."
puts

budget = RetryBudget.new(5)
calls_b, fast_failed, spent = drill("budgeted", budget: budget)
puts "  strategy B - one wallet of 5 retries for the whole fleet:"
puts "    #{calls_b} calls total: #{JOBS} first attempts + #{spent} budgeted retries."
puts "    #{fast_failed} jobs failed FAST once the wallet emptied - no call, no"
puts "    timeout, no bill. the auth job spent nothing from the wallet:"
puts "    hopeless failures don't get retries, so they can't drain the"
puts "    budget the transient ones might still need."
puts
puts "  the fleet cut #{calls_a - calls_b} pointless requests (#{calls_a} -> #{calls_b}) and lost nothing -"
puts "  every retry was doomed anyway. per-job retry policies answer"
puts "  \"should I try again?\"; the budget answers \"should ANYONE?\" -"
puts "  round 9's breaker asked that per-upstream, this asks it per-"
puts "  window, and both read the same journaled verdicts. retries are"
puts "  a shared resource. give them a wallet, not a habit. (and the"
puts "  wallet is now a real windowed RateLimit - try_acquire says no"
puts "  without making anyone wait for it, which is the entire point.)"
