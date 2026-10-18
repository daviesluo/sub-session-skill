## 2. The communication bus

Contents:

- 2. The communication bus
- Instruction protocol: the inbox
- Report protocol: the outbox
- Latency: four steps, one of them unavoidable
- Two lines in each session's own window
- Visibility: the three levels, and which one a seat is on
- Notifications: one format for the whole team
- Making a message become a visible turn


Per sub-session `<name>`, two files with exclusive writers. The
directory is the master's choice and is written `<bus-dir>` in every
runnable block below, so that choosing another one stays a mechanical
substitution (`collab/` is a fine default. Any existing infrastructure
directory works): the BINDING property is one writer
per file. The path itself binds nothing.

- **Inbox** `<bus-dir>/INBOX_<name>.md`, lives on <integration>, written
  only by the master. Holds numbered instructions under a `## Open
  instructions` heading. Sub-sessions read it from `origin/<integration>`
  (never from their own stale copy): `git fetch origin
  +<integration>:refs/remotes/origin/<integration> && git show
  origin/<integration>:<bus-dir>/INBOX_<name>.md`. The explicit refspec is
  not decoration: in a clone made with `--single-branch`, and in any clone
  whose configured refspec does not cover the branch, a plain `git fetch
  origin <branch>` updates FETCH_HEAD and never creates `origin/<branch>`,
  so every later `git show origin/<branch>:file` fails and the reader
  silently sees nothing at all.
- **Outbox** `<bus-dir>/OUTBOX_<name>.md`, lives on the SUB-SESSION's
  branch, written only by that sub-session. Append-only, UTC-timestamped,
  terse factual log lines in the repository's written language. READ THE
  CLOCK FOR EVERY TIMESTAMP. Continuing a sequence from context instead
  writes fabricated times into the one file the team treats as evidence,
  which has happened: two entries in one log carried times hours off,
  each continuing the previous sitting's hour, in both cases after the
  correct time had just been printed.

Exclusive writers mean the two sides never race a push: the master
pushes <integration>, each sub-session pushes its own branch, and merges are
one-directional. This is the property that makes the bus safe. Do not
weaken it.

