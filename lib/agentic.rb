# frozen_string_literal: true

require "zeitwerk"

# Zeitwerk is the single code loader for this gem: every constant under
# Agentic:: is autoloaded on first reference, including the CLI, so
# library consumers never pay for Thor or the tty-* UI stack at require
# time. Files must not require_relative their siblings - reference the
# constant and let the loader resolve it.
loader = Zeitwerk::Loader.for_gem

# Configure Zeitwerk to handle the CLI class name properly
loader.inflector.inflect(
  "cli" => "CLI",
  "ui" => "UI"
)

# The CLI is only autoloaded on demand (exe/agentic), never eager loaded
loader.do_not_eager_load("#{__dir__}/agentic/cli")

loader.setup

module Agentic
  class Error < StandardError; end

  class << self
    attr_accessor :logger
  end

  self.logger ||= Logger.new($stdout, level: :debug)

  class Configuration
    attr_accessor :access_token, :agent_store_path, :api_base_url

    def initialize
      @access_token = ENV["OPENAI_ACCESS_TOKEN"] || ENV["AGENTIC_API_TOKEN"] || "ollama"
      @agent_store_path = ENV["AGENTIC_AGENT_STORE_PATH"] || File.join(Dir.home, ".agentic", "agents")
      @api_base_url = ENV["AGENTIC_API_BASE_URL"] || ENV["OPENAI_BASE_URL"]
    end
  end

  class << self
    attr_writer :configuration
    attr_reader :agent_capability_registry, :agent_assembly_engine, :agent_store
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end

  def self.client(config)
    LlmClient.new(config)
  end

  # Plan and execute a goal in one call - the 80% path
  #
  # @example
  #   result = Agentic.run("Summarize this week's support tickets")
  #   puts result.results.values.map(&:output) if result.successful?
  #
  # @param goal [String] What you want done, in plain language
  # @param model [String, nil] Optional LLM model override
  # @param concurrency [Integer] Maximum number of tasks to run at once
  # @return [PlanExecutionResult] The structured execution results
  def self.run(goal, model: nil, concurrency: 5)
    config = LlmConfig.new
    config.model = model if model

    plan = TaskPlanner.new(goal, config).plan

    orchestrator = PlanOrchestrator.new(concurrency_limit: concurrency)
    plan.tasks.each do |task_def|
      orchestrator.add_task(
        Task.new(
          description: task_def.description,
          agent_spec: task_def.agent,
          input: {}
        )
      )
    end

    orchestrator.execute_plan(DefaultAgentProvider.new(config))
  end

  # Initialize the core agent self-assembly components
  def self.initialize_agent_assembly
    # Create registry, store, and assembly engine if not already initialized
    unless @agent_capability_registry
      @agent_capability_registry = AgentCapabilityRegistry.instance
      @agent_store = PersistentAgentStore.new(configuration.agent_store_path, @agent_capability_registry)
      @agent_assembly_engine = AgentAssemblyEngine.new(@agent_capability_registry, @agent_store)

      # Register standard capabilities
      Capabilities.register_standard_capabilities

      logger.info("Initialized agent assembly system")
    end
  end

  # Register a capability with the system
  # @param capability [CapabilitySpecification] The capability to register
  # @param provider [CapabilityProvider] The provider for the capability
  # @return [CapabilitySpecification] The registered capability
  def self.register_capability(capability, provider)
    initialize_agent_assembly
    agent_capability_registry.register(capability, provider)
  end

  # Assemble an agent for a task
  # @param task [Task] The task to assemble an agent for
  # @param strategy [AgentCompositionStrategy, nil] The strategy to use
  # @param store [Boolean] Whether to use the agent store
  # @param use_llm [Boolean] Whether to use LLM-assisted strategy if no strategy provided
  # @return [Agent] The assembled agent
  def self.assemble_agent(task, strategy: nil, store: true, use_llm: false)
    initialize_agent_assembly

    # Use LLM-assisted strategy if requested and no strategy provided
    if use_llm && strategy.nil?
      strategy = LlmAssistedCompositionStrategy.new
    end

    agent_assembly_engine.assemble_agent(task, strategy: strategy, store: store)
  end

  # Create an LLM-assisted composition strategy
  # @param llm_config [LlmConfig, nil] The LLM config to use
  # @return [LlmAssistedCompositionStrategy] The strategy
  def self.llm_assisted_strategy(llm_config = nil)
    LlmAssistedCompositionStrategy.new(llm_config)
  end
end
