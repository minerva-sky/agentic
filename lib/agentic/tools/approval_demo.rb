# frozen_string_literal: true

require "ruby_llm"

module Agentic
  module Tools
    # A harmless tool that always needs a person's approval before it runs.
    # It exists so a tool-level pause can be exercised end to end: the chat
    # pauses on the call, `agentic pending` shows the question, and an
    # `--answer` in a later process resumes it (ADR-023 point 7).
    #
    # Turn it on for library use with
    #   Agentic.configure { |c| c.tools = [Agentic::Tools::ApprovalDemo] }
    # or for the CLI with AGENTIC_TOOLS=approval_demo, which every process
    # in the pause/resume pair must share.
    class ApprovalDemo < RubyLLM::Tool
      def self.name = "ApprovalDemo"

      description "Writes a short note. Needs a person to approve it first."
      parameter :note, description: "The note to write"
      requires_approval

      # @param note [String]
      # @return [String] confirmation the approved call ran
      def execute(note:)
        "approved and wrote: #{note}"
      end
    end
  end
end