RUNNING BESIDE THE LEDGER PROTOCOL COSTS ONE CONFIG LINE PER SEAT, AND
LEAVING IT OUT REFUSES EVERY SEAT'S FIRST CHECKPOINT. Where the
repository also runs the companion protocol linked from `README.md`,
its pre-commit hook requires each commit to carry the ledger it guards.
A SEAT'S LEDGER IS ITS OWN OUTBOX, since that is the file it owns under
the rule above, so each seat's clone sets `git config --local
ledger.path <bus-dir>/OUTBOX_<name>.md` once, in the same breath as the
hook path and before its first commit. The master's clone sets nothing
and falls through to the project default. Without that line a seat is
refused for not staging a ledger it does not own, and staging that
ledger would break the one-writer rule this paragraph just stated, so
the seat is caught between the two protocols with no legal move.

### Instruction protocol: the inbox

- Instructions are numbered `<name>-1`, `<name>-2`, ... after the
  sub-session's own name, capitalised or not as long as one form is used
  throughout, and are self-contained: what to do, in what order, what gates
  the result must pass, what to report back.
  A NUMBER IS NEVER REUSED, AND THE NEXT ONE COMES FROM THE HIGHEST THAT HAS
  EVER EXISTED, read from the whole inbox and the seat's acknowledgements
  together, never from whatever sits at the top of Open. A reused number is
  INVISIBLE IN BOTH DIRECTIONS: the seat selects by what its outbox has not
  acked, so an instruction carrying an already-acked ID is skipped in silence,
  while the master sees a written, pushed instruction and waits for a reply
  that is never coming. Measured here on 31 August, twice in one file: a
  release review and a machine-setup task were both issued on numbers the seat
  had acked weeks earlier, because the master read the newest entries rather
  than the whole series. Tidying Open into Closed makes this MORE likely, not
  less, since the numbers that prove a series' length are the ones tidying
  moves out of sight.
- A later instruction can SUPERSEDE an earlier one by saying so. The
  sub-session acknowledges the superseded ID without completing it.
- An instruction to WAIT for something carries a bound. When the
  master omits one and the wait starts blocking real work, the
  sub-session proposes a bound built from what the wait is FOR: when the
  purpose is a datapoint, stop as soon as the datapoint is
  established (a lower bound often establishes it), and escalate the
  proposal rather than waiting unboundedly or cutting off
  unilaterally.
- The sub-session checks every instruction against its hard limits. A
  conflicting instruction is SKIPPED, and the skip plus its reason is
  reported in the outbox. Hard limits always win. The master widens a
  limit explicitly in the instruction when that is intended.
- Acknowledgement: after completing (or skipping) instruction ID, the
  sub-session includes `[done: ID]` (or `[skipped: ID]`) in the SUBJECT,
  the first line, of its next checkpoint commit, and logs the details in
  the outbox. The subject is the one place the acknowledgement gate
  reads, deliberately, since prose discussing a marker in a body or an
  outbox is not a release of one, so a marker anywhere else is invisible
  to it.
- A NEW INSTRUCTION GOES AT THE TOP OF `## Open instructions`, NOT AT THE
  BOTTOM OF THE FILE, and the difference is not cosmetic. Appending with a
  shell redirect puts the new instruction after whatever the file ends
  with, which is the CLOSED section, so a seat that reads its inbox finds
  the newest work filed as already finished. Measured here: four
  instructions in one night were written under `## Closed instructions` by
  an append, and a fifth landed at line 2,662 of the file, deep inside an
  Open section 2,233 lines long, where the seat read the top and never saw
  it.
  Newest first also makes the cheap read the correct one.
- THE INBOX IS NOT APPEND-ONLY. When an instruction is completed,
  skipped or superseded, the master moves it under the `## Closed
  instructions` heading or marks it as such, so that `## Open
  instructions` means what it says. THIS RULE ROTS QUIETLY AND
  EXPENSIVELY: the same night, seventy of the seventy-two instructions
  under Open were already acked done and none had been moved, which is the
  whole reason Open was long enough to hide something in. A fresh master
  must be able to see what is outstanding from the file alone, without
  reconstructing it from commit messages. THE ACK IS THE TRIGGER: the
  commit in which the master answers `[done: ID]` carries BOTH the ruling
  and the move, since the ack itself arrives in a commit on the
  sub-session's branch and only the master writes the inbox. A closing
  rule with no trigger does not fire.
- THE SEAT READS THE WHOLE OF `## Open instructions`, NEVER ITS HEAD.
  Selection is by what the outbox has not acked, which cannot be decided
  from the first few entries, and a seat that reads the top of a long Open
  section misses exactly the work that was just assigned. This is the seat's
  half of the placement rule above, and one live seat broke it the same
  night the master broke the other half.
- A DIRECT USER INSTRUCTION to a sub-session, mid-flight, outranks
  the inbox: the user is the principal. The sub-session records it
  VERBATIM in its outbox so the master learns of it without the user
  repeating himself, and the master folds it into the ledger.
  Without this rule a team gives the user two mouths and one ear.
- An absent or empty inbox at startup is NORMAL: the master may not
  have written it yet. The sub-session says so in the outbox, starts its
  watcher, and executes any assignment the user gave it directly,
  logging that assignment in the outbox as an out-of-band instruction
  so the master can see what it is doing and fold it into the inbox.

### Report protocol: the outbox

ONE INSTRUCTION, ITS ANSWERS AND THE RULING ARE WORKED THROUGH ON ONE
PAGE IN [`EXAMPLE.md`](EXAMPLE.md), beside this file. Read it once
before writing your first inbox or outbox entry: the shapes below are a
contract, and a contract is faster to learn from a filled-in copy than
from its clauses.

