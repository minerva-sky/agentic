# frozen_string_literal: true

# The Telemetry Bus: lifecycle hooks are callbacks - one producer,
# one consumer, coupled at configuration time. A telemetry bus
# inverts that: the orchestrator emits NAMED EVENTS into a bus, and
# any number of handlers attach, detach, and crash independently.
# The producer never learns who is listening. This is the :telemetry
# pattern Elixir converged on, because every library inventing its
# own instrumentation callbacks was the worse world.
#
#   bundle exec ruby examples/telemetry_bus.rb
#
# Runs offline; three handlers listen, one detaches mid-flight.

require_relative "../lib/agentic"

Agentic.logger.level = :fatal

# The bus: names, payloads, and isolation. A crashing handler is
# detached and reported - it never takes the plan down with it.
class TelemetryBus
  def initialize
    @handlers = Hash.new { |h, k| h[k] = {} }
  end

  def attach(id, event, &handler)
    @handlers[event][id] = handler
  end

  def detach(id)
    @handlers.each_value { |hs| hs.delete(id) }
  end

  def execute(event, measurements, metadata = {})
    @handlers[event].each do |id, handler|
      handler.call(measurements, metadata)
    rescue => e
      detach(id)
      puts "    [bus] handler #{id} crashed (#{e.class}) - detached, plan unharmed"
    end
  end
end

BUS = TelemetryBus.new

# The bridge: hooks in, events out. This is the ONLY place the
# orchestrator and the bus know about each other.
def telemetry_hooks(bus)
  {
    after_task_success: ->(task_id:, task:, result:, duration:) {
      bus.execute([:agentic, :task, :success], {duration: duration}, {task: task.description})
    },
    after_task_failure: ->(task_id:, task:, failure:, duration:) {
      bus.execute([:agentic, :task, :failure], {duration: duration}, {task: task.description, type: failure.type})
    },
    plan_completed: ->(plan_id:, status:, execution_time:, tasks:, results:) {
      bus.execute([:agentic, :plan, :completed], {execution_time: execution_time}, {status: status})
    }
  }
end

# Handler 1: a metrics counter - knows nothing about logging or tracing
metrics = Hash.new(0)
BUS.attach(:metrics, [:agentic, :task, :success]) { |m, _| metrics[:tasks] += 1 }
BUS.attach(:metrics2, [:agentic, :task, :failure]) { |m, _| metrics[:failures] += 1 }

# Handler 2: a slow-task tracer - only speaks when something is worth saying
BUS.attach(:tracer, [:agentic, :task, :success]) do |measurements, metadata|
  puts "    [trace] SLOW: #{metadata[:task]} took #{(measurements[:duration] * 1000).round}ms" if measurements[:duration] > 0.05
end

# Handler 3: a fragile exporter someone deployed on a Friday
BUS.attach(:exporter, [:agentic, :task, :success]) do |_m, metadata|
  raise IOError, "export endpoint down" if metadata[:task] == "enrich"
end

def run_plan(bus)
  orchestrator = Agentic::PlanOrchestrator.new(lifecycle_hooks: telemetry_hooks(bus))
  fetch = Agentic::Task.new(description: "fetch", agent_spec: {"name" => "w", "instructions" => "w"})
  enrich = Agentic::Task.new(description: "enrich", agent_spec: {"name" => "w", "instructions" => "w"})
  publish = Agentic::Task.new(description: "publish", agent_spec: {"name" => "w", "instructions" => "w"})
  orchestrator.add_task(fetch, agent: ->(_t) { sleep(0.01) })
  orchestrator.add_task(enrich, [fetch], agent: ->(_t) { sleep(0.08) })
  orchestrator.add_task(publish, [enrich], agent: ->(_t) { sleep(0.01) })
  orchestrator.execute_plan
end

puts "TELEMETRY BUS (three handlers, one bridge, zero coupling)"
puts
puts "  run 1 - all handlers attached:"
run_plan(BUS)
puts "    [metrics] #{metrics.inspect}"
puts

puts "  run 2 - tracer detached at runtime (ops got tired of it):"
BUS.detach(:tracer)
run_plan(BUS)
puts "    [metrics] #{metrics.inspect}"
puts
puts "  the orchestrator emitted the same events both runs - it cannot"
puts "  tell that the tracer left or that the exporter crashed, and"
puts "  that ignorance is the feature. hooks couple one producer to"
puts "  one consumer at configuration time; a bus decouples N handlers"
puts "  at RUNTIME, with isolation (the Friday exporter died alone)."
puts "  event names are namespaced tuples, measurements are separated"
puts "  from metadata - steal the whole :telemetry design; it was"
puts "  right. the framework's hooks made the bridge ten lines, which"
puts "  is exactly what hooks are for: being the floor a bus stands on."
