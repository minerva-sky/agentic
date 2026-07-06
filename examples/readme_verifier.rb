# frozen_string_literal: true

# The README Verifier: every ruby code fence in the README is a promise.
# This extracts them all, syntax-checks each with Prism, and verifies
# that every Agentic constant a snippet mentions actually exists in the
# loaded gem. Docs rot silently; this makes the rot loud.
#
#   bundle exec ruby examples/readme_verifier.rb [markdown_file]
#
# Runs offline. Exit 1 if the README promises anything the gem can't keep.

require_relative "../lib/agentic"
require "prism"

README = File.expand_path(ARGV.first || "#{__dir__}/../README.md")

# Pull ruby code fences with their line numbers
snippets = []
current = nil
File.readlines(README, encoding: "UTF-8").each_with_index do |line, index|
  if current
    if line.start_with?("```")
      snippets << current
      current = nil
    else
      current[:code] << line
    end
  elsif line.start_with?("```ruby")
    current = {line: index + 2, code: +""}
  end
end

orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 8)

checks = snippets.map do |snippet|
  task = Agentic::Task.new(
    description: "snippet at line #{snippet[:line]}",
    agent_spec: {"name" => "Verifier", "instructions" => "verify the snippet"},
    payload: snippet
  )
  orchestrator.add_task(task, agent: ->(t) {
    code = t.payload[:code]
    parsed = Prism.parse(code)

    missing = code.scan(/Agentic(?:::[A-Z]\w*)+/).uniq.reject { |const|
      begin
        Object.const_get(const)
        true
      rescue NameError
        false
      end
    }

    {
      line: t.payload[:line],
      lines: code.lines.size,
      syntax_errors: parsed.errors.map { |e| "#{e.message} (snippet line #{e.location.start_line})" },
      missing_constants: missing
    }
  })
  task
end

verdict = Agentic::Task.new(
  description: "the verdict",
  agent_spec: {"name" => "Editor", "instructions" => "sum it up"}
)
orchestrator.add_task(verdict, checks, agent: ->(t) {
  reports = checks.map { |c| t.output_of(c) }
  {
    total: reports.size,
    total_lines: reports.sum { |r| r[:lines] },
    broken: reports.select { |r| r[:syntax_errors].any? || r[:missing_constants].any? }
  }
})

result = orchestrator.execute_plan
report = result.results[verdict.id].output

puts "README VERIFIER: #{File.basename(README)}"
puts "  #{report[:total]} ruby snippets, #{report[:total_lines]} lines of promised code"
puts

if report[:broken].empty?
  puts "  every snippet parses and every Agentic constant it names exists."
  puts "  the README keeps its promises."
else
  report[:broken].each do |broken|
    puts "  BROKEN: snippet at README line #{broken[:line]}"
    broken[:syntax_errors].each { |e| puts "    syntax: #{e}" }
    broken[:missing_constants].each { |c| puts "    missing constant: #{c}" }
  end
  exit 1
end
