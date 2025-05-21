# frozen_string_literal: true

module Agentic
  # Value object representing expected answer format
  class ExpectedAnswerFormat
    # @return [String] The format of the expected answer
    attr_reader :format

    # @return [Array<String>] The sections expected in the answer
    attr_reader :sections

    # @return [String] The expected length of the answer
    attr_reader :length

    # Initializes a new expected answer format
    # @param format [String] The format of the expected answer
    # @param sections [Array<String>] The sections expected in the answer
    # @param length [String] The expected length of the answer
    def initialize(format:, sections:, length:)
      @format = format
      @sections = sections
      @length = length
    end

    # Returns a serializable representation of the expected answer format
    # @return [Hash] The expected answer format as a hash
    def to_h
      {
        "format" => @format,
        "sections" => @sections,
        "length" => @length
      }
    end

    # Creates an ExpectedAnswerFormat from a hash
    # @param hash [Hash] The hash representation
    # @return [ExpectedAnswerFormat] A new expected answer format
    def self.from_hash(hash)
      new(
        format: hash["format"],
        sections: hash["sections"],
        length: hash["length"]
      )
    end
  end
end
