# frozen_string_literal: true

require "spec_helper"

RSpec.describe Agentic::Capabilities::FileGenerationCapability do
  let(:workspace_path) { "/tmp/agentic_filegen_#{SecureRandom.hex(8)}" }
  let(:workspace) { Agentic::Workspace.new(workspace_path) }

  after do
    FileUtils.rm_rf(workspace_path) if Dir.exist?(workspace_path)
  end

  def agent_returning(artifacts)
    agent = instance_double("Agentic::Agent")
    allow(agent).to receive(:execute_with_workspace)
      .and_return(JSON.generate("artifacts" => artifacts))
    agent
  end

  describe ".execute" do
    it "skips an artifact the workspace rejects and keeps the rest" do
      agent = agent_returning([
        {"name" => "notes.md", "content" => "# Notes"},
        {"name" => "../escape.md", "content" => "# Escape"},
        {"name" => "README.md", "content" => "# Readme"}
      ])

      result = described_class.execute(
        agent: agent,
        inputs: {workspace: workspace, task_description: "Write three files"}
      )

      expect(result[:success]).to be(true)
      expect(result[:artifact_count]).to eq(2)
      expect(result[:artifacts].map { |a| a[:name] }).to eq(["notes.md", "README.md"])
      expect(File).not_to exist(File.expand_path("../escape.md", workspace_path))
    end

    it "logs the rejected artifact instead of raising" do
      agent = agent_returning([{"name" => "../escape.md", "content" => "# Escape"}])
      allow(Agentic.logger).to receive(:error)

      expect {
        described_class.execute(
          agent: agent,
          inputs: {workspace: workspace, task_description: "Write one file"}
        )
      }.not_to raise_error

      expect(Agentic.logger).to have_received(:error).with(/path traversal/)
    end
  end
end
