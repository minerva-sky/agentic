# frozen_string_literal: true

module Agentic
  # Built-in RubyLLM tools a chat may call (see RubyLlmAdapter's tools:).
  module Tools
    # Tools the CLI can switch on by name through AGENTIC_TOOLS.
    REGISTRY = {"approval_demo" => "Agentic::Tools::ApprovalDemo"}.freeze

    # @param names [String, nil] comma-separated REGISTRY keys
    # @return [Array<Class>] the tool classes, in the order given
    # @raise [Errors::ConfigurationError] for a name not in REGISTRY
    def self.resolve(names)
      names.to_s.split(",").map(&:strip).reject(&:empty?).map do |name|
        const = REGISTRY.fetch(name) do
          raise Errors::ConfigurationError,
            "Unknown tool #{name.inspect} in AGENTIC_TOOLS; known: #{REGISTRY.keys.join(", ")}"
        end
        Object.const_get(const)
      end
    end
  end
end
