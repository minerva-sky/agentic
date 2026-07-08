# frozen_string_literal: true

# The Kill Switch: feature flags answer "who should get this?";
# kill switches answer a grimmer question - "how fast can a human
# make this STOP?" Every capability that talks to money, email, or
# an external API needs a big red button: instant, global, requiring
# no deploy, leaving an audit trail of who pressed it and why. Two
# minutes of incident is a story; twenty is a postmortem.
#
#   bundle exec ruby examples/kill_switch.rb
#
# Runs offline; an incident is simulated, the button is pressed.

require_relative "../lib/agentic"
require "tmpdir"

Agentic.logger.level = :fatal

class KillSwitches
  def initialize(journal:)
    @journal = journal
    @killed = {}
    @lock = Mutex.new
  end

  # Killing takes WHO and WHY - a red button with no audit trail
  # becomes a mystery outage six months later
  def kill!(capability, by:, reason:)
    @lock.synchronize { @killed[capability] = {by: by, reason: reason} }
    @journal.record(:kill_switch, description: capability, actor: by, reason: reason, state: "killed")
  end

  def restore!(capability, by:)
    @lock.synchronize { @killed.delete(capability) }
    @journal.record(:kill_switch, description: capability, actor: by, state: "restored")
  end

  def killed?(capability) = @lock.synchronize { @killed.key?(capability) }

  # The guard wraps an agent: killed capabilities fail fast with a
  # HOPELESS verdict - retrying a kill switch is defying the human
  def guard(capability, agent)
    lambda do |task|
      if killed?(capability)
        info = @lock.synchronize { @killed[capability] }
        raise Agentic::Errors::LlmAuthenticationError, # non-retryable: a human said stop
          "#{capability} is KILLED (by #{info[:by]}: #{info[:reason]})"
      end
      agent.call(task)
    end
  end
end

journal = Agentic::ExecutionJournal.new(path: File.join(Dir.tmpdir, "agentic_kill.jsonl"))
File.delete(journal.path) if File.exist?(journal.path)
switches = KillSwitches.new(journal: journal)

def run_digest(switches, journal)
  orchestrator = Agentic::PlanOrchestrator.new(
    lifecycle_hooks: journal.lifecycle_hooks, retry_policy: {max_retries: 0, retryable_errors: []}
  )
  summarize = Agentic::Task.new(description: "summarize", agent_spec: {"name" => "s", "instructions" => "w"})
  email = Agentic::Task.new(description: "email:digest", agent_spec: {"name" => "e", "instructions" => "w"})
  orchestrator.add_task(summarize, agent: switches.guard("llm:summarize", ->(_t) { "42 tickets summarized" }))
  orchestrator.add_task(email, [summarize], agent: switches.guard("email:send", ->(t) { "emailed: #{t.previous_output}" }))
  orchestrator.execute_plan
end

puts "THE KILL SWITCH (how fast can a human make it stop?)"
puts

result = run_digest(switches, journal)
puts "  monday, all switches closed:"
puts "    digest ran: #{result.results.values.map(&:output).last.inspect}"
puts

# TUESDAY, 09:14 - the email provider is duplicating sends. INCIDENT.
switches.kill!("email:send", by: "oncall-dana", reason: "provider duplicating sends, INC-2291")
result = run_digest(switches, journal)
failed = result.results.values.find { |r| !r.successful? }
puts "  tuesday 09:14, email:send KILLED mid-incident:"
puts "    digest status: #{result.status}"
puts "    #{failed.failure.message}"
puts "    summarize still ran (only the risky capability is dark);"
puts "    verdict journaled retryable: #{failed.failure.retryable?.inspect} - the dead letter office"
puts "    will PARK these, not hammer a bleeding provider with retries."
puts

switches.restore!("email:send", by: "oncall-dana")
result = run_digest(switches, journal)
puts "  tuesday 11:40, provider fixed, switch restored:"
puts "    digest ran: #{result.results.values.map(&:output).last.inspect}"
puts

state = Agentic::ExecutionJournal.replay(path: journal.path)
flips = state.events.select { |e| e[:event] == "kill_switch" }
puts "  the audit trail (same journal as the work):"
flips.each { |f| puts format("    %-14s %-9s by %-12s %s", f[:description], f[:state], f[:actor], f[:reason]) }
puts
puts "  design notes written in pager ink: the switch is checked at USE"
puts "  time (no deploy, no restart - the next task sees it); killing is"
puts "  per-CAPABILITY, not global (summarize kept working; dark the"
puts "  organ, not the patient); killed calls fail with a NON-RETRYABLE"
puts "  verdict because a human said stop and the retry machinery must"
puts "  not out-vote her; and every flip records who and why, because"
puts "  the switch nobody remembers pressing is the outage nobody can"
puts "  end. flags ask who should get a feature. switches answer how"
puts "  fast you can take one away. build both; press calmly."
