# frozen_string_literal: true

# The Release Rehearsal: your repo is not your gem. The gem is
# whatever the gemspec PACKAGES, installed into a clean GEM_HOME,
# required by a Ruby that has never seen your working directory -
# and the day to discover a file missing from the package is today,
# on this machine, not release day in someone's CI. Build, audit,
# install, boot: the full ceremony, rehearsed.
#
#   bundle exec ruby examples/release_rehearsal.rb
#
# Runs offline; exits 1 if the packaged gem can't do its job.

require_relative "../lib/agentic"
require "open3"
require "rbconfig"
require "tmpdir"

failures = []
stage = Dir.mktmpdir("agentic_rehearsal")

# --- act 1: build the actual artifact --------------------------------------------
out, err, status = Open3.capture3("gem", "build", "agentic.gemspec", "--output", File.join(stage, "rehearsal.gem"))
if status.success?
  puts "  act 1 - gem build: ok (#{File.size(File.join(stage, "rehearsal.gem")) / 1024}KB)"
else
  failures << "build failed"
  puts "  act 1 - gem build FAILED: #{err.lines.last&.strip || out.lines.last&.strip}"
end

# --- act 2: audit the manifest - every lib file must be aboard -------------------
spec = Gem::Specification.load("agentic.gemspec")
packaged = spec.files
missing = Dir["lib/**/*.rb"].reject { |f| packaged.include?(f) }
version_ok = spec.version.to_s == Agentic::VERSION
failures << "manifest missing #{missing.size} lib file(s)" if missing.any?
failures << "version drift" unless version_ok
puts "  act 2 - manifest audit: #{packaged.size} files packaged; lib coverage #{missing.empty? ? "complete" : "MISSING #{missing.take(3).join(", ")}"}"
puts "           version: gemspec #{spec.version} == Agentic::VERSION #{Agentic::VERSION} - #{version_ok ? "agree" : "DRIFT"}"

# --- act 3: install into a clean GEM_HOME ----------------------------------------
gem_home = File.join(stage, "gem_home")
_, err, status = Open3.capture3(
  {"GEM_HOME" => gem_home},
  "gem", "install", "--local", "--no-document", "--ignore-dependencies",
  File.join(stage, "rehearsal.gem")
)
if status.success?
  puts "  act 3 - clean install: ok (GEM_HOME=#{File.basename(gem_home)})"
else
  failures << "install failed"
  puts "  act 3 - install FAILED: #{err.lines.last&.strip}"
end

# --- act 4: boot the INSTALLED gem, far from this repo ---------------------------
# The child's load path knows the temp GEM_HOME (for our gem) and the
# host gem path (for dependencies) - and pointedly NOT this repo's lib/
probe = <<~RUBY
  gem "agentic"
  require "agentic"
  raise "loaded from the repo, not the package!" if Agentic.method(:run).source_location.first.include?("/lib/agentic") && !Agentic.method(:run).source_location.first.include?("gem_home")
  orchestrator = Agentic::PlanOrchestrator.new
  task = Agentic::Task.new(description: "boot", agent_spec: {"name" => "b", "instructions" => "w"})
  orchestrator.add_task(task, agent: ->(_t) { "the package works" })
  print orchestrator.execute_plan.task_result(task.id).output
RUBY
# Scrub the inherited environment: under `bundle exec`, RUBYOPT
# smuggles bundler/setup into every child, which would quietly put
# THIS REPO back on the load path - the exact contamination the
# rehearsal exists to prevent (and its first run caught)
clean_env = {
  "GEM_HOME" => gem_home,
  "GEM_PATH" => "#{gem_home}#{File::PATH_SEPARATOR}#{Gem.paths.home}",
  "RUBYOPT" => nil, "RUBYLIB" => nil,
  "BUNDLE_GEMFILE" => nil, "BUNDLE_BIN_PATH" => nil, "BUNDLER_SETUP" => nil
}
out, err, status = Open3.capture3(clean_env, RbConfig.ruby, "-e", probe, chdir: stage)
if status.success? && out.include?("the package works")
  puts "  act 4 - boot from the package: \"#{out}\" (repo lib/ never on the path)"
else
  failures << "packaged gem failed to boot"
  puts "  act 4 - boot FAILED: #{err.lines.grep_v(/warning/).last&.strip}"
end

puts
if failures.empty?
  puts "  the rehearsal passed all four acts, which certifies the thing"
  puts "  releases actually ship: not your repo, THE PACKAGE. the classic"
  puts "  release-day wounds are all rehearsable - a file added without"
  puts "  `git add` (invisible to git-ls-files manifests), a version.rb"
  puts "  bumped but gemspec pinned, an implicit load-order dependency"
  puts "  that only your spec_helper satisfied. rubygems maintenance is"
  puts "  mostly this lesson at scale: every gem that breaks on install"
  puts "  worked perfectly in its own repo. rehearse the ceremony in CI"
  puts "  and release day becomes a tag, not an event."
else
  puts "  REHEARSAL FAILED: #{failures.join("; ")} - fix before tagging."
end
exit(failures.empty? ? 0 : 1)
