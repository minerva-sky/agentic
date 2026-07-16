# frozen_string_literal: true

RSpec.describe "Artifact Generation Integration", :integration do
  let(:workspace_path) { "/tmp/agentic_integration_#{SecureRandom.hex(8)}" }
  let(:workspace) { Agentic::Workspace.new(workspace_path) }

  # Mock agent that simulates LLM responses
  let(:mock_agent) do
    agent = instance_double(Agentic::Agent)
    allow(agent).to receive(:execute_with_workspace) do |_prompt, _ws|
      generate_mock_response
    end
    agent
  end

  after do
    FileUtils.rm_rf(workspace_path) if Dir.exist?(workspace_path)
  end

  def generate_mock_response
    <<~JSON
      {
        "artifacts": [
          {
            "name": "lib/user.rb",
            "type": "ruby_class",
            "content": "# frozen_string_literal: true\\n\\nclass User\\n  attr_accessor :name, :email\\n\\n  def initialize(name:, email:)\\n    @name = name\\n    @email = email\\n  end\\nend",
            "references": []
          },
          {
            "name": "lib/user_service.rb",
            "type": "ruby_class",
            "content": "# frozen_string_literal: true\\n\\nrequire_relative 'user'\\n\\nclass UserService\\n  def create_user(name:, email:)\\n    User.new(name: name, email: email)\\n  end\\nend",
            "references": ["lib/user.rb"]
          }
        ]
      }
    JSON
  end

  describe "end-to-end artifact generation" do
    it "creates workspace, generates artifacts, and writes files" do
      # 1. Create workspace
      expect(workspace).to be_a(Agentic::Workspace)
      expect(Dir.exist?(workspace_path)).to be true

      # 2. Create generator with mock agent
      generator = Agentic::ArtifactGenerator.new(mock_agent, workspace)

      # 3. Generate artifacts
      result = generator.generate("Create a User class and UserService")

      # 4. Verify result
      expect(result).to be_a(Agentic::ArtifactGenerationResult)
      expect(result.successful?).to be true
      expect(result.artifact_count).to eq(2)

      # 5. Verify artifacts are in workspace
      expect(workspace.artifact_count).to eq(2)

      user_artifact = workspace.find_artifact(name: "lib/user.rb")
      expect(user_artifact).not_to be_nil
      expect(user_artifact.type).to eq(:ruby_class)

      service_artifact = workspace.find_artifact(name: "lib/user_service.rb")
      expect(service_artifact).not_to be_nil
      expect(service_artifact.references).to include("lib/user.rb")

      # 6. Verify files exist on filesystem
      expect(File.exist?(File.join(workspace_path, "lib/user.rb"))).to be true
      expect(File.exist?(File.join(workspace_path, "lib/user_service.rb"))).to be true

      # 7. Verify file content
      user_content = File.read(File.join(workspace_path, "lib/user.rb"))
      expect(user_content).to include("class User")
      expect(user_content).to include("attr_accessor :name, :email")

      # 8. Verify artifact graph relationships
      dependents = workspace.artifacts_referencing(user_artifact)
      expect(dependents.map(&:name)).to include("lib/user_service.rb")

      dependencies = workspace.artifacts_referenced_by(service_artifact)
      expect(dependencies.map(&:name)).to include("lib/user.rb")
    end
  end

  describe "Task with artifact_mode" do
    let(:agent_spec) do
      Agentic::AgentSpecification.new(
        name: "code_generator",
        description: "Generates code files",
        instructions: "Generate well-structured Ruby code"
      )
    end

    it "creates a task with artifact_mode enabled" do
      task = Agentic::Task.new(
        description: "Create a User model",
        agent_spec: agent_spec,
        workspace: workspace,
        artifact_mode: true
      )

      expect(task.artifact_mode).to be true
      expect(task.requires_artifacts?).to be true
      expect(task.has_workspace?).to be true
    end

    it "task with workspace but no artifact_mode still requires artifacts" do
      task = Agentic::Task.new(
        description: "Create a User model",
        agent_spec: agent_spec,
        workspace: workspace,
        artifact_mode: false
      )

      expect(task.artifact_mode).to be false
      expect(task.requires_artifacts?).to be true # has_workspace? is true
    end

    it "task without workspace does not require artifacts by default" do
      task = Agentic::Task.new(
        description: "Analyze code",
        agent_spec: agent_spec,
        artifact_mode: false
      )

      expect(task.requires_artifacts?).to be false
    end

    it "task with artifact_mode but no workspace still requires artifacts" do
      task = Agentic::Task.new(
        description: "Create code",
        agent_spec: agent_spec,
        artifact_mode: true
      )

      expect(task.artifact_mode).to be true
      expect(task.requires_artifacts?).to be true
      expect(task.has_workspace?).to be false
    end
  end

  describe "workspace isolation and security" do
    it "prevents path traversal in artifact names" do
      malicious_response = <<~JSON
        {
          "artifacts": [
            {
              "name": "../../../etc/passwd",
              "type": "text",
              "content": "malicious content"
            }
          ]
        }
      JSON

      malicious_agent = instance_double(Agentic::Agent)
      allow(malicious_agent).to receive(:execute_with_workspace).and_return(malicious_response)

      generator = Agentic::ArtifactGenerator.new(malicious_agent, workspace)
      result = generator.generate("Create a file")

      # Should fail due to security validation
      expect(result.successful?).to be false
    end

    it "prevents disallowed file extensions" do
      exe_response = <<~JSON
        {
          "artifacts": [
            {
              "name": "malware.exe",
              "type": "binary",
              "content": "binary content"
            }
          ]
        }
      JSON

      exe_agent = instance_double(Agentic::Agent)
      allow(exe_agent).to receive(:execute_with_workspace).and_return(exe_response)

      generator = Agentic::ArtifactGenerator.new(exe_agent, workspace)
      result = generator.generate("Create a file")

      # Should fail due to disallowed extension
      expect(result.successful?).to be false
    end
  end

  describe "ArtifactGenerationResult serialization" do
    it "can serialize and inspect generation results" do
      generator = Agentic::ArtifactGenerator.new(mock_agent, workspace)
      result = generator.generate("Create a User class")

      # Test to_h serialization
      hash = result.to_h
      expect(hash[:success]).to be true
      expect(hash[:artifacts]).to be_an(Array)
      expect(hash[:artifact_count]).to eq(2)
      expect(hash[:workspace_id]).to eq(workspace.id)
      expect(hash[:workspace_path]).to eq(workspace.path)

      # Test to_s
      str = result.to_s
      expect(str).to include("success")
      expect(str).to include("artifacts=2")

      # Test inspect
      inspection = result.inspect
      expect(inspection).to include("ArtifactGenerationResult")
      expect(inspection).to include("success=true")
    end
  end

  describe "workspace cleanup" do
    it "cleans up non-persistent workspace" do
      generator = Agentic::ArtifactGenerator.new(mock_agent, workspace)
      generator.generate("Create files")

      expect(File.exist?(File.join(workspace_path, "lib/user.rb"))).to be true

      # Cleanup
      workspace.cleanup

      expect(Dir.exist?(workspace_path)).to be false
    end

    it "preserves persistent workspace" do
      persistent_workspace = Agentic::Workspace.new(workspace_path, persistent: true)
      generator = Agentic::ArtifactGenerator.new(mock_agent, persistent_workspace)
      generator.generate("Create files")

      # Attempt cleanup
      result = persistent_workspace.cleanup

      expect(result).to be false
      expect(Dir.exist?(workspace_path)).to be true
    end
  end
end
