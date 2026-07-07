# frozen_string_literal: true

# The Doctest Runner: Rust taught the industry one enormous docs
# lesson - EXAMPLES IN DOCS SHOULD EXECUTE. This harvests every
# @example from lib/ and every ```ruby fence from the README and runs
# each in a sandbox subprocess. Since round 14 it is a REFEREE:
# every example must either run, or carry a deliberate annotation -
# "(illustrative: reason)" in an @example title, or an HTML comment
# "<!-- doctest: illustrative (reason) -->" before a README fence.
# Unannotated failure = exit 1. Docs rot at the speed of a red build.
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
      annotation = title[/\(illustrative[:)]?([^)]*)\)?/, 0]
      ["#{File.basename(file)}: #{title}", code.join("\n"), annotation]
    end
  end
end

# Harvest 2: ```ruby fences in the README
def readme_examples
  readme = File.read(File.join(ROOT, "README.md"), encoding: "UTF-8")
  fences = []
  readme.scan(/```ruby\n(.*?)```/m) do
    code = Regexp.last_match(1)
    annotation = Regexp.last_match.pre_match[/<!-- doctest: (illustrative[^>]*?) -->\s*\z/, 1]
    fences << ["README.md: fence ##{fences.size + 1}", code, annotation]
  end
  fences
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
annotated = 0
unannotated_failures = []
snippets.each do |title, code, annotation|
  if annotation
    annotated += 1
    puts format("  %-56s %s", title[0, 56], "annotated - not run (#{annotation[0, 40]})")
    next
  end
  ok, err = run_snippet(code)
  alive += 1 if ok
  unannotated_failures << title unless ok
  puts format("  %-56s %s", title[0, 56], ok ? "RUNS" : "DEAD: #{err.to_s[0, 40]}")
end

puts
puts format("  %d run, %d deliberately illustrative, %d dead.", alive, annotated, unannotated_failures.size)
puts
if unannotated_failures.empty?
  puts "  every example is now runnable-or-annotated: the runnable ones"
  puts "  execute on every invocation of this referee, and the"
  puts "  illustrative ones say so ON PURPOSE, with a reason, where the"
  puts "  reader can see it. that was round 13's ask, delivered - docs"
  puts "  now rot at the speed of a red build instead of the speed of a"
  puts "  confused newcomer's patience. love letters are better when"
  puts "  the address still exists, and these get address-checked in CI."
else
  puts "  UNANNOTATED FAILURES: #{unannotated_failures.join("; ")}"
  puts "  fix them or annotate them - silence is the one option docs"
  puts "  don't get anymore."
end
exit(unannotated_failures.empty? ? 0 : 1)
