# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe "Agentic.initialize_agent_assembly" do
  let(:assembly_ivars) { %i[@agent_capability_registry @agent_store @agent_assembly_engine] }

  around do |example|
    ivars = %i[@agent_capability_registry @agent_store @agent_assembly_engine]
    saved = ivars.to_h { |ivar| [ivar, Agentic.instance_variable_get(ivar)] }
    ivars.each { |ivar| Agentic.instance_variable_set(ivar, nil) }
    example.run
  ensure
    saved.each { |ivar, value| Agentic.instance_variable_set(ivar, value) }
  end

  it "initializes the store exactly once under concurrent callers" do
    Dir.mktmpdir do |dir|
      allow(Agentic.configuration).to receive(:agent_store_path).and_return(dir)

      # Widen the race window so a missing lock would reliably lose the race
      allow(Agentic::PersistentAgentStore).to receive(:new).and_wrap_original do |original, *args|
        sleep 0.01
        original.call(*args)
      end

      8.times.map {
        Thread.new { Agentic.initialize_agent_assembly }
      }.each(&:join)

      expect(Agentic::PersistentAgentStore).to have_received(:new).once
      expect(Agentic.agent_capability_registry).not_to be_nil
      expect(Agentic.agent_store).not_to be_nil
      expect(Agentic.agent_assembly_engine).not_to be_nil
    end
  end

  it "does not reinitialize on subsequent calls" do
    Dir.mktmpdir do |dir|
      allow(Agentic.configuration).to receive(:agent_store_path).and_return(dir)

      Agentic.initialize_agent_assembly
      store = Agentic.agent_store

      Agentic.initialize_agent_assembly

      expect(Agentic.agent_store).to equal(store)
    end
  end
end
