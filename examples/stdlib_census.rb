# frozen_string_literal: true

# The Stdlib Census: "it's in the standard library" is a statement
# with a shelf life. Default gems become bundled gems on a published
# schedule, and every `require` your gem makes is either covered by
# ruby itself, covered by your gemspec, or a warning that hasn't
# fired yet. This census reads lib/'s requires, cross-checks the
# gemspec, and flags everything the next Ruby will bill you for.
#
#   bundle exec ruby examples/stdlib_census.rb
#
# Runs offline; exits 1 if any require is covered by nobody.

LIB = File.expand_path("../lib", __dir__)
GEMSPEC = File.read(File.expand_path("../agentic.gemspec", __dir__), encoding: "UTF-8")

# require name -> gem name, where they differ
GEM_FOR = {
  "dry/schema" => "dry-schema", "openai" => "ruby-openai",
  "async/semaphore" => "async", "async" => "async"
}.freeze

# Default gems already promoted to bundled (3.4 wave) or announced
# for promotion (3.5 wave) - require them without declaring them and
# a future ruby upgrade breaks your users' bundle
GEMIFIED = %w[
  ostruct pstore benchmark logger rdoc fiddle irb reline win32ole
  csv drb mutex_m base64 bigdecimal getoptlong observer rinda
  resolv-replace syslog abbrev nkf
].freeze

# Genuinely-safe stdlib for the foreseeable schedule
CORE_SAFE = %w[
  json fileutils time date yaml securerandom set singleton net/http
  uri open3 stringio tmpdir digest erb forwardable
].freeze

requires = Dir[File.join(LIB, "**/*.rb")].flat_map { |file|
  File.readlines(file, encoding: "UTF-8").filter_map { |line|
    name = line[/\Arequire "([^"]+)"/, 1]
    [name, File.basename(file)] if name
  }
}.group_by(&:first).transform_values { |rows| rows.map(&:last).uniq }

declared = GEMSPEC.scan(/add_dependency "([^"]+)"/).flatten

verdicts = requires.keys.sort.map do |name|
  gem_name = GEM_FOR[name] || name.split("/").first
  verdict = if declared.include?(gem_name) || declared.any? { |d| gem_name.start_with?(d) }
    [:declared, "gemspec: #{gem_name}"]
  elsif GEMIFIED.include?(name)
    declared.include?(name) ? [:declared, "gemspec: #{name}"] : [:gemified, "PROMOTED to bundled gem - declare it or a ruby upgrade breaks the bundle"]
  elsif CORE_SAFE.include?(name)
    [:core, "default gem, no promotion scheduled"]
  else
    [:uncovered, "COVERED BY NOBODY - works today by accident"]
  end
  [name, verdict]
end

puts "THE STDLIB CENSUS (#{requires.size} distinct requires across lib/)"
puts
order = {uncovered: 0, gemified: 1, declared: 2, core: 3}
verdicts.sort_by { |_, (kind, _)| order[kind] }.each do |name, (kind, note)|
  marker = {uncovered: "!!", gemified: " !", declared: "  ", core: "  "}[kind]
  puts format("  %s %-18s %-10s %s", marker, name, kind.to_s.upcase, note)
end

uncovered = verdicts.count { |_, (kind, _)| kind == :uncovered }
gemified = verdicts.select { |_, (kind, _)| kind == :gemified }.map(&:first)

puts
puts "  the receipts: ostruct was declared during the 3.4 warning wave,"
puts "  and this census's own first run caught TWO more - logger"
puts "  (promoted to bundled in 3.5) and cgi (trimmed to a bundled gem"
puts "  in 3.5, used here for CGI.escape) - both now declared in the"
puts "  gemspec with comments saying why. the round-11 'time' bug was"
puts "  the same lesson at file scope: require what you use; a"
puts "  transitive require is a loan, and rubies refinance."
if gemified.any?
  puts "  still to declare before the next ruby: #{gemified.join(", ")}."
end
puts "  release engineering isn't glamorous: it's reading the NEWS file"
puts "  of every ruby release AS IF your gem's install matrix depends"
puts "  on it, because it does. this census is 60 lines; run it in CI"
puts "  and the 3.5 upgrade becomes a non-event instead of an issue"
puts "  tracker full of LoadErrors."

exit(uncovered.zero? ? 0 : 1)
