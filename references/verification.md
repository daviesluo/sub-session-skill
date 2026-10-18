## 5. Verification discipline

Contents:

- 5. Verification discipline


These rules came out of real failures. Keep all of them.

- **Artifacts over banners.** A runbook's "COMPLETE" line or an exit
  code can lie (piping through `tee` makes every block's `rc` the exit
  of tee, always 0). Completion means the artifact exists and passes
  inspection: open the cache, count the items, check the version.
- **A RUN THAT DID NOT PRINT ITS OWN TOTALS LINE DID NOT HAPPEN.** A
  suite reports by finishing, so a partial log is evidence of nothing:
  the cases it never reached are exactly the ones whose outcome is
  unknown, and a tail full of passes reads the same either way. Measured
  here: a run was killed at case 34 and reported as green, and the seat
  that re-ran it to the end found three failures. Never quote a count
  from a log whose last line is not the totals. Confirm the process is
  gone, confirm the totals line is there, then recount the passes
  yourself. Two numbers that agree came from one finished run, and one
  number alone came from wherever you stopped reading.
- **A CASE THAT ALWAYS STARTS FROM ONE INITIAL STATE TESTS THAT STATE
  AND NOT THE RULE.** The states a rule distinguishes are the states its
  case has to begin in, and a fixture that resets to empty every time
  exercises only the empty one. Measured here: the race case began every
  trial with no claim record at all, so it proved the create was atomic
  and said nothing about the path taken when the create FAILS, which is
  where the defect an outside reader found actually lived. Enumerate the
  starting states the rule tells apart, and drive the case from each.
- **A NEW CASE IS TRIED IN A HARNESS THAT COPIES THE SUITE'S OWN SHELL
  SETTINGS, OR IT IS NOT TRIED AT ALL.** Writing a case in a scratch
  script and watching it pass says nothing about how it behaves inside
  the run, and the gap is usually `set -e`. Under it an assignment from
  a command substitution carries the substitution's status, so
  `x=$(cmd)` where `cmd` legitimately exits non-zero ends the RUN at
  that line, and `cmd; rc=$?` never reaches the assignment. Measured
  here twice in one day: an assertion added to inspect an exit code
  killed the suite with that code, and then the case written to
  document THAT trap died the same way two assertions in, because its
  scratch harness had no `set -e` and the real file does. Copy the
  settings, and give the harness a trap that says the run died rather
  than letting it end quietly.
- **A CONTROL WHOSE ANSWER DEPENDS ON WHICH OF TWO PROCESSES WINS IS
  NOT A CONTROL.** Where a case asserts that one side finished before
  another killed it, give the side under test enough real work that it
  cannot win by luck. Measured here: an adapter whose cleanup was one
  `cat` and one `kill` passed on this machine and failed on another,
  the same code, one assertion apart on a suite of over three hundred,
  and what differed between them was the scheduler. With a
  handler that takes two seconds the same case failed every time on
  the defect and passed every time on the repair.
- **A TRUNCATED LISTING IS NOT A MEASUREMENT, and an absence it reports
  is not an absence.** Every list call in every platform API takes a
  limit, most default to a small one, and what comes back is ordered by
  something you did not choose. Measured here at the cost of a published
  correction: a reviewer checked whether a routine had fired, called the
  listing with a limit of two, did not find the routine, and reported
  that it had never fired. The listing returns the two most recently
  CREATED routines and the one it was looking for was third. It then
  cited that same call twice as two sightings at different times. The
  routine had fired twenty-six seconds before the check. So when a query
  is the evidence for an ABSENCE, name the record by its own identifier
  and fetch it directly, or raise the limit past the total and say what
  the total was. This is the same species as an accepted call read as a
  delivery, and a team that has just corrected one is exactly the team
  that will produce the other.
