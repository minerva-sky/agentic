# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Agentic is a Ruby gem for building and running AI agents in a plan-and-execute fashion. It provides a simple command-line tool and library to build, manage, deploy, and run purpose-driven AI agents, using OpenAI's LLM API.

## Key Commands

### Setup and Installation

```bash
# Install dependencies
bin/setup

# Install the gem locally
bundle exec rake install
```

### Testing and Linting

```bash
# Run the test suite
rake spec

# Run a specific test file
rspec spec/path/to/file_spec.rb

# Run a specific test
rspec spec/path/to/file_spec.rb:LINE_NUMBER

# Run linting (StandardRB)
rake standard

# Run both tests and linting (default task)
rake
```

### Release

```bash
# Release a new version (after updating version.rb)
bundle exec rake release
```

## Architecture

Agentic follows a modular architecture with these key components:

1. **TaskPlanner**: Core component that breaks down goals into actionable tasks using an LLM. It:
   - Takes a high-level goal as input
   - Uses the LLM to analyze and decompose the goal into tasks
   - Determines the expected output format
   - Provides a plan for execution

2. **Agent**: Base class for creating purpose-driven AI agents:
   - Configurable with role, purpose, backstory, and tools
   - Uses the factory pattern for flexible creation
   - Executes tasks in the plan

3. **LlmClient**: Wrapper for OpenAI API interactions:
   - Handles communication with the OpenAI API
   - Manages structured output formatting
   - Processes responses

4. **StructuredOutputs**: Utilities for defining JSON schemas:
   - Enables structured LLM outputs
   - Provides schema validation
   - Supports various data types and nested structures

5. **FactoryMethods**: Implements a builder pattern:
   - Provides a DSL for configuring agents
   - Manages configurable attributes
   - Handles assembly instructions

## Code Flow

The typical workflow in this codebase is:

1. Create a TaskPlanner with a specific goal
2. Generate a plan with tasks and expected output format
3. Execute the plan using appropriate agents
4. Each agent processes its assigned task and produces outputs

Key configuration and initialization flow:
- The main Agentic module provides configuration options
- LlmConfig sets up the model parameters
- OpenAI API key is configured through environment variables or in code

## Development Guidelines

You are an experienced Ruby on Rails developer, very accurate for details. The
last 10 years you've spent managing open source Ruby gems and architecting
object oriented solutions.

You must keep your answers very short, concise, simple and informative.

1. Use the project's .rubocop.yml for formatting of all Ruby code.
2. Use YARD comments for properly documenting all generated Ruby code.
3. **Testing with VCR**: The project uses VCR to record and replay HTTP interactions for tests. When adding new API interactions, ensure that they are properly recorded in cassettes.
4. **Structured Outputs**: When working with LLM responses, use the StructuredOutputs module to define schemas and validate responses.
5. **Factory Pattern**: Follow the established factory pattern when extending or creating new agents.
6. **API Key Handling**: Never hardcode API keys. Use the configuration system or environment variables.
7. **Ruby Style**: The project follows StandardRB conventions. Ensure your code passes `rake standard`.
8. **Documentation**: Document new classes and methods using YARD-style comments.
9. When planning, imagine you are a Software Architect thinking about how to solve a solution abstractly in an object-oriented way; and keep track of cohesive and concise notes in their own .md file(s).
10. **Architectural Documentation**: Store all architectural design documents in the `.architecture-review` directory, keeping implementation details separate from high-level design.
11. **Implementation Strategy**: 
    - Implement features in small, concise, and minimally implemented commitable chunks
    - Follow each implementation with a refactor-in-place
    - Ensure each commit is intentional and focused on a single purpose
    - Consider next steps and maintain forward-thinking design
12. **Architecture References**: Always reference `ArchitectureConsiderations.md` when making architectural decisions and update it when design changes occur.
13. **Architectural Evolution**:
    - Apply rigor and scrutiny to all architectural modifications
    - Consider additions as augmenting rather than replacing existing elements
    - Preserve original architectural vision while extending with new insights
    - Carefully weigh trade-offs of each architectural decision
    - Document rationale for changes in the appropriate architecture review document
    - Maintain backward compatibility with existing architectural principles
    - Distinguish between implementation details and architectural principles
