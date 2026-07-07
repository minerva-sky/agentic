# Round 12 field notes — Justin Searls checks the fakes' references

*Built: `examples/honest_doubles.rb` — an owned port at the LLM
boundary, plus a verifier that rejects any double whose methods or
arity have drifted from the port. One double is honest; one has been
lying since last quarter.*

## What I built and why

Every agent test suite on earth contains a fake LLM, and I promise
you at least one of them is lying. Not maliciously — *entropically*.
Somebody wrote a stub against the client's interface in March, the
interface grew a keyword in June, and the stub has been vouching for
code that would crash on its first production call ever since. Green
suite. Broken app. The two rules that prevent this cost almost
nothing:

**Rule 1: don't mock what you don't own.** Stubbing
`Agentic::LlmClient` couples every test to a vendor interface that
changes at gem-update speed. Instead, define *your* port —
`CompletionPort#complete(prompt, max_tokens:)` — one class that
names the entire vendor surface you permit yourself to use. (The
census two stalls over says the smaller that surface, the better;
we agree from different directions.)

**Rule 2: verify every double against the port.** The verifier is
twenty lines: methods must exist, and *parameter shapes must match*
— required, optional, keyword, by name:

```
honest double:  verified - method AND arity match
drifted double: REJECTED before any test ran -
  port takes [[:req, :prompt], [:keyreq, :max_tokens]],
  double takes [[:req, :prompt]]
```

## The treachery of unverified fakes

Look at what the drifted double would have done *without* the
verifier: passed. Every test. `complete` responds, strings come
back, assertions green. Unverified fakes don't fail — **they
vouch**, and a false character witness is worse than no witness,
because it converts your test suite from an early-warning system
into a lullaby. The verifier moves the failure to load time, which
is the cheapest possible place: the drift is announced before a
single test runs, with both parameter lists printed so the fix
writes itself.

This is, of course, what verified doubles in RSpec and Mocktail's
signature checks do — the point of hand-rolling it in forty lines is
to show there's no magic, just `Method#parameters` and the
discipline to call it. The mechanism is cheap; the *habit* is the
technology.

## Notes

- The port declines to be clever: no dynamic dispatch, no
  method_missing forwarding. Boundary classes should be so boring
  that drift has nowhere to hide.
- What this deliberately doesn't verify: return *values*. Arity
  honesty is checkable statically; semantic honesty needs the
  round-8 eval scorers pointed at the real adapter in a nightly
  contract test. Both layers, different cadences.

## Verdict

Your tests are only as honest as their most casual fake. Own the
boundary with one port, make every double show its papers at load
time, and interface drift becomes a loud ArgumentError instead of a
quiet quarter of false confidence.