- **A FACT ABOUT THE PLATFORM GOES INTO THE WRITTEN RECORD IN THE SAME
  PUSH AS THE MEASUREMENT, or it is paid for twice.** Where it goes is
  the part people get wrong: a runnable artifact is not a record. Measured
  here at the worst possible cost. A seat measured which of two wake calls
  actually delivers, wrote the answer correctly and completely, and put it
  in the PROMPT PAYLOAD OF A ROUTINE, which is a place no reader goes: not
  the protocol, not the appendix, not the ledger. Two days later the
  master rediscovered half of it from first principles, chose the call
  that does not work, told the user the wake was fixed, and the seat
  stayed deaf for two more days. The knowledge existed the whole time and
  was invisible. So when a probe settles a question about the host, the
  same push carries the answer into the file a stranger would open,
  BEFORE the thing that uses it. A note inside a config, a comment in a
  live script, a line in a chat window and a sentence in a routine's
  prompt are all the same failure.
- **A TEST THAT PASSES ON THE BROKEN CODE PROVES NOTHING, so run it
  against the defect before trusting it against the fix.** This is the
  most expensive lesson in this file, because it hides behind a green
  suite. Measured: a quarantined lock's reclaim rule read the wrong clock,
  making the lock reclaimable the instant it was taken, and the case
  written to cover that behaviour PASSED for a reason unrelated to the
  rule, its command returning in seconds against a sixty minute threshold,
  so the right rule and the wrong one gave the same answer. An outside
  reader found it twice in one session, in code that session had just
  repaired. THE HABIT THAT CATCHES IT costs one run: copy the tree, revert
  ONLY the fix, run the suite, and require the new assertion to FAIL
  there. Then say which assertions discriminated and which did not,
  because a case usually contains both and only the discriminating ones
  are evidence. An existence check that the fix wrote a file is not
  evidence that anything reads it.
- **Pre-register gates.** Before a validation run starts, the master
  writes down the acceptance criteria AND their interpretation rules
  (what counts as a pass, a conditional pass, a fail). Deciding
  after seeing the numbers invites gate-shopping. Two properties every
  gate needs: express each bound in UNITS THAT SURVIVE THE
  CONFIGURATION A REMEDY MIGHT CHANGE (a rate or per-unit quantity,
  never a raw count whose denominator the remedy routinely moves), and
  make the branches EXHAUSTIVE. Deciding each branch is the easy half.
  Enumerate which criteria can fail independently and confirm every
  combination of them lands somewhere, because the case that falls
  between two branches is usually the one that occurs.
- **Decidability check.** When writing a gate, confirm the planned
  artifact stores enough to decide EVERY branch of the rule. A rule
  that needs per-item values while the artifact stores only the
  extremes is undecidable exactly in the interesting case. Store the
  full dictionaries. Scalars are for display.
- **The sub-session pre-flights the master's new code.** The division of
  labour puts writing on one side and execution on the other, so the
  sub-session is the last line of defence before compute is spent. When
  the master pushes new or changed code the sub-session is about to run,
  the sub-session first exercises the new lines on a real small instance,
  a tiny sample run against the actual API objects and never a stand-in.
  It escalates a break BEFORE the long run, with the verified fix where it
  has one. A ten-second pre-flight has repeatedly saved multi-hour
  blind failures.
- **Verify claims independently.** The reviewer re-derives the
  mathematics, re-runs the check, or reads the primary artifact
  rather than trusting the author's summary, and states what its
  evidence can and cannot support (ruling X out is not ruling Y in).
  Corrections to one's own earlier claims are logged promptly as
  CORRECTION entries, and whoever RAISES a hypothesis owns CLOSING
  it: a refutation is recorded as prominently as the suspicion was,
  so the master never carries open worries the evidence has settled.
- **Nested or independent, say which.** In a "rerun it bigger and see
  if it moved" test, establish whether the runs are nested
  continuations or independent realisations (a shared seed may cover
  only the initialisation), and state which next to the result: a
  small movement between independent runs carries both runs' Monte
  Carlo noise and is unremarkable, while the same movement between
  nested runs is the effect being tested.
