# frozen_string_literal: true

# The Job Adapter: your Rails app already has a vocabulary for
# background work - perform_later, retry_on, discard_on - and the
# fastest way to adopt a new tool is to let it speak that vocabulary.
# This wraps a plan in an ActiveJob-shaped class: retry_on maps to
# the framework's retry policy, discard_on maps to the hopeless
# convention, and your team learns nothing new until they want to.
#
#   bundle exec ruby examples/job_adapter.rb
#
# Runs offline; the queue is an array, the lessons are real.

require_relative "../lib/agentic"

Agentic.logger.level = :fatal

# ActiveJob's essential shape, mapped onto Agentic underneath
class PlanJob
  class << self
    attr_reader :retried, :discarded

    def retry_on(*errors, attempts: 3)
      @retried = {errors: errors, attempts: attempts}
    end

    def discard_on(*errors)
      @discarded = errors
    end

    def perform_later(**args)
      QUEUE << [self, args]
    end
  end

  def execute(**args)
    orchestrator = Agentic::PlanOrchestrator.new(
      retry_policy: {
        max_retries: self.class.retried[:attempts] - 1,
        retryable_errors: self.class.retried[:errors].map(&:name)
      }
    )
    build_plan(orchestrator, **args)
    result = orchestrator.execute_plan

    return {status: :ok} if result.successful?

    failure = result.results.values.find { |r| !r.successful? }.failure
    if self.class.discarded.any? { |e| failure.type == e.name } || failure.hopeless?
      {status: :discarded, reason: failure.message}
    else
      {status: :failed_will_requeue, reason: failure.message}
    end
  end
end

QUEUE = []

# --- the job your app would actually write ---------------------------------------
class DigestJob < PlanJob
  retry_on Agentic::Errors::LlmRateLimitError, attempts: 3
  discard_on Agentic::Errors::LlmAuthenticationError

  def build_plan(orchestrator, user:, flaky: 0, revoked: false)
    attempts = 0
    fetch = Agentic::Task.new(description: "fetch:#{user}", agent_spec: {"name" => "f", "instructions" => "w"})
    send_task = Agentic::Task.new(description: "send:#{user}", agent_spec: {"name" => "s", "instructions" => "w"})
    orchestrator.add_task(fetch, agent: ->(_t) {
      raise Agentic::Errors::LlmAuthenticationError, "401 key revoked" if revoked

      attempts += 1
      raise Agentic::Errors::LlmRateLimitError, "429" if attempts <= flaky

      "stories for #{user}"
    })
    orchestrator.add_task(send_task, [fetch], agent: ->(t) { "sent: #{t.previous_output}" })
  end
end

puts "THE JOB ADAPTER (ActiveJob's vocabulary, Agentic underneath)"
puts
DigestJob.perform_later(user: "rosa")
DigestJob.perform_later(user: "sam", flaky: 2)     # succeeds on 3rd try
DigestJob.perform_later(user: "kim", revoked: true) # hopeless

QUEUE.each do |job_class, args|
  outcome = job_class.new.execute(**args)
  puts format("  %-32s -> %s", "#{job_class}(#{args.map { |k, v| "#{k}: #{v}" }.join(", ")})", outcome.inspect)
end

puts
puts "  read the mapping, because it's the whole example: retry_on"
puts "  became the orchestrator's retry_policy (attempts: 3 means two"
puts "  retries - same accounting as ActiveJob), so sam's double-429"
puts "  healed INSIDE the plan without ever bouncing off the queue."
puts "  discard_on became a check on the failure's type PLUS the"
puts "  hopeless? convention, so kim's revoked key discards even if"
puts "  nobody remembered to list AuthenticationError - the error's own"
puts "  testimony backstops the macro. and the adapter is 40 lines"
puts "  because both vocabularies were already talking about the same"
puts "  three ideas: try again, give up, or ask a human. meet your"
puts "  team where they are; the framework doesn't mind the costume."
