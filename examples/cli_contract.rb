# frozen_string_literal: true

# The CLI Contract: a command-line tool is an API whose clients are
# shell scripts, cron, CI, and a tired human at 2am - and each of
# those clients reads a different channel. Data goes to stdout,
# diagnostics to stderr, the verdict goes in the EXIT CODE, and
# --format json exists because your most important user is a pipe.
# This wraps a plan in a CLI that honors all four, then proves it
# by invoking itself the way scripts would.
#
#   bundle exec ruby examples/cli_contract.rb
#
# Runs offline; each invocation is captured like a shell would see it.

require_relative "../lib/agentic"
require "json"
require "stringio"

Agentic.logger.level = :fatal

# The tool: `digest [--format json|text] [--quiet] [--fail]`
module DigestCLI
  EXIT_OK = 0
  EXIT_PARTIAL = 1
  EXIT_USAGE = 64 # EX_USAGE from sysexits.h - scripts can tell "it failed" from "I called it wrong"

  def self.run(argv, stdout:, stderr:)
    options = {format: "text", quiet: false, fail: false}
    argv.each do |arg|
      case arg
      when "--format=json" then options[:format] = "json"
      when "--format=text" then options[:format] = "text"
      when "--quiet" then options[:quiet] = true
      when "--fail" then options[:fail] = true # scripted failure, for the demo
      else
        stderr.puts "error: unknown option #{arg}"
        stderr.puts "usage: digest [--format=json|text] [--quiet]"
        return EXIT_USAGE
      end
    end

    orchestrator = Agentic::PlanOrchestrator.new(retry_policy: {max_retries: 0, retryable_errors: []})
    fetch = Agentic::Task.new(description: "fetch", agent_spec: {"name" => "f", "instructions" => "w"})
    rank = Agentic::Task.new(description: "rank", agent_spec: {"name" => "r", "instructions" => "w"})
    orchestrator.add_task(fetch, agent: ->(_t) { %w[story-a story-b story-c] })
    orchestrator.add_task(rank, [fetch], agent: ->(t) {
      raise Agentic::Errors::LlmServerError, "ranker 503" if options[:fail]

      t.previous_output.sort
    })

    stderr.puts "digest: running 2 tasks..." unless options[:quiet]
    result = orchestrator.execute_plan

    if result.successful?
      stories = result.task_result(rank.id).output
      if options[:format] == "json"
        stdout.puts JSON.generate({stories: stories, count: stories.size})
      else
        stories.each { |s| stdout.puts s }
      end
      stderr.puts "digest: done (#{stories.size} stories)" unless options[:quiet]
      EXIT_OK
    else
      failure = result.results.values.find { |r| !r.successful? }.failure
      stderr.puts "digest: FAILED at rank: #{failure.message}"
      stderr.puts "digest: hint: transient upstream error - rerun, or check the ranker's status page"
      EXIT_PARTIAL
    end
  end
end

def invoke(argv)
  out = StringIO.new
  err = StringIO.new
  code = DigestCLI.run(argv, stdout: out, stderr: err)
  [code, out.string, err.string]
end

puts "THE CLI CONTRACT (four channels, each with one job)"
puts
INVOCATIONS = [
  ["human at a terminal", []],
  ["pipe to jq", ["--format=json", "--quiet"]],
  ["cron (quiet until it matters)", ["--quiet", "--fail"]],
  ["typo'd flag", ["--formt=json"]]
].freeze

INVOCATIONS.each do |label, argv|
  code, out, err = invoke(argv)
  puts "  $ digest #{argv.join(" ")}".rstrip + "   (#{label})"
  out.lines.each { |l| puts "    stdout | #{l}" }
  err.lines.each { |l| puts "    stderr | #{l}" }
  puts "    exit   | #{code}"
  puts
end

puts "  read the invocations like their consumers would: the human got"
puts "  progress on stderr and stories on stdout (so `digest > out.txt`"
puts "  captures DATA, not chatter). the pipe got pure JSON and silence -"
puts "  jq never chokes on a progress message. cron stayed quiet until"
puts "  failure, then got a diagnosis AND a hint on stderr with exit 1"
puts "  (so || alerting fires). and the typo got exit 64 - EX_USAGE -"
puts "  because \"you called me wrong\" and \"the work failed\" are"
puts "  different facts and scripts deserve to tell them apart. none of"
puts "  this is glamorous; all of it is the difference between a CLI"
puts "  people script against and one they script AROUND."