Entry types the master relies on:

- Block or job start and finish lines with the headline numbers.
- A WATERMARK on every checkpoint and every closing entry, written as
  a git revision the other side can pass to `git log`, for example
  `watermark 4f2a9c1`: the commit on <integration> the sub-session had
  read up to when it wrote the entry. Everything that resumes work reads
  it, the change-triggered review, the range query that finds a stranded
  push, and the wake-up poke, which has no other way to know where to
  start after a stand-down. An entry that omits it forces the next reader
  to guess or to re-read everything.
- `DIAGNOSTIC`: warnings and anomalies with the sub-session's judgement.
- `FINDING-<n>` with a severity and a proposed fix, numbered in one
  series per sub-session, and `SUGGESTION` for improvements: the
  shadow-review outputs. The ID is what the check-in list, the
  ruling and the closure all refer to, so a finding without one
  cannot be tracked to its ruling. Severity is a three-rung
  ladder with obligations attached: HIGH blocks the deliverable and
  needs a ruling before the next merge, MEDIUM must be ruled before
  the running phase closes, LOW may be batched. The master answers
  each with a ruling (often via the inbox) and both sides record it.
  A reviewer who believes a REJECTED high-severity finding is real
  and blocks the deliverable may put it to the user ONCE, saying so
  in the outbox, and then drops it: adjudication stays with the
  master, and a reviewer with no appeal at all is left with silence.
  The sub-session carries the IDs of its unruled findings in its own
  check-in prompt and reconciles them at every check-in against the
  rulings that have landed: a finding closes only on a recorded
  ruling, and one that goes two check-ins unruled is re-raised as an
  ESCALATION, so the loop survives a context loss on either side. Where
  nothing can be scheduled, the trigger is two relayed turns instead of
  two check-ins, since this is the one closure rule with no other way
  to fire.
- `ESCALATION`: something the sub-session cannot or must not fix itself.
  Time-critical escalations say by when action is needed and what
  happens if none comes.
- `CORRECTION`: the sub-session correcting its own earlier entry. Doing
  this promptly is a duty. It never embarrasses the corrector.
- Judgement calls the sub-session made (what and why), so the master can
  audit reasoning, not just results.

### Latency: four steps, one of them unavoidable

**A message is only as fast as the slowest of the four.** The
bus is judged by the time between one side deciding something and the
other side acting on it, and that time splits into write, push, detect
and act. Only detection has an unavoidable cost, one poll interval, and
the delay that actually hurts is almost always a bus line that was
written and never pushed.

- WRITE AND PUSH IN THE SAME ACTION. A bus file edited and left in the
  working tree, or committed and left unpushed while the turn moves on to
  something else, is invisible to everyone: the other side polls the
  remote, and your disk is not the remote. Push the bus line before
  starting the next piece of work, in a commit of its own if that is what
  it takes. This is the largest and most common delay in practice, and it
  is entirely self-inflicted.
- DETECTION COSTS THE POLL INTERVAL, AND THE POLL IS CHEAP. One
  `git ls-remote` is a single network round trip and no tokens, so the
  interval answers to politeness towards the remote and not to budget.
  Sixty seconds is the resting default. TIGHTEN IT TO FIFTEEN OR TWENTY
  SECONDS FOR A BOUNDED WINDOW whenever a reply is expected: just after
  an instruction goes out, around a job's expected finish, and through
  the handshake. Relax back afterwards. The watchers already back off
  when a remote call fails, which is what keeps a tightened interval
  safe.
- ACT ON THE TURN THE MESSAGE ARRIVES. A watcher notification that lands
  mid-turn is handled at the end of the current batch of calls. The
  check-in covers the case where nothing arrived, and deferring a
  message that did arrive turns a one-minute bus into a thirty-minute
  one.
