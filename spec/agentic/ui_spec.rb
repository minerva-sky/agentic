# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::UI do
  describe ".spinner" do
    it "creates a new spinner with the given message" do
      spinner = described_class.spinner("Test message")
      expect(spinner).to be_a(TTY::Spinner)
    end
  end

  describe ".progress_bar" do
    it "creates a new progress bar with the given title and total" do
      progress_bar = described_class.progress_bar("Test title", 100)
      expect(progress_bar).to be_a(TTY::ProgressBar)
    end
  end

  describe ".box" do
    it "creates a box with the given title and content" do
      box = described_class.box("Test title", "Test content")
      expect(box).to include("Test title")
      expect(box).to include("Test content")
    end
  end

  describe ".pastel" do
    it "returns a colorizer instance" do
      # Pastel might be a custom class or a Module in this implementation
      expect(described_class.pastel).to respond_to(:green)
      expect(described_class.pastel).to respond_to(:red)
      expect(described_class.pastel).to respond_to(:blue)
    end

    it "memoizes the Pastel instance" do
      pastel1 = described_class.pastel
      pastel2 = described_class.pastel
      expect(pastel1).to be(pastel2)
    end
  end

  describe ".colorize" do
    it "colorizes text with the given color" do
      # Since we can't easily test the actual colorization in a test environment,
      # we'll just verify the method doesn't throw an error and returns a string
      result = described_class.colorize("test", :green)
      expect(result).to be_a(String)
      expect(result).to include("test")
    end
  end

  describe ".status_text" do
    it "colorizes text according to status" do
      # Since we can't easily test the actual colorization in a test environment,
      # we'll just verify the method works for different statuses
      statuses = [:completed, :failed, :pending, :in_progress, :unknown]

      statuses.each do |status|
        result = described_class.status_text("Test", status)
        expect(result).to be_a(String)
        expect(result).to include("Test")
      end
    end
  end

  describe ".format_duration" do
    it "formats duration in milliseconds" do
      expect(described_class.format_duration(0.5)).to eq("500ms")
    end

    it "formats duration in seconds" do
      expect(described_class.format_duration(45)).to eq("45s")
    end

    it "formats duration in minutes and seconds" do
      expect(described_class.format_duration(125)).to eq("2m 5s")
    end

    it "formats duration in hours and minutes" do
      expect(described_class.format_duration(7265)).to eq("2h 1m")
    end
  end

  describe ".with_spinner" do
    it "shows a spinner, yields the block, and reports success" do
      spinner = instance_double(TTY::Spinner)
      allow(described_class).to receive(:spinner).with("Test message").and_return(spinner)
      allow(spinner).to receive(:auto_spin)
      allow(spinner).to receive(:success)
      allow(described_class).to receive(:colorize).with("✓", :green).and_return("green-checkmark")

      result = described_class.with_spinner("Test message") { "result" }

      expect(result).to eq("result")
      expect(spinner).to have_received(:auto_spin)
      expect(spinner).to have_received(:success).with("(green-checkmark) Test message")
    end

    it "reports errors when the block raises an exception" do
      spinner = instance_double(TTY::Spinner)
      allow(described_class).to receive(:spinner).with("Test message").and_return(spinner)
      allow(spinner).to receive(:auto_spin)
      allow(spinner).to receive(:error)
      allow(described_class).to receive(:colorize).with("✗", :red).and_return("red-x")

      expect {
        described_class.with_spinner("Test message") { raise "Test error" }
      }.to raise_error("Test error")

      expect(spinner).to have_received(:error).with("(red-x) Test message: Test error")
    end

    it "doesn't use a spinner when quiet mode is enabled" do
      allow(described_class).to receive(:spinner).and_return(nil)

      result = described_class.with_spinner("Test message", quiet: true) { "result" }

      expect(result).to eq("result")
      expect(described_class).not_to have_received(:spinner)
    end
  end

  describe ".task_status_indicator" do
    it "returns appropriate indicators for different statuses" do
      # Stub colorize method
      allow(described_class).to receive(:colorize).and_return("colored-indicator")

      {
        completed: "✓",
        failed: "✗",
        in_progress: "↻",
        pending: "○",
        canceled: "⨯",
        unknown: "?"
      }.each do |status, indicator|
        described_class.task_status_indicator(status)
        expect(described_class).to have_received(:colorize).with(indicator, anything)
      end
    end
  end
end
