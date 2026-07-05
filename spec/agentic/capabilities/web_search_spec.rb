# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::Capabilities::WebSearch do
  after { Agentic::Capabilities::WebSearch.backend = nil }

  describe ".search" do
    it "delegates to the configured backend" do
      described_class.backend = lambda do |query:, num_results:|
        {results: ["#{query} (#{num_results})"], sources: ["https://internal.example/1"]}
      end

      result = described_class.search("ruby agents", num_results: 5)

      expect(result[:results]).to eq(["ruby agents (5)"])
      expect(result[:sources]).to eq(["https://internal.example/1"])
    end

    it "defaults to the DuckDuckGo backend" do
      expect(described_class.backend).to be_a(described_class::DuckDuckGo)
    end
  end

  describe Agentic::Capabilities::WebSearch::DuckDuckGo do
    let(:payload) do
      {
        "AbstractText" => "Ruby is a dynamic language.",
        "AbstractURL" => "https://www.ruby-lang.org",
        "RelatedTopics" => [
          {"Text" => "Ruby on Rails - a web framework", "FirstURL" => "https://rubyonrails.org"},
          {"Topics" => [
            {"Text" => "Matz - creator of Ruby", "FirstURL" => "https://example.org/matz"}
          ]},
          {"Name" => "See also"}
        ]
      }.to_json
    end

    let(:http) { double("http", get: payload) }

    subject(:backend) { described_class.new(http: http) }

    it "flattens abstract and related topics into results with sources" do
      result = backend.call(query: "ruby", num_results: 3)

      expect(result[:results]).to eq([
        "Ruby is a dynamic language.",
        "Ruby on Rails - a web framework",
        "Matz - creator of Ruby"
      ])
      expect(result[:sources]).to include("https://www.ruby-lang.org", "https://rubyonrails.org")
    end

    it "honors num_results" do
      result = backend.call(query: "ruby", num_results: 1)

      expect(result[:results].size).to eq(1)
    end

    it "escapes the query" do
      backend.call(query: "ruby & rails?", num_results: 1)

      expect(http).to have_received(:get) do |uri|
        expect(uri.query).to include("q=ruby+%26+rails%3F")
      end
    end
  end

  describe "standard capability integration" do
    it "routes the registered web_search capability through the backend" do
      described_class.backend = ->(query:, num_results:) {
        {results: ["hit for #{query}"], sources: ["https://example.test"]}
      }

      registry = Agentic::AgentCapabilityRegistry.instance
      registry.clear
      Agentic::Capabilities.register_standard_capabilities

      provider = registry.get_provider("web_search")
      result = provider.execute(query: "agentic ruby gem")

      expect(result[:results]).to eq(["hit for agentic ruby gem"])
    end
  end
end
