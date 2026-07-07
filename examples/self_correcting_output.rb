# frozen_string_literal: true

# Self-Correcting Output: the pattern that makes LLM components
# shippable. The model's output is validated against the capability's
# contract; violations don't raise to the user - they become the
# CORRECTION PROMPT for a bounded retry. The contract is the editor,
# the model is the writer, and the loop converges or fails honestly
# with the full paper trail.
#
#   bundle exec ruby examples/self_correcting_output.rb
#
# Runs offline; the "model" is scripted to be sloppy, then coachable.

require_relative "../lib/agentic"
require "json"

Agentic.logger.level = :fatal

CONTRACT = Agentic::CapabilitySpecification.new(
  name: "extract_invoice", description: "Extract structured invoice data", version: "1.0.0",
  inputs: {text: {type: "string", required: true}},
  outputs: {
    vendor: {type: "string", required: true, non_empty: true},
    total_cents: {type: "number", required: true, min: 0},
    currency: {type: "string", required: true, enum: %w[USD EUR GBP]},
    due_date: {type: "string", required: true}
  }
)
VALIDATOR = Agentic::CapabilityValidator.new(CONTRACT)

# The "model": pass 1 is what models actually do to schemas; pass 2
# reads the corrections like a chastened intern
MODEL = lambda do |prompt, attempt|
  if attempt == 1
    # currency invented, total as a string, due_date forgotten
    {vendor: "Initech Supply Co", total_cents: "4200", currency: "usd"}
  else
    # the correction prompt names each violation; the model complies
    {vendor: "Initech Supply Co", total_cents: 4200, currency: "USD", due_date: "2026-08-01"}
  end
end

def correction_prompt(violations)
  lines = violations.map { |field, messages| "- #{field}: #{messages.join("; ")}" }
  "Your previous answer violated the output contract:\n#{lines.join("\n")}\n" \
    "Return the SAME data corrected to satisfy every constraint. Do not apologize; return JSON."
end

MAX_ATTEMPTS = 3
INVOICE = "Invoice from Initech Supply Co, total $42.00, due Aug 1 2026"

puts "SELF-CORRECTING OUTPUT (the contract is the editor)"
puts
attempt = 0
output = nil
prompt = "Extract the invoice fields from: #{INVOICE}"
loop do
  attempt += 1
  output = MODEL.call(prompt, attempt)
  puts "  attempt #{attempt}: #{JSON.generate(output)}"
  begin
    VALIDATOR.validate_outputs!(output)
    puts "  -> contract satisfied. shipped after #{attempt} attempt(s)."
    break
  rescue Agentic::Errors::ValidationError => e
    if attempt >= MAX_ATTEMPTS
      puts "  -> #{MAX_ATTEMPTS} attempts exhausted; failing HONESTLY with the paper trail."
      raise
    end
    puts "  -> rejected by the contract; violations become the next prompt:"
    correction = correction_prompt(e.violations)
    correction.lines.each { |l| puts "       #{l.chomp}" }
    prompt = correction
  end
end

puts
puts "  the shape of the trick: nothing here trusts the model, and"
puts "  nothing here burdens the user. the contract that documents the"
puts "  capability (rounds 5-11 built six tools on it) turns out to be"
puts "  the exact artifact a correction loop needs - violations arrive"
puts "  pre-written as actionable feedback (\"currency: must be one of:"
puts "  USD, EUR, GBP\"), which beats \"please try again\" by exactly the"
puts "  margin your production error rate will show. the loop is"
puts "  bounded (#{MAX_ATTEMPTS} attempts - unbounded self-correction is a billing"
puts "  strategy), each retry costs one more model call and is worth"
puts "  it, and when it fails it fails with every draft on record."
puts "  ship the editor with the writer; never ship the writer alone."
