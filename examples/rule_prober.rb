# frozen_string_literal: true

# The Rule Prober: structured rules declare which fields they read -
# so now that claim can be AUDITED. For each rule, perturb fields it
# does NOT declare; if the verdict flips, the rule is reading fields
# off the books. One of the rules below lies. The prober finds it.
#
#   bundle exec ruby examples/rule_prober.rb [seed]
#
# Runs offline and deterministically.

require_relative "../lib/agentic"

seed = (ARGV.first || 20260707).to_i
rng = Random.new(seed)

SPEC = Agentic::CapabilitySpecification.new(
  name: "approve_loan",
  description: "Approve a loan application",
  version: "1.0.0",
  inputs: {
    amount: {type: "number", required: true, min: 1},
    income: {type: "number", required: true, min: 0},
    score: {type: "number", required: true, min: 300, max: 850},
    cosigned: {type: "boolean", required: true}
  },
  rules: {
    affordability: {
      message: "amount may not exceed 5x income",
      fields: [:amount, :income],
      check: ->(i) { i[:amount] <= i[:income] * 5 }
    },
    subprime_needs_cosigner: {
      message: "scores under 600 require a cosigner",
      fields: [:score, :cosigned],
      check: ->(i) { i[:score] >= 600 || i[:cosigned] }
    },
    # The liar: declares [:amount] but secretly reads :score too
    jumbo_screening: {
      message: "amounts over 400k get extra screening",
      fields: [:amount],
      check: ->(i) { i[:amount] <= 400_000 || i[:score] > 700 }
    }
  }
)

# Generate a conforming application
def sample_application(rng)
  {
    amount: rng.rand(10_000..900_000),
    income: rng.rand(30_000..250_000),
    score: rng.rand(300..850),
    cosigned: [true, false].sample(random: rng)
  }
end

# Perturb one field to another conforming value
def perturb(application, field, rng)
  fresh = sample_application(rng)
  application.merge(field => fresh[field])
end

TRIALS = 300
findings = Hash.new { |h, k| h[k] = [] }

SPEC.rules.each do |rule_id, definition|
  undeclared = SPEC.inputs.keys - definition[:fields]

  TRIALS.times do
    application = sample_application(rng)
    verdict = definition[:check].call(application)

    undeclared.each do |field|
      mutated = perturb(application, field, rng)
      next if mutated == application

      if definition[:check].call(mutated) != verdict
        findings[rule_id] << field
      end
    end
  end
end

puts "RULE PROBER (seed #{seed}, #{TRIALS} trials per rule)"
puts
SPEC.rules.each do |rule_id, definition|
  flipped = findings[rule_id].tally
  if flipped.empty?
    puts "  #{rule_id}: honest - declares #{definition[:fields].inspect}, " \
      "and no undeclared field ever changed its verdict"
  else
    puts "  #{rule_id}: LYING - declares #{definition[:fields].inspect} but its verdict"
    flipped.each do |field, count|
      puts "    flipped when :#{field} changed (#{count} of #{TRIALS} trials)"
    end
  end
end

puts
puts "why it matters: Piotr's 422 renderer highlights the DECLARED fields."
puts "a rule that secretly reads :score sends users to fix :amount while"
puts "the real problem sits unhighlighted. field declarations are now"
puts "testable claims - so test them."
exit findings.empty? ? 0 : 1