- COUNT ROUND TRIPS, NOT MINUTES. Each exchange costs a poll interval
  plus a turn on the far side, so two questions sent one after the other
  cost twice what the same two cost in one message. Send everything the
  other side needs to finish the step, say what a complete reply
  contains, and reply with the result itself wherever the result is ready
  AND THE OTHER SIDE IS WAITING ON IT, since an acknowledgement that a
  result is coming buys the reader nothing and spends a round trip. A
  finished result nobody is blocked on rides the next block instead, per
  section 9, which is the same rule read from the cost side.

MEASURE THE LOOP ONCE AND WRITE THE NUMBER DOWN. The handshake in section
7 times a no-op in both directions, and that pair of numbers is the
team's floor. An exchange that later runs well above the floor is a
defect with a short list of causes, checked in this order: a write that
was never pushed, a watcher that expired or died, a monitor cap shorter
than the check-in period, an approval dialog waiting on a human, a seat
that had been stood down, and only then the network. The floor belongs in
the ledger, so a later session can tell a slow link from a normal one.

### Two lines in each session's own window

**Both ends answer to the user in their own window, on arrival and on
completion.** A team whose whole conversation lives in committed files is
invisible to the person paying for it: the work lands as commits while
the chat window sits still, and a still window reads as a dead session.
Every session on every platform therefore REPORTS TWICE in its own chat
for every message it handles, once when it arrives and once when the work
is done.

- ON ARRIVAL, in the same turn the message is detected: what arrived,
  from which seat, the instruction or finding ID, the time, and what this
  session is about to do about it. One line, written BEFORE the work
  starts, because its job is to show that the link is alive, and a line
  written after a twenty-minute job says nothing about the twenty minutes
  the user spent wondering.
- ON COMPLETION, in the turn that finishes the work: what was done, the
  outcome with its numbers where there are numbers, where the evidence
  sits (the commit, the outbox entry, the artifact), what went back to
  the other side, and what this session turns to next. One short
  paragraph at most.

Neither report ever replaces the outbox entry. The outbox is the team's
record, written for other sessions and read out of git. These lines are
the user's view, written in the session's own voice where the user is
already looking. Both omissions have happened in real deployments: a seat
that worked correctly for an hour and told nobody, and a master that read
a review and ruled on it while its own window had shown nothing since the
previous morning.

**THE DUTY ATTACHES TO MESSAGES HANDLED, NEVER TO POLLS. A LOOK THAT
FINDS NOTHING IS SILENT.** Read the rule as written and the trigger is a
message arriving and that message's work finishing. A seat running a
self check-in reads its own timer as the event instead, and then every
firing produces a line, so the window fills with a report that says the
seat looked and there was nothing to look at. This has happened: a seat
on a one-minute self check-in wrote sixty lines an hour, each announcing
an iteration number and no work, and the user shut the seat down to stop
it. The cost is not only the noise. A window that reports nothing sixty
times an hour is a window in which a real arrival is invisible, so the
spam destroys the very signal the two-line duty exists to give.

So the three cases are separate and only the first two speak.

- A MESSAGE ARRIVED. Report on arrival and again on completion, as above.
- SOMETHING CHANGED WITHOUT A MESSAGE, and the user would want to know:
  a campaign finished, a watcher died, a lock was reclaimed, a run
  failed, the link has been silent past its alarm. One line, once, when
  the state changes and not on every poll that observes the same state.
- NOTHING CHANGED. Say nothing. Write no line, write no iteration
  counter, and do not confirm that the check-in ran. A watcher that is
  alive proves itself by delivering the next real event, and a seat
  whose liveness is genuinely in doubt is checked by looking at its
  branch, not by having it narrate its own pulse.

