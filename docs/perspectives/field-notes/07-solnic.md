# Field notes — Piotr Solnica (solnic)

*Build: make the declared capability contracts real, with the dry-rb
dependency the gem already had.*

## What I did

- Added `CapabilityValidator`: it takes a `CapabilitySpecification` and
  compiles the declared `inputs:`/`outputs:` hashes into actual
  `Dry::Schema` definitions, memoized per capability. Declared types are
  enforced, required keys are required, unknown keys stay permitted (a
  capability may accept more than it declares — the contract is a floor,
  not a ceiling).
- Added `Agentic::Errors::ValidationError` carrying `capability`, `kind`
  (`:inputs`/`:outputs`), and a `violations` hash with **every** problem,
  not just the first. Boundary errors should let you fix a payload in one
  round trip, not one message at a time.
- `CapabilityProvider#execute` now delegates to the validator; the two
  40-line hand-rolled type-checking case statements (one for inputs, one
  for outputs, near-identical twins) are gone.

## The thing I have to say out loud

`dry-schema` was in the gemspec. It was `require`d at the top of
`structured_outputs.rb`. And it was used **zero** times in the entire
codebase — while forty lines away, someone hand-rolled the exact
first-match, string-raising type checker that dry-schema exists to replace.
You invited dry-rb to the party and left it standing at the door. I have
now handed it a drink.

## What I found while doing it

- The old validator had reasonable instincts (skip undeclared keys, check
  both string and symbol keys) but reported only the *first* failure, as a
  `RuntimeError` with no structure — so a caller couldn't distinguish "you
  sent bad inputs" from "the capability broke" without parsing prose.
- There was **no spec file for `CapabilityProvider` at all**. The contract
  enforcement — the thing standing between an LLM's creative output and
  your capability implementations — was untested. It has one now, including
  the case I care most about: an implementation that violates its *own*
  output contract gets caught too. Contracts point both ways.
- The `type?: Numeric` predicate is doing honest work: the LLM-adjacent
  world is full of `"3"` where `3` was meant, and coercing silently
  (`Dry::Schema.Params`) would have hidden exactly the class of bug this
  layer exists to expose. I chose the strict schema deliberately.

## What I'd do next

- `AgentSpecification`, `TaskDefinition`, `ExpectedAnswerFormat` are still
  hand-written structs with `to_h`/`from_hash` pairs. They work; they'd be
  a third the code as `Dry::Struct`. But that's taste plus a dependency
  decision, not a defect, so it stays a suggestion.
- The planner's LLM responses flow into `Task.new(agent_spec: <raw hash>)`.
  The boundary between "JSON some model emitted" and "typed value object"
  is precisely where dry-validation contracts earn their keep. One
  `PlanContract` would let the CLI reject a malformed plan file with named
  errors instead of a NoMethodError three layers deep.
