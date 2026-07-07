# frozen_string_literal: true

# The Relation Diff: round 8's semver advisor classified declaration
# changes but had to shrug at rules - lambdas can't be compared. Now
# relations are data, so the RULES diff too: a tightened limit is
# breaking, a loosened one compatible, a new rule breaking, a removed
# one compatible, and a changed relation TYPE is a different law
# entirely. The last opaque corner of the contract joins semver.
#
#   bundle exec ruby examples/relation_diff.rb
#
# Runs offline; v2 contains one of every interesting rule change.

require_relative "../lib/agentic"

V1_RULES = {
  fits: {relation: :sum_lte, fields: [:weight, :volume], limit: 6_000},
  customs: {relation: :requires, fields: [:express, :customs_code]},
  one_auth: {relation: :mutually_exclusive, fields: [:api_key, :oauth_token]},
  legacy: {relation: :requires, fields: [:fragile, :packaging]},
  audited: {message: "audited accounts only", fields: [:account], check: ->(i) { true }}
}.freeze

V2_RULES = {
  fits: {relation: :sum_lte, fields: [:weight, :volume], limit: 4_000},   # tightened
  customs: {relation: :requires, fields: [:express, :customs_code, :incoterm]}, # widened scope
  one_auth: {relation: :requires, fields: [:api_key, :oauth_token]},      # DIFFERENT LAW
  speedy: {relation: :sum_lte, fields: [:weight], limit: 100},            # new rule
  # legacy: removed
  audited: {message: "audited accounts only", fields: [:account], check: ->(i) { i[:account] != "test" }}
}.freeze

def classify(v1, v2)
  changes = []
  (v1.keys & v2.keys).each do |id|
    old_rule, new_rule = v1[id], v2[id]
    if old_rule[:relation] && new_rule[:relation]
      if old_rule[:relation] != new_rule[:relation]
        changes << [:breaking, "rule :#{id} changed LAW: #{old_rule[:relation]} -> #{new_rule[:relation]} - not an edit, a replacement"]
        next
      end
      case new_rule[:relation]
      when :sum_lte
        changes << [:breaking, "rule :#{id} limit tightened #{old_rule[:limit]} -> #{new_rule[:limit]} - previously legal calls rejected"] if new_rule[:limit] < old_rule[:limit]
        changes << [:compatible, "rule :#{id} limit loosened #{old_rule[:limit]} -> #{new_rule[:limit]}"] if new_rule[:limit] > old_rule[:limit]
      when :requires
        added = new_rule[:fields] - old_rule[:fields]
        removed = old_rule[:fields] - new_rule[:fields]
        changes << [:breaking, "rule :#{id} now also demands #{added.join(", ")} - callers satisfying v1 fail v2"] if added.any?
        changes << [:compatible, "rule :#{id} no longer demands #{removed.join(", ")}"] if removed.any? && added.none?
      when :mutually_exclusive
        changes << [:breaking, "rule :#{id} exclusion widened to #{new_rule[:fields].join(", ")}"] if (new_rule[:fields] - old_rule[:fields]).any?
      end
    elsif old_rule[:relation].nil? && new_rule[:relation].nil?
      changes << [:opaque, "rule :#{id} is a lambda in both versions - the diff cannot see inside; treat as breaking unless proven"]
    end
  end
  (v2.keys - v1.keys).each do |id|
    changes << [:breaking, "rule :#{id} added (#{V2_RULES[id][:relation]}) - a new law existing callers never agreed to"]
  end
  (v1.keys - v2.keys).each do |id|
    changes << [:compatible, "rule :#{id} removed - every v1-legal call remains legal"]
  end
  changes
end

changes = classify(V1_RULES, V2_RULES)
breaking = changes.count { |kind, _| kind == :breaking }

puts "RELATION DIFF: quote_shipping rules, v1 -> v2"
puts
order = {breaking: 0, opaque: 1, compatible: 2}
changes.sort_by { |kind, _| order[kind] }.each do |kind, message|
  puts format("  %-10s %s", kind.to_s.upcase, message)
end

puts
puts "  verdict: #{breaking} breaking rule change(s) -> major version bump."
puts
puts "  round 8's advisor ended every report with a shrug: \"3 breaking"
puts "  changes IN THE DECLARATIONS\" - rules were lambdas, invisible to"
puts "  any diff. relations closed that: the limit, the fields, and the"
puts "  law itself are data, so tightening 6000->4000 is as diffable as"
puts "  a max: change. note the one law-change row: same rule id, same"
puts "  fields, different relation - that's not an edit, it's a new"
puts "  contract wearing an old name, and the diff says so. the lambda"
puts "  rule still gets the shrug (OPAQUE, presumed breaking) - which is"
puts "  now a choice you make per rule, not a ceiling on the tool."