- **Absence claims need a control from the same region, and remote
  questions need remote evidence.** Before reporting that something
  does not exist (a commit, a file, a pattern in a file), run a
  positive control drawn from the SAME REGION as the claim: a control
  from the region you can already see only proves your view works,
  and a boundary (a shallow clone, an extraction that stopped early)
  is invisible from its own inside. And a question about shared state
  (is this commit reachable from <integration>) is answered against
  the remote, by a fresh clone or an explicitly unshallowed store,
  never by local resolution or local absence alone, in either
  direction. An absence claim also names its SEARCH SPACE: enumerate
  every store the thing could live in, prose, source, binary
  artifacts and caches alike, and say which were searched, because
  the store that is inconvenient to search is where the
  counterexample lives. And prove the instrument on a known positive
  before trusting its zero: a filter built for one purpose (skipping
  one language, stopping at a fence, reading the wrong revision, or a
  phrase search run against a hard-wrapped file that split the phrase
  across two lines) hides its own blind spot and reads clean.
- **Consult the hazards list, and keep one.** If the repository
  documents its known traps, read them before writing code against an
  API they cover. Violating your own documented hazard is the
  avoidable class of bug. If the project has no hazards list, start
  one with the first trap the team hits.
- **No silent scope changes.** If a comparison's measurement scope
  differs between two things being compared (different variable sets,
  different machines, different configurations), either align the
  scope or state the difference next to the numbers.
- **The rendered artifact is a primary source.** Some defect classes
  exist only in the compiled output, layout, overflow a wrapper
  silences, what a reader actually sees, and no log or assert
  reaches them: render and measure by script, and read the pages a
  scan flags. Verify a fix in the compiled artifact too, never only
  in the source diff.
- **Check the edges as their own step.** A claim's boundary
  conditions, index ranges, a sum's limits, first and last items,
  empty cases, get verified separately from its body, because
  body-checking habitually certifies a range it never looked at.
- **A TEST SUITE MUST NOT BE ABLE TO REACH THE THING IT IS TESTING.**
  Measured: the suite drove the injector, the injector preferred a keyboard
  tool the suite had not faked, and the tests activated the LIVE application
  and pasted fixtures into a working seat, which recorded two of them as
  instructions from its operator mid-campaign. Faking the route was the wrong
  repair and failed twice, on undocumented details of a route nobody
  publishes. What worked was A NAMED DELIVERY COMMAND the suite points at a
  log: one path on every machine instead of one branch per platform, unable
  to reach an application at all, and useful outside the tests too. And a
  fixture is scoped by WHERE IT LIVES, not only by when it is on the path:
  fakes left in a directory a later section added to its own path went on
  deciding which branch ran, six sections later.
- **PUSHING A FIX IS NOT DELIVERING IT, and a fix is not done until it is
  running.** A correction lands in the repository and the machine that
  shows the notifications carries on unchanged, for two reasons at once: a
  clone may be holding an inward merge while a campaign runs, and a
  long-running watcher is a shell that read its script at start, so even
  an updated file on disk changes nothing until the process restarts.
  Measured: reported defects were corrected, committed and pushed, and the
  person who reported them was still reading the old notifications hours
  later. So every fix carries a DELIVERY step and a PROOF step, the proof
  being a measurement on the machine that matters. Take the tooling
  directory alone rather than merging, since tooling sits outside most
  freezes. Run the suite on the delivered files BEFORE restarting
  anything, because restarting a watcher on scripts that fail their own
  tests is worse than leaving the old one up. Restart, then demonstrate
  the corrected behaviour by hand and quote what it printed. A commit hash
  recited back is not evidence that a notification looks different. The
  watchers help: each prints a short fingerprint of its own bytes when it
  arms, so a stale process is visible in one glance.
- **Sweep mechanics** (the proactive duty of section 1). Trigger on
  idle attention, not on a clock: a block is running and no event is
  pending. One NAMED lens per pass, stated in the outbox report, and a
  pass that finds nothing is a valid result reported as such.
  Manufacturing findings to look busy is the failure mode to avoid.
  Alternate deliberately between the two axes a reviewer left alone
  will not balance: STRUCTURE (plan ordering, handover integrity,
  documentation currency, process rules being followed) and CONTENT
  (the mathematics, the implementations, the numbers against their
  sources). Sweep the master's work as readily as your own lane. The
  protocol's division of labour means each side is the other's only
  reviewer.

