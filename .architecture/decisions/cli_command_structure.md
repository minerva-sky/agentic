# Architectural Decision Record: CLI Command Structure

## Context

The Agentic CLI currently has duplicate command definitions appearing in the help output. Commands related to agent management and configuration appear both as top-level commands and as subcommands. This is causing confusion for users trying to understand the proper command structure.

Investigation revealed that two implementations of the same functionality exist:
1. Nested classes within the main CLI class (`AgentCommands` and `ConfigCommands` in cli.rb) with enhanced UI
2. Standalone files in the cli/ directory (`agent.rb` and `config.rb`) with simpler implementations

Both implementations are being loaded and registered, resulting in duplicate commands in the help output.

## Decision

We will standardize on the nested class implementation and remove the standalone file implementations. This approach:

1. Provides enhanced UI with colorization and box output for a better user experience
2. Maintains a clear hierarchy of commands
3. Eliminates duplicate commands in the help output

We will:
1. Remove or disable the standalone CLI command files (agent.rb, config.rb)
2. Update requires in agentic.rb to reflect this change
3. Ensure proper Thor subcommand registration

## Rationale

The nested class implementation provides a superior user experience with colorized output and formatted boxes. While moving to standalone files might provide better modularity in the long term, the current priority is to fix the command duplication and maintain the enhanced UI.

## Consequences

### Positive
- Elimination of duplicate commands in CLI help output
- Consistent, enhanced UI for all commands
- Clear command hierarchy

### Negative
- The CLI implementation remains in a single file, which may be less modular
- Future changes to the CLI may require more coordination
- Long-term maintenance might be more challenging

### Neutral
- This approach prioritizes user experience over code modularity
- A future refactoring to a hybrid approach may still be desirable

## Future Considerations

In future versions, we may want to consider:
1. Refactoring to a hybrid approach that maintains the enhanced UI while improving modularity
2. Separating UI presentation from command logic
3. Creating a more comprehensive testing framework for CLI commands

## Implementation Notes

The implementation will:
1. Remove or comment out requires for standalone CLI files in agentic.rb
2. Ensure only nested class implementations are being registered
3. Test all CLI commands to ensure they work as expected
4. Update documentation to reflect the command structure

Date: May 22, 2024