The cadence floor of section 9 is the other half of this and the two are
enforced together: a check-in never fires on a timer tighter than the
event it is waiting for, and the watcher, not the check-in, is the
primary signal. A one-minute self check-in was already a defect under
that rule before it wrote a single line. Where a seat's platform gives
it a self check-in at all, the check-in is a BACKSTOP for the watcher
being dead, so it belongs at the interval the watcher's own alarm uses
and not below it.

### Visibility: the three levels, and which one a seat is on

**WHAT THE WINDOW CAN ACTUALLY SHOW IS A PLATFORM FACT, AND IT IS
ESTABLISHED AT SETUP, NOT ASSUMED.** The duty above is the goal, and on
some platforms it is not reachable. Where a seat's unattended path is a
headless command-line turn, that turn writes into the CLI's own
transcript and THE WINDOW THE USER WATCHES DOES NOT MOVE. Writing two
lines there does not make them visible. This was measured on a live
deployment: an instruction landed, the headless turn ran and pushed a
commit, and the chat window the user was watching stayed still until he
typed into it. So each seat states, in its first outbox entry and in the
ledger beside the roster, which of three levels it can offer.

1. THE WINDOW UPDATES BY ITSELF on an unattended turn. The duty applies
   as written and there is nothing to configure.
2. THE WINDOW UPDATES BECAUSE SOMETHING INJECTS A MESSAGE INTO IT. THIS
   IS THE DEFAULT CONFIGURATION AND THE FIRST THING TO TRY ON ANY SEAT
   THAT HAS A DESKTOP WINDOW. `bin/inject.sh` ships with this protocol:
   it types a line into the chat application's input box, presses enter,
   and then WAITS for the seat to finish. Nothing about it is a feature
   of any platform. The master's whole part is still writing to the bus,
   and the injector is driving a graphical application the way a person
   would, which is why it generalises to any desktop chat client rather
   than to any particular tool.

   STATE ITS COST HONESTLY WHEREVER IT IS USED. It needs an automation or
   accessibility permission granted by hand, it breaks when the
   application's interface changes, it takes focus from whatever the user
   was doing, and a mistimed injection lands in the wrong window, which has
   happened on a live team. It is configured per machine, so a seat that
   moves machines loses it. Measured on a live
   team, adding one turned a seat silent for nine hours into one that woke
   visibly on every instruction.
3. THE WINDOW NEVER UPDATES UNATTENDED, because the seat has no desktop,
   no grant, or runs on a remote host, in a browser tab or in continuous
   integration. This is the FALLBACK and never the first choice. The
   outbox is the whole record until the next human turn, which opens with
   the digest of everything that ran unwatched.

LEVEL THREE IS A CHOICE AND NOT A PLATFORM FACT, which took a live seat
going quiet for an hour to see: working and dead look identical without a
sign. `bin/watch-inbox.sh` takes a `NOTIFY` command and runs it on every
state change with `NOTIFY_STATE` set to armed, started, finished, failed,
slowing, recovered or alarm, and `NOTIFY_TEXT` set to one line about it.
`bin/notify.sh` ships that recipe, because the hook alone was not enough:
without it every operator retyped an `osascript` one-liner with four levels
of quoting, and the seats nobody got round to stayed invisible.

```sh
NOTIFY="sh .../bin/notify.sh 'Claude Opus 5' 'Cursor Grok'"
```

ARMING DOES NOT REACH THE DESKTOP, and the proof it used to carry moves
into the setup. A watcher arming is the most frequent notification a team
raises and the least informative: supervisors restart watchers, screens
are relaunched, containers are rebuilt, and a person running several
seats with two watchers each gets a burst every time, none of it about
the work. What arming was for still matters, since a link that works
perfectly and looks dead costs the same as a broken one. So raise ONE
real notification by hand, once per machine, before arming anything, at
the moment a person is watching the terminal and can act on what they
see:

```sh
NOTIFY_STATE=started NOTIFY_FLOW=in NOTIFY_TEXT="the link is live" \
  sh .../bin/notify.sh 'Claude Opus 5' 'Cursor Grok'
```

