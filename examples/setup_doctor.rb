# frozen_string_literal: true

# The Setup Doctor: every onboarding wiki page is a bug. This runs the
# checks a README asks a new hire to do by hand - ruby version, bundle
# health, git state, test suite presence - in parallel, then one
# diagnosis task reads them all BY NAME and prescribes.
#
#   bundle exec ruby examples/setup_doctor.rb
#
# Runs offline against the current repo. Exit 0 means "start coding".

require_relative "../lib/agentic"

ROOT = File.expand_path("..", __dir__)

def check(description)
  Agentic::Task.new(
    description: description,
    agent_spec: {"name" => description, "instructions" => "examine the machine"}
  )
end

orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 4)

ruby = check("ruby version")
orchestrator.add_task(ruby, agent: ->(_t) {
  required = File.read(File.join(ROOT, "agentic.gemspec"))[/required_ruby_version.*?([\d.]+)/, 1]
  {ok: Gem::Version.new(RUBY_VERSION) >= Gem::Version.new(required),
   detail: "running #{RUBY_VERSION}, gem requires >= #{required}"}
})

bundle = check("bundle health")
orchestrator.add_task(bundle, agent: ->(_t) {
  ok = system("bundle check > /dev/null 2>&1", chdir: ROOT)
  {ok: ok, detail: ok ? "all gems installed" : "run bin/setup (or bundle install)"}
})

git = check("git state")
orchestrator.add_task(git, agent: ->(_t) {
  dirty = `git -C #{ROOT} status --porcelain`.lines.size
  branch = `git -C #{ROOT} branch --show-current`.strip
  {ok: true, detail: "on #{branch}, #{dirty} uncommitted change(s)"}
})

suite = check("test suite")
orchestrator.add_task(suite, agent: ->(_t) {
  specs = Dir[File.join(ROOT, "spec", "**", "*_spec.rb")].size
  {ok: specs.positive?, detail: "#{specs} spec files ready (bundle exec rake spec)"}
})

diagnosis = check("diagnosis")
orchestrator.add_task(diagnosis, needs: {ruby: ruby, bundle: bundle, git: git, suite: suite}, agent: ->(t) {
  findings = {
    "ruby" => t.needs.ruby,
    "bundle" => t.needs.bundle,
    "git" => t.needs.git,
    "tests" => t.needs.suite
  }
  {healthy: findings.values.all? { |f| f[:ok] }, findings: findings}
})

result = orchestrator.execute_plan
verdict = result.results[diagnosis.id].output

puts "SETUP DOCTOR"
puts
verdict[:findings].each do |name, finding|
  puts format("  %s  %-8s %s", finding[:ok] ? "ok " : "FIX", name, finding[:detail])
end
puts
if verdict[:healthy]
  puts "you're good. write code, not wiki pages."
else
  puts "fix the FIX lines above, run me again."
  exit 1
end
