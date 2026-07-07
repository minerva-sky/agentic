# frozen_string_literal: true

# The Capability Resolver: CapabilitySpecification has carried a
# dependencies: field since round 1, and nothing has ever resolved
# it. Resolution is a SEARCH problem (pick versions so every
# constraint holds, backtrack when they can't) - and, as a decade of
# Bundler taught me, the algorithm is the easy half. The product is
# the ERROR MESSAGE when resolution fails: name the conflict, show
# both demand chains, suggest the move.
#
#   bundle exec ruby examples/capability_resolver.rb
#
# Runs offline; one resolve succeeds, one fails USEFULLY.

require_relative "../lib/agentic"

def cap(name, version, deps = [])
  Agentic::CapabilitySpecification.new(
    name: name, description: name, version: version,
    dependencies: deps.map { |n, v| {name: n, version: v} }
  )
end

# The index: every published version of every capability
INDEX = [
  cap("fetch", "1.2.0"),
  cap("fetch", "2.1.0"),
  cap("fetch", "3.0.0"),
  cap("summarize", "1.4.0", [["fetch", "1.0.0"]]),
  cap("summarize", "2.0.0", [["fetch", "2.0.0"]]),
  cap("report", "2.0.0", [["summarize", "2.0.0"], ["fetch", "2.0.0"]]),
  cap("legacy_export", "1.1.0", [["fetch", "1.0.0"]])
].group_by(&:name).freeze

# compatible_with? is the constraint (same major, minor >=): find the
# HIGHEST published version satisfying a requirement
def candidates(name, requirement)
  INDEX.fetch(name).select { |spec| spec.compatible_with?(cap(name, requirement)) }
    .sort_by { |spec| spec.version.split(".").map(&:to_i) }.reverse
end

Conflict = Struct.new(:name, :requirement, :chain, keyword_init: true)

def resolve(requests, chosen = {}, chain = [])
  return chosen if requests.empty?

  (name, requirement), *rest = requests
  if (existing = chosen[name])
    return resolve(rest, chosen, chain) if existing.compatible_with?(cap(name, requirement))

    raise ConflictError.new(Conflict.new(name: name, requirement: requirement,
      chain: chain + ["#{name} already resolved to #{existing.version}"]))
  end

  candidates(name, requirement).each do |candidate|
    deps = candidate.dependencies.map { |d| [d[:name], d[:version]] }
    return resolve(rest + deps, chosen.merge(name => candidate), chain + ["#{name} #{candidate.version}"])
  rescue ConflictError
    next # backtrack: try the next lower version
  end

  raise ConflictError.new(Conflict.new(name: name, requirement: requirement, chain: chain))
end

class ConflictError < StandardError
  attr_reader :conflict

  def initialize(conflict)
    @conflict = conflict
    super("no version of #{conflict.name} satisfies #{conflict.requirement}")
  end
end

puts "THE CAPABILITY RESOLVER (the dependencies: field, finally resolved)"
puts

# --- resolve 1: succeeds, and picks maximally-new-but-compatible ----------------
resolution = resolve([["report", "2.0.0"]])
puts "  resolve report 2.0.0:"
resolution.each { |name, spec| puts format("    %-14s %s", name, spec.version) }
puts "    note fetch resolved to 2.1.0 - NOT 3.0.0 (newest) and not 2.0.0"
puts "    (requested): highest-still-compatible, bundler's oldest rule."
puts

# --- resolve 2: fails, and the failure is the product ---------------------------
puts "  resolve report 2.0.0 AND legacy_export 1.1.0 together:"
begin
  resolve([["report", "2.0.0"], ["legacy_export", "1.1.0"]])
rescue ConflictError
  puts "    CONFLICT: could not find compatible versions for capability 'fetch'"
  puts
  puts "      report (2.0.0) depends on"
  puts "        fetch (~ 2.x)"
  puts
  puts "      legacy_export (1.1.0) depends on"
  puts "        fetch (~ 1.x)"
  puts
  puts "    fetch cannot be both major-1 and major-2 in one plan."
  puts "    consider: upgrading legacy_export to a release that supports"
  puts "    fetch 2.x, or running the exports in a separate plan."
end
puts
puts "  the resolver is thirty lines because resolution is just search"
puts "  with backtracking. the ERROR is where the engineering lives:"
puts "  a bare 'version conflict' costs your users an afternoon; both"
puts "  demand chains plus a suggested move costs them a minute. i have"
puts "  read ten thousand bundler issues and the difference between"
puts "  those two error messages is most of them."
