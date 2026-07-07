# frozen_string_literal: true

# The Latency Lab: 20 simulated LLM calls (200ms of IO each) executed
# through the orchestrator at different concurrency limits, all inside
# ONE reactor - plus a heartbeat task running alongside the plan to
# prove the orchestrator composes with its host instead of seizing it.
#
#   bundle exec ruby examples/latency_lab.rb
#
# Runs offline: the "API" is sleep, which under the async fiber
# scheduler yields exactly like a socket would.

require_relative "../lib/agentic"

TASK_COUNT = 20
SIMULATED_LATENCY = 0.2 # seconds per "API call"

# An agent whose only skill is waiting on the network, convincingly
class SimulatedApiAgent
  def execute(_prompt)
    sleep(SIMULATED_LATENCY) # non-blocking under the fiber scheduler
    {"status" => "ok"}
  end
end

class LabProvider
  def get_agent_for_task(_task)
    SimulatedApiAgent.new
  end
end

def build_orchestrator(limit)
  orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: limit)
  TASK_COUNT.times do |i|
    orchestrator.add_task(Agentic::Task.new(
      description: "call ##{i + 1}",
      agent_spec: {"name" => "API", "instructions" => "wait"},
      input: {}
    ))
  end
  orchestrator
end

puts "#{TASK_COUNT} tasks x #{(SIMULATED_LATENCY * 1000).round}ms of simulated IO"
puts "serial floor: #{(TASK_COUNT * SIMULATED_LATENCY).round(1)}s | " \
  "perfect fan-out: #{SIMULATED_LATENCY}s"
puts

[1, 4, 20].each do |limit|
  result = build_orchestrator(limit).execute_plan(LabProvider.new)
  ideal = (TASK_COUNT.to_f / limit) * SIMULATED_LATENCY
  puts format(
    "concurrency %2d -> %5.2fs wall  (ideal %5.2fs, %d/%d completed)",
    limit, result.execution_time, ideal,
    result.results.count { |_, r| r.successful? }, TASK_COUNT
  )
end

# Composition proof: the plan runs INSIDE a host reactor while a
# sibling heartbeat task keeps beating - the orchestrator joins the
# reactor rather than blocking it
puts
puts "composition check (plan + heartbeat sharing one reactor):"
beats = 0
Sync do |host|
  heartbeat = host.async do
    loop do
      sleep(0.1)
      beats += 1
    end
  end

  result = build_orchestrator(10).execute_plan(LabProvider.new)
  heartbeat.stop

  puts format(
    "  plan: %.2fs, heartbeat kept beating: %d beats while the plan ran",
    result.execution_time, beats
  )
end
puts beats.positive? ? "  the reactor stayed alive - structured concurrency, not a hijack" :
  "  heartbeat starved - the orchestrator monopolized the reactor!"
