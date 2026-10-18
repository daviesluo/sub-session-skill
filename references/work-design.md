## 4. Work design rules

Contents:

- 4. Work design rules


- **Disjoint lanes are mandatory.** The master partitions outputs so
  no file is ever written by two sessions. If two sub-sessions need the
  same artifact, the master splits the artifact or serialises the work
  through <integration>. Disjoint lanes are what make every merge trivially
  clean. Lanes partition FILES, and sessions must also be partitioned
  in the FILESYSTEM: separate machines or containers need nothing
  beyond their own branches, but two sessions on ONE machine need one
  working tree each, a git worktree or a second clone, or their
  checkouts overwrite each other between commits.
- **A LONG JOB RUNS AGAINST FROZEN INPUTS, and the freeze is a copy and
  not a promise.** Stage the code and data a long run reads into its own
  directory, record a hash over every staged path, and leave the working
  copy free to move. A run measured in hours will otherwise be overtaken
  by the repository it came from, and the result is the worst kind of
  wrong: half the items computed by one version and half by another, with
  nothing in the artifact saying which. The freeze also buys the thing
  that makes a campaign survivable, which is that fixing the module in the
  repository does not disturb anything already running. When the run
  harvests, compare the hash before merging, and merge into the panel by
  KEY so a re-run of an item already present is skipped rather than
  silently replacing it.
- **SIZE A WAVE SO ITS WORK DIVIDES INTO ONE PASS, and keep the next job
  queued.** Where a job runs N items across W workers, the wall clock is
  the per-item time multiplied by the number of passes, so a request that
  leaves a handful of items for a second pass costs twice the wall clock
  for a few percent more work. State, for every submission, the item
  count, the worker count, the resulting pass count, and the wall clock
  that follows from the MEASURED per-item time. Where the per-item time
  has never been measured at that setting, measure it with a two-item
  probe before sizing anything. And keep a standing queue of the next
  useful work, so that when a job ends its capacity is taken within one
  watcher poll rather than sitting idle until a human notices. Check the
  critical path before churning a running job: a wave that is not the
  binding one gains the team nothing by being restarted, and restarting
  it throws away whatever it has already done.
- **A COMPLETION SIGNAL MUST NAME THE JOB THE WATCHER ACTUALLY SAW END.** A
  retargeted watcher carries the new id in its template while an old process
  may still hold the old id in memory, so when the old job leaves the queue
  that leftover announces the completion of a job that has not started. A
  false completion is worse than none, because a missing signal is eventually
  noticed and a false one is acted upon. So a retarget kills the old process
  and VERIFIES it is gone by measurement, since a process asked to quit may
  not have, and the signal quotes the id the watcher OBSERVED leaving the
  queue, never one filled in from a template. The receiving side verifies a
  completion against the scheduler before acting: one command against a wrong
  report.
- **A JOB WITH NO WATCHER ON IT IS A JOB NOBODY IS WAITING ON.** Arming the
  watcher is part of submitting the work, not a follow-up task. A run that
  ends unwatched reports to nobody, and the loss is the whole gap between
  the moment it finished and the moment someone next thought to look, which
  on a busy master is measured in hours. The master's own liveness does not
  cover this, because the master learns about a job through the
  sub-session's outbox and the sub-session learns about it through the
  watcher. So the instruction that assigns long work names the watcher it
  must carry, and the report that acks the submission states that watcher's
  process and what it fires on. A probe or a smoke counts. Those are the
  runs most often left unwatched and the ones whose result is most
  time-critical, since everything sized from them is blocked until it
  arrives.
- **Resumable blocks.** Long jobs save incrementally (atomic per-item
  writes) and skip work already done, keyed by an explicit version
  stamp in the artifact. A version bump forces a clean rebuild. An
  unchanged version resumes. This turns crashes and restarts into
  non-events. The bump's BLAST RADIUS is a scoping decision that no retry
  rule owns: the gate reruns EVERY item in the block, including ones that
  passed, so the sub-session reports the radius and its cost alongside
  the failure that motivates the bump, and the master chooses between
  a scoped rerun and a uniform version with the bill in view. A
  SALVAGE mechanism, dumping partial results so a killed run leaves a shorter
  but valid sample, is not a resume: state restored mid-algorithm is rarely
  homogeneous with a fresh start, so treat salvaged output as a smaller
  complete result and never as a segment to splice. Pre-flight it at VALUE
  level, not shape level, since a buffer padded with uninitialised memory has
  exactly the right shape while carrying junk.
