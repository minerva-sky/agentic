# frozen_string_literal: true

# The Plan Lockfile: Gemfile.lock for workflows. A plan that says
# "give me text.summarize ~> 1.0" is a WISH; production runs need a
# FACT. `lock` resolves constraints once and writes plan.lock -
# exact versions plus a content digest per capability. `run --frozen`
# resolves nothing: it verifies the world still matches the lockfile
# and refuses to run anything it didn't agree to - a new version
# published? ignored until you relock. an implementation edited
# in place under the same version number? REFUSED BY DIGEST,
# because "same version, different code" is the lie lockfiles exist
# to catch.
#
#   bundle exec ruby examples/plan_lockfile.rb
#
# Runs offline; exits 1 unless frozen runs are deterministic and
# drift is refused with a usable message.

require_relative "../lib/agentic"
require "digest"
require "json"
require "tmpdir"

Agentic.logger.level = :fatal

# The capability "rubygems.org": versions are immutable... unless
# someone edits one in place, which is exactly what we'll do to prove
# the digests earn their keep
REGISTRY = {
  "text.summarize" => {
    "1.0.0" => "->(t) { t[:text].split('. ').first }",
    "1.1.0" => "->(t) { t[:text].split('. ').first + '.' }"
  },
  "markdown.render" => {
    "2.3.1" => "->(t) { \"<p>\#{t[:text]}</p>\" }"
  }
}

PLAN_REQUIREMENTS = {"text.summarize" => "~> 1.0", "markdown.render" => "~> 2.3"}.freeze

def resolve(requirements)
  requirements.to_h do |name, constraint|
    versions = REGISTRY.fetch(name).keys.map { |v| Gem::Version.new(v) }.sort
    best = versions.reverse.find { |v| Gem::Requirement.new(constraint).satisfied_by?(v) }
    raise "no version of #{name} satisfies #{constraint}" unless best
    [name, best.to_s]
  end
end

def write_lock(path, resolution)
  entries = resolution.to_h { |name, version| [name, {"version" => version, "digest" => Digest::SHA256.hexdigest(REGISTRY[name][version])[0, 12]}] }
  File.write(path, JSON.pretty_generate({"capabilities" => entries, "locked_by" => "plan_lockfile 1.0"}))
end

# Frozen semantics: verify, never resolve. Every failure names the
# capability, what was expected, what was found, and the way out.
def frozen_check(path)
  lock = JSON.parse(File.read(path))
  lock["capabilities"].filter_map do |name, entry|
    source = REGISTRY.dig(name, entry["version"])
    if source.nil?
      "#{name} #{entry["version"]} is locked but no longer available"
    elsif Digest::SHA256.hexdigest(source)[0, 12] != entry["digest"]
      "#{name} #{entry["version"]}: content digest mismatch (locked #{entry["digest"]}, found #{Digest::SHA256.hexdigest(source)[0, 12]})"
    end
  end
end

def run_plan(path)
  lock = JSON.parse(File.read(path))
  impls = lock["capabilities"].to_h { |name, e| [name, eval(REGISTRY[name][e["version"]])] } # rubocop:disable Security/Eval -- registry sources are this file's own fixtures
  orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 2)
  summarize = Agentic::Task.new(description: "summarize", agent_spec: {"name" => "s", "instructions" => "w"})
  render = Agentic::Task.new(description: "render", agent_spec: {"name" => "r", "instructions" => "w"})
  orchestrator.add_task(summarize, agent: ->(_t) { impls["text.summarize"].call({text: "Lock your plans. Trust your deploys."}) })
  orchestrator.add_task(render, [summarize], agent: ->(t) { impls["markdown.render"].call({text: t.previous_output}) })
  result = orchestrator.execute_plan
  [result.task_result(render.id).output, lock["capabilities"].map { |n, e| "#{n} #{e["version"]}" }]
end

failures = []
puts "THE PLAN LOCKFILE (a constraint is a wish; production runs need a fact)"
puts

Dir.mktmpdir("plan_lock") do |dir|
  lockfile = File.join(dir, "plan.lock")

  # Day 1: developer locks and deploys
  write_lock(lockfile, resolve(PLAN_REQUIREMENTS))
  output, versions = run_plan(lockfile)
  puts "  day 1   lock + frozen run: #{versions.join(", ")} -> #{output.inspect}"

  # Day 30: a new version is published upstream. The frozen run does
  # not care - determinism means new code enters through a relock, ever
  REGISTRY["text.summarize"]["1.2.0"] = "->(t) { t[:text].upcase }"
  drift = frozen_check(lockfile)
  output2, versions2 = run_plan(lockfile)
  puts "  day 30  text.summarize 1.2.0 published; frozen run: #{versions2.join(", ")} (ignored it)"
  failures << "frozen run drifted to a new version" unless versions2 == versions && output2 == output && drift.empty?

  # Day 31: someone edits 2.3.1 IN PLACE - same version, different code
  REGISTRY["markdown.render"]["2.3.1"] = "->(t) { \"<p class='tracked'>\#{t[:text]}</p>\" }"
  drift = frozen_check(lockfile)
  puts
  puts "  day 31  markdown.render 2.3.1 edited in place (same version, new code):"
  drift.each { |d| puts "    FROZEN RUN REFUSED: #{d}" }
  puts "    the fix is explicit, one command, and leaves a diff: plan lock --update"
  failures << "digest drift was not refused" if drift.empty?

  # The relock: deliberate, reviewable, and the plan runs again
  write_lock(lockfile, resolve(PLAN_REQUIREMENTS))
  output3, versions3 = run_plan(lockfile)
  puts
  puts "  relock  #{versions3.join(", ")} -> #{output3.inspect}"
  puts "          (1.2.0 adopted NOW, in a diff someone reviews - not silently on day 30)"
  failures << "relock didn't adopt the new version" unless versions3.first.include?("1.2.0")
end

puts
puts "  three moments, one discipline: the constraint file says what you"
puts "  can ACCEPT, the lockfile says what you ARE RUNNING, and nothing"
puts "  moves between them without a human making a diff. the digest is"
puts "  the underrated half - version numbers are claims, and every"
puts "  ecosystem eventually meets code that lies about itself. bundler"
puts "  spent a decade earning these rules; plans that call LLMs and"
puts "  APIs and each other get to inherit them for the cost of one"
puts "  JSON file."
exit(failures.empty? ? 0 : 1)
