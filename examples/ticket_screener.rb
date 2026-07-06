# frozen_string_literal: true

# A HEY-style ticket screener: every inbound support ticket flows
# through screen -> categorize -> draft, all tickets in parallel.
# The inbox you see at the end is the product.
#
#   bundle exec ruby examples/ticket_screener.rb
#
# Runs offline: screening heuristics are lambda-backed capabilities.
# With an API key you'd swap the draft capability for the LLM client -
# same pipeline, better prose.

require_relative "../lib/agentic"

TICKETS = [
  {id: "T-101", from: "carol@bigco.example", subject: "Invoice shows wrong amount",
   body: "Our March invoice is $400 higher than the plan we're on."},
  {id: "T-102", from: "winner@lottery.example", subject: "You have WON $1,000,000!!!",
   body: "Click here immediately to claim your prize before it expires!!!"},
  {id: "T-103", from: "dev@startup.example", subject: "API returns 500 on /v2/orders",
   body: "Since this morning every POST to /v2/orders returns a 500. Stack trace attached."},
  {id: "T-104", from: "sam@agency.example", subject: "Love the product",
   body: "No question - just wanted to say the new dashboard is great."},
  {id: "T-105", from: "urgent-notice@refund-dept.example", subject: "Re: Re: Your account refund",
   body: "Dear customer, verify your bank details here to receive your refund."}
].freeze

# One capability per pipeline stage - small, testable, swappable
def register(name, inputs, outputs, &impl)
  spec = Agentic::CapabilitySpecification.new(
    name: name, description: name.tr("_", " "), version: "1.0.0",
    inputs: inputs, outputs: outputs
  )
  Agentic.register_capability(
    spec, Agentic::CapabilityProvider.new(capability: spec, implementation: impl)
  )
end

register("screen",
  {from: {type: "string", required: true}, subject: {type: "string", required: true}, body: {type: "string", required: true}},
  {verdict: {type: "string", required: true}}) do |t|
  spammy = t[:subject].count("!") >= 2 || t[:body].match?(/click here|verify your bank|claim your prize/i)
  {verdict: spammy ? "screened_out" : "in"}
end

register("categorize",
  {subject: {type: "string", required: true}, body: {type: "string", required: true}},
  {category: {type: "string", required: true}, urgent: {type: "boolean", required: true}}) do |t|
  text = "#{t[:subject]} #{t[:body]}".downcase
  category =
    if text.match?(/invoice|billing|charge|amount/) then "billing"
    elsif text.match?(/500|error|bug|stack trace|fail/) then "engineering"
    else
      "general"
    end
  {category: category, urgent: text.match?(/500|every|down|urgent/)}
end

register("draft_reply",
  {subject: {type: "string", required: true}, category: {type: "string", required: true}},
  {draft: {type: "string", required: true}}) do |t|
  openers = {
    "billing" => "Thanks for flagging this - I've pulled up your invoice and I'm checking the discrepancy now.",
    "engineering" => "Sorry about that - I've escalated this to the on-call engineer and we're digging in.",
    "general" => "Thanks for writing in - really appreciate you taking the time."
  }
  {draft: "Re: #{t[:subject]}\n    #{openers.fetch(t[:category])}"}
end

# The screener agent owns all three stages
screener = Agentic::Agent.build { |a| a.name = "Screener" }
%w[screen categorize draft_reply].each { |c| screener.add_capability(c) }

# Each ticket is a task; the orchestrator fans them out in parallel
TicketDesk = Struct.new(:agent, :inbox) do
  def get_agent_for_task(task)
    desk = self
    ticket = TICKETS.find { |t| t[:id] == task.description }
    Object.new.tap do |worker|
      worker.define_singleton_method(:execute) do |_prompt|
        verdict = desk.agent.execute_capability("screen", ticket.slice(:from, :subject, :body))[:verdict]
        entry = ticket.slice(:id, :from, :subject).merge(verdict: verdict)

        if verdict == "in"
          triage = desk.agent.execute_capability("categorize", ticket.slice(:subject, :body))
          entry[:category] = triage[:category]
          entry[:urgent] = triage[:urgent]
          entry[:draft] = desk.agent.execute_capability(
            "draft_reply", {subject: ticket[:subject], category: triage[:category]}
          )[:draft]
        end

        desk.inbox << entry
        entry
      end
    end
  end
end

inbox = []
orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 5)
TICKETS.each do |ticket|
  orchestrator.add_task(Agentic::Task.new(
    description: ticket[:id],
    agent_spec: {"name" => "Screener", "instructions" => "Screen this ticket"},
    input: {}
  ))
end
result = orchestrator.execute_plan(TicketDesk.new(screener, inbox))

screened_in = inbox.select { |t| t[:verdict] == "in" }.sort_by { |t| t[:urgent] ? 0 : 1 }
screened_out = inbox - screened_in

puts "INBOX (#{screened_in.size})"
screened_in.each do |t|
  flag = t[:urgent] ? "URGENT " : ""
  puts "  #{flag}[#{t[:category]}] #{t[:id]} #{t[:subject]} - #{t[:from]}"
  puts "    #{t[:draft]}"
end
puts
puts "SCREENED OUT (#{screened_out.size})"
screened_out.each { |t| puts "  #{t[:id]} #{t[:subject]}" }
puts
puts "(#{TICKETS.size} tickets, #{result.status} in #{(result.execution_time * 1000).round}ms)"
