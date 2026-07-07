# frozen_string_literal: true

# Honest Doubles: every fake LLM in every agent test suite is lying a
# little - the question is whether anyone checks. The discipline:
# (1) don't mock what you don't own - wrap the vendor in an adapter
# whose interface YOU define; (2) verify every double against that
# interface (methods AND arity), so a rename breaks the test suite
# loudly instead of letting a thousand fakes drift into fiction.
#
#   bundle exec ruby examples/honest_doubles.rb
#
# Runs offline; one double is honest, one drifted. Guess which passes.

require_relative "../lib/agentic"

Agentic.logger.level = :fatal

# --- the owned boundary ----------------------------------------------------------
# We do NOT stub Agentic::LlmClient (we don't own it; its interface
# can change under us at gem-update speed). We define OUR port:
class CompletionPort
  # The whole vendor surface we permit ourselves to use, in one place
  def complete(prompt, max_tokens:)
    raise NotImplementedError
  end
end

# The real adapter would wrap Agentic::LlmClient. For tests, doubles:
class HonestDouble < CompletionPort
  def initialize(scripted)
    @scripted = scripted
  end

  def complete(prompt, max_tokens:)
    @scripted.fetch(prompt[/\w+/])
  end
end

# This one was written against LAST QUARTER's port and nobody noticed
# the port grew a keyword since - classic double drift
class DriftedDouble
  def complete(prompt)
    "sure, whatever you say"
  end
end

# --- the verifier: doubles must match the port they claim to be -----------------
def verify_double!(double, port)
  port_methods = port.public_instance_methods(false)
  port_methods.each do |name|
    unless double.respond_to?(name)
      raise ArgumentError, "double #{double.class} is missing ##{name}"
    end

    expected = port.instance_method(name).parameters
    actual = double.method(name).parameters
    # Compare shapes: required/optional/keyword names must line up
    if expected.map { |kind, n| [kind, n] } != actual.map { |kind, n| [kind, n] }
      raise ArgumentError, "double #{double.class}##{name} has drifted: " \
        "port takes #{expected.inspect}, double takes #{actual.inspect}"
    end
  end
end

# --- a consumer under test -------------------------------------------------------
def triage(port, ticket)
  label = port.complete("classify: #{ticket}", max_tokens: 5)
  {ticket: ticket, label: label}
end

puts "HONEST DOUBLES (verify the fake against the port, every time)"
puts

honest = HonestDouble.new("classify" => "billing")
verify_double!(honest, CompletionPort)
puts "  honest double: verified against CompletionPort - method AND arity match"
result = triage(honest, "I was charged twice")
puts "    triage under test: #{result.inspect}"
puts

drifted = DriftedDouble.new
begin
  verify_double!(drifted, CompletionPort)
  puts "  drifted double: verified?! the verifier has no teeth"
  exit(1)
rescue ArgumentError => e
  puts "  drifted double: REJECTED before any test ran -"
  puts "    #{e.message}"
end
puts
puts "  without the verifier, the drifted double PASSES every test you"
puts "  write with it - `complete` responds, strings come back, green"
puts "  everywhere - while the real adapter takes max_tokens: and would"
puts "  raise ArgumentError on the very first production call. that's"
puts "  the treachery of unverified fakes: they don't fail, they VOUCH."
puts "  the two rules, cheap to follow: own the boundary (one port class"
puts "  names everything you use from the vendor - the census says the"
puts "  smaller that surface, the better), and verify every double"
puts "  against it in the double's own definition, so interface drift"
puts "  breaks the suite at load time, not the demo. your tests are"
puts "  only as honest as their most casual fake."
