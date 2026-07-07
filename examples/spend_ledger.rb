# frozen_string_literal: true

# The Spend Ledger: LLM plans spend real money, and money has rules
# older than software - integer cents (floats round YOUR money, never
# theirs), a ledger where every entry has a description, and a budget
# that stops the spending BEFORE the overdraft, not in the postmortem.
# The journal already receipts every task; this makes the receipts
# denominate.
#
#   bundle exec ruby examples/spend_ledger.rb
#
# Runs offline; the invoice at the end balances to the cent.

require_relative "../lib/agentic"
require "tmpdir"

Agentic.logger.level = :fatal

# Price list in INTEGER CENTS. 0.1 + 0.2 != 0.3 is a cute trivia
# question everywhere except billing, where it's a lawsuit.
PRICES = {
  "fetch:tickets" => 0,        # api call, free tier
  "classify:batch" => 240,     # cheap model
  "draft:responses" => 1875,   # expensive model, long output
  "review:drafts" => 1875,
  "polish:tone" => 950,
  "render:report" => 0
}.freeze

BUDGET_CENTS = 4_500

class SpendLedger
  attr_reader :entries

  def initialize(budget_cents:, journal:)
    @budget_cents = budget_cents
    @journal = journal
    @entries = []
  end

  def spent_cents = @entries.sum { |e| e[:cents] }

  def remaining_cents = @budget_cents - spent_cents

  # The affordability check runs BEFORE the work: a budget that only
  # notices overdrafts is a historian, not a control
  def afford!(description, cents)
    if cents > remaining_cents
      @journal.record(:spend_declined, description: description, cents: cents, remaining_cents: remaining_cents)
      raise Agentic::Errors::LlmRateLimitError, # budget exhaustion is transient: tomorrow has a new budget
        "budget: #{description} costs #{format_cents(cents)} but only #{format_cents(remaining_cents)} remains"
    end

    @entries << {description: description, cents: cents}
    @journal.record(:spend, description: description, cents: cents, remaining_cents: remaining_cents)
  end

  def format_cents(cents) = format("$%.2f", cents / 100.0)

  def invoice
    puts format("    %-20s %10s %12s", "item", "amount", "running")
    running = 0
    @entries.each do |e|
      running += e[:cents]
      puts format("    %-20s %10s %12s", e[:description], format_cents(e[:cents]), format_cents(running))
    end
    puts format("    %-20s %10s   (budget %s)", "TOTAL", format_cents(spent_cents), format_cents(@budget_cents))
  end
end

journal = Agentic::ExecutionJournal.new(path: File.join(Dir.tmpdir, "agentic_spend.jsonl"))
File.delete(journal.path) if File.exist?(journal.path)
ledger = SpendLedger.new(budget_cents: BUDGET_CENTS, journal: journal)

orchestrator = Agentic::PlanOrchestrator.new(
  concurrency_limit: 1, lifecycle_hooks: journal.lifecycle_hooks,
  retry_policy: {max_retries: 0, retryable_errors: []}
)
previous = nil
PRICES.each do |name, cents|
  task = Agentic::Task.new(description: name, agent_spec: {"name" => name, "instructions" => "w"})
  orchestrator.add_task(task, previous ? [previous] : [], agent: ->(_t) {
    ledger.afford!(name, cents)
    "#{name} done"
  })
  previous = task
end

puts "THE SPEND LEDGER (budget #{ledger.format_cents(BUDGET_CENTS)}, prices in integer cents)"
puts
result = orchestrator.execute_plan
puts "  plan status: #{result.status}"
failed = result.results.values.find { |r| !r.successful? }
puts "  stopped at: #{failed.failure.message}" if failed
puts
puts "  the invoice (from the ledger, balances to the cent):"
ledger.invoice
puts
state = Agentic::ExecutionJournal.replay(path: journal.path)
declined = state.events.count { |e| e[:event] == "spend_declined" }
puts "  journal receipts: #{state.events.count { |e| e[:event] == "spend" }} spends, #{declined} declined - the money"
puts "  trail and the work trail live in ONE fsynced file, so 'what did"
puts "  this run cost' and 'what did this run do' are the same replay."
puts
puts "  three rules from every payments postmortem I've read: INTEGER"
puts "  CENTS (floats round your money eventually, and eventually is"
puts "  audit season); check affordability BEFORE the spend (a budget"
puts "  that only notices overdrafts is a historian); and classify"
puts "  budget-stop as RETRYABLE - tomorrow has a new budget, so the"
puts "  dead letter office requeues it instead of parking it with the"
puts "  revoked keys. the plan stopped at #{ledger.format_cents(ledger.spent_cents)} of #{ledger.format_cents(BUDGET_CENTS)}, which is"
puts "  the entire point: the overdraft that didn't happen is invisible"
puts "  in every metric except the one that matters."
