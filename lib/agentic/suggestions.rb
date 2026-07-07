# frozen_string_literal: true

module Agentic
  # "Did you mean?" for framework errors. At the moment most errors are
  # raised, the framework is holding the list of every valid name - the
  # contract knows its fields, the plan knows its tasks. Spending one
  # Levenshtein pass there converts a stack trace into a one-keystroke
  # fix. The threshold scales with word length and is deliberately
  # conservative: a wrong suggestion is worse than none.
  module Suggestions
    module_function

    # Levenshtein edit distance, single-row implementation
    # @param a [String]
    # @param b [String]
    # @return [Integer]
    def distance(a, b)
      rows = (0..b.size).to_a
      a.each_char.with_index(1) do |ca, i|
        previous = rows[0]
        rows[0] = i
        b.each_char.with_index(1) do |cb, j|
          current = rows[j]
          rows[j] = [rows[j] + 1, rows[j - 1] + 1, previous + ((ca == cb) ? 0 : 1)].min
          previous = current
        end
      end
      rows[b.size]
    end

    # The closest candidate within a length-scaled budget, or nil -
    # silence beats a confident wrong answer
    # @param typo [String, Symbol] What was given
    # @param candidates [Enumerable<String, Symbol>] What was valid
    # @return [String, Symbol, nil]
    def suggest(typo, candidates)
      threshold = (typo.to_s.size / 2).clamp(1, 3)
      scored = candidates.map { |candidate| [candidate, distance(typo.to_s, candidate.to_s)] }
      scored.select { |_, d| d <= threshold }.min_by { |_, d| d }&.first
    end

    # A ready-to-append hint sentence, or an empty string
    # @param typo [String, Symbol] What was given
    # @param candidates [Enumerable<String, Symbol>] What was valid
    # @return [String] e.g. " (did you mean weight_kg?)" or ""
    def hint(typo, candidates)
      match = suggest(typo, candidates)
      match ? " (did you mean #{match}?)" : ""
    end
  end
end