- **One change per remedy.** A remedy that alters two factors at once
  cannot attribute its own outcome, whichever way it lands, and
  recovering the attribution afterwards costs extra runs. Change one
  thing, measure, then the next. When two changes must ship together,
  say so and say what the run will not be able to establish.
- **Checkpoint cadence.** Sub-sessions commit and push their branch about
  every 15 minutes while artifacts change, always before going idle, and
  THE MOMENT a long block completes: a result that exists only in a
  working tree is not delivered, and sessions sharing one usage allowance
  die together, so the minutes between landing and push are the whole
  exposure. For the same reason, duplicating a job across sessions hedges
  nothing. Resumable saves plus push-on-completion are the real insurance.
  Rebuild side effects that change only timestamps or embedded dates are
  reverted, not committed. Use the repository's rules for hooks (if a
  check suite is expected to fail mid-rebuild, bypass it for checkpoints
  the way the repository sanctions, and say so in the commit or ledger).
  On a repository whose continuous integration builds every branch, a
  checkpoint every fifteen minutes floods it: scope the builds to
  <integration>, or skip them on work branches, and say which.
- **Chaining.** When block B must follow block A but A is still running,
  chain B behind A (a terminal multiplexer session waiting on A's process,
  with a match pattern per section 3) instead of polling or idling, and say
  so in the outbox. The script a chained job runs is read AT LAUNCH, so an
  inward merge that must reach that job has to land before the chain fires,
  verified by confirming the chained job's log is still empty after the
  merge. Leave a chained job that has already started alone and rerun it
  afterwards, rather than racing it. When the needed reaction is "act within
  seconds of an event whose timing nobody can predict" (bank an artifact the
  moment a line appears, kill before the next block starts), AUTOMATE it
  with a background watchdog that polls for the marker and acts through a
  verified process pattern. A notification round trip is too slow by
  construction. Write any finalize step behind a chain IDEMPOTENT (assert
  its anchors before writing), so a duplicate manual run after a false or
  lost completion notice is refused safely instead of applied twice.
- **Freeze what a running job reads.** When a long block starts, the
  scripts, configuration and input artifacts it depends on are FROZEN
  for its duration, and the master declares the freeze by naming those
  files in the inbox and the ledger. A job reads its script at launch,
  so an edit landing mid-run leaves some workers on the old text and
  some on the new, and their outputs stop being comparable without
  anything having errored. The freeze names files and never whole
  directories, so unrelated work is not blocked, and only the master
  lifts it. A sub-session that finds a frozen file changed under it
  stops and escalates instead of judging for itself whether the change
  was harmless. Where a fix to a frozen file cannot wait, the answer is
  to stop the run, land the fix and start again under a fresh version
  stamp, with the ledger recording what the discarded run cost.
- **Copy an irreplaceable artifact aside before a step that can void
  it.** Some artifacts cost days to rebuild, and some regeneration
  steps destroy one without raising an error: a cache keyed on a
  fingerprint of its own inputs answers an input change by returning an
  empty container, and the next block to finish stamps that empty one
  over the good one. Before any step that could invalidate such an
  artifact, copy it aside, record its checksum in the ledger, and check
  the checksum afterwards against whatever the step left behind. Committed
  history is a weaker backup than people assume, since the version in git is
  often superseded and an artifact too large for the repository was never in
  it. The test of this rule is naming, BEFORE the step runs, the exact command
  that puts the artifact back.
- **Reorder, do not idle, unless the machine is full.** While you are
  blocked on the master, do the next unblocked assigned job and log the
  reordering as a judgement entry. But the reorder rule yields to
  resource contention: do not start a job that would fight the
  running one for cores (a four-process job beside a four-worker
  pool on a four-core box helps neither). Chain it instead.

A SIGNAL BUILT FROM AN EMPTY QUERY IS NOT A SIGNAL, which is the same failure
one step further back. A scheduler forgets a finished job, so a query about it
returns nothing, and a watcher that prints its fields prints them blank:
`State=` `Reason=` `StartTime=`, an update about nothing that reads like a
transition.
Measured, three times in one night, once on a job that had been cancelled while
a different job was the live one, where a stray signal naming the wrong job can
misdirect a harvest. A watcher that reports state must treat an absent record as
"I could not see it" and say so, and must never wake anyone with a row of empty
fields.

