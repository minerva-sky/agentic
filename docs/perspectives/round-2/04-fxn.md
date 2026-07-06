# Round 2 field notes — Xavier Noria builds the Namespace Cartographer

*Built: `examples/namespace_cartographer.rb` — one orchestrator task per
file, Prism reading actual definitions, producing a map of a gem's
constant tree and auditing every file against the constant its path
promises.*

## What I built and why

A cartographer, because the loader conventions are a *projection* between
two spaces — file paths and constant paths — and any projection deserves
a map. Point it at a `lib/` directory and it fans one survey task per
file through the `PlanOrchestrator`; each survey parses the file with
Prism and records every module, class, and constant it defines. Then the
map is compared with the territory: 63 files, and the verdict for this
gem after round one's cleanup is the sentence I hoped to print:

> Every file defines the constant its path promises. The map IS the
> territory.

## The best moment: my map was wrong first

The first run reported one deviation: `agentic/version.rb`, "expected
`Agentic::Version`, defines `Agentic`". I nearly filed it as a finding —
then remembered whose rule this is. `Zeitwerk::Loader.for_gem` uses
`GemInflector`, which **special-cases the gem's `version.rb` to expect
`VERSION`**, precisely so the classic `Foo::VERSION` constant conforms.
My cartographer's inflector didn't know the special case, so the
deviation was in the *map*, not the territory. I taught the map the rule
and the deviation disappeared.

I want to underline this because it is the whole discipline in
miniature: a conformance tool is itself a model of the convention, and a
model can be wrong in exactly the ways it accuses others of. Verify the
verifier. (It took `const_source_location` and a read of Zeitwerk's
`cref.rb` to be sure which side was mistaken.)

## Building-with-it observations

- The fan-out was the right shape for a survey: files are independent,
  order is irrelevant, and the orchestrator's result object gave me
  status and timing for free. 110ms for 63 files.
- Same adapter tax my colleagues reported: an `Expedition` provider
  struct and a path smuggled through `task.description`. I now believe
  this is the framework's single most instructive piece of user
  feedback: four builders, four identical workarounds, one missing
  affordance — tasks need a payload and the orchestrator should accept
  agents (or callables) directly.
- Capability declarations (`inputs: {path: ...}` → `outputs: {defined:
  ...}`) made the survey's contract explicit, and solnic's validator
  enforced it while I iterated. Typed seams between stages are worth
  their ceremony when a stage is being rewritten — which, see above, it
  was.

## Verdict

The gem is a competent expedition outfitter: it carried Prism up the
mountain and back without complaint. And the exercise produced a
sentence every Zeitwerk user should frame: the map is not the territory
— except when your naming conventions hold, and then, wonderfully, it is.
