# frozen_string_literal: true

RSpec.describe Agentic::ArtifactGenerator do
  let(:workspace_path) { "/tmp/agentic_test_#{SecureRandom.hex(8)}" }
  let(:workspace) { Agentic::Workspace.new(workspace_path) }

  let(:agent) do
    instance_double(Agentic::Agent)
  end

  let(:llm_response) do
    <<~JSON
      {
        "artifacts": [
          {
            "name": "user.rb",
            "type": "ruby_class",
            "content": "class User\\n  attr_accessor :name, :email\\nend",
            "references": []
          }
        ]
      }
    JSON
  end

  let(:multi_artifact_response) do
    <<~JSON
      {
        "artifacts": [
          {
            "name": "models/user.rb",
            "type": "ruby_class",
            "content": "class User\\n  attr_accessor :name\\nend",
            "references": []
          },
          {
            "name": "services/user_service.rb",
            "type": "ruby_class",
            "content": "require_relative '../models/user'\\n\\nclass UserService\\nend",
            "references": ["models/user.rb"]
          }
        ]
      }
    JSON
  end

  after do
    FileUtils.rm_rf(workspace_path) if Dir.exist?(workspace_path)
  end

  describe "#initialize" do
    it "creates a generator with agent and workspace" do
      generator = described_class.new(agent, workspace)

      expect(generator.agent).to eq(agent)
      expect(generator.workspace).to eq(workspace)
    end

    it "accepts configuration options" do
      generator = described_class.new(agent, workspace, {
        verify_artifacts: false,
        default_constraints: {max_files: 5}
      })

      expect(generator.config[:verify_artifacts]).to be false
      expect(generator.config[:default_constraints]).to eq({max_files: 5})
    end

    it "has sensible defaults" do
      generator = described_class.new(agent, workspace)

      expect(generator.config[:verify_artifacts]).to be true
      expect(generator.config[:default_constraints]).to eq({})
    end
  end

  describe "#generate" do
    it "generates artifacts from task description" do
      allow(agent).to receive(:execute_with_workspace).and_return(llm_response)

      generator = described_class.new(agent, workspace)
      result = generator.generate("Create a Ruby User class")

      expect(result).to be_a(Agentic::ArtifactGenerationResult)
      expect(result.successful?).to be true
      expect(result.artifact_count).to eq(1)
      expect(result.artifacts.first.name).to eq("user.rb")
    end

    it "passes task description to agent" do
      expect(agent).to receive(:execute_with_workspace) do |prompt, ws|
        expect(prompt).to include("Create a User class with validation")
        expect(ws).to eq(workspace)
        llm_response
      end

      generator = described_class.new(agent, workspace)
      generator.generate("Create a User class with validation")
    end

    it "includes input context in task description" do
      expect(agent).to receive(:execute_with_workspace) do |prompt, _ws|
        expect(prompt).to include("Create a model")
        expect(prompt).to include("attributes")
        expect(prompt).to include("name")
        expect(prompt).to include("email")
        llm_response
      end

      generator = described_class.new(agent, workspace)
      generator.generate(
        "Create a model",
        input: {attributes: ["name", "email"]}
      )
    end

    it "merges constraints with default constraints" do
      allow(agent).to receive(:execute_with_workspace).and_return(llm_response)

      generator = described_class.new(agent, workspace, {
        default_constraints: {max_files: 10}
      })

      # The constraints should be passed to the capability
      # We can verify by checking the prompt includes the constraints
      result = generator.generate(
        "Create files",
        constraints: {allowed_types: [:ruby_class]}
      )

      expect(result.successful?).to be true
    end

    it "writes artifacts to workspace filesystem" do
      allow(agent).to receive(:execute_with_workspace).and_return(llm_response)

      generator = described_class.new(agent, workspace)
      result = generator.generate("Create a Ruby User class")

      expect(result.successful?).to be true

      # Verify file was written
      file_path = File.join(workspace_path, "user.rb")
      expect(File.exist?(file_path)).to be true
      expect(File.read(file_path)).to include("class User")
    end

    it "handles multiple artifacts with references" do
      allow(agent).to receive(:execute_with_workspace).and_return(multi_artifact_response)

      generator = described_class.new(agent, workspace)
      result = generator.generate("Create model and service")

      expect(result.successful?).to be true
      expect(result.artifact_count).to eq(2)

      artifact_names = result.artifacts.map(&:name)
      expect(artifact_names).to include("models/user.rb")
      expect(artifact_names).to include("services/user_service.rb")

      # Verify files were written
      expect(File.exist?(File.join(workspace_path, "models/user.rb"))).to be true
      expect(File.exist?(File.join(workspace_path, "services/user_service.rb"))).to be true
    end

    it "returns failure result on agent error" do
      allow(agent).to receive(:execute_with_workspace)
        .and_raise(StandardError.new("LLM service unavailable"))

      generator = described_class.new(agent, workspace)
      result = generator.generate("Create a class")

      expect(result.successful?).to be false
      expect(result.errors).to include("LLM service unavailable")
      expect(result.metadata[:exception_class]).to eq("StandardError")
    end

    it "returns failure result on invalid JSON response" do
      allow(agent).to receive(:execute_with_workspace).and_return("not valid json")

      generator = described_class.new(agent, workspace)
      result = generator.generate("Create a class")

      expect(result.successful?).to be false
      expect(result.errors.first).to include("JSON")
    end

    it "includes workspace in result" do
      allow(agent).to receive(:execute_with_workspace).and_return(llm_response)

      generator = described_class.new(agent, workspace)
      result = generator.generate("Create a class")

      expect(result.workspace).to eq(workspace)
      expect(result.workspace_id).to eq(workspace.id)
      expect(result.workspace_path).to eq(workspace.path)
    end

    context "when a tool pauses the chat for a person (agentic#101)" do
      let(:pause) do
        Agentic::Errors::ToolInputRequiredError.new(
          [{"id" => "call_1", "kind" => "approval", "message" => "Allow approval_demo to run?"}],
          chat_state: {"messages" => []}
        )
      end

      it "lets the pause through instead of reporting a failed generation" do
        allow(agent).to receive(:execute_with_workspace).and_raise(pause)

        generator = described_class.new(agent, workspace)

        expect { generator.generate("Write a note") }
          .to raise_error(Agentic::Errors::ToolInputRequiredError)
      end

      it "hands tool_resume to the agent and keeps it out of the prompt" do
        resume = {"answers" => {"call_1" => "yes"}, "chat_state" => {"messages" => []}}
        expect(agent).to receive(:execute_with_workspace)
          .with(satisfy { |prompt| !prompt.include?("chat_state") && prompt.include?("topic") }, workspace, tool_resume: resume)
          .and_return(llm_response)

        generator = described_class.new(agent, workspace)
        result = generator.generate("Write a note", input: {topic: "owls", tool_resume: resume})

        expect(result).to be_successful
      end

      it "calls the agent without tool_resume on a fresh turn" do
        expect(agent).to receive(:execute_with_workspace).with(kind_of(String), workspace).and_return(llm_response)

        described_class.new(agent, workspace).generate("Write a note")
      end
    end
  end

  describe "#generate_with_context" do
    it "includes existing artifacts in generation context" do
      # First add an existing artifact
      existing_artifact = Agentic::Artifact.new(
        name: "base.rb",
        type: :ruby_class,
        content: "class Base; end"
      )
      workspace.add_artifact(existing_artifact, verify: false)

      expect(agent).to receive(:execute_with_workspace) do |prompt, _ws|
        expect(prompt).to include("existing_artifacts")
        expect(prompt).to include("base.rb")
        llm_response
      end

      generator = described_class.new(agent, workspace)
      generator.generate_with_context("Create a subclass")
    end
  end
end
