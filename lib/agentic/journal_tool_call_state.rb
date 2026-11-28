# frozen_string_literal: true

require "ruby_llm"

module Agentic
  # Tool-call state for an agent's chat that can be written into the
  # execution journal and read back by another process (ADR-023 point 7).
  #
  # RubyLLM keeps what a chat knows about paused tool calls (the questions a
  # tool asked, approvals and declines, remembered approvals) in a
  # ToolCallState. Its Rails integration swaps in a subclass backed by the
  # database; this one is backed by plain JSON instead, so a paused task can
  # carry it in its +task_awaiting_human+ event as +chat_state+ and a resumed
  # run can rebuild the chat with the same state.
  #
  # ToolCallState is undocumented. spec/agentic/journal_tool_call_state_spec.rb
  # pins the parts of its interface this class relies on.
  class JournalToolCallState < RubyLLM::Chat::ToolCallState
    FORMAT_VERSION = 1

    # Rebuilds a state from what #to_h produced, before or after a JSON round
    # trip. Raises ArgumentError for a hash from an unknown format version.
    def self.from_h(hash)
      hash = stringify(hash || {})
      version = hash.fetch("version", FORMAT_VERSION)
      raise ArgumentError, "unknown chat_state version #{version.inspect}" unless version == FORMAT_VERSION

      new.tap { |state| state.load(hash) }
    end

    def self.stringify(value)
      case value
      when Hash then value.to_h { |k, v| [k.to_s, stringify(v)] }
      when Array then value.map { |v| stringify(v) }
      else value
      end
    end
    private_class_method :stringify

    # The state as a JSON-safe hash. Inputs are already string-keyed JSON in
    # RubyLLM (their "requests" are what Question.from_h reads), so they are
    # copied as they are.
    def to_h
      exclusively do
        {
          "version" => FORMAT_VERSION,
          "inputs" => @inputs.dup,
          "decisions" => @decisions.dup,
          "decline_notes" => @notes.dup,
          "remembered" => @remembered.map(&:dup),
          "spent_escalations" => @spent_escalations.dup
        }
      end
    end

    def to_json(*args)
      to_h.to_json(*args)
    end

    # Fills an empty state from a string-keyed hash. Used by .from_h.
    def load(hash)
      exclusively do
        @inputs = hash.fetch("inputs", {}).dup
        @decisions = hash.fetch("decisions", {}).dup
        @notes = hash.fetch("decline_notes", {}).dup
        @remembered = hash.fetch("remembered", []).map(&:dup)
        @spent_escalations = hash.fetch("spent_escalations", []).dup
      end
      self
    end
  end
end
