# Round 4 field notes — Matz unfolds the exquisite corpse

*Built: `examples/exquisite_corpse.rb` — three artists draw a creature's
parts without peeking; the assembler reads them by name and unfolds the
paper.*

## What I built and why

The surrealists' parlor game is secretly a concurrency diagram: three
independent workers, no shared knowledge, one fan-in reveal. Last round
the reveal would have read `t.dependency_outputs.values` and prayed
about ordering; this round the assembler says what it means:

```ruby
orchestrator.add_task(reveal, needs: artists, agent: ->(t) {
  t.needs.head + t.needs.torso + t.needs.legs
})
```

`needs: artists` — my artists hash *is already* the declaration. And in
the agent, `t.needs.head` reads like the sentence "the reveal needs the
head." When the declaration and the consumption share a vocabulary,
there is no translation step for a bug to live in.

## Small delights

- Seeded randomness makes every creature reproducible: seed 7 gives the
  cat-headed armored thing with acrobat legs; a bug report about a
  malformed monster comes with its seed attached. (Jeremy has fully
  converted me on this.)
- `previous_output` — my other round-3 wish — I didn't even need here,
  and that is its own lesson: the two conveniences serve different
  sentence shapes. Chains say "answer what came before"; gatherings say
  "bring me the head." A good API has grammar for both and forces
  neither.

## One more wish, smaller than the last

`needs: artists` worked because my hash happened to map names to tasks.
Lovely. But `t.needs.head + t.needs.torso + t.needs.legs` still spells
the stacking order by hand — `t.needs.to_h.values` loses the order I
declared. If `NamedOutputs#to_h` preserved *declaration* order (it
does, Ruby hashes are ordered — but nothing promises it), the assembler
could be `t.needs.to_h.values.flatten`. Promise the order in the
documentation; ordered hashes are one of Ruby's quiet gifts, and
promises are what make gifts usable.

## Verdict

Round 3's asks became round 4's grammar. The game took twenty minutes,
most of it spent drawing ASCII torsos — which is to say the framework
has reached the correct level of invisibility: the hard part of the
program was the art.
