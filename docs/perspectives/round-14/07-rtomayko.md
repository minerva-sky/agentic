# Round 14 field notes — Ryan Tomayko spells it fork, pipe, kill, wait

*Built: `examples/unix_workers.rb` — a master preforks three plan
workers, work arrives on a shared pipe, SIGTERM means finish-then-
die-with-dignity, and every child is reaped by pid and exit status.
9/9 jobs served, 3/3/3.*

## What I built and why

I like Unix because the operating system already solved process
supervision, isolation, and work distribution — and nobody told the
frameworks. Every worker-pool gem is a reimplementation of fork(2)
with more YAML. So the example uses the originals:

```
UNIX WORKERS (master 12200, 3 preforked children)
deploy signal: SIGTERM to all workers
the reaping:
  pid 12204  exit 0  served 3 job(s)
  pid 12207  exit 0  served 3 job(s)
  pid 12210  exit 0  served 3 job(s)
total served: 9/9
```

Count what's *not* here: no supervisor gem, no heartbeat table, no
distributed lock. **fork** gives isolation — a worker segfault kills
one plan, not the fleet. **The shared pipe** is a work queue because
Unix says it's a queue. **TERM-then-wait2** is the deploy: workers
trap TERM as "finish what you hold," the master reaps each child by
pid *and exit status*, and unserved jobs stay in the pipe for the
next fleet. Every piece has a man page older than most gems'
maintainers.

## Two honest lessons from the drill itself

First, the example's own first run died with `undefined method
'tmpdir'` — I used `Dir.tmpdir` without requiring "tmpdir", in the
same repo where hsbt's census made that exact sermon last round.
Require what you use; the preacher is not exempt.

Second, the burst-fed pipe taught the fairness lesson live: write
all nine jobs at once and the first reader drains everything (9/0/0)
— a pipe is a queue but not a *fair* one, because IO buffering lets
one process slurp ahead. Pacing arrivals like real work actually
arrives got the fleet lifting together (3/3/3). This is the same
reason unicorn balances on `accept` rather than on reads from a
shared stream: you want the kernel arbitrating *admission*, not
buffering. The example keeps the pipe (right size for the demo) and
documents the limit, which is the Unix way — know exactly what your
primitive promises.

The framework's contribution slots in exactly where it should:
each worker owns a journal (flock'd — the process drill certified
that across forks), group-committed for throughput, synced before
exit. Per-process durability with kernel-arbitrated files: the 1970s
and round 13, interoperating cleanly.

## Verdict

Three processes, four syscalls, one signal, zero dependencies —
deploys that finish in-flight work and a reaping that accounts for
every child. The operating system is the best framework you already
have; its DSL is just spelled fork, pipe, kill, and wait.
