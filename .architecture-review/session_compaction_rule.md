# Session Compaction Rule

## Purpose
Store session history summaries in a structured format to maintain an accessible record of design decisions, implementation activities, and architectural evolution across the project.

## Rules

1. **Directory Structure**
   - All session summaries are stored in the `.claude-sessions/` directory
   - Directory is created if it doesn't exist

2. **Naming Convention**
   - Files follow the format: `NNN-descriptive-session-name.md`
   - Where NNN is a sequential number (e.g., 001, 002)
   - The descriptive name should concisely capture the session's main focus

3. **Content Structure**
   - Each file includes:
     - Primary request and intent
     - Key technical concepts
     - Files and code sections impacted
     - Problem-solving approach
     - Pending tasks and next steps

4. **When to Compact**
   - After completing significant architectural or implementation work
   - When switching to a new major feature or component
   - Periodically during long sessions to maintain continuity

5. **Process**
   - Generate a comprehensive summary of the conversation
   - Save to a new file in the `.claude-sessions/` directory
   - Ensure all key decisions and implementation details are captured

## Integration with Architecture Documentation

Session compaction summaries should cross-reference with other architectural documents to maintain a coherent history of the project's evolution. Key architectural decisions identified during sessions should be properly documented in:

- Architecture Decision Records (ADRs) in the `.architecture-review/` directory
- Updates to `ArchitectureConsiderations.md` for high-level changes
- Component-specific documentation files

This ensures that the project maintains both a record of what was done (session summaries) and the rationale behind architectural decisions (formal documentation).