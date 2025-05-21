# Agentic

A Ruby gem for building and running AI agents in a [plan-and-execute](https://blog.langchain.dev/planning-agents/#plan-and-execute) fashion. Agentic provides a simple command-line tool and library to build, manage, deploy, and run purpose-driven AI agents using OpenAI's LLM API.

## Installation

Install the gem and add to the application's Gemfile by executing:

```bash
$ bundle add agentic
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
$ gem install agentic
```

## Usage

### Command-Line Interface

Agentic comes with a command-line interface for easy interaction:

```bash
# Display version information
$ agentic version

# Initialize configuration
$ agentic config init

# Set your OpenAI API token
$ agentic config set api_token=your_openai_api_key

# Create a plan for a goal
$ agentic plan "Generate a market research report on AI trends"

# Save the plan to a file
$ agentic plan "Write a blog post about Ruby" --save plan.json

# Execute a plan
$ agentic execute --plan plan.json

# List available agents
$ agentic agent list
```

### Programmatic API

To use Agentic in your Ruby code:

#### Basic Usage

```ruby
require 'agentic'

# Configure your OpenAI API key
Agentic.configure do |config|
  config.access_token = 'your_openai_api_key'
end

# Create a TaskPlanner instance with a goal
planner = Agentic::TaskPlanner.new("Write a blog post about Ruby on Rails")

# Generate the plan
plan = planner.plan

# Display the plan
puts plan.to_s

# Or access the structured data
plan.tasks.each do |task|
  puts "Task: #{task.description}"
  puts "Agent: #{task.agent.name}"
end
```

#### Working with Agents

```ruby
# Create an agent with specific configuration
agent = Agentic::Agent.build do |a|
  a.name = "ResearchAgent"
  a.role = "Research Assistant"
  a.instructions = "Conduct thorough research on the given topic"
end

# Configure the LLM
config = Agentic::LlmConfig.new(
  model: "gpt-4o-mini",
  temperature: 0.7
)

# Create a task
task = Agentic::Task.new(
  description: "Research the latest trends in Ruby on Rails",
  agent_spec: {
    "name" => "ResearchAgent",
    "description" => "An agent that performs research",
    "instructions" => "Research the given topic thoroughly"
  }
)

# Execute the task with the agent
result = task.perform(agent)

# Check the result
if result.successful?
  puts "Task completed successfully!"
  puts result.output
else
  puts "Task failed: #{result.failure.message}"
end
```

#### Plan Orchestration

```ruby
# Create an orchestrator
orchestrator = Agentic::PlanOrchestrator.new(
  concurrency_limit: 5,
  continue_on_failure: true
)

# Add tasks to the orchestrator
tasks.each do |task|
  orchestrator.add_task(task)
end

# Create an agent provider
agent_provider = Agentic::DefaultAgentProvider.new

# Execute the plan
result = orchestrator.execute_plan(agent_provider)

# Process the results
if result.successful?
  puts "Plan executed successfully!"
else
  puts "Plan execution had issues: #{result.status}"
  result.results.each do |task_id, task_result|
    if task_result.failed?
      puts "Task #{task_id} failed: #{task_result.failure.message}"
    end
  end
end
```

## Extension System

Agentic includes a powerful Extension System to help integrate with external systems and customize the framework's behavior. The Extension System consists of three main components:

### Domain Adapters

Domain Adapters let you customize Agentic's behavior for specific domains like healthcare, finance, or legal:

```ruby
# Create a domain adapter for healthcare
adapter = Agentic::Extension.domain_adapter("healthcare")

# Add domain-specific knowledge
adapter.add_knowledge(:terminology, {
  terms: ["patient", "diagnosis", "treatment"],
  specialty: "cardiology"
})

# Create a custom prompt adapter
prompt_adapter = ->(prompt, context) {
  specialty = context[:domain_knowledge][:terminology][:specialty]
  "#{prompt} [Adapted for #{context[:domain]} #{specialty}]"
}

# Register the adapter
adapter.register_adapter(:prompt, prompt_adapter)

# Apply adaptation to a prompt
adapted_prompt = adapter.adapt(:prompt, "Describe the symptoms")
# => "Describe the symptoms [Adapted for healthcare cardiology]"
```

### Protocol Handlers

Protocol Handlers standardize connections to external systems and APIs:

```ruby
# Get the protocol handler
handler = Agentic::Extension.protocol_handler(
  default_headers: { "User-Agent" => "AgenticApp/1.0" }
)

# Create and register a protocol implementation
http_protocol = Object.new
def http_protocol.send_request(endpoint, options)
  # Implement HTTP request logic
  { status: 200, body: "Response data" }
end

# Register the protocol
handler.register_protocol(:http, http_protocol, { timeout: 30 })

# Send a request
response = handler.send_request(:http, "/api/data", {
  method: "GET",
  headers: { "Accept" => "application/json" }
})
```

### Plugin Manager

The Plugin Manager handles third-party extensions and their lifecycle:

```ruby
# Get the plugin manager
manager = Agentic::Extension.plugin_manager

# Register a plugin
plugin = MyPlugin.new
manager.register("my_plugin", plugin, { version: "1.0.0" })

# Get and use a plugin
if plugin = manager.get("my_plugin")
  result = plugin.call(arg1, arg2)
end

# Disable a plugin
manager.disable("my_plugin")
```

## Configuration

### Setting up the OpenAI API Key

You can configure the OpenAI API key in several ways:

1. Environment variable:
   ```bash
   export OPENAI_ACCESS_TOKEN="your_api_key"
   ```

2. Configuration file:
   Create `.agentic.yml` in your project directory or home directory:
   ```yaml
   api_token: "your_api_key"
   model: "gpt-4o-mini"
   ```

3. In your Ruby code:
   ```ruby
   Agentic.configure do |config|
     config.access_token = "your_api_key"
   end
   ```

### LLM Configuration

You can customize the LLM behavior:

```ruby
config = Agentic::LlmConfig.new(
  model: "gpt-4o-mini",
  max_tokens: 500,
  temperature: 0.7,
  top_p: 1.0,
  frequency_penalty: 0,
  presence_penalty: 0
)

# Use in TaskPlanner
planner = Agentic::TaskPlanner.new("Write a blog post", config)

# Or with LlmClient directly
client = Agentic::LlmClient.new(config)
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/codenamev/agentic. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/codenamev/agentic/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Agentic project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/codenamev/agentic/blob/main/CODE_OF_CONDUCT.md).