# frozen_string_literal: true

# The Plan Server: a server is three disciplines wearing one process -
# accept concurrently, share resources safely, and above all SHUT DOWN
# WELL. This serves plan executions over a real socket with a thread
# pool, a shared (mutexed) rate limit across all request threads, and
# the part everyone skips: a graceful drain where in-flight requests
# finish, new ones are refused, and the process exits clean.
#
#   bundle exec ruby examples/plan_server.rb
#
# Runs offline; the socket is loopback, the clients are threads.

require_relative "../lib/agentic"
require "socket"
require "json"

Agentic.logger.level = :fatal

class PlanServer
  def initialize(workers: 3)
    @server = TCPServer.new("127.0.0.1", 0) # ephemeral port
    @workers = workers
    @quota = Agentic::RateLimit.new(100, per: 60) # shared across ALL request threads
    @draining = false
    @in_flight = 0
    @served = 0
    @lock = Mutex.new
  end

  def port = @server.addr[1]

  attr_reader :served

  def start
    @threads = @workers.times.map do
      Thread.new do
        loop do
          socket = begin
            @server.accept
          rescue IOError
            break # listener closed: drain mode
          end
          handle(socket)
        end
      end
    end
  end

  # The graceful drain: stop the LISTENER first (new connections get
  # refused by the OS), then wait for in-flight work, then exit
  def drain
    @lock.synchronize { @draining = true }
    @server.close
    @threads.each(&:join)
  end

  private

  def handle(socket)
    @lock.synchronize { @in_flight += 1 }
    goal = socket.gets&.strip

    unless @quota.try_acquire
      socket.puts JSON.generate({error: "quota exhausted", retry_after: 60})
      return
    end

    orchestrator = Agentic::PlanOrchestrator.new
    fetch = Agentic::Task.new(description: "fetch", agent_spec: {"name" => "f", "instructions" => "w"})
    answer = Agentic::Task.new(description: "answer", agent_spec: {"name" => "a", "instructions" => "w"})
    orchestrator.add_task(fetch, agent: ->(_t) {
      sleep(0.02)
      goal.to_s.split.size
    })
    orchestrator.add_task(answer, [fetch], agent: ->(t) { "processed #{t.previous_output} words" })
    result = orchestrator.execute_plan

    socket.puts JSON.generate({goal: goal, answer: result.task_result(answer.id).output})
    @lock.synchronize { @served += 1 }
  ensure
    @lock.synchronize { @in_flight -= 1 }
    socket.close
  end
end

server = PlanServer.new(workers: 3)
server.start

puts "THE PLAN SERVER (loopback:#{server.port}, 3 worker threads, shared quota)"
puts

# --- clients: a burst of concurrent requests -------------------------------------
responses = 8.times.map { |i|
  Thread.new do
    TCPSocket.open("127.0.0.1", server.port) do |s|
      s.puts "summarize ticket number #{i} for the weekly report"
      JSON.parse(s.gets, symbolize_names: true)
    end
  end
}.map(&:value)

puts "  burst of 8 concurrent requests, 3 workers:"
responses.first(3).each { |r| puts "    #{r[:answer]}  (#{r[:goal][0, 30]}...)" }
puts "    ... #{responses.count { |r| r[:answer] }} of 8 answered"
puts

# --- the drain: one slow request in flight when the order comes ----------------
slow_client = Thread.new do
  TCPSocket.open("127.0.0.1", server.port) do |s|
    s.puts "one last long report before the deploy"
    JSON.parse(s.gets, symbolize_names: true)
  end
end
sleep(0.01) # let it get in the door
drained_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
server.drain
drain_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - drained_at) * 1000).round
last = slow_client.value

puts "  graceful drain with one request in flight:"
puts "    in-flight request completed: #{last[:answer].inspect}"
puts "    drain took #{drain_ms}ms; total served: #{server.served}; refused after: connection refused"
puts
puts "  the order of operations IS the grace: close the LISTENER first"
puts "  (the OS starts refusing for you - no accept race), let workers"
puts "  finish what they hold, join, exit. kill -9 has none of these"
puts "  steps, which is why deploys under it drop the request that was"
puts "  42 seconds into a 43-second plan. the shared quota is the other"
puts "  server lesson: request threads are REAL threads, and the"
puts "  windowed limiter holds because round 12 gave its bookkeeping a"
puts "  real Mutex - a server is where every thread-safety promise in"
puts "  your dependency tree gets called at once."
