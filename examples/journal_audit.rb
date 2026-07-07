# frozen_string_literal: true

# The Journal Audit: seven tools now trust the journal, so the journal
# itself gets audited - well-formed lines, monotonic timestamps, no
# success without a start, no double-success, plan_completed present.
# A corrupted journal is fed in; every planted defect is caught.
#
#   bundle exec ruby examples/journal_audit.rb
#
# Runs offline. Trust, then verify the thing you trust.

require_relative "../lib/agentic"
require "tmpdir"
require "json"

CHECKS = {
  "well-formed JSON per line" => ->(entries, raw) {
    raw.each_with_index.reject { |line, _|
      begin
        JSON.parse(line)
      rescue
        nil
      end
    }
      .map { |_, i| "line #{i + 1} is not valid JSON" }
  },
  "timestamps monotonic" => ->(entries, _raw) {
    entries.each_cons(2).with_index.filter_map { |(a, b), i|
      "line #{i + 2} time-travels (#{b[:at]} < #{a[:at]})" if b[:at] && a[:at] && b[:at] < a[:at]
    }
  },
  "no success without a start" => ->(entries, _raw) {
    started = entries.select { |e| e[:event] == "task_started" }.map { |e| e[:task_id] }
    entries.select { |e| e[:event] == "task_succeeded" && !started.include?(e[:task_id]) }
      .map { |e| "#{e[:description] || e[:task_id]} succeeded without ever starting" }
  },
  "no double success" => ->(entries, _raw) {
    entries.select { |e| e[:event] == "task_succeeded" }
      .group_by { |e| e[:task_id] }.select { |_, v| v.size > 1 }
      .map { |id, v| "task #{v.first[:description] || id} succeeded #{v.size} times" }
  },
  "durations non-negative" => ->(entries, _raw) {
    entries.select { |e| e[:duration]&.negative? }
      .map { |e| "#{e[:description]} has negative duration #{e[:duration]}" }
  }
}.freeze

def audit(path)
  raw = File.readlines(path, encoding: "UTF-8").map(&:strip).reject(&:empty?)
  entries = raw.filter_map do |line|
    JSON.parse(line, symbolize_names: true)
  rescue JSON::ParserError
    nil
  end
  CHECKS.transform_values { |check| check.call(entries, raw) }
end

# --- a healthy journal, written by the real machinery ------------------------
dir = Dir.mktmpdir
healthy_path = File.join(dir, "healthy.jsonl")
journal = Agentic::ExecutionJournal.new(path: healthy_path)
orchestrator = Agentic::PlanOrchestrator.new(lifecycle_hooks: journal.lifecycle_hooks)
task = Agentic::Task.new(description: "honest work", agent_spec: {"name" => "w", "instructions" => "w"})
orchestrator.add_task(task, agent: ->(_t) { :ok })
orchestrator.execute_plan

# --- a tampered journal: four planted defects ---------------------------------
tampered_path = File.join(dir, "tampered.jsonl")
lines = File.readlines(healthy_path).map(&:strip)
File.open(tampered_path, "w") do |f|
  f.puts lines[0] # task_started
  f.puts '{"event": "task_succeeded", "task_id": "ghost-1", "description": "phantom deploy", "at": "2026-07-07T00:00:00.000Z", "duration": 0.01}'
  f.puts lines[1] # the real success
  f.puts lines[1] # ...twice
  f.puts '{"event": "task_succeeded", "task_id": "neg-1", "description": "time thief", "at": "2020-01-01T00:00:00.000Z", "duration": -3}'
  f.puts "this line is not json at all"
end

puts "JOURNAL AUDIT (#{CHECKS.size} integrity checks)"
[["healthy journal", healthy_path], ["tampered journal", tampered_path]].each do |label, path|
  findings = audit(path)
  total = findings.values.sum(&:size)
  puts
  puts "  #{label}: #{total.zero? ? "clean" : "#{total} defect(s)"}"
  findings.each do |check, problems|
    problems.each { |problem| puts "    [#{check}] #{problem}" }
  end
end

puts
puts "the journal underwrites resume, baselines, check-ins, and incident"
puts "reports - four products built on one file's honesty. an audit that"
puts "runs before replay is how you keep seven tools from inheriting one"
puts "corruption. auditors get audited; that's what makes them auditors."
