# frozen_string_literal: true

require "agentic"

require "vcr"

# Give the test environment a credential so fail-fast configuration
# validation passes without a real key; VCR intercepts all HTTP anyway
Agentic.configure do |config|
  config.access_token ||= "test-token"
end

VCR.configure do |config|
  config.cassette_library_dir = "spec/vcr_cassettes"
  config.hook_into :webmock
  config.filter_sensitive_data("<OPENAI_ACCESS_TOKEN>") { Agentic.configuration.access_token }
  config.allow_http_connections_when_no_cassette = true
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
