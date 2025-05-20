# frozen_string_literal: true

module Agentic
  # Value object representing statistics for an LLM generation
  class GenerationStats
    # @return [String] The ID of the generation
    attr_reader :id
    
    # @return [Integer] The number of prompt tokens
    attr_reader :prompt_tokens
    
    # @return [Integer] The number of completion tokens
    attr_reader :completion_tokens
    
    # @return [Integer] The total number of tokens
    attr_reader :total_tokens
    
    # @return [Hash] The raw statistics from the API
    attr_reader :raw_stats
    
    # Initializes a new generation statistics object
    # @param id [String] The ID of the generation
    # @param prompt_tokens [Integer] The number of prompt tokens
    # @param completion_tokens [Integer] The number of completion tokens
    # @param total_tokens [Integer] The total number of tokens
    # @param raw_stats [Hash] The raw statistics from the API
    def initialize(id:, prompt_tokens:, completion_tokens:, total_tokens:, raw_stats: {})
      @id = id
      @prompt_tokens = prompt_tokens
      @completion_tokens = completion_tokens
      @total_tokens = total_tokens
      @raw_stats = raw_stats
    end
    
    # Returns a hash representation of the generation statistics
    # @return [Hash] The generation statistics as a hash
    def to_h
      {
        id: @id,
        prompt_tokens: @prompt_tokens,
        completion_tokens: @completion_tokens,
        total_tokens: @total_tokens
      }
    end
    
    # Creates a GenerationStats object from an API response
    # @param response [Hash] The API response
    # @return [GenerationStats] A new generation statistics object
    def self.from_response(response)
      usage = response&.dig("usage") || {}
      
      new(
        id: response&.dig("id") || "",
        prompt_tokens: usage["prompt_tokens"] || 0,
        completion_tokens: usage["completion_tokens"] || 0,
        total_tokens: usage["total_tokens"] || 0,
        raw_stats: response || {}
      )
    end
  end
end