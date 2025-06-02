## [0.2.0] - 2025-05-29

### Added
- Agent Self-Assembly System for dynamic agent construction
  - AgentCapabilityRegistry for managing capability specifications and providers
  - PersistentAgentStore for saving and retrieving agent configurations
  - AgentAssemblyEngine for analyzing tasks and assembling appropriate agents
  - CapabilityOptimizer for improving capability implementations
  - LLM-assisted capability selection strategy
- Capability System with rich specification and versioning
  - Clear distinction between capabilities and tools
  - Semantic versioning for capability evolution
  - Capability composition for building complex capabilities
  - Dependency management for capabilities
- CLI commands for capability and agent management
  - Listing and filtering capabilities
  - Viewing capability details
  - Searching for capabilities
  - Agent creation and management
- Example capabilities for common tasks
- Integration with learning system for capability optimization
- Comprehensive integration tests for agent assembly workflow
- Documentation for capability API and agent self-assembly
- Comprehensive CLI implementation with subcommands for plan, execute, agent, and config
- Real-time feedback with progress bars, spinners, and colorized output
- Per-user and per-project configuration support
- Enhanced LLM error and refusal handling with categorization
- First-class configuration objects for LLM, retry handling, and orchestration
- Value objects for task definitions, agent specifications, and execution results
- Expanded test coverage for core components

### Improved
- Test coverage across all major features
- Documentation for integration testing
- Stability in edge cases like timeouts and partial failures
- Metrics collection for learning system analysis
- Agent reusability through persistent storage
- Decoupled data from presentation throughout the codebase
- Improved error handling with specific error types and recovery strategies
- Enhanced documentation with CLI examples and API snippets

## [0.1.0] - 2024-06-27

### Added
- Comprehensive CLI implementation with subcommands for plan, execute, agent, and config
- Real-time feedback with progress bars, spinners, and colorized output
- Per-user and per-project configuration support
- Enhanced LLM error and refusal handling with categorization
- First-class configuration objects for LLM, retry handling, and orchestration
- Value objects for task definitions, agent specifications, and execution results
- Expanded test coverage for core components

### Changed
- Decoupled data from presentation throughout the codebase
- Improved error handling with specific error types and recovery strategies
- Enhanced documentation with CLI examples and API snippets

## [0.1.0] - 2024-06-27

- Initial release