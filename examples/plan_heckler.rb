# frozen_string_literal: true

# The Plan Heckler: mutation testing for workflows. Your plan has
# tests. Cute. Do the tests actually FAIL when the plan is wrong, or
# are they decoration? The heckler finds out the honest way: it
# breaks the plan on purpose - five sabotages, one at a time - and
# runs your spec against each mutant. A mutant your spec kills is
# coverage. A mutant that SURVIVES is a bug your tests would wave
# through the door. Tests that can't fail aren't tests.
#
#   bundle exec ruby examples/plan_heckler.rb
#
# Runs offline; exits 1 if any mutant survives the final spec.

require_relative "../lib/agentic"

Agentic.logger.level = :fatal

SMALL_ORDER = [{sku: "flog", cents: 4200}, {sku: "flay", cents: 3100}].freeze # 7300, under the discount bar
BULK_ORDER = [{sku: "flog", cents: 4200}] * 3                                 # 12600, discount fires
SMALL_GOLDEN = 7884   # 7300 * 1.08, hand-priced
BULK_GOLDEN = 12_247  # (12600 * 0.9) * 1.08 = 12247.2, rounded

# --- the plan under test: a pricing pipeline, optionally sabotaged ----------------
def build_pipeline(order, mutation = nil)
  orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 1)
  ran = []
  stage = ->(name, deps, fn) {
    task = Agentic::Task.new(description: name, agent_spec: {"name" => name, "instructions" => "price"})
    orchestrator.add_task(task, deps, agent: ->(t) {
      ran << name
      fn.call(t.previous_output)
    })
    task
  }

  price_fn = ->(_) { {cents: order.sum { |i| i[:cents] }} }
  price_fn = ->(_) { {cents: 0} } if mutation == :price_returns_zero

  discount_fn = ->(o) { {cents: (o[:cents] >= 10_000) ? (o[:cents] * 0.9).round : o[:cents]} }
  discount_fn = ->(o) { o } if mutation == :discount_never_fires

  tax_rate = (mutation == :tax_off_by_10x) ? 1.008 : 1.08
  tax_fn = ->(o) { {cents: (o[:cents] * tax_rate).round} }

  receipt_fn = ->(o) { "TOTAL: #{o[:cents]} cents" }
  receipt_fn = ->(o) { "TOTAL: #{o[:cents] / 100 * 100} cents" } if mutation == :receipt_truncates

  price = stage.call("price", [], price_fn)
  discount = stage.call("discount", [price], discount_fn)
  tax = stage.call("tax", [discount], tax_fn)
  receipt_dep = (mutation == :tax_stage_bypassed) ? discount : tax
  receipt = stage.call("receipt", [receipt_dep], receipt_fn)

  [orchestrator, receipt, ran]
end

MUTANTS = [:price_returns_zero, :discount_never_fires, :tax_off_by_10x, :tax_stage_bypassed, :receipt_truncates].freeze

# --- three specs: what the team wrote, then what the heckler extorts, twice -------
SPEC_V1 = {
  "plan completes" => ->(runs) { runs.all? { |r| r[:result].status == :completed } },
  "receipt says TOTAL" => ->(runs) { runs.all? { |r| r[:out].to_s.include?("TOTAL") } },
  "total is positive" => ->(runs) { runs.all? { |r| r[:out].to_s[/\d+/].to_i.positive? } }
}.freeze

SPEC_V2 = SPEC_V1.merge(
  "small order prices to the golden 7884" => ->(runs) { runs.first[:out].to_s[/\d+/].to_i == SMALL_GOLDEN },
  "all four stages ran, in order" => ->(runs) { runs.all? { |r| r[:ran] == %w[price discount tax receipt] } }
).freeze

SPEC_V3 = SPEC_V2.merge(
  "BULK order prices to the golden 12247" => ->(runs) { runs.last[:out].to_s[/\d+/].to_i == BULK_GOLDEN }
).freeze

def run_spec(spec, mutation = nil)
  runs = [SMALL_ORDER, BULK_ORDER].map do |order|
    orchestrator, receipt, ran = build_pipeline(order, mutation)
    result = orchestrator.execute_plan
    {result: result, out: result.task_result(receipt.id)&.output, ran: ran}
  end
  spec.reject { |_name, check| check.call(runs) }.keys
end

def heckle(spec_name, spec)
  puts "  heckling with #{spec_name} (#{spec.size} assertions):"
  survivors = MUTANTS.reject do |mutation|
    failed = run_spec(spec, mutation)
    puts format("    %-22s %s", mutation, failed.any? ? "KILLED by #{failed.first.inspect}" : "SURVIVED - your tests shrug")
    failed.any?
  end
  puts format("    score: %d/%d mutants killed", MUTANTS.size - survivors.size, MUTANTS.size)
  puts
  survivors
end

puts "THE PLAN HECKLER (tests that can't fail aren't tests)"
puts

baseline = run_spec(SPEC_V3)
abort("  baseline is red; heckling a broken plan proves nothing") unless baseline.empty?
puts "  baseline: unmutated plan passes every assertion (heckling requires green)"
puts

heckle("SPEC v1 - the tests the team wrote", SPEC_V1)
survivors_v2 = heckle("SPEC v2 - plus one golden total and a stage roll-call", SPEC_V2)
survivors_v3 = heckle("SPEC v3 - plus a golden total that CROSSES the discount bar", SPEC_V3)

puts "  v1 waved four saboteurs through - \"completes, says TOTAL, positive\""
puts "  can't see a bypassed tax stage or a 10x rate error. v2's golden"
puts "  number killed three more, but #{survivors_v2.first} still walked:"
puts "  the small order never crosses the discount bar, so a dead discount"
puts "  branch is INVISIBLE to any assertion about it. that's the heckler's"
puts "  real product - it doesn't just grade your assertions, it audits your"
puts "  FIXTURES: every branch your inputs never reach is a mutant sanctuary."
puts "  one bulk order later, 5/5. pin golden numbers you priced by hand,"
puts "  roll-call the stages, and make your inputs visit every branch."
puts "  mutation testing doesn't ask whether tests pass; it asks whether"
puts "  they can FAIL - the only thing a test is for."
exit(survivors_v3.empty? ? 0 : 1)
