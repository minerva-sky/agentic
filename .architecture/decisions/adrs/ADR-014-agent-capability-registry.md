# ADR-014: Agent Capability Registry

## Status

Accepted

## Context

As we develop the Agentic framework, we need a centralized system to manage, discover, and utilize agent capabilities. Capabilities are richer than simple tools, with versioning, dependencies, and composition possibilities. The system must support:

1. Registration of capabilities with semantic versioning
2. Discovery of capabilities based on name, version, or functionality
3. Composition of capabilities into higher-order capabilities
4. Runtime validation of capability inputs and outputs
5. Management of capability providers (implementations)

Previously, we had a more limited "tool" concept which lacked versioning, composition, and formal interface definitions. We need to evolve this concept while maintaining backward compatibility.

## Decision

We will implement an `AgentCapabilityRegistry` that serves as the central repository for all agent capabilities in the system. The registry will:

1. Be implemented as a singleton to provide global access
2. Maintain a collection of capability specifications and their providers
3. Support semantic versioning for capability evolution
4. Enable capability composition through dependency management
5. Provide a rich API for capability discovery and filtering

Key classes:

- `CapabilitySpecification`: Defines the interface for a capability
- `CapabilityProvider`: Implements a capability interface
- `AgentCapabilityRegistry`: Manages capability specifications and providers

The registry will provide these core operations:

```ruby
# Registration
registry.register(specification, provider)

# Discovery
registry.get(name, version = nil)
registry.list(filter = {})

# Provider access
registry.get_provider(name, version = nil)

# Composition
registry.compose(name, description, version, dependencies, implementation)
```

## Consequences

### Positive

1. Centralized management of capabilities improves discovery and reuse
2. Semantic versioning enables capability evolution while maintaining compatibility
3. Capability composition facilitates building complex capabilities from simpler ones
4. Formal interface definitions improve capability documentation and usage
5. Provider abstraction allows multiple implementations of the same capability

### Negative

1. Singleton pattern creates global state that may complicate testing
2. Centralized registry could become a performance bottleneck at scale
3. Version management adds complexity compared to simpler approaches
4. Requires migration from previous tool-based approach

### Neutral

1. Requires agents to adopt capability-aware execution model
2. Necessitates formal capability specification development

## Implementation Notes

The registry will be implemented as a singleton class with thread-safe operations. Capability specifications will include name, version, description, inputs, outputs, and dependencies. Providers will encapsulate the actual implementation logic.

The registry will maintain an index of capabilities by name and version, allowing efficient lookups. It will also support finding the latest version of a capability when no specific version is requested.

For backward compatibility, existing tools will be automatically wrapped as capabilities with appropriate adapters.