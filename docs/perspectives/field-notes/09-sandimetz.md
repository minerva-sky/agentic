# Field notes — Sandi Metz

*Build: make the messages honest — `execute_with_schema`, factory
inheritance, and errors with names.*

## What I did

1. **`Agent#execute_with_schema` now does what its name promises.** The old
   method checked for a `text_generation` capability first and, finding one,
   executed the prompt *and silently discarded the schema you passed it*.
   The caller asked for structured output and received free text with no
   indication anything was ignored — and `Task#perform` routes through this
   method whenever a task declares an output schema, so plans were quietly
   losing their structure guarantees. Now the LLM client (which can honor
   the schema) is preferred; a capability-only agent raises
   `SchemaNotSupportedError` that says exactly what to do instead. A method
   that can't keep its promise should decline the message, not fake it.

2. **`FactoryMethods` survives inheritance.** The DSL stored
   `configurable :role, ...` in class-level ivars set only on the including
   class. Subclass `Agent` and your subclass's `build` finds `nil` where its
   attributes should be — the parent's interface silently vanished. An
   `inherited` hook now copies the sets down, and a subclass's additions stay
   its own. If you offer a class as an extension point, subclassing it is a
   message you've promised to answer.

3. **Errors got names.** `raise "Capability not found: #{name}"` became
   `CapabilityNotFoundError` (which knows its capability), plus
   `SchemaNotSupportedError`, `AgentNotConfiguredError`, and LLM failures
   now raise the `Errors::LlmError` the codebase already owned but wasn't
   using here. `rescue => e; e.message.include?("not found")` is a stringly
   dependency on prose; a named class is a dependency on a promise.

4. Fixed `Agent.from_h` — the third occurrence of the
   `Agent.new do ... end` ignored-block bug this session (after the CLI and
   the integration specs). Three call sites independently guessed wrong
   about the same constructor.

## The design observation that matters

That ignored-block bug repeating three times is the interesting finding.
When one caller misuses your API, it's their bug; when three do, it's your
interface. `Agent.new` accepting-and-ignoring a block *looks exactly like*
`Agent.build`, and Ruby won't warn. The deep fix isn't in any of the call
sites — it's making the wrong usage impossible or loud. If I kept going I'd
either have `initialize` yield (make `new` and `build` agree) or make
`new` private API. I limited myself to the visible defects; changing the
constructor contract deserves its own conversation.

## A Zeitwerk footnote (Xavier was right)

My first draft put the new error classes as siblings in one
`errors/agent_error.rb`. Instant lesson: Zeitwerk loads a file when its
*namesake* is referenced, so `SchemaNotSupportedError` was a NameError until
`AgentError` happened to load first — and the pre-existing `llm_error.rb`
had been playing this same load-order lottery with eight sibling classes
all along. All errors now live in one `errors.rb` behind the `Errors`
namespace constant, so referencing any of them loads all of them.
Conventions aren't decoration; they're load-bearing.
