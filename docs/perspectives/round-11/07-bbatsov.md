# Round 11 field notes — Bozhidar Batsov puts cops on the contracts

*Built: `examples/contract_cop.rb` — seven named cops for capability
specs, an offense report, and autocorrection for everything with
exactly one right answer.*

## What I built and why

The community style guide exists because "we argue about this in
every review" is a bug with a known fix: decide once, name the
decision, automate the enforcement. Contracts in this framework are
now the most-read documents in the system — by my count six tools
consume them (validator, docs, schema export, fixtures, diff,
polite-form) plus every human integrator — and the most-read
document is exactly where style buys the most. So, cops:

```
Naming/SnakeCaseName            'QuoteShipping' is not snake_case
Naming/SnakeCaseFields          :weightKg is not snake_case
Documentation/Description       capability has no description
Style/EnumOrder                 :Mode enum is not sorted
Lint/UntypedField               :ref has no type (won't project)
Lint/OpaqueRuleWithoutMessage   rule :check1 will say nothing
Metrics/RequiredInputCount      7 required inputs - one capability
                                or three?
8 offenses; autocorrect fixes 4
```

Cop *names* matter as much as cop checks — `Lint/UntypedField` is a
sentence you can put in a commit message, a ticket, or a `.todo`
file. Anonymous complaints breed arguments; named ones breed
configuration.

## The autocorrect line

The split between corrected and remaining offenses is the design.
Autocorrect handles transformations with **exactly one right
answer**: snake_casing a name, sorting an enum. It refuses the rest,
each refusal with a reason: a description only the author can write;
a type that guessed wrong becomes a typed bug; a rule's message is
testimony you can't forge. RuboCop learned this boundary the hard
way — unsafe autocorrections cost more trust than they save
keystrokes, and a linter spends trust every time it speaks.

Note which cops are style and which are load-bearing:
`Lint/UntypedField` isn't aesthetic — since round 11, untyped fields
keep relations out of schema projections, so `:ref` having no type
*silently narrows what five other tools can do*. The best lint rules
are the ones where "style" turns out to be an interoperability
contract wearing casual clothes.

## Notes

- `Metrics/RequiredInputCount` is the contracts' flog: past five
  required inputs, the question isn't formatting, it's "is this one
  capability or three?" Metrics cops should ask questions, not
  issue verdicts — the number is the evidence, the design review is
  the trial.
- Every cop is a lambda over the spec *hash*, not the object — same
  data the diff and generator read. The whole linter is 40 lines
  because the declarations did the hard work years... rounds ago.

## Verdict

Contracts have a style guide with teeth: seven named cops, four
mechanical fixes applied without discussion, four judgment calls
made impossible to not-see. Style is applied empathy for the next
reader — and these documents have six readers, so the empathy
compounds.
