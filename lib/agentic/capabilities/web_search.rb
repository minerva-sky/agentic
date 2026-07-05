# frozen_string_literal: true

require "cgi"
require "json"
require "net/http"
require "uri"

module Agentic
  module Capabilities
    # Web search with a pluggable backend.
    #
    # The default backend uses DuckDuckGo's Instant Answer API - no API key,
    # no signup - so `web_search` works out of the box. Swap in your own
    # backend (SerpAPI, Brave, Tavily, an internal index) with any callable
    # that accepts (query:, num_results:) and returns
    # {results: [String], sources: [String]}:
    #
    #   Agentic::Capabilities::WebSearch.backend = lambda do |query:, num_results:|
    #     hits = MySearchClient.search(query, limit: num_results)
    #     {results: hits.map(&:snippet), sources: hits.map(&:url)}
    #   end
    module WebSearch
      class << self
        # @return [#call] The active search backend
        attr_writer :backend

        # The active search backend (defaults to DuckDuckGo)
        # @return [#call]
        def backend
          @backend ||= DuckDuckGo.new
        end

        # Searches the web using the configured backend
        # @param query [String] The search query
        # @param num_results [Integer] Maximum number of results
        # @return [Hash] {results: [String], sources: [String]}
        def search(query, num_results: 3)
          backend.call(query: query, num_results: num_results)
        end
      end

      # Zero-configuration backend using DuckDuckGo's Instant Answer API
      class DuckDuckGo
        ENDPOINT = "https://api.duckduckgo.com/"

        # @param http [#get] HTTP client (defaults to Net::HTTP; injectable for tests)
        def initialize(http: Net::HTTP)
          @http = http
        end

        # @param query [String] The search query
        # @param num_results [Integer] Maximum number of results
        # @return [Hash] {results: [String], sources: [String]}
        def call(query:, num_results: 3)
          uri = URI("#{ENDPOINT}?q=#{CGI.escape(query)}&format=json&no_html=1&skip_disambig=1")
          body = @http.get(uri).to_s

          begin
            data = JSON.parse(body)
          rescue JSON::ParserError
            raise Agentic::Error,
              "Web search backend received a non-JSON response from " \
              "#{ENDPOINT} (blocked network? proxy error page?): #{body[0, 120]}"
          end

          entries = extract_entries(data).first(num_results)

          {
            results: entries.map { |entry| entry["Text"] },
            sources: entries.map { |entry| entry["FirstURL"] }.compact
          }
        end

        private

        # Instant Answers nest results under Abstract and RelatedTopics
        # (which may themselves contain grouped Topics)
        def extract_entries(data)
          entries = []

          if data["AbstractText"] && !data["AbstractText"].empty?
            entries << {"Text" => data["AbstractText"], "FirstURL" => data["AbstractURL"]}
          end

          Array(data["RelatedTopics"]).each do |topic|
            if topic["Topics"]
              entries.concat(Array(topic["Topics"]).select { |nested| nested["Text"] })
            elsif topic["Text"]
              entries << topic
            end
          end

          entries
        end
      end
    end
  end
end
