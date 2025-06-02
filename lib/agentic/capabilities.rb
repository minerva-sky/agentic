# frozen_string_literal: true

require_relative "capabilities/examples"

module Agentic
  # Namespace for capability-related functionality
  module Capabilities
    # Register standard capabilities
    # @return [void]
    def self.register_standard_capabilities
      Examples.register_all
    end
  end
end
