# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::ExpectedAnswerFormat do
  let(:expected_answer_format) do
    described_class.new(
      format: "PDF",
      sections: ["Summary", "Trends", "Conclusion"],
      length: "10 pages"
    )
  end

  describe "#initialize" do
    it "sets the format, sections, and length" do
      expect(expected_answer_format.format).to eq("PDF")
      expect(expected_answer_format.sections).to eq(["Summary", "Trends", "Conclusion"])
      expect(expected_answer_format.length).to eq("10 pages")
    end
  end

  describe "#to_h" do
    it "returns a hash representation of the expected answer format" do
      expect(expected_answer_format.to_h).to eq({
        "format" => "PDF",
        "sections" => ["Summary", "Trends", "Conclusion"],
        "length" => "10 pages"
      })
    end
  end

  describe ".from_hash" do
    let(:hash) do
      {
        "format" => "PDF",
        "sections" => ["Summary", "Trends", "Conclusion"],
        "length" => "10 pages"
      }
    end

    it "creates an ExpectedAnswerFormat from a hash" do
      format = described_class.from_hash(hash)
      expect(format).to be_a(described_class)
      expect(format.format).to eq("PDF")
      expect(format.sections).to eq(["Summary", "Trends", "Conclusion"])
      expect(format.length).to eq("10 pages")
    end
  end
end
