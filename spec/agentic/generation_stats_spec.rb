# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::GenerationStats do
  let(:generation_stats) do
    described_class.new(
      id: "gen-123",
      prompt_tokens: 50,
      completion_tokens: 150,
      total_tokens: 200,
      raw_stats: {"usage" => {"prompt_tokens" => 50, "completion_tokens" => 150, "total_tokens" => 200}}
    )
  end

  describe "#initialize" do
    it "sets the id, prompt_tokens, completion_tokens, and total_tokens" do
      expect(generation_stats.id).to eq("gen-123")
      expect(generation_stats.prompt_tokens).to eq(50)
      expect(generation_stats.completion_tokens).to eq(150)
      expect(generation_stats.total_tokens).to eq(200)
    end

    it "sets the raw_stats" do
      expect(generation_stats.raw_stats).to eq({
        "usage" => {
          "prompt_tokens" => 50,
          "completion_tokens" => 150,
          "total_tokens" => 200
        }
      })
    end
  end

  describe "#to_h" do
    it "returns a hash representation of the generation statistics" do
      expect(generation_stats.to_h).to eq({
        id: "gen-123",
        prompt_tokens: 50,
        completion_tokens: 150,
        total_tokens: 200
      })
    end
  end

  describe ".from_response" do
    let(:response) do
      {
        "id" => "gen-123",
        "usage" => {
          "prompt_tokens" => 50,
          "completion_tokens" => 150,
          "total_tokens" => 200
        }
      }
    end

    it "creates a GenerationStats from an API response" do
      stats = described_class.from_response(response)
      expect(stats).to be_a(described_class)
      expect(stats.id).to eq("gen-123")
      expect(stats.prompt_tokens).to eq(50)
      expect(stats.completion_tokens).to eq(150)
      expect(stats.total_tokens).to eq(200)
      expect(stats.raw_stats).to eq(response)
    end

    it "handles missing or incomplete data gracefully" do
      incomplete_response = {"id" => "gen-123"}
      stats = described_class.from_response(incomplete_response)
      expect(stats).to be_a(described_class)
      expect(stats.id).to eq("gen-123")
      expect(stats.prompt_tokens).to eq(0)
      expect(stats.completion_tokens).to eq(0)
      expect(stats.total_tokens).to eq(0)
      expect(stats.raw_stats).to eq(incomplete_response)
    end

    it "handles nil response gracefully" do
      stats = described_class.from_response(nil)
      expect(stats).to be_a(described_class)
      expect(stats.id).to eq("")
      expect(stats.prompt_tokens).to eq(0)
      expect(stats.completion_tokens).to eq(0)
      expect(stats.total_tokens).to eq(0)
      expect(stats.raw_stats).to eq({})
    end
  end
end
