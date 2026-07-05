# frozen_string_literal: true

module Agentic
  module Errors
    # Raised when the library is asked to talk to an LLM without usable
    # credentials or endpoint configuration. Raised at client construction
    # time so misconfiguration fails at boot, not at request time.
    class ConfigurationError < StandardError; end
  end
end
