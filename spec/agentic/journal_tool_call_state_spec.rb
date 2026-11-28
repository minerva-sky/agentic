# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe Agentic::JournalToolCallState do
  let(:call_class) { Struct.new(:id, :name, :namespace, keyword_init: true) }
  let(:ask_call) { call_class.new(id: "call_ask", name: "pick_color", namespace: nil) }
  let(:write_call) { call_class.new(id: "call_write", name: "write_file", namespace: nil) }
  let(:paused_input) do
    {"requests" => [{"id" => "q1", "message" => "Which colour?", "choices" => %w[red blue]}]}
  end

  def round_trip(state)
    described_class.from_h(JSON.parse(JSON.generate(state.to_h)))
  end

  # ToolCallState is undocumented in ruby_llm. These examples fail loudly if
  # the parts this class depends on move (ADR-023 point 7).
  describe "ruby_llm contract" do
    let(:base) { RubyLLM::Chat::ToolCallState }

    it "is a RubyLLM::Chat::ToolCallState" do
      expect(described_class.ancestors).to include(base)
    end

    it "keeps the reader and writer methods the chat calls" do
      %i[input record_input settle exclusively record_decision decision
        decline_note record_decline_note denied? remember remembered?
        escalation_spent? spend_escalation claim release started
        interrupted? running_elsewhere?].each do |name|
        expect(base.public_method_defined?(name)).to be(true), "ToolCallState##{name} is gone"
      end
    end

    it "keeps the instance variables #to_h serialises" do
      ivars = base.new.instance_variables
      expect(ivars).to include(:@inputs, :@decisions, :@notes, :@remembered, :@spent_escalations)
    end

    it "lets a chat take a swapped-in state" do
      expect(RubyLLM::Chat.private_method_defined?(:tool_call_state=) ||
             RubyLLM::Chat.public_method_defined?(:tool_call_state=)).to be(true)
    end

    it "stores remembered approvals as [namespace, name]" do
      expect(base.remembered_identity(write_call)).to eq([nil, "write_file"])
    end
  end

  describe "#to_h / .from_h" do
    it "round-trips an empty state through JSON" do
      restored = round_trip(described_class.new)

      expect(restored.input(ask_call)).to be_nil
      expect(restored.decision(write_call)).to be_nil
      expect(restored.remembered?(write_call)).to be(false)
    end

    it "round-trips inputs, decisions, decline notes, remembered approvals and spent escalations" do
      state = described_class.new
      state.record_input(ask_call, paused_input)
      state.record_decision(write_call.id, false)
      state.record_decline_note(write_call, "not that file")
      state.remember(described_class.remembered_identity(ask_call))
      state.spend_escalation(write_call)

      restored = round_trip(state)

      expect(restored.input(ask_call)).to eq(paused_input)
      expect(restored.decision(write_call)).to be(false)
      expect(restored).to be_denied(write_call)
      expect(restored.decline_note(write_call)).to eq("not that file")
      expect(restored.remembered?(ask_call)).to be(true)
      expect(restored.remembered?(write_call)).to be(false)
      expect(restored.escalation_spent?(write_call)).to be(true)
    end

    it "lets a restored state settle the paused input" do
      state = described_class.new
      state.record_input(ask_call, paused_input)
      restored = round_trip(state)

      restored.settle(ask_call) do |input|
        input.merge("requests" => input["requests"].map { |r| r.merge("response" => "blue") })
      end

      expect(restored.input(ask_call)["requests"].first["response"]).to eq("blue")
      expect(state.input(ask_call)["requests"].first).not_to have_key("response")
    end

    it "accepts symbol keys from a hash that never went through JSON" do
      restored = described_class.from_h(version: 1, decisions: {call_write: true})

      expect(restored.decision(write_call)).to be(true)
    end

    it "treats nil as an empty state" do
      expect(described_class.from_h(nil).to_h["inputs"]).to eq({})
    end

    it "refuses an unknown format version" do
      expect { described_class.from_h("version" => 99) }
        .to raise_error(ArgumentError, /unknown chat_state version 99/)
    end

    it "serialises with to_json" do
      state = described_class.new
      state.record_decision(write_call.id, true)

      expect(JSON.parse(state.to_json)).to include("version" => 1, "decisions" => {"call_write" => true})
    end
  end
end
