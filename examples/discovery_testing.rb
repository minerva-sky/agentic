# frozen_string_literal: true

# Discovery Testing: most people use test doubles to ISOLATE code
# that already exists. The better trick is using them to DISCOVER
# code that doesn't: start at the top with fakes for collaborators
# you haven't designed yet, let the failing test tell you what
# interfaces you wish existed, then descend one level and make each
# wish real. The doubles are scaffolding; the interfaces they
# discovered are the building.
#
#   bundle exec ruby examples/discovery_testing.rb
#
# Runs offline; three acts, each act's checks actually execute.

require_relative "../lib/agentic"

Agentic.logger.level = :fatal

CHECKS = []
def check(claim, ok) = CHECKS << [claim, ok]

# --- ACT 1: the top, with everything below it imaginary -------------------------
# We want a TicketTriager. What does it NEED? We don't know yet - so
# we write the fakes we WISH existed, and the wishes become the design.
class TicketTriager
  def initialize(classifier:, router:)
    @classifier = classifier
    @router = router
  end

  def triage(ticket)
    label = @classifier.classify(ticket[:text]) # <- wish #1: classify(text) -> label
    @router.route(ticket[:id], label)           # <- wish #2: route(id, label) -> receipt
  end
end

fake_classifier = Class.new {
  def classify(text) = "billing"
}.new
fake_router = Class.new {
  attr_reader :routed

  def route(id, label)
    (@routed = [id, label]) && "receipt-#{id}"
  end
}.new

triager = TicketTriager.new(classifier: fake_classifier, router: fake_router)
receipt = triager.triage({id: 7, text: "refund please"})
check("act 1: triager orchestrates two DISCOVERED interfaces", receipt == "receipt-7" && fake_router.routed == [7, "billing"])

# --- ACT 2: descend one level - realize the classifier, router stays fake -------
# The wish list from act 1 is now a spec: classify(text) -> label.
class KeywordClassifier
  def classify(text) = text.match?(/refund|charge/i) ? "billing" : "general"
end

check("act 2: real classifier honors the discovered interface",
  KeywordClassifier.new.classify("refund please") == "billing" &&
  KeywordClassifier.new.classify("hello") == "general")

triager = TicketTriager.new(classifier: KeywordClassifier.new, router: fake_router)
check("act 2: triager unchanged as fakes become real (the seam held)",
  triager.triage({id: 8, text: "you charged me twice"}) == "receipt-8")

# --- ACT 3: realize the router AS A PLAN - the seams become tasks ----------------
class PlanRouter
  def route(id, label)
    orchestrator = Agentic::PlanOrchestrator.new
    enqueue = Agentic::Task.new(description: "enqueue:#{id}", agent_spec: {"name" => "q", "instructions" => "w"})
    notify = Agentic::Task.new(description: "notify:#{id}", agent_spec: {"name" => "n", "instructions" => "w"})
    orchestrator.add_task(enqueue, agent: ->(_t) { "#{label}-queue" })
    orchestrator.add_task(notify, [enqueue], agent: ->(t) { "receipt-#{id} (#{t.previous_output})" })
    orchestrator.execute_plan.task_result(notify.id).output
  end
end

triager = TicketTriager.new(classifier: KeywordClassifier.new, router: PlanRouter.new)
check("act 3: router realized as a two-task plan, same interface",
  triager.triage({id: 9, text: "refund"}) == "receipt-9 (billing-queue)")

# The final honesty pass: every fake must still match the real thing
# it stood in for (round 12's verifier, kept in the toolbox)
[[fake_classifier, KeywordClassifier], [fake_router, PlanRouter]].each do |fake, real|
  real.instance_methods(false).each do |m|
    matches = fake.respond_to?(m) && fake.method(m).parameters.map(&:first) == real.instance_method(m).parameters.map(&:first)
    check("fakes still match reality: ##{m}", matches)
  end
end

puts "DISCOVERY TESTING (the fakes are scaffolding; the interfaces are the building)"
puts
CHECKS.each { |claim, ok| puts format("  %-4s %s", ok ? "ok" : "FAIL", claim) }
failures = CHECKS.count { |_, ok| !ok }
puts
puts "  read the acts as a design session, because that's what they were:"
puts "  act 1 wrote fakes for collaborators that DIDN'T EXIST, and the"
puts "  messages we wished for (classify(text), route(id, label)) became"
puts "  the design - discovered under test pressure, not drawn on a"
puts "  whiteboard. act 2 made one wish real without touching the"
puts "  triager: the seam held, which is the proof the seam was right."
puts "  act 3's payoff is the plan-shaped one: a discovered interface is"
puts "  INDIFFERENT to whether a lambda, a class, or a whole orchestrated"
puts "  plan stands behind it - route(id, label) became two tasks and"
puts "  nobody upstream knew. and the last checks keep the round-12"
puts "  rule: fakes that outlive their realization must show their"
puts "  papers, or they quietly start vouching for a design that moved."
exit(failures.zero? ? 0 : 1)
