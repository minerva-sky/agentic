# Agent Capabilities API

This document provides an overview of the Agent Capabilities API in Agentic, which enables the creation, registration, and management of agent capabilities.

## Core Components

The capability system consists of these key components:

1. **CapabilitySpecification**: Defines the interface of a capability
2. **CapabilityProvider**: Implements the functionality of a capability
3. **AgentCapabilityRegistry**: Central registry for discovering and managing capabilities
4. **AgentAssemblyEngine**: Dynamically assembles agents with appropriate capabilities
5. **PersistentAgentStore**: Stores and retrieves agent configurations

## Using the Capability API

### Registering a Capability

```ruby
# Define a capability specification
text_gen_capability = Agentic::CapabilitySpecification.new(
  name: "text_generation",
  description: "Generates text based on a prompt",
  version: "1.0.0",
  inputs: {
    prompt: { type: "string", required: true, description: "The prompt to generate text from" }
  },
  outputs: {
    response: { type: "string", description: "The generated text" }
  }
)

# Create a provider for the capability
text_gen_provider = Agentic::CapabilityProvider.new(
  capability: text_gen_capability,
  implementation: ->(inputs) { 
    # Implementation logic here
    { response: "Generated text for: #{inputs[:prompt]}" }
  }
)

# Register the capability with the system
Agentic.register_capability(text_gen_capability, text_gen_provider)
```

### Adding a Capability to an Agent

```ruby
# Create an agent
agent = Agentic::Agent.new do |a|
  a.role = "Assistant"
  a.purpose = "Help users with their questions"
  a.backstory = "I am an AI assistant designed to be helpful and informative."
end

# Add a capability to the agent
agent.add_capability("text_generation")
```

### Executing a Capability

```ruby
# Execute a capability on an agent
result = agent.execute_capability("text_generation", { prompt: "Tell me about AI" })
puts result[:response]
```

### Creating an Agent with the Assembly Engine

```ruby
# Define a task
task = Agentic::Task.new(
  description: "Generate some text and search the web for information",
  agent_spec: Agentic::AgentSpecification.new(
    name: "Research Agent",
    description: "An agent for research tasks",
    instructions: "Perform research and generate text based on findings"
  ),
  input: {
    query: "AI trends in 2023"
  }
)

# Assemble an agent for the task
agent = Agentic.assemble_agent(task)
```

### Storing and Retrieving Agents

```ruby
# Store an agent for future use
agent_id = Agentic.agent_store.store(agent, name: "research_agent")

# Later, retrieve the agent
stored_agent = Agentic.agent_store.build_agent("research_agent")

# Or retrieve by ID
stored_agent = Agentic.agent_store.build_agent(agent_id)
```

## API Reference

### CapabilitySpecification

A capability specification defines the interface of a capability, including inputs, outputs, and metadata.

#### Attributes

- `name`: String - The name of the capability
- `description`: String - A description of the capability
- `version`: String - The version of the capability (semantic versioning)
- `inputs`: Hash - The inputs required by the capability
- `outputs`: Hash - The outputs produced by the capability
- `dependencies`: Array - Other capabilities this one depends on

#### Key Methods

- `compatible_with?(other)`: Checks if this capability is compatible with another
- `to_h`: Converts the specification to a hash
- `from_h(hash)`: Creates a specification from a hash
- `requirements_description`: Gets a human-readable description of the requirements

### CapabilityProvider

A capability provider implements the functionality of a capability.

#### Attributes

- `capability`: CapabilitySpecification - The specification of the capability
- `implementation`: Proc or Class - The implementation of the capability

#### Key Methods

- `execute(inputs)`: Executes the capability with the given inputs
- `validate_inputs!(inputs)`: Validates inputs against the specification
- `validate_outputs!(outputs)`: Validates outputs against the specification

### AgentCapabilityRegistry

The registry manages capability specifications and providers.

#### Key Methods

- `register(capability, provider)`: Registers a capability and provider
- `get(name, version)`: Gets a capability by name and version
- `get_provider(name, version)`: Gets a provider by name and version
- `list(include_providers)`: Lists all registered capabilities
- `find(criteria)`: Finds capabilities matching criteria
- `compose(name, description, version, capabilities, compose_fn)`: Composes multiple capabilities into a new one

### AgentAssemblyEngine

The assembly engine dynamically builds agents with appropriate capabilities.

#### Key Methods

- `assemble_agent(task, strategy, store)`: Assembles an agent for a task
- `analyze_requirements(task)`: Analyzes a task to determine capability requirements
- `select_capabilities(requirements, strategy)`: Selects capabilities based on requirements
- `build_agent(task, capabilities)`: Builds an agent with selected capabilities

### PersistentAgentStore

The agent store manages persistence of agent configurations.

#### Key Methods

- `store(agent, name, metadata)`: Stores an agent configuration
- `build_agent(id_or_name, version)`: Builds an agent from a stored configuration
- `all(filter)`: Lists all stored agent configurations
- `delete(id_or_name, version)`: Deletes an agent configuration
- `version_history(id)`: Gets the version history of an agent

## Command Line Interface

The Agentic CLI provides commands for managing capabilities and agents:

### Capability Commands

```bash
# List available capabilities
agentic capabilities list

# Show details of a specific capability
agentic capabilities show text_generation

# Search for capabilities
agentic capabilities search generation
```

### Agent Commands

```bash
# List available agents
agentic agent list

# Create a new agent
agentic agent create my_agent --role="Assistant" --purpose="Help users" --capabilities=text_generation,web_search

# Show details of a specific agent
agentic agent show my_agent

# Delete an agent
agentic agent delete my_agent

# Build an agent from storage
agentic agent build my_agent
```

## Advanced Usage

### Creating Composite Capabilities

```ruby
# Compose multiple capabilities into a new one
registry = Agentic.agent_capability_registry

registry.compose(
  "advanced_research",
  "Performs advanced research with text generation and web search",
  "1.0.0",
  [
    { name: "text_generation", version: "1.0.0" },
    { name: "web_search", version: "1.0.0" }
  ],
  ->(providers, inputs) {
    # Implementation that uses both capabilities
    search_results = providers[1].execute(query: inputs[:topic])[:results]
    text = providers[0].execute(prompt: "Write about #{inputs[:topic]} using this information: #{search_results.join(', ')}")[:response]
    { research_report: text, sources: search_results }
  }
)
```

### Custom Composition Strategies

```ruby
# Create a custom composition strategy
class MyCompositionStrategy < Agentic::AgentCompositionStrategy
  def select_capabilities(requirements, registry)
    # Custom logic to select capabilities
    # ...
  end
end

# Use the custom strategy
strategy = MyCompositionStrategy.new
agent = Agentic.assemble_agent(task, strategy: strategy)
```

## Best Practices

1. **Atomic Capabilities**: Design capabilities to be focused on a single responsibility
2. **Clear Interfaces**: Define clear input and output schemas for capabilities
3. **Semantic Versioning**: Use semantic versioning for capability versions
4. **Composition**: Compose simple capabilities into more complex ones
5. **Dependency Management**: Explicitly declare dependencies between capabilities
6. **Persistence**: Store assembled agents for reuse with similar tasks
7. **Validation**: Validate inputs and outputs against the capability specification