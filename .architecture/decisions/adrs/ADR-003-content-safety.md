# ADR-003: Content Safety Filtering Approach

## Status

Draft

## Context

The architectural review of version 0.2.0 identified that the Agentic gem currently lacks protection against harmful or inappropriate content being generated or requested. As AI agents can potentially generate or be prompted with unsafe content, this poses several risks:

1. Safety risks from generating harmful instructions or content
2. Reputational risks for users of the library
3. Potential violations of API provider terms of service
4. Lack of controls to prevent misuse
5. Inconsistent handling of unsafe content across the system

As AI capabilities continue to advance, content safety becomes increasingly important for any production AI system.

## Decision Drivers

* Safety: Prevent generation of harmful content and instructions
* Compliance: Ensure compliance with API provider policies
* Configurability: Allow users to adapt filtering to their specific needs
* Performance: Minimize impact on system performance
* Transparency: Make filtering decisions transparent to users
* Consistency: Apply safety measures consistently across the system

## Decision

Implement a comprehensive content safety filtering system with:

1. Input filtering before sending to LLMs
2. Output filtering after receiving LLM responses
3. Configurable filtering levels and rules
4. Transparent logging of filtering decisions
5. Override mechanisms for trusted contexts

**Architectural Components Affected:**
* LlmClient (modified to apply filtering)
* ContentSafetyFilter (new component)
* Agent (modified to apply filtering to instructions)
* Configuration (extended to include safety settings)

**Interface Changes:**
* New ContentSafetyFilter class with methods for:
  - Checking input safety
  - Checking output safety
  - Configuring filtering rules
  - Logging filtering decisions
* Configuration extensions for safety settings

## Consequences

### Positive

* Reduced risk of generating or processing harmful content
* Better compliance with API provider policies
* More control for users over content safety
* Consistent handling of content safety across the system
* Transparent safety decisions with appropriate logging

### Negative

* Additional processing overhead for all LLM interactions
* Potential for false positives blocking legitimate content
* Complexity of handling edge cases in content filtering
* Need for regular updates to filtering rules as threats evolve

### Neutral

* Shift in responsibility for content safety to the library
* Need for documentation about safety capabilities and limitations
* Potential need for domain-specific customizations

## Implementation

**Phase 1: Basic Filtering**
* Create ContentSafetyFilter class with basic pattern-based filtering
* Integrate with LlmClient for input and output filtering
* Add configuration options for enabling/disabling filtering
* Implement logging for filtering decisions

**Phase 2: Enhanced Filtering**
* Add support for different filtering levels (minimal, standard, strict)
* Implement domain-specific filtering rules
* Create override mechanisms for trusted contexts
* Add detection for more subtle safety issues

**Phase 3: Advanced Capabilities**
* Implement embeddings-based filtering for semantic safety issues
* Add support for custom filtering rules
* Create tools for analyzing and improving filtering accuracy
* Implement content sanitization (as opposed to just blocking)

## Alternatives Considered

### Alternative 1: Rely on API provider safety measures

**Pros:**
* Less development effort
* No performance overhead in our library
* Leverage specialized expertise of API providers

**Cons:**
* Inconsistent handling across different providers
* Limited control over filtering behavior
* No protection for inputs before they reach API providers
* Potential compliance gaps with some providers

### Alternative 2: Third-party content moderation service

**Pros:**
* Leverage specialized moderation expertise
* Regular updates to detection capabilities
* Potentially higher accuracy than internal solution

**Cons:**
* External dependency for critical functionality
* Additional latency from API calls
* Potential cost implications
* Privacy concerns with sending data to third parties

### Alternative 3: Client-side responsibility only

**Pros:**
* Simplicity in library implementation
* No performance overhead within the library
* Maximum flexibility for library users

**Cons:**
* Inconsistent safety measures across implementations
* Higher burden on library users
* No protection by default
* Potential reputation risks if misused

## Validation

**Acceptance Criteria:**
- [ ] Content filtering can detect common categories of unsafe content
- [ ] False positive rate is below acceptable threshold (target: <5%)
- [ ] Performance impact is acceptable (target: <50ms per interaction)
- [ ] Filtering can be configured at different levels
- [ ] Override mechanisms work correctly for trusted contexts
- [ ] Filtering decisions are properly logged

**Testing Approach:**
* Unit tests with various input patterns including edge cases
* Performance benchmarks for filtering overhead
* Integration tests with LlmClient
* Validation with synthetic (safe) examples of problematic patterns
* User testing of configuration options

## References

* [Architectural Review 0.2.0](../../../.architecture/reviews/0-2-0.md)
* [Implementation Roadmap](../../../.architecture/recalibration/implementation_roadmap_0-2-0.md)
* [OpenAI Moderation API](https://platform.openai.com/docs/guides/moderation)
* [AI content safety best practices](https://www.responsible.ai/resources/content-safety)