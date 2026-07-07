# frozen_string_literal: true

# The Progress Channel: broadcasting plan progress to N subscribers
# is easy until one subscriber is slow - then your "real-time" layer
# quietly becomes a memory leak or a brake on the plan itself.
# AnyCable years distilled to one rule: every channel names its
# BACKPRESSURE POLICY. This one offers two - :latest_wins for
# dashboards (drop stale frames), :every_event for auditors (bounded
# buffer, disconnect on overflow) - and proves each under a slow
# subscriber.
#
#   bundle exec ruby examples/progress_channel.rb
#
# Runs offline; the slow subscriber is deliberately awful.

require_relative "../lib/agentic"

Agentic.logger.level = :fatal

class ProgressChannel
  Subscriber = Struct.new(:name, :policy, :queue, :dropped, :dead, keyword_init: true)
  BUFFER_LIMIT = 8

  def initialize
    @subscribers = []
    @lock = Mutex.new
  end

  def subscribe(name, policy:)
    subscriber = Subscriber.new(name: name, policy: policy, queue: [], dropped: 0, dead: false)
    @lock.synchronize { @subscribers << subscriber }
    subscriber
  end

  # Publish never blocks and never fails the publisher - the plan's
  # fiber is doing real work; the channel absorbs or sheds, by policy
  def publish(event)
    @lock.synchronize do
      @subscribers.each do |sub|
        next if sub.dead

        case sub.policy
        when :latest_wins
          sub.dropped += sub.queue.size
          sub.queue.clear
          sub.queue << event
        when :every_event
          if sub.queue.size >= BUFFER_LIMIT
            sub.dead = true # an auditor with gaps is worse than no auditor
            sub.queue.clear
          else
            sub.queue << event
          end
        end
      end
    end
  end

  def hooks
    {
      task_slot_acquired: ->(task_id:, task:, waited:) { publish({at: :start, task: task.description}) },
      after_task_success: ->(task_id:, task:, result:, duration:) { publish({at: :done, task: task.description}) }
    }
  end
end

channel = ProgressChannel.new
dashboard = channel.subscribe("dashboard", policy: :latest_wins)   # slow: renders at its own pace
auditor = channel.subscribe("auditor", policy: :every_event)       # must see everything or nothing
firehose = channel.subscribe("firehose", policy: :every_event)     # fast consumer, drains promptly

orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 2, lifecycle_hooks: channel.hooks)
previous = nil
10.times do |i|
  task = Agentic::Task.new(description: "step-#{i}", agent_spec: {"name" => "s", "instructions" => "w"})
  orchestrator.add_task(task, previous ? [previous] : [], agent: ->(_t) {
    # the fast consumer drains during the plan; the others just... don't
    firehose.queue.clear
    sleep(0.055)
    :ok
  })
  previous = task
end

started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
orchestrator.execute_plan
elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

puts "THE PROGRESS CHANNEL (backpressure is a policy, and policies have names)"
puts
puts format("  plan: 10 sequential tasks in %dms (publish never blocked it)", (elapsed * 1000).round)
puts
puts format("  %-11s %-13s %s", "subscriber", "policy", "outcome after a slow session")
puts format("  %-11s %-13s holding %d frame (the LATEST); %d stale frames dropped",
  dashboard.name, dashboard.policy, dashboard.queue.size, dashboard.dropped)
puts format("  %-11s %-13s DISCONNECTED at buffer %d - it fell behind and gaps were unacceptable",
  auditor.name, auditor.policy, ProgressChannel::BUFFER_LIMIT)
puts format("  %-11s %-13s alive and current (it kept draining)", firehose.name, firehose.policy)
puts
puts "  the two policies are two PROMISES, and mixing them up is how"
puts "  real-time layers hurt people: a dashboard promised every-event"
puts "  buffers unboundedly behind one laggy browser tab until the"
puts "  publisher OOMs; an auditor promised latest-wins silently has"
puts "  holes exactly where the incident was. so the subscriber DECLARES"
puts "  which lie it can live with - stale (dashboard) or absent"
puts "  (auditor, disconnected LOUDLY so someone reconnects it) - and"
puts "  the publisher never blocks either way, because the plan's fibers"
puts "  have real work to do and instrumentation must never be the"
puts "  brake. name your backpressure policy or it names itself in"
puts "  production, and its name will be 'incident'."
