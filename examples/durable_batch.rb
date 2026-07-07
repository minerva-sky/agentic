# frozen_string_literal: true

# The Durable Batch: six billable "LLM calls" run under an
# ExecutionJournal. Mid-batch, the process dies for real - exit!, no
# cleanup, the honest kill -9. Then a second process replays the
# journal and finishes the batch WITHOUT re-paying for completed work.
#
#   bundle exec ruby examples/durable_batch.rb
#
# Runs offline; the "API" is sleep plus an invoice counter. The number
# to watch is the last one: total paid should equal the batch size,
# crash or no crash.

require_relative "../lib/agentic"
require "tmpdir"

# exit! discards buffered IO - the child's narration would die with it
$stdout.sync = true

JOURNAL = File.join(Dir.tmpdir, "agentic_durable_batch.journal.jsonl")
File.delete(JOURNAL) if File.exist?(JOURNAL)

INVOICES = %w[invoice-1 invoice-2 invoice-3 invoice-4 invoice-5 invoice-6].freeze
COST_PER_CALL = 0.25 # dollars of imaginary tokens

# Bills the imaginary API, then optionally dies like a deploy
BillableAgent = Struct.new(:crash_on, :billed) do
  def execute(prompt)
    invoice = prompt[/invoice-\d+/]
    sleep(0.05) # the API call we pay for
    billed << invoice

    if invoice == crash_on
      puts "  !! power cut during #{invoice} - process dying with exit!(97)"
      Process.exit!(97) # no ensure blocks, no at_exit - a real crash
    end

    {"invoice" => invoice, "status" => "paid"}
  end
end

Desk = Struct.new(:agent) do
  def get_agent_for_task(_task)
    agent
  end
end

def run_batch(label, skip: [], crash_on: nil)
  journal = Agentic::ExecutionJournal.new(path: JOURNAL)
  billed = []
  orchestrator = Agentic::PlanOrchestrator.new(
    concurrency_limit: 1, # deterministic order, one call in flight
    lifecycle_hooks: journal.lifecycle_hooks
  )

  todo = INVOICES - skip
  todo.each do |invoice|
    orchestrator.add_task(Agentic::Task.new(
      description: invoice,
      agent_spec: {"name" => "Biller", "instructions" => "Process #{invoice}"},
      input: {}
    ))
  end

  puts "#{label}: processing #{todo.size} invoice(s): #{todo.join(", ")}"
  orchestrator.execute_plan(Desk.new(BillableAgent.new(crash_on, billed)))
  billed
end

# Maps journal task ids back to invoice names via task_started events
def completed_invoices(state)
  names = state.events.each_with_object({}) do |event, map|
    map[event[:task_id]] = event[:description] if event[:event] == "task_started"
  end
  state.completed_task_ids.map { |id| names[id] }
end

# --- Run 1: a child process that will not survive invoice-4 ---------------
child = fork do
  run_batch("run 1", crash_on: "invoice-4")
end
_, status = Process.wait2(child)
puts "  child exited with status #{status.exitstatus} (journal survived on disk)"
puts

# --- The journal knows exactly what was paid for --------------------------
state = Agentic::ExecutionJournal.replay(path: JOURNAL)
paid = completed_invoices(state)
puts "journal replay: #{paid.size} invoice(s) already paid: #{paid.join(", ")}"
puts "                #{INVOICES.size - paid.size} remain (including the one mid-flight when we died)"
puts

# --- Run 2: same batch, skip what the journal proves is done --------------
billed_in_run2 = run_batch("run 2", skip: paid)
puts

total_calls = paid.size + 1 + billed_in_run2.size # +1: paid for, then died during
naive_calls = paid.size + 1 + INVOICES.size # rerunning the whole batch
puts "RECEIPT"
puts "  run 1 paid:  #{paid.size + 1} calls (#{paid.size} journaled + 1 lost to the crash)"
puts "  run 2 paid:  #{billed_in_run2.size} calls"
puts format("  total spend: $%.2f for %d invoices (naive rerun-everything: $%.2f)",
  total_calls * COST_PER_CALL, INVOICES.size, naive_calls * COST_PER_CALL)
puts "  journal: #{JOURNAL}"
