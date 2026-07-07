# frozen_string_literal: true

# Gentle Deprecations: the hard part of maintaining a framework isn't
# adding the better name - it's the two years of not breaking anyone
# who used the old one. This shims a renamed contract field through
# three release phases: translate-and-warn (once per call site, with
# the caller named), count everything for the migration report, and
# a strict mode that turns warnings into CI failures ON YOUR schedule,
# not the users'.
#
#   bundle exec ruby examples/gentle_deprecations.rb
#
# Runs offline; three "apps" call the API from three code sites.

require_relative "../lib/agentic"

Agentic.logger.level = :fatal

# v2 renamed weight: -> weight_kg:. The contract only knows the new world.
CONTRACT = Agentic::CapabilitySpecification.new(
  name: "quote_shipping", description: "Quote a shipment", version: "2.0.0",
  inputs: {
    mode: {type: "string", required: true, enum: %w[air sea]},
    weight_kg: {type: "number", required: true, min: 1}
  },
  outputs: {price_cents: {type: "number", required: true}}
)

# The shim: old names translated at the door, warned once per call
# site, tallied for the report. Deprecation is DATA about your users.
class DeprecationShim
  RENAMES = {weight: :weight_kg}.freeze

  attr_reader :hits

  def initialize(strict: false)
    @strict = strict
    @warned = {}
    @hits = Hash.new(0)
  end

  def translate(inputs)
    RENAMES.each do |old_name, new_name|
      next unless inputs.key?(old_name)

      # The interesting frame is the USER's: skip the shim and the API
      # boundary, blame the first frame that belongs to neither
      site_location = caller_locations.find { |l| !l.label.include?("translate") && !%w[each quote].include?(l.label) }
      site = "#{site_location.label} (#{site_location.to_s[/[^\/]+:\d+/]})"
      @hits["#{old_name} at #{site}"] += 1
      if @strict
        raise ArgumentError, "DEPRECATED input :#{old_name} (use :#{new_name}) - strict mode refuses it"
      end
      unless @warned["#{old_name}-#{site}"]
        @warned["#{old_name}-#{site}"] = true
        warn "  DEPRECATION: :#{old_name} is now :#{new_name} (called from #{site}; this warning shows once per site)"
      end
      inputs = inputs.dup
      inputs[new_name] = inputs.delete(old_name)
    end
    inputs
  end
end

SHIM = DeprecationShim.new
VALIDATOR = Agentic::CapabilityValidator.new(CONTRACT)

def quote(inputs)
  inputs = SHIM.translate(inputs)
  VALIDATOR.validate_inputs!(inputs)
  {price_cents: (inputs[:weight_kg] * ((inputs[:mode] == "air") ? 9 : 2) * 100).round}
end

# Three call sites: one migrated, two still on the old name
def legacy_billing_job = quote(mode: "air", weight: 12)

def legacy_admin_panel = quote(mode: "sea", weight: 400)

def migrated_checkout = quote(mode: "air", weight_kg: 3)

puts "GENTLE DEPRECATIONS (rename shipped; nobody broken; everybody counted)"
puts
3.times { legacy_billing_job }
2.times { legacy_admin_panel }
4.times { migrated_checkout }

puts
puts "  the migration report (deprecation is data about your users):"
SHIM.hits.each { |site, count| puts format("    %-46s %d call(s)", site, count) }
puts "    migrated call sites warn nothing and appear nowhere."
puts

# Release N+2: strict mode - the same shim becomes the enforcement
strict = DeprecationShim.new(strict: true)
begin
  strict.translate(mode: "air", weight: 12)
rescue ArgumentError => e
  puts "  strict mode (release N+2, or CI today): #{e.message}"
end
puts
puts "  the choreography, straight from the Rails playbook: release N"
puts "  adds the new name and the shim - old code runs, warns once per"
puts "  call site (per-site, or your logs become the outage), and the"
puts "  tally tells you exactly who still needs a PR. release N+1 you"
puts "  chase the tally to zero. release N+2 flips strict and deletes"
puts "  the shim on YOUR schedule - because the deadline was enforced"
puts "  by CI failures in the laggards' builds, not by breaking their"
puts "  production. renames are cheap; broken trust compounds."
