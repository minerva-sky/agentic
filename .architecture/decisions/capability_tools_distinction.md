# Capability and Tools Distinction

## Overview

This document clarifies the distinction between "capabilities" and "tools" in the Agentic framework. While both concepts relate to agent functionality, they serve different purposes and have different characteristics.

## Capabilities

Capabilities represent rich, composable components that provide significant functionality to agents. They are formal, versioned interfaces with well-defined inputs and outputs.

### Key Characteristics

1. **Rich Interface Definition**
   - Formal specification of inputs and outputs
   - Type definitions and validation
   - Required vs. optional parameters

2. **Semantic Versioning**
   - Major.Minor.Patch versioning scheme
   - Backward compatibility guarantees
   - Version constraints for dependencies

3. **Dependency Management**
   - Explicit declaration of dependencies
   - Version constraints for dependencies
   - Automatic resolution of dependency graphs

4. **Composition Support**
   - Capabilities can be composed from other capabilities
   - Higher-order capabilities encapsulate multiple capabilities
   - Composition strategies for complex capability combinations

5. **Provider Implementation**
   - Separation of interface (specification) from implementation
   - Multiple providers can implement the same capability
   - Providers can be swapped without affecting consumers

6. **Performance Tracking**
   - Execution metrics collection
   - Success/failure tracking
   - Performance optimization based on historical data

### Example

```ruby
# Define a capability specification
text_gen_capability = Agentic::CapabilitySpecification.new(
  name: "text_generation",
  description: "Generates text based on a prompt",
  version: "1.0.0",
  inputs: {
    prompt: { type: "string", required: true, description: "The prompt to generate text from" },
    max_tokens: { type: "integer", default: 100, description: "Maximum tokens to generate" }
  },
  outputs: {
    response: { type: "string", description: "The generated text" }
  }
)

# Create a provider for the capability
text_gen_provider = Agentic::CapabilityProvider.new(
  capability: text_gen_capability,
  implementation: ->(inputs) { { response: "Generated text for: #{inputs[:prompt]}" } }
)

# Register with the system
registry.register(text_gen_capability, text_gen_provider)
```

## Tools

Tools are simpler function-like utilities that agents can use for specific, focused tasks. They provide a lightweight mechanism for extending agent functionality without the formality of capabilities.

### Key Characteristics

1. **Simple Interface**
   - Function-like calling convention
   - Minimal parameter validation
   - Limited formal documentation

2. **No Versioning**
   - Single implementation at a time
   - No formal backward compatibility guarantees
   - No dependency management

3. **Direct Implementation**
   - No separation between interface and implementation
   - Direct execution without provider indirection
   - Typically implemented as lambda functions or simple methods

4. **Limited Composition**
   - No formal composition support
   - Manual composition through function calls
   - No dependency resolution

5. **Minimal Tracking**
   - Basic usage logging only
   - No formal performance metrics
   - Limited optimization opportunities

### Example

```ruby
# Define a simple tool
agent.add_tool("calculate_sum") do |numbers|
  numbers.sum
end

# Use the tool
result = agent.use_tool("calculate_sum", [1, 2, 3, 4, 5])
# => 15
```

## When to Use Each

### Use Capabilities When:

- The functionality is complex and reusable across multiple agent types
- Formal versioning and backward compatibility are important
- The functionality has dependencies on other capabilities
- Performance tracking and optimization are needed
- Multiple implementations might be required
- The functionality will evolve over time

### Use Tools When:

- The functionality is simple and focused
- Formal versioning isn't necessary
- The tool has no dependencies on other components
- Quick implementation is more important than formality
- The tool is specific to a particular agent or use case
- Performance tracking isn't critical

## Compatibility Layer

For backward compatibility, the framework provides a compatibility layer that allows tools to be used as capabilities and vice versa:

```ruby
# Convert a tool to a capability
capability = registry.tool_to_capability("calculate_sum", agent.tools["calculate_sum"])

# Convert a capability to a tool
agent.add_tool_from_capability("text_generation", registry.get("text_generation"))
```

## Future Direction

The framework is gradually moving toward a capability-centric approach, as capabilities provide richer functionality, better composition, and improved maintainability. However, tools will continue to be supported for simpler use cases and backward compatibility.

Over time, we expect more functionality to migrate from tools to capabilities, especially as the agent assembly system evolves to leverage capability-based composition more effectively.