# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"
require "timecop"

RSpec.describe "Agent Assembly Integration" do
  let(:temp_dir) { Dir.mktmpdir("agentic_integration_test") }
  let(:registry) { Agentic::AgentCapabilityRegistry.instance }
  let(:agent_store) { Agentic::PersistentAgentStore.new(temp_dir, registry) }
  let(:assembly_engine) { Agentic::AgentAssemblyEngine.new(registry, agent_store) }

  # Test capabilities
  let(:text_gen_capability) do
    Agentic::CapabilitySpecification.new(
      name: "text_generation",
      description: "Generates text based on a prompt",
      version: "1.0.0",
      inputs: {
        prompt: {type: "string", required: true, description: "The prompt to generate text from"}
      },
      outputs: {
        response: {type: "string", description: "The generated text"}
      }
    )
  end

  let(:text_gen_provider) do
    Agentic::CapabilityProvider.new(
      capability: text_gen_capability,
      implementation: ->(inputs) { {response: "Generated text for: #{inputs[:prompt]}"} }
    )
  end

  let(:data_analysis_capability) do
    Agentic::CapabilitySpecification.new(
      name: "data_analysis",
      description: "Analyzes data and extracts insights",
      version: "1.0.0",
      inputs: {
        data: {type: "object", required: true, description: "The data to analyze"},
        analysis_type: {type: "string", description: "The type of analysis to perform"}
      },
      outputs: {
        insights: {type: "array", description: "The extracted insights"},
        summary: {type: "string", description: "A summary of the analysis"}
      },
      dependencies: [
        {name: "text_generation", version: "1.0.0"}
      ]
    )
  end

  let(:data_analysis_provider) do
    Agentic::CapabilityProvider.new(
      capability: data_analysis_capability,
      implementation: ->(inputs) {
        data = inputs[:data]
        type = inputs[:analysis_type] || "basic"

        insights = ["Found #{data.keys.size} keys in the data"]
        insights << "Analysis type: #{type}"

        {
          insights: insights,
          summary: "Analysis complete. Found #{data.keys.size} keys in the data using #{type} analysis."
        }
      }
    )
  end

  before do
    # Reset the registry before each test
    registry.clear

    # Register test capabilities
    registry.register(text_gen_capability, text_gen_provider)
    registry.register(data_analysis_capability, data_analysis_provider)

    # Make Agentic use our test components
    allow(Agentic).to receive(:agent_capability_registry).and_return(registry)
    allow(Agentic).to receive(:agent_store).and_return(agent_store)
    allow(Agentic).to receive(:agent_assembly_engine).and_return(assembly_engine)
    allow(Agentic).to receive(:initialize_agent_assembly).and_return(nil)
  end

  after do
    # Clean up temp directory
    FileUtils.remove_entry(temp_dir)

    # Reset timecop
    Timecop.return
  end

  describe "end-to-end workflow" do
    it "registers capabilities, assembles an agent, and executes capabilities" do
      # 1. Check that capabilities are registered
      expect(registry.list.keys).to include("text_generation", "data_analysis")

      # 2. Create a task
      task = Agentic::Task.new(
        description: "Analyze data and generate a summary report",
        agent_spec: Agentic::AgentSpecification.new(
          name: "Data Analyst",
          description: "An agent that analyzes data",
          instructions: "Analyze the provided data and generate insights"
        ),
        input: {
          data: {"sales" => 100, "revenue" => 5000, "customers" => 20},
          analysis_type: "financial"
        }
      )

      # 3. Assemble an agent for the task
      agent = assembly_engine.assemble_agent(task)

      # 4. Verify that the agent has the required capabilities
      expect(agent).to be_a(Agentic::Agent)
      expect(agent.role).to eq("Data Analyst")
      expect(agent.has_capability?("data_analysis")).to be true
      expect(agent.has_capability?("text_generation")).to be true

      # 5. Execute the data_analysis capability
      result = agent.execute_capability("data_analysis", {
        data: {"sales" => 100, "revenue" => 5000, "customers" => 20},
        analysis_type: "financial"
      })

      # 6. Verify the result
      expect(result).to be_a(Hash)
      expect(result[:insights]).to be_an(Array)
      expect(result[:summary]).to include("financial")

      # 7. Store the agent
      id = agent_store.store(agent, name: "data_analyst")

      # 8. Retrieve the agent from storage
      stored_agent = agent_store.build_agent(id)

      # 9. Verify the retrieved agent
      expect(stored_agent).to be_a(Agentic::Agent)
      expect(stored_agent.role).to eq(agent.role)
      expect(stored_agent.has_capability?("data_analysis")).to be true

      # 10. Execute a capability on the retrieved agent
      stored_result = stored_agent.execute_capability("text_generation", {
        prompt: "Summarize the analysis"
      })

      # 11. Verify the result from the stored agent
      expect(stored_result).to be_a(Hash)
      expect(stored_result[:response]).to include("Summarize the analysis")
    end

    it "finds a stored agent for similar tasks" do
      # 1. Create and store an agent with data_analysis capability
      original_agent = Agentic::Agent.build do |a|
        a.role = "Data Analyst"
        a.purpose = "Analyze financial data"
        a.backstory = "I am a data analysis expert"
      end
      original_agent.add_capability("data_analysis")

      # Store the agent with relevant metadata
      agent_store.store(original_agent, name: "financial_analyst", metadata: {
        task_description: "Analyze financial data and generate insights"
      })

      # 2. Create a similar task
      task = Agentic::Task.new(
        description: "Analyze financial data and generate insights",
        agent_spec: Agentic::AgentSpecification.new(
          name: "Analyst",
          description: "Financial data analysis",
          instructions: "Analyze the provided financial data"
        ),
        input: {
          data: {"profit" => 1000, "loss" => 200},
          analysis_type: "financial"
        }
      )

      # 3. Assemble an agent for the task
      agent = assembly_engine.assemble_agent(task)

      # 4. Verify that the engine found and reused the stored agent
      expect(agent.role).to eq("Data Analyst")
      expect(agent.purpose).to eq("Analyze financial data")
      expect(agent.has_capability?("data_analysis")).to be true
    end

    it "composes capabilities into a new capability" do
      # 1. Compose text_generation and data_analysis into a new capability
      composed_capability = registry.compose(
        "comprehensive_analysis",
        "Performs analysis and generates a formatted report",
        "1.0.0",
        [
          {name: "data_analysis", version: "1.0.0"},
          {name: "text_generation", version: "1.0.0"}
        ],
        ->(providers, inputs) {
          # First provider is data_analysis, second is text_generation
          analysis_result = providers[0].execute({
            data: inputs[:data],
            analysis_type: inputs[:analysis_type]
          })

          # Use the analysis result to generate a report
          report_prompt = "Create a report for: #{analysis_result[:summary]}"
          report = providers[1].execute({prompt: report_prompt})[:response]

          {
            analysis: analysis_result,
            report: report
          }
        }
      )

      # 2. Verify that the composed capability is registered
      expect(registry.get("comprehensive_analysis")).to eq(composed_capability)

      # 3. Create an agent with the composed capability
      agent = Agentic::Agent.build do |a|
        a.role = "Report Generator"
        a.purpose = "Generate comprehensive reports"
      end
      agent.add_capability("comprehensive_analysis")

      # 4. Execute the composed capability
      result = agent.execute_capability("comprehensive_analysis", {
        data: {"metric1" => 100, "metric2" => 200},
        analysis_type: "detailed"
      })

      # 5. Verify the result
      expect(result).to be_a(Hash)
      expect(result[:analysis]).to be_a(Hash)
      expect(result[:analysis][:insights]).to be_an(Array)
      expect(result[:report]).to be_a(String)
      expect(result[:report]).to include("Create a report for")
    end
  end

  describe "using the Agentic module API" do
    it "provides convenient methods for working with capabilities and agents" do
      # 1. Register a capability through the Agentic module
      expect {
        Agentic.register_capability(
          Agentic::CapabilitySpecification.new(
            name: "web_search",
            description: "Searches the web",
            version: "1.0.0",
            inputs: {query: {type: "string", required: true}},
            outputs: {results: {type: "array"}}
          ),
          Agentic::CapabilityProvider.new(
            capability: Agentic::CapabilitySpecification.new(
              name: "web_search",
              description: "Searches the web",
              version: "1.0.0"
            ),
            implementation: ->(inputs) { {results: ["Result for: #{inputs[:query]}"]} }
          )
        )
      }.not_to raise_error

      # 2. Create a task
      task = Agentic::Task.new(
        description: "Search the web for information about AI",
        agent_spec: Agentic::AgentSpecification.new(
          name: "Researcher",
          description: "Web researcher",
          instructions: "Research topics on the web"
        ),
        input: {query: "artificial intelligence"}
      )

      # 3. Assemble an agent through the Agentic module
      agent = Agentic.assemble_agent(task)

      # 4. Verify that the agent has the required capabilities
      expect(agent).to be_a(Agentic::Agent)
      expect(agent.has_capability?("web_search")).to be true
    end
  end
end
