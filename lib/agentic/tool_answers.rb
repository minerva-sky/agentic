# frozen_string_literal: true

module Agentic
  # Checks a person's answers to a tool-level pause (ADR-023 point 7)
  # against the questions the journal recorded, and prepares what the
  # resumed chat needs.
  #
  # A task-level pause takes any answer. A tool-level one recorded
  # questions, so its answer is a Hash keyed by question id; a plain value
  # is accepted when exactly one question is open. Approvals become
  # decisions in the paused chat's JournalToolCallState; input answers stay
  # in +answers+ for the adapter to hand to Chat#answer, since settling a
  # tool's question needs the rebuilt chat.
  module ToolAnswers
    APPROVE = %w[yes y approve approved allow true].freeze
    DECLINE = %w[no n decline declined deny false].freeze

    module_function

    # @param pause [Hash] Replayed awaiting_human entry with :questions and :chat_state
    # @param answer [String, Hash] The person's answer
    # @return [Hash] "answers" (question id => value) and "chat_state"
    #   (with "tool_call_state" updated for approvals)
    # @raise [ArgumentError] For an unknown question id, a value outside the
    #   offered choices, or an approval that is neither yes nor no
    def resolve(pause, answer)
      questions = Array(pause[:questions]).to_h { |q| [fetch(q, :id).to_s, q] }
      answers = normalize(questions, answer)
      answers = answers.to_h { |id, value| [id, check(questions.fetch(id), id, value)] }

      {"answers" => answers, "chat_state" => record_approvals(pause[:chat_state], questions, answers)}
    end

    def normalize(questions, answer)
      unless answer.is_a?(Hash)
        return {questions.keys.first => answer} if questions.size == 1

        raise ArgumentError, "#{questions.size} questions are open (#{questions.keys.join(", ")}); answer each by id"
      end
      raise ArgumentError, "no answers given" if answer.empty?

      answer.to_h do |id, value|
        id = id.to_s
        raise ArgumentError, "no open question #{id} (open: #{questions.keys.join(", ")})" unless questions.key?(id)

        [id, value]
      end
    end

    def check(question, id, value)
      case fetch(question, :kind).to_s
      when "approval" then approval(id, value)
      else
        choices = fetch(question, :choices)
        if choices && !choices.map(&:to_s).include?(value.to_s)
          raise ArgumentError, "question #{id} takes one of #{choices.join(", ")}, got #{value.inspect}"
        end
        value
      end
    end

    def approval(id, value)
      return value if value == true || value == false

      word = value.to_s.strip.downcase
      return true if APPROVE.include?(word)
      return false if DECLINE.include?(word)

      raise ArgumentError, "question #{id} is an approval; answer yes or no, got #{value.inspect}"
    end

    def record_approvals(chat_state, questions, answers)
      chat_state = (chat_state || {}).to_h { |k, v| [k.to_s, v] }
      approvals = answers.select { |id, _| fetch(questions[id], :kind).to_s == "approval" }
      return chat_state if approvals.empty? && !chat_state.key?("tool_call_state")

      state = JournalToolCallState.from_h(chat_state["tool_call_state"])
      approvals.each { |id, approved| state.record_decision(id, approved) }
      chat_state.merge("tool_call_state" => state.to_h)
    end

    def fetch(hash, key)
      hash[key] || hash[key.to_s]
    end
  end
end
