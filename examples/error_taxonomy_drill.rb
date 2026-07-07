# frozen_string_literal: true

# The Error Taxonomy Drill: three tasks fail three different ways -
# a rate limit (retryable, says the error itself), an auth failure
# (not retryable, says the error itself), and a mystery error (no
# opinion, so the policy's type list decides). One retry policy,
# three correct outcomes, because errors now testify.
#
#   bundle exec ruby examples/error_taxonomy_drill.rb
#
# Runs offline and deterministically.

require_relative "../lib/agentic"

attempts = Hash.new(0)

drills = {
  "rate-limited sync" => lambda { |task|
    attempts[task.description] += 1
    if attempts[task.description] < 3
      raise Agentic::Errors::LlmRateLimitError.new("429 slow down", retry_after: 1)
    end
    "synced on attempt #{attempts[task.description]}"
  },
  "bad-credentials sync" => lambda { |task|
    attempts[task.description] += 1
    raise Agentic::Errors::LlmAuthenticationError.new("401 key revoked")
  },
  "mystery-error sync" => lambda { |task|
    attempts[task.description] += 1
    raise "something vague" if attempts[task.description] < 2
    "recovered on attempt #{attempts[task.description]}"
  }
}

orchestrator = Agentic::PlanOrchestrator.new(
  concurrency_limit: 3,
  retry_policy: {
    max_retries: 3,
    backoff_strategy: :constant,
    backoff_constant: 0.02,
    # The type list is the fallback for errors with no opinion.
    # RuntimeError is listed; the auth error's own verdict will overrule
    # any list. That's the point.
    retryable_errors: ["RuntimeError", "Agentic::Errors::LlmAuthenticationError"]
  }
)

tasks = drills.map do |name, drill|
  task = Agentic::Task.new(
    description: name,
    agent_spec: {"name" => name, "instructions" => "call the API"},
    payload: drill
  )
  orchestrator.add_task(task, agent: ->(t) { t.payload.call(t) })
  task
end

result = orchestrator.execute_plan

puts "ERROR TAXONOMY DRILL (max 3 retries for everyone)"
puts
tasks.each do |task|
  task_result = result.results[task.id]
  outcome = task_result.successful? ? task_result.output : "gave up: #{task_result.failure.message}"
  verdict = task_result.successful? ? "OK " : "DEAD"
  puts format("  %s %-22s %d attempt(s)  %s", verdict, task.description, attempts[task.description], outcome)
end

puts
puts "plan: #{result.status}"
puts
puts "why each outcome is right:"
puts "  - the rate limit said retryable? -> true: retried until it cleared"
puts "  - the auth error said retryable? -> false: ONE attempt, even though"
puts "    someone unwisely put it in the retryable_errors list. a revoked"
puts "    key does not improve with persistence; the error knew that"
puts "  - the mystery RuntimeError had no opinion: the policy's type list"
puts "    decided, and it earned its second chance"
