# frozen_string_literal: true

# Ports and Adapters: the domain is the part of your app that would
# survive a framework migration - IF you kept it clean. Here the
# use-case (quote a shipment) is pure Ruby speaking only to PORTS;
# the adapters live at the edge; and Agentic is the delivery
# mechanism, replaced in the second act by a bare call to prove the
# domain never knew it was there. The proof is mechanical: the
# domain's source is scanned for framework constants.
#
#   bundle exec ruby examples/ports_and_adapters.rb
#
# Runs offline; exits 1 if the domain mentions the framework.

require_relative "../lib/agentic"

Agentic.logger.level = :fatal

# --- the domain (would survive the migration) -----------------------------------
DOMAIN_SOURCE = <<~RUBY
  class QuoteShipment
    Result = Struct.new(:price_cents, :carrier, keyword_init: true)

    def initialize(rate_source:, quote_repository:)
      @rate_source = rate_source        # port: #rate_for(mode)
      @quote_repository = quote_repository # port: #save(result)
    end

    def call(mode:, weight:)
      rate = @rate_source.rate_for(mode)
      result = Result.new(price_cents: (weight * rate).round, carrier: rate > 5 ? "premium" : "standard")
      @quote_repository.save(result)
      result
    end
  end
RUBY
eval(DOMAIN_SOURCE) # standard:disable Security/Eval -- the string exists so the purity scan below is honest

# --- the adapters (edge; disposable) --------------------------------------------
class StaticRates
  def rate_for(mode) = {"air" => 9, "sea" => 2}.fetch(mode)
end

class MemoryQuotes
  def all = @all ||= []

  def save(result) = all << result
end

# --- act one: Agentic as the delivery mechanism ---------------------------------
repo = MemoryQuotes.new
use_case = QuoteShipment.new(rate_source: StaticRates.new, quote_repository: repo)

orchestrator = Agentic::PlanOrchestrator.new
quote_task = Agentic::Task.new(
  description: "quote", agent_spec: {"name" => "quote", "instructions" => "quote"},
  payload: {mode: "air", weight: 120}
)
orchestrator.add_task(quote_task, agent: ->(t) { use_case.call(**t.payload) })
orchestrator.execute_plan

puts "PORTS AND ADAPTERS (the domain would survive the migration)"
puts
puts "  act one - delivered by Agentic:"
puts "    plan ran the use-case: #{repo.all.last.to_h}"
puts

# --- act two: the framework leaves; the domain doesn't notice -------------------
bare = use_case.call(mode: "sea", weight: 300)
puts "  act two - delivered by a bare method call:"
puts "    same use-case, no orchestrator: #{bare.to_h}"
puts "    repository holds #{repo.all.size} quotes; the domain never knew who called."
puts

# --- the proof: scan the domain for framework constants -------------------------
leaks = DOMAIN_SOURCE.scan(/\b(?:Agentic|PlanOrchestrator|Task|CapabilityS\w+)\b/).uniq - ["Task"]
leaks += DOMAIN_SOURCE.scan(/\bAgentic::\w+/)
puts "  the purity scan: grep the domain's source for framework constants"
if leaks.empty?
  puts "    0 mentions of the framework in the domain. the dependency"
  puts "    arrow points ONE way: the edge knows the center; the center"
  puts "    has never heard of the edge."
else
  puts "    LEAKED: #{leaks.join(", ")} - the domain is coupled to its delivery."
end
puts
puts "  what Agentic added in act one wasn't the business logic - it was"
puts "  everything AROUND it: retry policy, lifecycle hooks, journaling,"
puts "  concurrency, the graph. that's the correct division of labor:"
puts "  frameworks orchestrate; domains decide. the ports (#rate_for,"
puts "  #save) are the entire vocabulary the domain needs from the"
puts "  world, and both adapters fit in six lines because the ports"
puts "  asked for so little. clean architecture isn't ceremony - it's"
puts "  the freedom to change your mind about everything but the truth."

exit(leaks.empty? ? 0 : 1)