If nothing appears on the screen, the link to the desktop is broken
somewhere and only this test says so, because a backend that is absent,
that fails, or that a Focus mode is swallowing all deliver the same
nothing. THE ONE FAILURE ARMING DOES CATCH is an empty `NOTIFY`, which
is why both watchers name the dial on the terminal as they arm, wired or
not: a lane nobody has heard from and a watcher nobody wired look
identical from outside, and one live seat on this team ran for days
with its other three dials set and this one forgotten.

### Notifications: one format for the whole team

ONE SHAPE, so nobody glancing at a wall of notifications works out whose
convention they are reading. The first line names the session, and where a
MESSAGE ACTUALLY CROSSED it names both sides with an arrow between them.
That distinction is the whole rule: an instruction going out and a finding
coming back mean different things to the watcher, while a watcher arming is
one session's own business and an arrow there claims a message moved when
none did. Arguments are PEER THEN SELF, which reads the same on both sides,
since a seat's INBOX watcher is the master talking to the seat and a
master's OUTBOX watcher is the seat talking back. One label alone is for a
single session's own timer.

THE DIRECTION IS DECLARED BY THE CALLER AND NEVER INFERRED FROM THE
STATE, and getting it wrong is invisible until someone reads a
notification carefully. A state name cannot carry a direction, because
the same name means an arrival on one watcher and a departure on
another: a seat's inbox watcher fires `started` when a task ARRIVES and
`finished` when the work goes BACK. Inferring from the name drew both as
master to seat, so a completed task looked exactly like a new one. So
the watcher sets `NOTIFY_FLOW` to `in` for a message arriving from the
peer and `out` for one going to it, and leaves it unset when nothing
crossed. AN UNDECLARED FLOW GETS NO ARROW: a wrong arrow asserts
something untrue, while a missing one only withholds what the text
usually says anyway, so a caller that forgets degrades to the plain
title rather than to a lie.

ANYTHING THAT STARTS A TURN IN A SEAT IS A MESSAGE CROSSING TO IT, and
notifies exactly like one. A job watcher poking the chat when a cluster
job lands, a scheduled wake-up, a harvest prompt: each of them puts work
in front of the seat, so each renders master to seat with `in`, in the
same three parts, and none of them invents its own shape. A person
should not have to learn one convention for instructions and another for
pokes, and a poke that looks unlike an instruction reads as noise and
gets ignored, which is the one thing a poke cannot afford.

AND THEY TAKE THE SEAT'S TURN LOCK BEFORE THEY TYPE. The lock is per
seat, not per watcher, and it exists so that two turns never run at
once. A poke fired outside the watcher bypasses it completely: measured
on a live seat, a harvest poke started an injection while the seat was
otherwise engaged, the seat declined the harvest and never wrote the
completion nonce, the injector waited out its full hour and left a
quarantined lock, and the next real instruction sat behind it unread.
Two injectors against one seat cannot share a nonce either, since the
seat writes one stamp and whichever nonce lands last strands the other
waiter. One injector at a time, holding the lock, or the poke does not
fire at all.

A TURN STARTED BY INJECTION WRITES THE COMPLETION NONCE AS ITS LAST ACT,
UNCONDITIONALLY, and the seat carries that duty, never the master.
It writes it when it does the work, when it finds nothing to do, and
above all WHEN IT DECLINES: a refusal is a finished turn, and the
injector waiting on the other side cannot tell a refusal from a hang. A
seat that answers "I am not doing that" and stops has left the lock held
and the link stalled for as long as the injector's timeout allows.

A LABEL IS THE PLATFORM AND THE MODEL, never the platform alone. One
tool runs many models and two seats on the same tool are different
colleagues, so `Cursor Grok` and `Cursor Composer` are not
interchangeable and a notification saying only `Cursor` leaves the
reader guessing which seat spoke. Take both halves from where the
ledger's source header takes them, and change the label when the
seat changes model, because a stale label names a colleague who is not
the one working.

