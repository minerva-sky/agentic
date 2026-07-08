# frozen_string_literal: true

# The Capability Autoloader: Zeitwerk's contract, ported. Drop a
# file at packs/text/summarize.rb defining Text::Summarize, and the
# capability "text.summarize" exists - no registration ceremony, no
# init file that lists everything twice. The convention IS the
# registry: file path <-> constant name <-> capability name, one
# bijection, three views. Lazy in development (load on first use),
# eager in production (load everything, and VERIFY the bijection -
# a file that defines the wrong constant is a bug you want at boot,
# not at 3am), reloadable in between.
#
#   bundle exec ruby examples/capability_autoloader.rb
#
# Runs offline; a capability pack is written to a tmpdir, then
# lazy-loaded, eager-verified, and hot-reloaded.

require_relative "../lib/agentic"
require "tmpdir"

Agentic.logger.level = :fatal

class CapabilityAutoloader
  attr_reader :loaded

  def initialize(root)
    @root = root
    @loaded = []
    @generation = 0
  end

  # "text.summarize" -> packs/text/summarize.rb -> Text::Summarize
  def ensure!(name)
    return if @loaded.include?(name)
    path = File.join(@root, *name.split("."))
    raise "no file at #{path}.rb for capability #{name.inspect}" unless File.exist?("#{path}.rb")
    load "#{path}.rb"
    constant = constant_for(name)
    register(name, constant)
    @loaded << name
  end

  # Production parity: load every file, and verify each one defines
  # the constant its path promises - the whole Zeitwerk contract
  def eager_load!
    errors = []
    Dir[File.join(@root, "**", "*.rb")].sort.each do |file|
      name = file.delete_prefix("#{@root}/").delete_suffix(".rb").tr("/", ".")
      begin
        ensure!(name)
      rescue NameError
        errors << "expected #{file.delete_prefix("#{@root}/")} to define #{camelize(name)}, but it doesn't"
      end
    end
    errors
  end

  # Development's third gear: forget everything, next use reloads
  # from disk - edits included, no process restart
  def reload!
    @loaded.each do |name|
      parts = camelize(name).split("::")
      parent = parts[0..-2].inject(Object) { |m, c| m.const_get(c) }
      parent.send(:remove_const, parts.last.to_sym)
    end
    @loaded.clear
    # The registry resolves unversioned lookups to the LATEST version,
    # so each reload generation registers as 1.0.N and simply outranks
    # its predecessor - old providers age out instead of being mutated
    @generation += 1
  end

  private

  def camelize(name) = name.split(".").map { |part| part.split("_").map(&:capitalize).join }.join("::")

  def constant_for(name) = Object.const_get(camelize(name))

  def register(name, constant)
    spec = Agentic::CapabilitySpecification.new(
      name: name, version: "1.0.#{@generation}",
      description: constant.const_defined?(:DESCRIPTION) ? constant::DESCRIPTION : name,
      inputs: constant.const_defined?(:INPUTS) ? constant::INPUTS : {},
      outputs: constant.const_defined?(:OUTPUTS) ? constant::OUTPUTS : {}
    )
    Agentic.register_capability(spec, Agentic::CapabilityProvider.new(capability: spec, implementation: ->(inputs) { constant.call(inputs) }))
  end
end

# --- the pack, written by convention (in real life: your repo) ----------------------
PACK = {
  "text/summarize.rb" => <<~RUBY,
    module Text
      module Summarize
        DESCRIPTION = "First sentence wins"
        def self.call(inputs) = {summary: inputs[:text].split(". ").first + "."}
      end
    end
  RUBY
  "text/word_count.rb" => <<~RUBY,
    module Text
      module WordCount
        def self.call(inputs) = {count: inputs[:text].split.size}
      end
    end
  RUBY
  "math/percentile.rb" => <<~RUBY
    module Math2 # <- 5pm strikes again: wrong constant for math/percentile.rb
      module Percentile
        def self.call(inputs) = {value: inputs[:samples].sort[(inputs[:samples].size * inputs[:p]).floor]}
      end
    end
  RUBY
}.freeze

failures = []
Dir.mktmpdir("capability_pack") do |root|
  PACK.each { |rel, src|
    FileUtils.mkdir_p(File.dirname(File.join(root, rel)))
    File.write(File.join(root, rel), src)
  }
  loader = CapabilityAutoloader.new(root)

  puts "THE CAPABILITY AUTOLOADER (the convention is the registry)"
  puts
  puts "  pack on disk: #{PACK.size} files; capabilities loaded: #{loader.loaded.size} (laziness is a feature)"

  # Lazy: first use loads exactly one file
  loader.ensure!("text.summarize")
  agent = Agentic::Agent.build { |a| a.name = "Reader" }
  agent.add_capability("text.summarize")
  summary = agent.execute_capability("text.summarize", {text: "Zeitwerk maps files to constants. The rest is commentary. Ask fxn."})
  puts "  first use of text.summarize -> loaded #{loader.loaded.size}/#{PACK.size} files, said: #{summary[:summary].inspect}"
  failures << "lazy load loaded too much" unless loader.loaded.size == 1

  # Eager: production wants everything loaded AND the bijection verified
  errors = loader.eager_load!
  puts
  puts "  eager_load! (production parity): #{loader.loaded.size} loaded, #{errors.size} contract violation:"
  errors.each { |e| puts "    BOOT ERROR: #{e}" }
  failures << "eager load missed the misnamed constant" unless errors.any? { |e| e.include?("Math::Percentile") }

  # Reload: edit on disk, forget, next use sees the edit - no restart
  File.write(File.join(root, "text/summarize.rb"), PACK["text/summarize.rb"].sub("First sentence wins", "Now shouty").sub("first + \".\"}", "first.upcase + \"!\"}"))
  loader.reload!
  loader.ensure!("text.summarize")
  # Cached references are every reloader's one true enemy: the agent
  # snapshots its provider at add_capability time, so refresh the add.
  # (Zeitwerk fights the same war against `MyClass = SomeConstant`.)
  agent.add_capability("text.summarize")
  shouty = agent.execute_capability("text.summarize", {text: "Edit the file. See it live."})
  puts
  puts "  reload! then re-use -> #{shouty[:summary].inspect} (the edit, live, no restart)"
  failures << "reload didn't pick up the edit" unless shouty[:summary] == "EDIT THE FILE!"
end

puts
puts "  one bijection, three views: the file path, the constant, the"
puts "  capability name. lazy loading makes development start instantly;"
puts "  eager loading makes production fail at BOOT when a file lies about"
puts "  its constant (math/percentile.rb defining Math2 - caught, named,"
puts "  fixable); reload makes the edit-run loop restart-free. none of it"
puts "  required the framework's cooperation - though a registry miss-hook"
puts "  (const_missing for capabilities) would make the loader invisible,"
puts "  which is what a loader should be."
exit(failures.empty? ? 0 : 1)
