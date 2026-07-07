# frozen_string_literal: true

# Gem Scout: describe what you need, get a ranked shortlist of gems.
# Search and scoring are separate capabilities; the search backend is
# the pluggable seam - offline it's a bundled index, online swap in
# the real WebSearch DuckDuckGo backend with one assignment.
#
#   bundle exec ruby examples/gem_scout.rb "background jobs"
#   bundle exec ruby examples/gem_scout.rb "vector search"
#
# Runs offline by default.

require_relative "../lib/agentic"

# A small index standing in for the network - same shape a live search
# backend returns, so the rest of the program can't tell the difference
CATALOG = [
  {name: "sidekiq", summary: "background jobs backed by Redis, threads not forks",
   topics: %w[background jobs queue async workers], downloads_m: 950, last_release_days: 20},
  {name: "solid_queue", summary: "database-backed background jobs for Active Job",
   topics: %w[background jobs queue rails database], downloads_m: 15, last_release_days: 30},
  {name: "good_job", summary: "Postgres-based Active Job backend with dashboard",
   topics: %w[background jobs queue rails postgres], downloads_m: 40, last_release_days: 14},
  {name: "neighbor", summary: "nearest neighbor vector search for Rails and Postgres",
   topics: %w[vector search embeddings pgvector similarity], downloads_m: 8, last_release_days: 45},
  {name: "pgvector", summary: "pgvector support for Ruby",
   topics: %w[vector search embeddings postgres], downloads_m: 12, last_release_days: 60},
  {name: "searchkick", summary: "intelligent search made easy with Elasticsearch/OpenSearch",
   topics: %w[search elasticsearch full-text ranking], downloads_m: 130, last_release_days: 90},
  {name: "pagy", summary: "the fastest pagination gem",
   topics: %w[pagination performance views], downloads_m: 85, last_release_days: 10},
  {name: "strong_migrations", summary: "catch unsafe migrations in development",
   topics: %w[migrations database safety postgres], downloads_m: 70, last_release_days: 25}
].freeze

# Offline backend for the WebSearch seam built in round 1
Agentic::Capabilities::WebSearch.backend = lambda do |query:, num_results:|
  terms = query.downcase.split
  hits = CATALOG.map { |gem|
    haystack = "#{gem[:name]} #{gem[:summary]} #{gem[:topics].join(" ")}"
    score = terms.count { |t| haystack.include?(t) }
    [gem, score]
  }.select { |_, s| s.positive? }.sort_by { |g, s| [-s, -g[:downloads_m]] }.first(num_results)

  {
    results: hits.map { |gem, _| "#{gem[:name]}: #{gem[:summary]}" },
    sources: hits.map { |gem, _| "https://rubygems.org/gems/#{gem[:name]}" }
  }
end

# Scoring is its own capability: search finds candidates, this ranks
# them on the things that matter when you have to live with a gem
spec = Agentic::CapabilitySpecification.new(
  name: "score_gem",
  description: "Score a gem on adoption and maintenance",
  version: "1.0.0",
  inputs: {name: {type: "string", required: true}},
  outputs: {score: {type: "number", required: true}, notes: {type: "array", required: true}}
)
Agentic.register_capability(spec, Agentic::CapabilityProvider.new(
  capability: spec,
  implementation: ->(inputs) {
    gem = CATALOG.find { |g| g[:name] == inputs[:name] } or
      next({score: 0.0, notes: ["unknown gem"]})

    adoption = Math.log10([gem[:downloads_m], 1].max) / 3.0 # 0..1 for 1M..1B
    freshness = [1.0 - gem[:last_release_days] / 365.0, 0].max
    notes = []
    notes << "widely adopted (#{gem[:downloads_m]}M downloads)" if gem[:downloads_m] > 50
    notes << "recently released (#{gem[:last_release_days]}d ago)" if gem[:last_release_days] < 31
    notes << "check maintenance cadence" if gem[:last_release_days] > 80

    {score: ((adoption * 0.6 + freshness * 0.4) * 100).round(1), notes: notes}
  }
))

scout = Agentic::Agent.build { |a| a.name = "GemScout" }
Agentic::Capabilities.register_standard_capabilities
scout.add_capability("web_search")
scout.add_capability("score_gem")

need = ARGV.join(" ")
need = "background jobs" if need.empty?

found = scout.execute_capability("web_search", {query: need, num_results: 4})
candidates = found[:results].map { |line| line.split(":").first }

ranked = candidates.map { |name|
  verdict = scout.execute_capability("score_gem", {name: name})
  {name: name, score: verdict[:score], notes: verdict[:notes]}
}.sort_by { |c| -c[:score] }

puts "GEM SCOUT: \"#{need}\""
puts
if ranked.empty?
  puts "  no candidates found - try different words, or plug in the live backend:"
  puts "  Agentic::Capabilities::WebSearch.backend = Agentic::Capabilities::WebSearch::DuckDuckGo.new"
else
  ranked.each_with_index do |c, i|
    marker = (i == 0) ? "->" : "  "
    puts format("%s %-18s %5.1f  %s", marker, c[:name], c[:score], c[:notes].join("; "))
  end
  puts
  winner = ranked.first
  puts "recommendation: start with #{winner[:name]} - " \
    "#{CATALOG.find { |g| g[:name] == winner[:name] }[:summary]}"
end
