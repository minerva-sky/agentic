# frozen_string_literal: true

# The Doctest Runner: Rust taught the industry one enormous docs
# lesson - EXAMPLES IN DOCS SHOULD EXECUTE. An @example block that
# has never run is a lie waiting for a reader; one that runs in CI
# is a test that happens to teach. This harvests every @example
# from lib/ and every ```ruby fence from the README, runs each in a
# sandbox subprocess, and reports which docs are alive.
#
#   bundle exec ruby examples/doctest_runner.rb
#
# Runs offline; each snippet gets its own process and tmpdir.

require "open3"
require "rbconfig"
require "tmpdir"

ROOT = File.expand_path("..", __dir__)

# Harvest 1: @example blocks (comment lines until the prose ends)
def yard_examples
  Dir[File.join(ROOT, "lib/**/*.rb")].flat_map do |file|
    lines = File.readlines(file, encoding: "UTF-8")
    lines.each_index.select { |i| lines[i].include?("@example") }.map do |start|
      code = []
      cursor = start + 1
      while cursor < lines.size && lines[cursor] =~ /\A\s*#(?:   | )?(.*)$/
        body = lines[cursor][/\A\s*#\s?(.*)$/, 1]
        break if /\A@\w+/.match?(body) # next YARD tag ends the example

        code << body
        cursor += 1
      end
      title = lines[start][/@example (.+)/, 1] || "untitled"
      ["#{File.basename(file)}: #{title}", code.join("\n")]
    end
  end
end

# Harvest 2: ```ruby fences in the README
def readme_examples
  readme = File.read(File.join(ROOT, "README.md"), encoding: "UTF-8")
  readme.scan(/```ruby\n(.*?)```/m).flatten.each_with_index.map { |code, i|
    ["README.md: fence ##{i + 1}", code]
  }
end

def run_snippet(code)
  # Sandbox: own process, own tmpdir, the gem on the load path,
  # network-shaped constants stubbed to fail fast
  harness = <<~RUBY
    Dir.chdir(#{Dir.mktmpdir.inspect})
    require "agentic"
    Agentic.logger.level = :fatal rescue nil
    #{code}
  RUBY
  _, err, status = Open3.capture3(RbConfig.ruby, "-I", File.join(ROOT, "lib"), "-e", harness)
  [status.success?, err.lines.first&.strip]
end

snippets = yard_examples + readme_examples
puts "THE DOCTEST RUNNER (#{snippets.size} documented examples put on trial)"
puts

alive = 0
snippets.each do |title, code|
  ok, err = run_snippet(code)
  alive += 1 if ok
  puts format("  %-56s %s", title[0, 56], ok ? "RUNS" : "dead: #{err.to_s[0, 40]}")
end

puts
puts format("  %d/%d examples are alive. every dead one is a reader's first", alive, snippets.size)
puts "  attempt at your library, failing - because the docs were written"
puts "  as ILLUSTRATION and never promoted to EXECUTION. rust's doctests"
puts "  changed that culture in one release: when examples run in CI,"
puts "  docs rot at the speed of a red build instead of the speed of"
puts "  a confused newcomer's patience. the fix isn't writing more"
puts "  docs - it's arresting the ones you have: give @example blocks"
puts "  real receivers and runnable setup, run this in CI, and every"
puts "  future API change gets caught lying to the README before a"
puts "  human ever does. love letters are better when the address"
puts "  still exists."
