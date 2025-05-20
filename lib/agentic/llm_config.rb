# frozen_string_literal: true

module Agentic
  # Configuration object for LLM API calls
  class LlmConfig
    # @return [String] The model to use for LLM requests
    attr_accessor :model
    
    # @return [Integer] The maximum number of tokens to generate
    attr_accessor :max_tokens
    
    # @return [Float] The temperature parameter (controls randomness)
    attr_accessor :temperature
    
    # @return [Float] The top_p parameter (nucleus sampling)
    attr_accessor :top_p
    
    # @return [Integer] The frequency penalty
    attr_accessor :frequency_penalty
    
    # @return [Integer] The presence penalty
    attr_accessor :presence_penalty
    
    # @return [Hash] Additional options to pass to the API
    attr_accessor :additional_options

    # Initializes a new LLM configuration
    # @param model [String] The model to use
    # @param max_tokens [Integer, nil] The maximum number of tokens to generate
    # @param temperature [Float] The temperature parameter (0.0-2.0)
    # @param top_p [Float] The top_p parameter (0.0-1.0)
    # @param frequency_penalty [Float] The frequency penalty (-2.0-2.0)
    # @param presence_penalty [Float] The presence penalty (-2.0-2.0)
    # @param additional_options [Hash] Additional options to pass to the API
    def initialize(
      model: "gpt-4o-2024-08-06",
      max_tokens: nil,
      temperature: 0.7,
      top_p: 1.0,
      frequency_penalty: 0.0,
      presence_penalty: 0.0,
      additional_options: {}
    )
      @model = model
      @max_tokens = max_tokens
      @temperature = temperature
      @top_p = top_p
      @frequency_penalty = frequency_penalty
      @presence_penalty = presence_penalty
      @additional_options = additional_options
    end
    
    # Returns a hash of parameters for the API call
    # @param base_params [Hash] Base parameters to include
    # @return [Hash] Parameters for the API call
    def to_api_parameters(base_params = {})
      params = {
        model: @model,
        temperature: @temperature,
        top_p: @top_p,
        frequency_penalty: @frequency_penalty,
        presence_penalty: @presence_penalty
      }
      
      # Add max_tokens if specified
      params[:max_tokens] = @max_tokens if @max_tokens
      
      # Merge any additional options
      params.merge!(@additional_options)
      
      # Merge with base parameters
      base_params.merge(params)
    end
  end
end
