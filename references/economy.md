## 9. Economy: the smallest budget that keeps the guarantees

Contents:

- 9. Economy: the smallest budget that keeps the guarantees


Two sessions do not cost twice one session. They cost twice one
session times whatever amplification the protocol adds, paid from the
user's own usage budget. Every mechanism above has a cheap form and
an expensive form. The DEFAULTS below are the cheap forms. Each
expensive form is a CAMPAIGN: a named, ledger-recorded, temporarily
expensive discipline that states its close condition when it opens,
is switched on by the user, and ends only when that condition is met
and declared.

- **Count input context, not turns.** Each model turn re-sends the
  session's accumulated context, so a "one-line" turn late in a long
  session costs far more than the same turn early, and many small
  turns beat few large ones only in appearance. Three consequences:
  the check-in dial scales with ACCUMULATED CONTEXT, not only with
  whether a watcher is up. Fold a due check-in's work into the next
  substantive turn when one is near instead of firing it alone. And
  the single biggest lever is RETIRING AND RESTARTING a session at a
  milestone so the context resets. The ledger handover this protocol
  already maintains is what makes that restart safe.
- **Watchers are free, check-ins are not.** A shell watcher polling git
  costs no model budget. Every check-in firing costs a model turn. So
  watchers are the primary signal (60 seconds at rest, tighter while a reply
  is due, per section 2) and check-ins the backup layer (shorter than the
  measured monitor cap while work runs, per section 3, longer while idle).
  Never schedule a model wake-up to poll for something a watcher already
  watches. A check-in that fires and finds nothing SAYS NOTHING, per the
  silence rule of section 2: a seat that narrates every firing turns its
  own window into noise and hides the arrival it was built to show.
  THIS RULE INVERTS WHERE A PLATFORM REAPS BACKGROUND PROCESSES WHEN A SEAT
  GOES IDLE, and one measured here does: in the cloud the container itself goes
  away, so no ancestry defeats it. A watcher there can report and can never
  WAKE, so it is detection only and its cadence is set as if there were no
  watcher at all. THE CHECK-IN IS NOT NECESSARILY THE ONLY WAKE PATH LEFT.
  Some hosts that reap containers also expose delivery into a named session,
  and where one does AND THE SEAT CONFIRMS IT, that beats a check-in
  outright: an event rather than a timer, free while the seat is idle, and
  carrying the master's own text. Ask for it before falling back to a timer,
  and DO NOT ACCEPT A FLAG IN THE SESSION RECORD AS THE ANSWER. A fire that
  is accepted, returns an id and quietly starts a throwaway session instead
  was measured here, and from the master's side that is indistinguishable
  from a wake that worked. The two properties are independent, since a host
  reaps containers because it will not keep compute alive, which says nothing
  about whether it can route a turn into a conversation that already exists.
  Ask both questions for your own platform, with `ps` after an idle gap you
  actually waited out: does a background process survive the seat doing
  nothing for twenty minutes, and can anything outside that session deliver a
  turn into it, PROVED BY THE SEAT ECHOING WHAT WAS SENT.
- **Routine watching belongs on the cheapest capable model.** Where the
  platform can schedule fresh sessions, put the recurring look-and-report
  loop in a minimal fresh session on the cheapest model that can run the
  checks: fire hourly, stay silent when all is well, and alert the master
  by message or stored poke only on a named condition. A heavyweight
  session re-reads its whole accumulated context on every wake, and the
  same watching done by fresh cheap sessions was measured an order of
  magnitude cheaper. Give the monitor a completion marker it can read, one
  exact line the master writes at close, so a finished campaign stops
  re-alerting. THE LIMIT THAT DECIDES THE DESIGN: a scheduler-fired FRESH
  SESSION may run WITHOUT the tools that wake another session, so it can see
  the event and be silently unable to report it, which has happened. A
  monitor therefore RECORDS while something else guarantees the wake, and
  where it is meant to alert, PROVE that path once with a deliberate test
  alert. What is trusted for an event that decides what happens next is the
  master's OWN scheduled wake, minutes to half an hour while a result is due
  and hours while nothing is expected. A monitor exists for the judgement a
  shell watcher cannot make, counting artifacts, reading escalation lines,
  judging whether a silence is a stall. It never duplicates a shell poll and
  never demotes the watchers of section 3, which stay the primary signal.
