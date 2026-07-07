# frozen_string_literal: true

# The Cancel Drill: structured concurrency's core promise is that
# cancellation is PROMPT - stop means stop, not "finish everything
# and then agree you'd stopped". Three drills measure what each
# cancel path actually delivers: the surgical ones keep the promise;
# the plan-wide one, under a joined reactor, turns out to be
# bookkeeping wearing a stop sign.
#
#   bundle exec ruby examples/cancel_drill.rb
#
# Runs offline; every claim below is a measurement.

require_relative "../lib/agentic"
require "async"

Agentic.logger.level = :fatal

JOB = 0.1

def build(count, agent_runs)
  orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 2)
  epoch = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  tasks = count.times.map { |i|
    Agentic::Task.new(description: "job#{i}", agent_spec: {"name" => "w", "instructions" => "w"})
  }
  tasks.each do |task|
    orchestrator.add_task(task, agent: ->(_t) {
      agent_runs << [task.description, Process.clock_gettime(Process::CLOCK_MONOTONIC) - epoch]
      sleep(JOB)
      :ok
    })
  end
  [orchestrator, tasks]
end

def states(orchestrator)
  orchestrator.instance_variable_get(:@execution_state).transform_values(&:size)
    .reject { |_, v| v.zero? }.map { |k, v| "#{v} #{k}" }.join(", ")
end

puts "CANCEL DRILL (6 jobs of #{(JOB * 1000).to_i}ms, 2 lanes; full plan = 300ms)"
puts

# --- drill 1: surgical cancel of one IN-FLIGHT task ---------------------------
runs = []
orchestrator, tasks = build(6, runs)
elapsed = nil
Sync do
  runner = Async { orchestrator.execute_plan }
  Async do
    sleep(0.03) # job0 and job1 are mid-sleep
    orchestrator.cancel_task(tasks[0].id)
  end
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  runner.wait
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
end
third_start = (runs[2][1] * 1000).round
puts "  drill 1 - cancel ONE in-flight task (at 30ms):"
puts "    #{states(orchestrator)}; plan finished in #{(elapsed * 1000).round}ms"
puts "    the proof the lane was freed is WHEN the next job started:"
puts "    #{runs[2][0]} began at #{third_start}ms - on the canceled fiber's lane,"
puts "    immediately - not at 100ms when that job would have finished."
puts

# --- drill 2: surgical cancel of one PENDING task ------------------------------
runs2 = []
orchestrator2, tasks2 = build(6, runs2)
Sync do
  runner = Async { orchestrator2.execute_plan }
  Async do
    sleep(0.03)
    orchestrator2.cancel_task(tasks2[5].id) # still queued behind the lanes
  end
  runner.wait
end
puts "  drill 2 - cancel ONE pending task:"
puts "    #{states(orchestrator2)}; agents actually ran: #{runs2.size}/6"
puts "    the canceled job never started and never billed. queued work"
puts "    canceled is money returned."
puts

# --- drill 3: cancel_plan mid-flight -------------------------------------------
runs3 = []
orchestrator3, = build(6, runs3)
flip_ms = wall = nil
Sync do
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  runner = Async { orchestrator3.execute_plan }
  Async do
    sleep(0.03)
    orchestrator3.cancel_plan
    flip_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
  end
  runner.wait
  wall = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
end
puts "  drill 3 - cancel_plan at 30ms:"
puts "    status flipped to :canceled by #{flip_ms}ms - and then the plan ran"
puts "    #{(wall * 1000).round}ms anyway, with #{runs3.size}/6 agents executing (#{states(orchestrator3)})."
puts
puts "  the drill's verdict: task-level cancel keeps the structured-"
puts "  concurrency promise - stop is prompt, lanes are freed, unstarted"
puts "  work stays unstarted. plan-level cancel under a joined reactor"
puts "  is bookkeeping wearing a stop sign: every task reports :canceled"
puts "  while every agent runs to completion and bills you, results"
puts "  discarded. that's the worst trade available - full cost, zero"
puts "  product. filed as the round-11 ask: cancel_plan must stop the"
puts "  scheduler and the in-flight fibers, not just restate their status."
