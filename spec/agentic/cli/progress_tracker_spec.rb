# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::CLI::ProgressTracker do
  let(:options) { {} }
  let(:tracker) { described_class.new(options) }

  describe "#initialize" do
    it "initializes with default values" do
      expect(tracker.sections).to eq({})
      expect(tracker.active_processes).to eq({})
    end

    it "respects quiet mode" do
      quiet_tracker = described_class.new(quiet: true)
      expect(quiet_tracker.instance_variable_get(:@quiet)).to be true
    end
  end

  describe "section management" do
    it "creates sections without immediately displaying them" do
      expect { tracker.create_section("test", "Test Section") }.not_to output.to_stdout

      sections = tracker.sections
      expect(sections).to have_key("test")
      expect(sections["test"][:title]).to eq("Test Section")
      expect(sections["test"][:status]).to eq(:active)
    end

    it "tracks section order" do
      tracker.create_section("first", "First Section")
      tracker.create_section("second", "Second Section")

      section_order = tracker.instance_variable_get(:@section_order)
      expect(section_order).to eq(["first", "second"])
    end
  end

  describe "process management" do
    before do
      tracker.create_section("test_section", "Test Section")
    end

    it "starts processes without immediately displaying them" do
      expect {
        tracker.start_process("test_section", "process_1", "Test process")
      }.not_to output.to_stdout

      expect(tracker.active_processes).to have_key("process_1")
      expect(tracker.sections["test_section"][:process_count]).to eq(1)
    end

    it "completes processes and displays section when all are done" do
      tracker.start_process("test_section", "process_1", "Test process")

      expect {
        tracker.complete_process("process_1", "Test result", 1.5)
      }.to output(/Test Section/).to_stdout

      expect(tracker.active_processes).not_to have_key("process_1")
      expect(tracker.sections["test_section"][:status]).to eq(:completed)
    end

    it "handles process failures" do
      tracker.start_process("test_section", "process_1", "Test process")

      expect {
        tracker.fail_process("process_1", "Test error", 1.0)
      }.to output(/Test Section/).to_stdout

      expect(tracker.sections["test_section"][:failed_count]).to eq(1)
    end
  end

  describe "smart truncation" do
    it "truncates at word boundaries when possible" do
      long_text = "This is a very long description that should be truncated"
      result = tracker.send(:smart_truncate, long_text, 20)

      # Should truncate at word boundary and be under the limit
      expect(result).to end_with("...")
      expect(result.length).to be <= 20
      expect(result).to match(/^This is a very/)
    end

    it "falls back to character truncation when no good word boundary" do
      long_text = "Supercalifragilisticexpialidocious"
      result = tracker.send(:smart_truncate, long_text, 20)

      expect(result).to end_with("...")
      expect(result.length).to be <= 20
    end

    it "returns original text if under limit" do
      short_text = "Short text"
      result = tracker.send(:smart_truncate, short_text, 20)

      expect(result).to eq(short_text)
    end
  end

  describe "result formatting" do
    it "extracts meaningful information from JSON results" do
      json_result = '{"interview_questions": [{"q": "test1"}, {"q": "test2"}]}'
      result = tracker.send(:format_result_text, json_result)

      expect(result).to include("Interview_questions: 2 items")
    end

    it "handles non-JSON results gracefully" do
      simple_result = "Task completed successfully"
      result = tracker.send(:format_result_text, simple_result)

      expect(result).to eq(" → Task completed successfully")
    end

    it "handles empty or nil results" do
      expect(tracker.send(:format_result_text, nil)).to eq("")
      expect(tracker.send(:format_result_text, "")).to eq("")
    end
  end

  describe "display summary" do
    it "shows accurate progress counts" do
      tracker.create_section("test", "Test Section")
      tracker.start_process("test", "p1", "Process 1")
      tracker.start_process("test", "p2", "Process 2")
      tracker.complete_process("p1", "Result 1", 1.0)
      tracker.complete_process("p2", "Result 2", 1.5)

      expect { tracker.display_summary }.to output(/Test Section: 2\/2 completed/).to_stdout
    end

    it "shows failure counts when present" do
      tracker.create_section("test", "Test Section")
      tracker.start_process("test", "p1", "Process 1")
      tracker.start_process("test", "p2", "Process 2")
      tracker.complete_process("p1", "Result 1", 1.0)
      tracker.fail_process("p2", "Error message", 1.5)

      expect { tracker.display_summary }.to output(/Test Section: 1\/2 completed, 1 failed/).to_stdout
    end
  end

  describe "quiet mode" do
    let(:quiet_tracker) { described_class.new(quiet: true) }

    it "suppresses all output in quiet mode" do
      expect {
        quiet_tracker.create_section("test", "Test Section")
        quiet_tracker.start_process("test", "p1", "Process 1")
        quiet_tracker.complete_process("p1", "Result", 1.0)
        quiet_tracker.display_summary
      }.not_to output.to_stdout
    end
  end

  describe "section status symbols" do
    it "returns correct symbols for different statuses" do
      completed_section = {status: :completed}
      failed_section = {status: :failed}
      partial_section = {status: :partial_failure}
      active_section = {status: :active}

      expect(tracker.section_status_symbol(completed_section)).to include("✓")
      expect(tracker.section_status_symbol(failed_section)).to include("✗")
      expect(tracker.section_status_symbol(partial_section)).to include("✗")
      expect(tracker.section_status_symbol(active_section)).to include("⋯")
    end
  end

  describe "empty section handling" do
    it "does not display sections with no completed processes" do
      tracker.create_section("empty_section", "Empty Section")
      tracker.start_process("empty_section", "process_1", "Test process")

      # Simulate that the process never completes (remains in active_processes)
      # This could happen due to errors, cancellations, etc.

      # Force check section completion (normally this wouldn't be called for incomplete sections)
      # but we can simulate a case where the orchestrator thinks the section is done
      section = tracker.sections["empty_section"]
      section[:process_count] = 0  # Simulate no processes actually started

      expect {
        tracker.send(:display_complete_section, "empty_section")
      }.not_to output.to_stdout
    end
  end
end