- **A check-in that finds nothing owed must cost almost nothing.** Open with
  the watermark range query, asked of the branch the work would arrive on. A
  sub-session asks `git fetch -q origin
  +<integration>:refs/remotes/origin/<integration>` and then `git log
  <watermark>..origin/<integration> --oneline`. The fetch and its refspec
  are both load-bearing: without the fetch the query answers from a stale
  copy and reports nothing new, and without the refspec some clones never
  create the ref the query names. A master asks the same pair of every
  sub-session branch, `git fetch -q origin
  +<branch>:refs/remotes/origin/<branch>` and then `git log
  <watermark>..origin/<branch> --oneline`, because nothing a sub-session
  does reaches <integration> until the master merges it there, so a master
  querying only <integration> reads clean while a finished campaign waits on
  a branch. Empty range and a live runner: one outbox line, re-arm, stop. No
  re-reading settled files, no re-verifying settled state.
- **Review coverage: watermark backbone, change-triggered reviews,
  content triage.** Reviews TRIGGER on changes landing, because
  freshness catches what batched review blurs. Coverage is recorded
  against a COMMIT WATERMARK that only a review NAMING WHAT IT
  CHECKED may advance, which makes coverage auditable and, when the
  notification net fails, recoverable by the range query. Depth is
  TRIAGED BY CONTENT: full treatment for code, numbers and prose. A
  one-line ruling for ledger-only commits. Byte-identical compiled
  artifacts are checked by comparing hashes, and the hash comparison
  IS the check. Depth follows the diff's blast radius, plus a fixed
  cheap regression micro-pass (earlier fixes still present in the
  rebuilt artifact). Re-running EVERY lens over EVERYTHING on every
  commit is a campaign mode, switched on deliberately, never the
  default.
- **Review and instruction traffic moves in blocks.** One instruction
  carries the whole batch of items for a round, one report answers all
  of them, one ruling closes them together. Fragmentary back-and-forth,
  a finding sent alone, a one-line follow-up, a clarification that
  could have ridden the next block, burns a full wake and its context
  on every fragment, and the wakes are what cost. Split a round only
  when something inside it is BLOCKING and the other side would
  otherwise wait idle, or when the whole task is genuinely small. WHERE
  THIS MEETS SECTION 2's rule to reply with the result itself as soon as
  it is ready, the test is who is waiting: a result the other side is
  blocked on goes the moment it exists, and a result nobody is waiting
  for rides the next round.
- **Do not run the same instrument twice.** The side that lands a
  change runs the mechanical verification (scans, counts, rebuilds).
  The other side audits the method and the result's plausibility,
  and runs its own fully instrumented pass at declared milestones,
  not per commit. Auditing a method means REPRODUCING it on at least
  one known-positive case, never just reading its description: a
  filter that hides its own blind spot reads clean and fails silent.
  Two sides deriving the same thing blind is the strongest and
  costliest check there is: only when the user orders it, and while
  it runs neither side reads the other's working until its own pass
  is complete. A campaign ends by its pre-stated close condition,
  declared in so many words by each side, never by petering out.
- **Vision is the priciest read.** Where the deliverable is something
  rendered, a typeset document, a slide deck, a user interface, geometry
  (text-block extents, page fill, overlap) is decided by scripts that send
  no image into the context. A rendered page enters the context only when a
  scan flags it, its content changed, or a finding about it is being
  adjudicated.
- **The bus carries telegrams. Journal prose belongs in the ledger.**
  Instructions, acks and reports carry the decision, the IDs and the numbers
  in about ten lines. Evidence lives once in the project ledger and is
  referenced, never restated. Do not quote the other side's text back to it,
  and do not repeat standing rules in every message.
- **Batch commits by adjudication.** Every commit lands in the other
  side's review queue, so commit granularity is review cost: one
  commit per adjudicated batch of findings, not one per micro-edit
  (compute checkpoint commits are exempt, section 4).
- **Read deltas, not documents.** At a check-in, read what changed
  since the watermark, not the whole inbox, ledger or skill again. A
  governing file is re-read whole only when it changed or after a
  context loss.
- **The floor these rules never cut through.** Economy applies to
  effort that can be redirected, never to the checks the work rests
  on: the artifact completion test, the pre-flight before a long
  run, independent verification of any number that will be
  published, and reading the deliverable itself. A suite can be
  green on every commit while defects sit in prose nobody read, so
  triage decides DEPTH, never whether the thing is looked at. A team
  that triages its way to rubber-stamping has saved nothing.
- **Idle means silent.** Blocked on the other side, or on compute,
  with nothing owed: no extra model turn. The watchers watch. The
  next turn happens at an event or a due check-in. Silence bounds
  the REPORT, never the firing: while a runner is live, the
  liveness check-in of section 3 still fires and costs its one
  line, because nothing else detects a dead runner.
- **Standing user instructions outrank every default here.** When
  the user orders an expensive discipline with no end date (review
  everything on every change, keep a duplicate derivation), it is
  recorded in the ledger as STANDING, not as a campaign with an
  end, and it stays in force until the user lifts it. The team may
  surface its measured cost once and propose a cheaper equivalent.
  It never downgrades the instruction silently.

