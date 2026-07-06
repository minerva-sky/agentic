# frozen_string_literal: true

# The Schema Advisor: give it a schema and a query log, get back the
# advisories a careful DBA would write - each rule its own capability,
# each table analyzed as its own task.
#
#   bundle exec ruby examples/schema_advisor.rb
#
# Runs offline: the rules are deterministic. Rules that fire are facts
# about your schema, not opinions from a model.

require_relative "../lib/agentic"

SCHEMA = {
  "users" => {
    columns: {
      "id" => {type: "integer", primary_key: true},
      "email" => {type: "text", null: true},
      "created_at" => {type: "timestamp", null: true}
    },
    indexes: ["id"]
  },
  "orders" => {
    columns: {
      "id" => {type: "integer", primary_key: true},
      "user_id" => {type: "integer", null: true},
      "status" => {type: "text", null: true},
      "total_cents" => {type: "float", null: true}
    },
    indexes: ["id"]
  },
  "audit_logs" => {
    columns: {
      "uuid" => {type: "text", primary_key: true},
      "payload" => {type: "text", null: true},
      "user_id" => {type: "integer", null: true}
    },
    indexes: []
  }
}.freeze

QUERY_LOG = [
  "SELECT * FROM orders WHERE user_id = ?",
  "SELECT * FROM orders WHERE status = ? ORDER BY id DESC",
  "SELECT * FROM users WHERE email = ?",
  "SELECT * FROM audit_logs WHERE user_id = ?"
].freeze

def register_rule(name, &impl)
  spec = Agentic::CapabilitySpecification.new(
    name: name, description: name.tr("_", " "), version: "1.0.0",
    inputs: {
      table: {type: "string", required: true},
      definition: {type: "object", required: true},
      queries: {type: "array", required: true}
    },
    outputs: {advisories: {type: "array", required: true}}
  )
  Agentic.register_capability(
    spec, Agentic::CapabilityProvider.new(capability: spec, implementation: impl)
  )
end

register_rule("check_missing_indexes") do |input|
  table, definition, queries = input.values_at(:table, :definition, :queries)
  filtered = queries.filter_map { |q| q[/FROM #{table} WHERE (\w+)/, 1] }.uniq
  advisories = (filtered - definition[:indexes]).map do |column|
    {severity: "high", table: table,
     advice: "queries filter on #{table}.#{column} but no index covers it - add_index :#{table}, :#{column}"}
  end
  {advisories: advisories}
end

register_rule("check_null_discipline") do |input|
  table, definition = input.values_at(:table, :definition)
  advisories = definition[:columns].filter_map do |column, meta|
    next if meta[:primary_key] || meta[:null] == false

    {severity: "medium", table: table,
     advice: "#{table}.#{column} allows NULL - if it's required, say so: NOT NULL with a default beats a validation"}
  end
  {advisories: advisories}
end

register_rule("check_money_types") do |input|
  table, definition = input.values_at(:table, :definition)
  advisories = definition[:columns].filter_map do |column, meta|
    next unless column.match?(/cents|price|amount|total/) && meta[:type] == "float"

    {severity: "high", table: table,
     advice: "#{table}.#{column} stores money as float - use integer cents or decimal before rounding errors become refunds"}
  end
  {advisories: advisories}
end

register_rule("check_text_primary_keys") do |input|
  table, definition = input.values_at(:table, :definition)
  advisories = definition[:columns].filter_map do |column, meta|
    next unless meta[:primary_key] && meta[:type] == "text"

    {severity: "low", table: table,
     advice: "#{table}.#{column} is a text primary key - fine if it's truly a UUID column type, expensive if it's a string"}
  end
  {advisories: advisories}
end

RULES = %w[check_missing_indexes check_null_discipline check_money_types check_text_primary_keys].freeze

dba = Agentic::Agent.build { |a| a.name = "DBA" }
RULES.each { |rule| dba.add_capability(rule) }

Consultation = Struct.new(:agent, :findings) do
  def get_agent_for_task(task)
    consultation = self
    Object.new.tap do |reviewer|
      reviewer.define_singleton_method(:execute) do |_prompt|
        table = task.description
        RULES.each do |rule|
          result = consultation.agent.execute_capability(rule, {
            table: table, definition: SCHEMA[table], queries: QUERY_LOG
          })
          consultation.findings.concat(result[:advisories])
        end
        "reviewed"
      end
    end
  end
end

findings = []
orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 4)
SCHEMA.each_key do |table|
  orchestrator.add_task(Agentic::Task.new(
    description: table,
    agent_spec: {"name" => "DBA", "instructions" => "Review the table"},
    input: {}
  ))
end
result = orchestrator.execute_plan(Consultation.new(dba, findings))

puts "SCHEMA REVIEW: #{SCHEMA.size} tables, #{QUERY_LOG.size} logged queries, " \
  "#{findings.size} advisories (#{result.status})"
puts
%w[high medium low].each do |severity|
  matching = findings.select { |f| f[:severity] == severity }
  next if matching.empty?

  puts severity.upcase
  matching.each { |f| puts "  - #{f[:advice]}" }
  puts
end