ONE RANK ACROSS THE THREE BACKENDS, decided from the state and rendered in
whatever the platform has. URGENT means a person is needed and covers
`failed` and `alarm`. NOTICE means the link changed state by itself and
covers `slowing` and `recovered`. Everything else is the ordinary
heartbeat and stays quiet. Each backend then spends its own medium on that
rank, a sound and a critical urgency and an error balloon being the same
rung in three languages. Letting each backend choose for itself is what
this replaced, and it had already drifted: the same `slowing` was audible
on one machine and ordinary on the next, while every Windows balloon came
out Info including `failed`. A team watching two platforms has to be able
to learn the rule once.

### Making a message become a visible turn

POLL IN THE SHELL, WAKE ONLY ON A CHANGE. `bin/watch-inbox.sh` polls with
`git ls-remote`: no model runs and no tokens are spent until something
actually arrives, so an idle seat costs nothing. A scheduled prompt that
wakes the agent to go and look pays a full turn every time, and overnight
that is hundreds of turns to deliver nothing. Fall back to a heartbeat only
where no delivery mechanism exists, and set its interval by how long a
person will wait.

A PLATFORM THAT CAN PUT A MESSAGE INTO AN EXISTING SESSION CAN BE DRIVEN
THIS WAY, and the test is usually already in hand: if a visibility check
ever delivered into that session from outside, a watcher can use the same
route. Before concluding a seat cannot be addressed at all, look in the
APPLICATION rather than at the prompt the model was given. One platform was
written up here as exposing no session identifier and that was wrong: the
model is not handed one at startup, which is a different fact.

THE ACCEPTANCE TEST FOR A SEAT IS THAT SOMETHING APPEARS IN THE WINDOW THE
HUMAN IS WATCHING. Send one benign message through the route you intend to
use and require it to appear in the EXISTING panel, not in a new one and not
in a log. A headless watcher that executes every instruction correctly and
pushes every line still reads as a dead seat, because the panel never moves.
A SUCCESSFUL OUTBOX COMMIT IS NOT A VISIBILITY TEST: it proves the bus works
and says nothing about who can see it. A route advertised in a help surface
is not a verified one.

INJECTION REPLACES THE HEADLESS TURN, IT NEVER JOINS IT. Both on one seat
recreates the accident the turn lock exists to prevent: two agents working
one inbox and writing one outbox, holding none of each other's locks,
because the watcher locks only the turns it starts. ONE path per seat. With
a window, `ON_CHANGE` is the injector and there is no headless entry point.
Without one, `ON_CHANGE` is the headless command and there is no injector.
When changing paths, keep the old one running until the new one has passed,
and stop the old watcher BEFORE the new one starts, or the visible reader
finds nothing to do while the invisible one works.

THE INJECTOR HOLDS THE LOCK UNTIL ITS TURN IS DONE. Injection is
asynchronous: the keystroke returns when enter is pressed while the turn
runs on, and the watcher holds its lock only for as long as `ON_CHANGE`
runs, so an injector that returned immediately would let the next change
start a second turn beside the first. `bin/inject.sh` therefore mints a
NONCE per injection, tells the seat to echo it as its last act, and blocks
until it appears. Its exit status is the contract: 0 finished, 1 nothing was
typed so retry freely, and 75 THE OUTCOME IS UNKNOWN, which covers a turn
that may already be running and a line that may have landed in part, on
which the watcher keeps its lock and starts nothing beside it until the
`HOLD` quarantine expires, recording no live owner so that reclaim can free the
lock if the turn really did die. A plain failure would not do, because
the watcher releases its lock on every other failure.

