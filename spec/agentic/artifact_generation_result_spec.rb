# frozen_string_literal: true

RSpec.describe Agentic::ArtifactGenerationResult do
  let(:workspace) do
    instance_double(
      Agentic::Workspace,
      id: "ws-123",
      path: "/tmp/test_workspace"
    )
  end

  let(:artifact1) do
    instance_double(
      Agentic::Artifact,
      name: "user.rb",
      type: :ruby_class,
      to_h: {name: "user.rb", type: :ruby_class, content: "class User; end"}
    )
  end

  let(:artifact2) do
    instance_double(
      Agentic::Artifact,
      name: "service.rb",
      type: :ruby_class,
      to_h: {name: "service.rb", type: :ruby_class, content: "class Service; end"}
    )
  end

  describe "#initialize" do
    it "creates a result with defaults" do
      result = described_class.new

      expect(result.artifacts).to eq([])
      expect(result.workspace).to be_nil
      expect(result.success).to be true
      expect(result.errors).to eq([])
      expect(result.metadata).to eq({})
    end

    it "creates a result with all parameters" do
      result = described_class.new(
        artifacts: [artifact1],
        workspace: workspace,
        success: true,
        errors: [],
        metadata: {custom: "data"}
      )

      expect(result.artifacts).to eq([artifact1])
      expect(result.workspace).to eq(workspace)
      expect(result.success).to be true
      expect(result.errors).to eq([])
      expect(result.metadata).to eq({custom: "data"})
    end
  end

  describe "#successful?" do
    it "returns true when success is true and no errors" do
      result = described_class.new(success: true, errors: [])
      expect(result.successful?).to be true
    end

    it "returns false when success is false" do
      result = described_class.new(success: false, errors: [])
      expect(result.successful?).to be false
    end

    it "returns false when there are errors even if success is true" do
      result = described_class.new(success: true, errors: ["Something went wrong"])
      expect(result.successful?).to be false
    end
  end

  describe "#failed?" do
    it "returns false when successful" do
      result = described_class.new(success: true, errors: [])
      expect(result.failed?).to be false
    end

    it "returns true when not successful" do
      result = described_class.new(success: false, errors: ["Error"])
      expect(result.failed?).to be true
    end
  end

  describe "#artifact_count" do
    it "returns zero for empty artifacts" do
      result = described_class.new(artifacts: [])
      expect(result.artifact_count).to eq(0)
    end

    it "returns the count of artifacts" do
      result = described_class.new(artifacts: [artifact1, artifact2])
      expect(result.artifact_count).to eq(2)
    end
  end

  describe "#has_artifacts?" do
    it "returns false for empty artifacts" do
      result = described_class.new(artifacts: [])
      expect(result.has_artifacts?).to be false
    end

    it "returns true when artifacts present" do
      result = described_class.new(artifacts: [artifact1])
      expect(result.has_artifacts?).to be true
    end
  end

  describe "#workspace_id" do
    it "returns nil when no workspace" do
      result = described_class.new(workspace: nil)
      expect(result.workspace_id).to be_nil
    end

    it "returns workspace id when present" do
      result = described_class.new(workspace: workspace)
      expect(result.workspace_id).to eq("ws-123")
    end
  end

  describe "#workspace_path" do
    it "returns nil when no workspace" do
      result = described_class.new(workspace: nil)
      expect(result.workspace_path).to be_nil
    end

    it "returns workspace path when present" do
      result = described_class.new(workspace: workspace)
      expect(result.workspace_path).to eq("/tmp/test_workspace")
    end
  end

  describe "#to_h" do
    it "returns a hash representation" do
      result = described_class.new(
        artifacts: [artifact1],
        workspace: workspace,
        success: true,
        errors: [],
        metadata: {key: "value"}
      )

      hash = result.to_h

      expect(hash[:success]).to be true
      expect(hash[:artifacts]).to eq([artifact1.to_h])
      expect(hash[:artifact_count]).to eq(1)
      expect(hash[:workspace_id]).to eq("ws-123")
      expect(hash[:workspace_path]).to eq("/tmp/test_workspace")
      expect(hash[:errors]).to eq([])
      expect(hash[:metadata]).to eq({key: "value"})
    end
  end

  describe "#to_s" do
    it "returns success status string" do
      result = described_class.new(artifacts: [artifact1], success: true)
      expect(result.to_s).to include("success")
      expect(result.to_s).to include("artifacts=1")
    end

    it "returns failed status string" do
      result = described_class.new(success: false, errors: ["error"])
      expect(result.to_s).to include("failed")
    end
  end

  describe ".success" do
    it "creates a successful result" do
      result = described_class.success(
        artifacts: [artifact1],
        workspace: workspace,
        metadata: {source: "test"}
      )

      expect(result.successful?).to be true
      expect(result.artifacts).to eq([artifact1])
      expect(result.workspace).to eq(workspace)
      expect(result.errors).to eq([])
      expect(result.metadata).to eq({source: "test"})
    end
  end

  describe ".failure" do
    it "creates a failed result with error string" do
      result = described_class.failure(
        errors: "Something went wrong",
        workspace: workspace
      )

      expect(result.successful?).to be false
      expect(result.errors).to eq(["Something went wrong"])
      expect(result.workspace).to eq(workspace)
    end

    it "creates a failed result with error array" do
      result = described_class.failure(
        errors: ["Error 1", "Error 2"],
        workspace: workspace,
        artifacts: [artifact1],
        metadata: {partial: true}
      )

      expect(result.successful?).to be false
      expect(result.errors).to eq(["Error 1", "Error 2"])
      expect(result.artifacts).to eq([artifact1])
      expect(result.metadata).to eq({partial: true})
    end
  end
end
