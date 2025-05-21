## [Unreleased]

### Added
- Learning System with ExecutionHistoryStore, PatternRecognizer, and StrategyOptimizer
- Execution history capturing and analysis for performance optimization
- Pattern recognition for identifying success/failure correlations
- Strategy optimization for prompts, parameters, and task sequences
- Performance reporting and optimization recommendations
- Automatic integration with PlanOrchestrator for execution tracking
- Extension System with Domain Adapters, Protocol Handlers, and Plugin Manager
- Domain adapters for customizing behavior in specific domains
- Protocol handlers for standardized external system communication
- Plugin infrastructure for third-party extensions and lifecycle management
- Plugin auto-discovery mechanism for seamless extension loading

## [0.2.0] - 2024-06-28

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