WHAT THE INJECTOR BOUNDS, AND WHAT AN ADAPTER OWES. When `INJECT_CMD` runs
past `DELIVER`, the injector signals that command and its direct children,
TERM then KILL, and returns 75. IT REACHES ONE LEVEL AND SAYS SO. A delivery
that double-forks or daemonises leaves a descendant the injector cannot see,
measured rather than assumed: the suite drives exactly that shape and checks
the descendant's own recorded pid. Killing a process GROUP would reach it and
is not portable at this package's floor, since stock macOS ships no `setsid`.
So the contract is the other way round, in four parts. A DELIVERY COMMAND
THAT DAEMONISES OWNS ITS OWN CLEANUP, tested, and one that cannot promise
that should not be an `INJECT_CMD`. A descendant the injector can no longer
reach is OUTSIDE its cleanup guarantee, and no wording here brings it back
inside. 75 MEANS THE DELIVERY STATE IS UNKNOWN AND THE SEAT IS QUARANTINED,
never that delivery activity has stopped: a detached process can go on
typing, enqueueing or changing state outside this repository for the whole
`HOLD` period, and the lock protects the turn rather than the world. So
`DELIVER` BOUNDS WHAT THE INJECTOR WAITS FOR AND WHAT IT CAN SIGNAL, not
everything an arbitrary adapter set in motion. The seat is safe from a
SECOND TURN either way, which is a narrower promise than it first reads
as, and the narrow one is the true one.

A WINDOW OF THE SEAT'S OWN IS A REQUIREMENT OF INJECTION, not a caveat on
it. The keyboard path types into whichever conversation is frontmost and
SELECTS NO THREAD, so an application showing another conversation swallows
the instruction. Never a window a person also works in by hand. The
per-platform focus, paste and clipboard behaviour, each step of it answering
a measured failure, is documented in `bin/inject.sh` beside the code that
does it, including the one loss it cannot prevent: a pasteboard holding
anything but plain text does not survive an injection.

SO THE ORDER TO CONFIGURE A SEAT IN HAS FOUR RUNGS. ONE, the tool's own
delivery command where one exists, set as `INJECT_CMD`, because it addresses
the seat by identifier instead of by whatever holds focus and needs no
permission (`codex queue --thread <task-id> --message '<line>'`). TWO, a CLI
in a named multiplexer session, since `tmux send-keys -t <session>` names its
target. THREE, a desktop window the seat owns alone. FOUR, a headless entry
point with `bin/notify.sh`.

ONE INJECTOR HOLDS THE KEYBOARD AT A TIME. The front window and the
clipboard are machine-wide, so two keyboard injections at one moment fight
over both and neither is broken on its own. The keyboard paths take a
machine-wide lock; `INJECT_CMD` does not, because a command addressing a
seat by identifier needs no window and must not queue behind one. An
injector that cannot take the lock reports that it typed nothing and asks
for a retry.

THE WATCHER'S LOCK HAS THE MATCHING LIMIT. It covers only the turns the
WATCHER starts, so a turn a person begins by typing is outside it and an
arriving change can be injected beside it. Stop the watcher before working
in a seat's window by hand, or have the seat take the same lock at the top
of its own turn, which section 7 asks of it.

STARTED IS EMITTED BEFORE THE TURN IS KNOWN TO SUCCEED, so a seat that then
dies has still said it was alive. The notifier's output is discarded and its
failures ignored: a broken view must never break the bus, and the suite
holds that.

THE MASTER MUST NOT READ SILENCE IN A SEAT'S WINDOW AS EVIDENCE OF ANYTHING
on level two or three. The branch is the evidence. Telling the user which
level a seat is on is worth more than any promise about visibility.

UNATTENDED TURNS OWE THE TRACE MOST. A poke-driven or watcher-started turn
has no human in front of it, so it writes both reports into the session
transcript and not only into git, and raises a native notification where the
platform has one. Where the watcher only appends to a file and no turn
starts on arrival, the arrival line goes at the TOP of the next turn and
names when the message landed as well as when it was read: that gap is the
honest measure of the platform's floor.

