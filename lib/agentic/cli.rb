# frozen_string_literal: true

require "thor"
require "json"
require "yaml"

module Agentic
  # Command Line Interface for Agentic
  class CLI < Thor
    class_option :verbose, type: :boolean, aliases: "-v", desc: "Enable verbose output"
    class_option :quiet, type: :boolean, aliases: "-q", desc: "Suppress output"
    class_option :config, type: :string, aliases: "-c", desc: "Specify config file"

    def self.exit_on_failure?
      true
    end

    # Global logging configuration based on options
    def initialize(*args)
      super
      configure_logging
    end

    desc "version", "Display version information"
    def version
      version_box = UI.box(
        "Agentic",
        [
          "Version: #{UI.colorize(Agentic::VERSION, :green)}",
          "Ruby: #{UI.colorize(RUBY_VERSION, :blue)}",
          "Platform: #{UI.colorize(RUBY_PLATFORM, :yellow)}"
        ].join("\n"),
        padding: [1, 2, 1, 2],
        style: {border: {fg: :blue}}
      )
      puts version_box
    end

    desc "plan GOAL", "Create an execution plan for a goal"
    long_desc <<-LONGDESC
      Creates an execution plan for the given goal using the TaskPlanner.
      
      Example:
        $ agentic plan "Generate a market research report on AI trends"
        
      You can also save the plan to a file:
        $ agentic plan "Generate a market research report" --save plan.json
    LONGDESC
    option :output, type: :string, aliases: "-o",
      enum: %w[json yaml text], default: "text",
      desc: "Output format (json, yaml, or text)"
    option :save, type: :string, aliases: "-s",
      desc: "Save plan to a file"
    option :model, type: :string, aliases: "-m",
      desc: "LLM model to use (defaults to configuration)"
    def plan(goal)
      check_api_token!

      say UI.colorize("Creating plan for goal: #{goal}", :green) unless options[:quiet]

      # Configure the LLM
      config = LlmConfig.new
      config.model = options[:model] if options[:model]

      # Create and run the task planner with spinner
      execution_plan = UI.with_spinner("Planning tasks for goal", quiet: options[:quiet]) do
        planner = TaskPlanner.new(goal, config)
        planner.plan
      end

      # Output the plan based on format option
      output_plan(execution_plan, options)
    end

    desc "execute", "Execute a plan"
    long_desc <<-LONGDESC
      Executes a plan created by the 'plan' command.
      
      You can provide a plan file:
        $ agentic execute --plan plan.json
        
      Or pipe in a plan:
        $ cat plan.json | agentic execute --from-stdin
    LONGDESC
    option :plan, type: :string, aliases: "-p",
      desc: "Path to a plan file"
    option :from_stdin, type: :boolean,
      desc: "Read plan from stdin"
    option :async, type: :boolean, default: true,
      desc: "Execute tasks asynchronously"
    option :max_concurrency, type: :numeric, default: 10,
      desc: "Maximum concurrent tasks"
    def execute
      check_api_token!

      # Load the plan
      plan_data = load_plan_data

      unless plan_data
        raise Thor::Error, "No plan provided. Use --plan FILE or --from-stdin"
      end

      say UI.colorize("Executing plan...", :green) unless options[:quiet]

      # Initialize task instances from the plan
      tasks = initialize_tasks(plan_data)

      # Create an execution observer for real-time feedback
      observer = ExecutionObserver.new(options)

      # Setup the PlanOrchestrator with the observer's lifecycle hooks
      orchestrator = PlanOrchestrator.new(
        concurrency_limit: options[:max_concurrency],
        lifecycle_hooks: observer.lifecycle_hooks
      )

      # Add tasks to the orchestrator
      tasks.each do |task|
        orchestrator.add_task(task)
      end

      # Show the total number of tasks
      unless options[:quiet]
        puts UI.colorize("Total tasks: #{tasks.size}", :blue)
        puts
      end

      # Execute the plan
      result = orchestrator.execute_plan(DefaultAgentProvider.new)

      # Output the result
      output_result(result, options)
    end

    # Agent commands
    class AgentCommands < Thor
      desc "list", "List available agents"
      def list
        puts UI.box(
          "Available Agents",
          "No custom agents registered yet.\n\n" \
          "You can create a new agent with:\n" \
          "  #{UI.colorize("agentic agent create NAME --role=ROLE --instructions=INSTRUCTIONS", :blue)}",
          padding: [1, 2, 1, 2],
          style: {border: {fg: :blue}}
        )
      end

      desc "create NAME", "Create a new agent"
      option :role, type: :string, required: true, desc: "Role of the agent"
      option :instructions, type: :string, required: true, desc: "Instructions for the agent"
      def create(name)
        role = options[:role]
        instructions = options[:instructions]

        # Create spinner for agent creation
        UI.with_spinner("Creating agent: #{name}") do
          # In a future implementation, this would create and register an agent
          sleep(0.5) # Simulate some work
        end

        # Show success message with agent details
        details = [
          "Name: #{UI.colorize(name, :blue)}",
          "Role: #{UI.colorize(role, :magenta)}",
          "Instructions: #{instructions}"
        ].join("\n")

        puts UI.box(
          "Agent Created",
          details,
          padding: [1, 2, 1, 2],
          style: {border: {fg: :green}}
        )
      end

      desc "delete NAME", "Delete an agent"
      def delete(name)
        # Create spinner for agent deletion
        UI.with_spinner("Deleting agent: #{name}") do
          # In a future implementation, this would delete an agent from a registry
          sleep(0.5) # Simulate some work
        end

        puts UI.box(
          "Agent Deleted",
          "Agent #{UI.colorize(name, :blue)} has been deleted successfully.",
          padding: [1, 2, 1, 2],
          style: {border: {fg: :yellow}}
        )
      end
    end

    desc "agent", "Manage agents"
    subcommand "agent", AgentCommands

    # Configuration commands
    class ConfigCommands < Thor
      desc "list", "List configuration settings"
      CONFIG_FILE_NAME = ".agentic.yml"
      USER_CONFIG_PATH = File.join(Dir.home, CONFIG_FILE_NAME)
      PROJECT_CONFIG_PATH = File.join(Dir.pwd, CONFIG_FILE_NAME)

      desc "list", "List configuration settings"
      def list
        user_config = load_config(USER_CONFIG_PATH)
        project_config = load_config(PROJECT_CONFIG_PATH)

        # Format user config
        user_config_str = "User configuration (#{USER_CONFIG_PATH}):\n"
        user_config_str += format_config(user_config)

        # Format project config
        project_config_str = "Project configuration (#{PROJECT_CONFIG_PATH}):\n"
        project_config_str += format_config(project_config)

        # Format active config
        active_config_str = "Active configuration:\n"
        active_config_str += format_config(active_config)

        # Format environment variables
        env_vars_str = "Environment variables:\n"
        token_status = ENV["OPENAI_ACCESS_TOKEN"] ?
                      UI.colorize("[SET]", :green) :
                      UI.colorize("[NOT SET]", :red)
        env_vars_str += "  OPENAI_ACCESS_TOKEN: #{token_status}"

        # Display in a box
        config_info = [
          user_config_str,
          "",
          project_config_str,
          "",
          active_config_str,
          "",
          env_vars_str
        ].join("\n")

        puts UI.box("Configuration", config_info, padding: [1, 2, 1, 2], style: {border: {fg: :blue}})
      end

      desc "get KEY", "Get a configuration setting"
      def get(key)
        config = active_config
        value = config[key]

        if value
          value_str = case value
          when true then UI.colorize("true", :green)
          when false then UI.colorize("false", :red)
          when String then "\"#{value}\""
          else value.to_s
          end

          puts UI.box(
            "Configuration Value",
            "#{UI.colorize(key, :blue)}: #{value_str}",
            padding: [1, 2, 1, 2],
            style: {border: {fg: :green}}
          )
        else
          puts UI.box(
            "Error",
            "Key '#{UI.colorize(key, :yellow)}' not found in configuration",
            padding: [1, 2, 1, 2],
            style: {border: {fg: :red}}
          )
          exit 1
        end
      end

      desc "set KEY=VALUE", "Set a configuration setting"
      option :global, type: :boolean, aliases: "-g",
        desc: "Set in global user config instead of project config"
      def set(key_value)
        key, value = key_value.split("=", 2)

        unless value
          puts "Error: Invalid format. Use KEY=VALUE"
          exit 1
        end

        path = options[:global] ? USER_CONFIG_PATH : PROJECT_CONFIG_PATH
        config = load_config(path) || {}

        # Convert string values to appropriate types
        value = case value.downcase
        when "true" then true
        when "false" then false
        when /^\d+$/ then value.to_i
        when /^\d+\.\d+$/ then value.to_f
        else value
        end

        config[key] = value
        save_config(path, config)

        puts UI.box(
          "Configuration Updated",
          "Set #{UI.colorize(key, :blue)} to #{UI.colorize(value.to_s, :green)} in #{path}",
          padding: [1, 2, 1, 2],
          style: {border: {fg: :green}}
        )
      end

      desc "init", "Initialize configuration"
      option :global, type: :boolean, aliases: "-g",
        desc: "Initialize global user config instead of project config"
      def init
        path = options[:global] ? USER_CONFIG_PATH : PROJECT_CONFIG_PATH

        if File.exist?(path)
          puts UI.box(
            "Configuration Exists",
            "Configuration already exists at #{UI.colorize(path, :blue)}",
            padding: [1, 2, 1, 2],
            style: {border: {fg: :yellow}}
          )
          return
        end

        config = {
          "model" => "gpt-4o-mini",
          "log_level" => "info"
          # Add other default configuration options here
        }

        save_config(path, config)

        # Format the config for display
        config_str = format_config(config)

        puts UI.box(
          "Configuration Initialized",
          "Created configuration at #{UI.colorize(path, :blue)}\n\n#{config_str}",
          padding: [1, 2, 1, 2],
          style: {border: {fg: :green}}
        )
      end

      private

      def load_config(path)
        return unless File.exist?(path)

        begin
          YAML.load_file(path)
        rescue => e
          puts "Error loading configuration from #{path}: #{e.message}"
          nil
        end
      end

      def save_config(path, config)
        # Create directory if it doesn't exist
        dir = File.dirname(path)
        FileUtils.mkdir_p(dir) unless File.directory?(dir)

        File.write(path, YAML.dump(config))
      end

      def active_config
        # Combine user and project configs, with project taking precedence
        user_config = load_config(USER_CONFIG_PATH) || {}
        project_config = load_config(PROJECT_CONFIG_PATH) || {}

        user_config.merge(project_config)
      end

      def format_config(config)
        if config.nil? || config.empty?
          "  #{UI.colorize("[empty]", :yellow)}\n"
        else
          config.map do |key, value|
            value_str = case value
            when true then UI.colorize("true", :green)
            when false then UI.colorize("false", :red)
            when String then "\"#{value}\""
            else value.to_s
            end

            "  #{UI.colorize(key, :blue)}: #{value_str}"
          end.join("\n") + "\n"
        end
      end
    end

    desc "config", "Configure Agentic settings"
    subcommand "config", ConfigCommands

    private

    # Configures logging based on command options
    def configure_logging
      if options[:verbose]
        Agentic.logger.level = :debug
        Agentic.logger.formatter = proc do |severity, datetime, progname, msg|
          color = case severity
          when "DEBUG" then :blue
          when "INFO" then :green
          when "WARN" then :yellow
          when "ERROR" then :red
          when "FATAL" then :red
          else :white
          end

          timestamp = UI.colorize(datetime.strftime("%Y-%m-%d %H:%M:%S"), :dim)
          severity_colored = UI.colorize(severity.ljust(5), color)

          "[#{timestamp}] #{severity_colored} : #{msg}\n"
        end
      elsif options[:quiet]
        Agentic.logger.level = :warn
      else
        Agentic.logger.level = :info
      end
    end

    # Checks for API token and raises error if not configured
    def check_api_token!
      unless Agentic.configuration.access_token
        error_box = UI.box(
          "Configuration Error",
          "No OpenAI API token configured.\n\n" \
          "You can set it using one of these methods:\n" \
          "- Environment variable: OPENAI_ACCESS_TOKEN\n" \
          "- Configuration file: .agentic.yml\n" \
          "- Run: agentic config set api_token=your_token",
          style: {border: {fg: :red}},
          padding: [1, 2, 1, 2]
        )

        raise Thor::Error, error_box
      end
    end

    # Outputs plan based on format options
    def output_plan(execution_plan, options)
      output = case options[:output]
      when "json"
        JSON.pretty_generate(execution_plan.to_h)
      when "yaml"
        YAML.dump(execution_plan.to_h)
      else # text
        format_plan(execution_plan)
      end

      if options[:save]
        File.write(options[:save], output)
        say UI.colorize("Plan saved to #{options[:save]}", :green) unless options[:quiet]
      else
        puts output unless options[:quiet]
      end
    end

    # Formats a plan for display
    # @param execution_plan [ExecutionPlan] The execution plan
    # @return [String] The formatted plan
    def format_plan(execution_plan)
      tasks_text = "Tasks:\n"
      execution_plan.tasks.each_with_index do |task, index|
        tasks_text += "  #{UI.colorize((index + 1).to_s, :blue)} #{task.description}\n"
        tasks_text += "    Agent: #{UI.colorize(task.agent.name, :magenta)}\n"
      end

      expected_answer_text = "Expected Answer:\n"
      expected_answer_text += "  Format: #{UI.colorize(execution_plan.expected_answer.format, :yellow)}\n"
      expected_answer_text += "  Sections: #{execution_plan.expected_answer.sections.map { |s| UI.colorize(s, :yellow) }.join(", ")}\n"
      expected_answer_text += "  Length: #{UI.colorize(execution_plan.expected_answer.length, :yellow)}\n"

      plan_text = "#{tasks_text}\n#{expected_answer_text}"

      UI.box(
        "Execution Plan",
        plan_text,
        padding: [1, 2, 1, 2],
        style: {border: {fg: :blue}}
      )
    end

    # Loads plan data from file or stdin based on options
    def load_plan_data
      if options[:plan]
        JSON.parse(File.read(options[:plan]))
      elsif options[:from_stdin]
        JSON.parse($stdin.read)
      end
    end

    # Initializes task instances from plan data
    def initialize_tasks(plan_data)
      tasks = []

      plan_data["tasks"].each do |task_data|
        task = Task.new(
          description: task_data["description"],
          agent_spec: task_data["agent"],
          input: task_data["input"] || {}
        )
        tasks << task
      end

      tasks
    end

    # Outputs execution result based on format options
    def output_result(result, options)
      output = case options[:output]
      when "json"
        JSON.pretty_generate(result.to_h)
      when "yaml"
        YAML.dump(result.to_h)
      else # text
        format_execution_result(result)
      end

      puts output unless options[:quiet]
    end

    # Formats execution result as text
    def format_execution_result(result)
      status_text = UI.status_text(result.status.to_s, result.status)
      execution_time = UI.format_duration(result.execution_time)

      output = "Execution Result:\n"
      output += "Status: #{status_text}\n"
      output += "Execution Time: #{execution_time}\n\n"

      output += "Tasks:\n"
      result.tasks.each do |task_id, task_data|
        task_result = result.task_result(task_id)
        status = task_result ? task_result.status : :pending

        status_indicator = UI.task_status_indicator(status)
        description = task_data[:description]

        output += "  #{status_indicator} #{description}\n"
      end

      # Create a box for the result
      UI.box(
        "Execution Summary",
        output,
        padding: [1, 2, 1, 2],
        style: {border: {fg: result.successful? ? :green : :yellow}}
      )
    end
  end
end
