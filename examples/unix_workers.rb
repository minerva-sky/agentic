# frozen_string_literal: true

# Unix Workers: I like Unix because the operating system already
# solved process supervision and nobody told the frameworks. A
# master preforks N plan workers, work arrives on a pipe, SIGTERM
# means "finish what you hold, then die with dignity", and the
# master reaps every child by PID and exit status. No supervisor
# gem, no thread pool config - fork(2), pipe(2), kill(2), wait(2).
#
#   bundle exec ruby examples/unix_workers.rb
#
# Runs offline; every process is real, every signal is real.

require_relative "../lib/agentic"
require "json"
require "tmpdir"

Agentic.logger.level = :fatal

WORKERS = 3
JOBS = 9

# Work arrives on a shared pipe: the kernel does the load balancing
# (whichever worker reads first wins - it's a queue because Unix
# says it's a queue)
reader, writer = IO.pipe
results_reader, results_writer = IO.pipe

pids = WORKERS.times.map do |n|
  fork do
    writer.close
    results_reader.close
    draining = false
    trap("TERM") { draining = true }

    journal = Agentic::ExecutionJournal.new(path: File.join(Dir.tmpdir, "agentic_worker_#{n}.jsonl"), fsync_every: 10)
    served = 0
    until draining
      line = begin
        reader.read_nonblock(256)
      rescue IO::WaitReadable
        sleep(0.005)
        next
      rescue EOFError
        break
      end
      line.split("\n").each do |job|
        orchestrator = Agentic::PlanOrchestrator.new(lifecycle_hooks: journal.lifecycle_hooks)
        task = Agentic::Task.new(description: job, agent_spec: {"name" => "w", "instructions" => "w"})
        orchestrator.add_task(task, agent: ->(_t) {
          sleep(0.03)
          "#{job} done"
        })
        orchestrator.execute_plan
        served += 1
      end
    end
    journal.sync
    results_writer.puts JSON.generate({worker: n, pid: Process.pid, served: served})
    exit!(0)
  end
end
reader.close
results_writer.close

puts "UNIX WORKERS (master #{Process.pid}, #{WORKERS} preforked children: #{pids.join(", ")})"
puts

# Feed the pipe as work actually arrives (paced) - a burst-written
# pipe gets drained by whoever reads first, which is a queue but not
# a fair one; arrival pacing is what lets the whole fleet lift
JOBS.times do |i|
  writer.puts "job-#{i}"
  sleep(0.025)
end
sleep(0.1) # let the fleet finish chewing

# The deploy: TERM the fleet, then REAP it - by pid, with status
puts "  deploy signal: SIGTERM to all workers (finish what you hold, then exit)"
pids.each { |pid| Process.kill("TERM", pid) }
statuses = pids.map { |pid| Process.wait2(pid) }
writer.close

reports = results_reader.read.lines.map { |l| JSON.parse(l, symbolize_names: true) }.sort_by { |r| r[:worker] }
puts
puts "  the reaping (every child accounted for, by pid and exit status):"
statuses.each do |pid, status|
  report = reports.find { |r| r[:pid] == pid }
  puts format("    pid %-7d exit %-3d served %d job(s)", pid, status.exitstatus, report ? report[:served] : 0)
end
puts format("  total served: %d/%d; unserved jobs stay in the pipe for the NEXT fleet", reports.sum { |r| r[:served] }, JOBS)
puts
puts "  count what's NOT here: no supervisor gem, no worker heartbeat"
puts "  table, no distributed lock. fork gave us isolation (a worker"
puts "  segfault kills ONE plan), the shared pipe gave us a work queue"
puts "  with kernel-grade load balancing, TERM-then-wait2 gave us"
puts "  deploys that finish in-flight work, and each worker's journal"
puts "  (flock'd - the process drill proved it) survives its process."
puts "  the operating system is the best framework you already have;"
puts "  it's just that its DSL is spelled fork, pipe, kill, and wait."

clean = statuses.all? { |_, s| s.exitstatus.zero? } && reports.sum { |r| r[:served] } == JOBS
exit(clean ? 0 : 1)
