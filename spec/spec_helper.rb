# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  add_filter "/vendor/"
  minimum_coverage 85

  add_group "Core", "lib/agentic/*.rb"
  add_group "CLI", "lib/agentic/cli/"
  add_group "Verification", "lib/agentic/verification/"
  add_group "Observability", "lib/agentic/observability/"
  add_group "Learning", "lib/agentic/learning/"
  add_group "Extensions", "lib/agentic/extension/"
  add_group "UI", "lib/agentic/ui/"
  add_group "Errors", "lib/agentic/errors/"
end

require "agentic"

require "vcr"

# Give the test environment a credential so fail-fast configuration
# validation passes without a real key; VCR intercepts all HTTP anyway
Agentic.configure do |config|
  config.access_token ||= "test-token"
end

# Compatibility shims for ruby-openai 8.x
# The gem simplified error classes, but our tests expect the old ones
unless defined?(OpenAI::RateLimitError)
  module OpenAI
    # Define missing error classes as subclasses of OpenAI::Error for test compatibility
    class RateLimitError < Error; end

    class APIError < Error; end

    class APIConnectionError < Error; end

    class InvalidRequestError < Error; end

    class Timeout < Error; end
  end
end

# Load test factories
Dir[File.join(__dir__, "factories", "*.rb")].each { |f| require f }

VCR.configure do |config|
  config.cassette_library_dir = "spec/vcr_cassettes"
  config.hook_into :webmock
  config.filter_sensitive_data("<OPENAI_ACCESS_TOKEN>") { Agentic.configuration.access_token }
  config.allow_http_connections_when_no_cassette = true
end

RSpec.configure do |config|
  # Include test factories
  config.include VerificationFactories
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Filter out slow integration tests by default
  config.filter_run_excluding :slow unless ENV["RUN_SLOW_TESTS"]

  # VCR configuration
  config.around(:each, :vcr) do |example|
    name = example.metadata[:cassette_name] || example.full_description.downcase.gsub(/\W+/, "_")
    VCR.use_cassette(name) { example.call }
  end

  # Focus on specific tests
  config.filter_run_when_matching :focus
  config.run_all_when_everything_filtered = true

  # Show slowest examples
  config.profile_examples = 10
end
