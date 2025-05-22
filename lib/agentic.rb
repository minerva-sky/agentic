# frozen_string_literal: true

require "zeitwerk"
loader = Zeitwerk::Loader.for_gem

# Configure Zeitwerk to handle the CLI class name properly
loader.inflector.inflect(
  "cli" => "CLI"
)

# Configure paths that need to be eager loaded or excluded from Zeitwerk
loader.do_not_eager_load("#{__dir__}/agentic/cli")

loader.setup

# Explicitly require Thor-related components to avoid Zeitwerk issues with Thor
# Thor requires subcommands to be loaded before they're referenced
require_relative "agentic/ui"
require_relative "agentic/default_agent_provider"
require_relative "agentic/cli"
require_relative "agentic/cli/execution_observer"
require_relative "agentic/extension"

module Agentic
  class Error < StandardError; end

  class << self
    attr_accessor :logger
  end

  self.logger ||= Logger.new($stdout, level: :debug)

  class Configuration
    attr_accessor :access_token

    def initialize
      @access_token = ENV["OPENAI_ACCESS_TOKEN"]
    end
  end

  class << self
    attr_writer :configuration
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end

  def self.client(config)
    LlmClient.new(config)
  end
end
