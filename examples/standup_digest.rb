# frozen_string_literal: true

# The Standup Digest: three collectors gather from the repo in
# parallel - recent commits, TODO debt, test suite shape - and a writer
# task fans their outputs in through the dependency pipe and publishes
# the digest nobody has to attend a meeting for.
#
#   bundle exec ruby examples/standup_digest.rb
#
# Runs offline against the current git repo. The meeting is cancelled.

require_relative "../lib/agentic"

ROOT = File.expand_path("..", __dir__)

def repo_task(description, payload = nil)
  Agentic::Task.new(
    description: description,
    agent_spec: {"name" => description, "instructions" => "Collect facts"},
    payload: payload
  )
end

orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 3)

commits = repo_task("recent commits")
orchestrator.add_task(commits, agent: ->(_t) {
  log = `git -C #{ROOT} log --oneline -12 --pretty=format:"%s"`.lines.map(&:strip)
  themes = log.group_by { |line| line[/\A(\w+)(?:\(|:)/, 1] || "misc" }
  {count: log.size, themes: themes.transform_values(&:size), latest: log.first}
})

debt = repo_task("todo debt")
orchestrator.add_task(debt, agent: ->(_t) {
  hits = Dir[File.join(ROOT, "lib", "**", "*.rb")].flat_map { |path|
    File.readlines(path, encoding: "UTF-8").each_with_index.select { |line, _| line =~ /#.*(TODO|FIXME|HACK)/ }
      .map { |line, i| "#{path.delete_prefix("#{ROOT}/")}:#{i + 1} #{line.strip.sub(/\A#\s*/, "")}" }
  }
  {count: hits.size, items: hits.first(5)}
})

tests = repo_task("test suite shape")
orchestrator.add_task(tests, agent: ->(_t) {
  spec_files = Dir[File.join(ROOT, "spec", "**", "*_spec.rb")]
  examples = spec_files.sum { |f| File.read(f, encoding: "UTF-8").scan(/^\s*it\s/).size }
  {files: spec_files.size, examples: examples}
})

digest = repo_task("digest")
orchestrator.add_task(digest, [commits, debt, tests], agent: ->(t) {
  shipped = t.output_of(commits)
  owed = t.output_of(debt)
  suite = t.output_of(tests)

  lines = []
  lines << "STANDUP DIGEST"
  lines << ""
  lines << "shipped: #{shipped[:count]} recent commits " \
    "(#{shipped[:themes].map { |k, v| "#{v} #{k}" }.join(", ")})"
  lines << "  latest: #{shipped[:latest]}"
  lines << ""
  lines << "owed: #{owed[:count]} TODO/FIXME/HACK markers in lib/"
  owed[:items].each { |item| lines << "  - #{item}" }
  lines << "  (clean!)" if owed[:count].zero?
  lines << ""
  lines << "guarded by: #{suite[:examples]} examples across #{suite[:files]} spec files"
  lines.join("\n")
})

result = orchestrator.execute_plan

puts result.results[digest.id].output
puts
puts "(three collectors in parallel + one writer, #{result.status} " \
  "in #{(result.execution_time * 1000).round}ms)"
