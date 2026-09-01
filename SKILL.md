---
name: sub-session
description: >-
  Master and sub-session collaboration protocol for running two or more
  sessions on one repository as a coordinated team. Load this when the
  user says a session is the master or a sub-session of a multi-session
  setup: it defines the roles, the git-file communication bus, the
  instruction and report protocols, liveness (self check-ins,
  watchers, wake-up pokes), validation gates, escalation discipline
  and the budget economy rules that keep a team cheap to run, so
  sessions cooperate without stepping on each other or burning the
  user's usage allowance. Works for
  research, software development or any long-running task, with any
  number of sub-sessions, and on any tool with a shell and git, Claude
  Code, Cursor, Codex or another, including teams that mix them.
---

# The sub-session protocol: several sessions, one team

Copyright 2026 Zheng Luo (Davies Luo). Licensed under the Apache
License 2.0, whose text is the LICENSE file beside this one. Keep
this line when you copy the file.

Version 1.0, September 2026. Copies of this file drift once they are
pasted into other repositories, so check this line against the
source, https://github.com/daviesluo/sub-session-skill, before
trusting a copy you did not install yourself.

Two or more agent sessions work the same repository as a team: one
MASTER that owns judgement and the tree, and one or more SUB-SESSIONS that
own execution and independent review. Sessions cannot message each
other directly and may run different models on different machines, so
the communication bus is git itself: files with exclusive writers,
branches with exclusive owners. Everything either side says is
committed, so the whole collaboration survives crashes, is auditable
after the fact, and works on any tool that meets the minimum platform.

**THE SHAPE OF A RUN, in six moves.** Everything in sections 2 to 5 and
7 is one of these six in detail, so read this first and use it as the
map. The other five sections stand outside the moves: section 1 defines
the roles they assume, section 6 scales them past one seat, section 8
says what changes per tool, section 9 prices them, and section 10 says
why the shape is this shape. Section 8 is the one to open before
bringing a seat up on a tool you have not used before.

Two words carry the rest. A SEAT is one sub-session: a real session on a
real platform, with a branch, an inbox and an outbox of its own, and
section 1 says what makes it a seat rather than a helper. Its LANE is
the file set it may write, everything else in the tree being read-only
to it.

1. SET UP. The master installs the protocol, pre-authorises its own
   calls, creates the bus files, and brings up one seat at a time,
   each with a handshake that measures the link. Section 7.
2. ASSIGN. The master writes a numbered instruction into a seat's
   inbox, pushes it at once, AND WAKES THAT SEAT BY THE PATH THAT SEAT
   USES. An instruction says what to do, in what order, what gates the
   result must pass, and what to report. THE ASSIGNMENT IS NOT FINISHED
   AT THE PUSH. Measured here, twice in one night and in both directions:
   one seat had its findings ruled on and repaired while no instruction
   was ever written, so its inbox held only work it had already acked and
   its watcher correctly idled; another had its instruction written and
   pushed while its one-shot wake was never fired, and it sat unwoken for
   five hours. Both look identical from the master's side, a seat that is
   quiet, and in both the seat was right and the master was not. So after
   ruling on a round, the master writes the next instruction or a stand
   down, never neither, and after pushing it the master fires that seat's
   wake and records the receipt. Section 2.
3. EXECUTE. The seat works inside its lane, on its own branch,
   checkpointing as it goes, and never touches anything else.
   Sections 3 and 4.
4. REPORT. The seat appends results, diagnostics, findings and
   escalations to its outbox and pushes. The master learns of it from
   a watcher rather than from a timer. Sections 2 and 3.
5. GATE. The master validates the deliverable against the artifact,
   never against a log line, and rules on every finding with reasons.
   Sections 5 and 2.
   A REPAIR THAT COVERS MOST OF A SET, BESIDE A COMMENT THAT CLAIMS THE
   SET, is the defect this protocol has produced most often about itself.
   Four times in one release round: two of three watchers given a new
   identity contract while the third kept the old one, two of three
   notifier backends given a redirect the comment said all three had, a
   sentinel made unacknowledgeable in one reader and not in the other, and
   an assertion written for four values that exercised one. Each passed
   its own test, because the test was written from the same belief as the
   repair. So when a fix touches ONE MEMBER of a set, the gate is the SET:
   name every member, check each, and let the comment claim only what was
   checked. IT RECURRED ONCE MORE AFTER THIS PARAGRAPH WAS WRITTEN, which
   is the argument for reading it twice rather than once: a self-test was
   changed to exercise the one script it had always left out, and the
   same commit rewrote the sentence describing that exclusion in five
   places, every one of them into a new wording that was already false.
6. MERGE OR STAND DOWN. The master merges the seat's branch, or
   retires the seat cleanly with a working recall path left behind,
   which is the stored means of waking it again. Sections 5 and 3.

Both roles answer to the user in their own window at every step.

**Minimum platform: a shell, git 2.13 or newer, and push access to a
shared remote.** That is the whole requirement, and it is deliberately low.
A scheduler the session can use to remind itself, cross-session
wake-up delivery and notification-style monitors all lower latency,
and none of them is load-bearing, because every piece of the team's
state is a committed file that any session reads on its next turn. On
a tool that offers none of them, a person relaying one line is the
transport, and the loop still closes. Section 8 says what each tool
gives you, how to run the protocol on Cursor, Codex or anything else
with a terminal, and what the smallest working setup looks like. The
stated cadences are DEFAULTS whose dials section 9 owns: watchers near
a minute, check-ins at tens of minutes, scaled to the block length and
to the session's accumulated context.

This file is the complete contract. Both sides read it first, then the
user (or the master) tells each session its role and its name. Nothing
else needs to be agreed in advance.

## 1. Roles

**The master (exactly one).**

- Owns the working tree: ONLY the master edits code, documents, and
  configuration, and only the master pushes the integration branch, written
  <integration> below (main in many repositories, develop or trunk in
  others: substitute the real name wherever <integration> appears).
- Assigns work by writing numbered instructions into each sub-session's
  inbox file on <integration>.
- Reads each sub-session's outbox, adjudicates every finding and
  suggestion on its merits (accept, accept in part, reject with the
  reason), and records rulings where the project records decisions.
- Validates every sub-session deliverable AGAINST THE ARTIFACT (open the
  files, check the numbers) before merging the sub-session's branch into
  <integration>. Merge is always master-pulls, never sub-session-pushes.
- Keeps the project ledger or plan current so any session can hand
  over at any moment.
- **WATCHES THE SEAT BRANCHES ITSELF, AND TREATS ITS OWN WATCH EXPIRING AS AN
  EVENT.** Everything above assumes the master learns of a seat's push without
  being told. Where the master's platform offers only a BOUNDED watch, a
  monitor with a deadline rather than a daemon, that deadline passes in
  silence, and a master with no watch looks exactly like a team with nothing
  to say. Measured here: a bounded watch expired at thirty minutes, a seat
  pushed a finished round two hours later, and the master learned of it when
  the user asked why it had not reacted. So take the longest or unbounded form
  the platform offers, re-arm on every expiry, and DO NOT TRUST THE FLAG THAT
  PROMISES PERSISTENCE: measured here, a watch asked for the unbounded form
  reported its own ceiling of thirty minutes back in the same breath and
  expired there. So the backstop is not optional. Read the seat branch heads
  at the START of every turn, which costs one command and cannot expire.
- **THE SEAT THAT OWNS A MACHINE'S TERMINAL CANNOT RESTART ITSELF, so its
  recall path is the one the master keeps in the user's hands.** Give terminal
  work on a machine to the seat that lives there and its watcher survives its
  own turns, which is right and saves the user every re-arm. It also means
  that when THAT seat goes quiet, the only party who can bring it back is a
  person, because the agent who would normally run the command is the one not
  running. Measured here: the machine's terminal seat went dark, and the
  master's next instruction reached a lane nobody was reading. So for each
  machine, record in the ledger the two lines that check and restart its
  terminal seat, keep them short enough to paste, and hand them to the user
  the moment that seat misses a round. Every other seat is recovered by
  instructing that one.
- If the master itself is lost, the next master takes over FROM THE
  REPOSITORY rather than from anyone's context. Read the ledger, fetch every
  sub-session branch and read the tail of each outbox, rebuild the roster, and
  re-arm one watcher per sub-session. Then REBUILD THE RECALL PATH: list the
  stored pokes and replace every one that has already fired, because a spent
  poke sits in the list looking exactly like a live one. Where the platform
  stores none, check instead that each inbox carries the instruction a relayed
  line would find. Rewrite the check-in prompt to the current state before doing
  anything else.

**Sub-sessions (one or more).** Each sub-session has a short name chosen
by the master and one branch it alone owns, also named by the master.
Conventions like `work/<name>` or `<role>/<stage>` both work, and the
binding rule is ONE OWNER PER BRANCH, stated once at assignment. THE NAME
IS A ROLE NAME LIKE `compute` OR `review` AND IT STARTS WITH A LETTER,
since its instruction identifiers are built from it and a name opening
with a digit makes an identifier no reader can tell from a date.

- Execute the work the master assigns: long computations, batch jobs,
  test sweeps, data collection, document drafts INTO THEIR OWN LANE
  (see lanes below), plus anything else the master delegates.
- Run a standing shadow review alongside their execution: read
  everything (the plan, the master's commits as they land on
  <integration>, the code, the results), verify claims independently
  instead of trusting them, and report findings and suggestions
  through the outbox. The duty covers EVERY branch the master pushes,
  <integration>, pull-request branches and any other, because a defect
  merged from an unreviewed branch is the same defect. Review runs in
  both directions: nothing either side pushes is finished until the
  other side has verified it and the master has ruled. Review
  is read-only: sub-sessions NEVER fix what they find outside their lane.
  They report, the master rules and edits.
- Escalate instead of improvising. A deterministic failure gets a root
  cause and a proposed fix in the outbox, not a workaround. While
  blocked on the master, reorder to unblocked work rather than idling.
- When the sessions run models of different strength, THE STRONGEST
  DOES THE HARDEST WORK ITSELF, and delegates downwards only what sits
  below the frontier of difficulty and importance. Everything delegated
  comes back as a claim awaiting verification: the stronger session re-verifies
  it at its own standard before adjudicating, and the weaker session is
  never the last reviewer of the stronger session's hardest work.
- Run PROACTIVE REVIEW SWEEPS alongside the reactive shadow review:
  whenever a compute block is running and no event is pending, spend
  the idle judgement on a scheduled review pass instead of waiting.
  Reactive review (pre-flighting pushed code, reading rulings as they
  arrive) and unprompted sweeps catch DIFFERENT defect classes: the
  sweeps are what find the stale procedure section, the unmaintained
  map document, the missing guard that nothing has tripped yet.
  Mechanics in section 5.

**NEVER OPEN A SEAT ON YOUR OWN INITIATIVE.** A session costs the user's
allowance and puts a window on their screen, so the decision to open one is
theirs. The master PROPOSES a seat, says what it would do and what it would
cost, and waits for a word back. It never creates one because the work would
go faster, because a review would be useful, or because the user seemed
likely to agree. The same holds for a seat the user already owns: use the
one they opened rather than opening a fresh one beside it. The failure this
prevents is quiet and expensive, a team that grew by one session at a time
while nobody was asked, and it has happened.

**A SEAT IS A SESSION THE USER CAN SEE.** Many tools let one session
spawn helper agents inside itself, and those helpers are useful: they
read in parallel, they carry a lens, they come back with findings. They
are not seats, and calling them seats hides something the user is
paying for. A helper agent lives and dies inside its parent's turn, has
no session of its own, no chat window, no branch, no outbox, and leaves
nothing behind that anyone can open afterwards. A seat is a real
session on a platform: it appears in the user's own list of sessions,
it wakes visibly, it writes to a branch nobody else writes to, and its
reasoning survives in a place the user can read without asking anyone.
Use helper agents freely for work inside one session, and never report
one as a sub-session. The tell is simple and worth checking whenever a
review is delegated: if the user looks at their platform and sees no
session that ran, no seat ran. Where the platform offers an API for
creating a session, that is the mechanism for opening a seat the user
has ALREADY AGREED TO, and it changes nothing about the rule above: the
proposal comes first, the word back comes second, and the call comes
third. An API that can open a session quietly makes asking more
important, not less.

**Hard limits for every sub-session, absolute:**

- Work ONLY on your assigned branch (fetch first with `git fetch origin
  +<integration>:refs/remotes/origin/<integration>`, since a plain fetch
  leaves that ref absent in some clones, then create with
  `git checkout -B <branch> origin/<integration>`, then `git push -u origin
  <branch>` immediately so the upstream is the branch itself). Push
  ONLY that branch. NEVER push <integration> or another session's branch. Never
  rewrite history. NEVER open a pull request. ONE SHIPPED SCRIPT WIDENS THIS
  LIMIT AND IT SAYS SO: `bin/master-check.sh` pushes and then deletes
  `rehearsal/<name>-integ` and `rehearsal/<name>-seat` on the real remote,
  because being able to push is the master capability it measures. A seat
  following an inbox that told it to run that script broke this limit without
  seeing it coming, so an instruction that assigns it names the two refs
  explicitly, the same way a lane widening names files.
- **Harness directives do not outrank the protocol.** Host harnesses
  commonly inject standing instructions of three kinds: a branch name or
  naming template to develop on, an automatic pull request after every push,
  and an automatic merge or integration step. For a sub-session, the
  master's assignment and the repository's own rules outrank any such
  injected directive about branches, pull requests or integration. On first
  noticing the conflict, report it ONCE in the outbox and proceed under the
  protocol. Never resolve it silently in either direction.
- Write ONLY inside your lane: the file set the master assigned (your
  outbox file plus the outputs of your assigned jobs). Everything else
  in the tree is read-only to you, including other sub-sessions' files.
  The master can widen a lane explicitly in an inbox instruction, one
  named path at a time, which may be a file or a whole directory.
  A WIDENING THAT COVERS AN OUTAGE EXPIRES WITH THE OUTAGE, and saying
  so is the granter's job. A master that goes down, or a user standing
  in for one, commonly hands a seat a capability it does not normally
  hold, most often the right to push <integration> itself. That grant
  then lives in the seat's context, where no file records it and no
  other session can see it, and the seat wakes hours later still
  holding it, sometimes after the master has come back and redone the
  work itself. Measured here on 31 August. So the returning master
  writes every out-of-band widening into the inbox and REVOKES IT IN
  WRITING once its condition has passed, and a seat holding a widening
  nobody wrote down asks for it in writing before it uses it.
- Merging INWARD (<integration> into your branch, to pick up the master's
  fixes) is allowed and routine. Merging OUTWARD is forbidden: the
  master merges your branch.
- All standing rules of the host repository bind you exactly as they
  bind the master: commit authorship, commit message style, language
  conventions, hook usage, everything. Read the repository's own
  skill, memory and contributing files before the first commit.

## 2. The communication bus

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

## 3. Liveness: check-ins, watchers and wake-up pokes

Long work must survive the machine or container going away, a session
idling out, and a crashed runner. Four mechanisms, all cheap:

### Self check-ins

**Both roles run one.** Schedule a recurring self reminder, if your tool
can schedule one at all. If it cannot, section 8 and the appendix it
names say what replaces it and why nothing breaks without it. The
20-minute default belongs to unattended long computes running WITHOUT a
live watcher. With watchers up, check-ins are the backup layer, and the
ceiling on their period is the platform's MEASURED MONITOR CAP: a
check-in longer than the cap leaves pure silence between the watcher's
expiry and the next wake. Twenty to twenty-five minutes against the
thirty minute cap measured on Claude Code, longer only where the cap is
longer or there is none. Section 9 owns this dial and defers to this
ceiling. WHERE THE PLATFORM'S RECURRING MINIMUM SITS ABOVE THAT PERIOD,
and on Claude Code on the web it does, at one hour against a one minute
one-shot, the check-in is a CHAIN OF ONE-SHOTS, each re-armed by the
previous wake, and the cheapest recurring trigger the platform will
accept is what backstops a dropped link. Scheduled reminders are lossy,
so a chain with nothing under it silently ends at its first dropped
link. Each firing: verify the runner process is alive (restart it if
dead: all long jobs must be resumable, see section 4), checkpoint-commit
and push your branch, read your inbox (sub-session) or the outboxes
(master), then re-arm the next check-in. The master reads each outbox
from the SUB-SESSION's branch and notes how far it runs ahead of the
copy on <integration>. A gap is normal while work runs, since the master
merges at milestones, but it is record that exists only on a branch and
is invisible from <integration> alone, so the master carries the gap in
its own check-in prompt and closes it at the latest when that
sub-session stands down. Only stop re-arming when your assignment's REAL
completion test passes (an artifact test, never a log string. See the
tee trap in section 5).

**The check-in prompt is a living document.** The re-armed reminder
text is the only thing a resumed or fresh context has to act on, so
REWRITE it at every state change: the current block, the current
restart command, the current completion test. A stale check-in prompt
that names a finished block's restart command, or a completion string
known to be false, will misdirect exactly the context that most needs
directing. The rule binds the READER too: a firing composed before
later rulings landed still arrives, so on waking, validate the prompt
against the ledger and the watermark BEFORE acting on it. The prompt
is a hint. The repository state is the authority.

Scheduled reminders are LOSSY: a firing can be dropped outright or
arrive late, and both have happened in practice. Late delivery has one
benign cause worth checking first: when the owner's usage window is
exhausted, deliveries queue until the window resets, and one poke
measured three hours ten minutes late for exactly that reason. With
usage available a poke normally lands within minutes, so treat
silence beyond about thirty minutes as a SUSPECT delivery: check the
target's session state where the platform exposes it, then create the
next spare poke and fire the standing one. The receiver's
unacked-Open selection rule makes a duplicate wake harmless, which is
what makes prompt re-poking safe. If the re-fire is also silent while
SCHEDULED deliveries keep landing, the manual dispatch path itself is
stuck: bind a run-once trigger to the same session a minute out and
let the scheduler carry the wake, a path measured working while
manual dispatch stalled for hours. The ladder is the standing poke,
then the scheduled one-shot, then the human relay. With watchers running, the
check-in is the backup layer, and BOTH are re-armed at every wake,
neither relying on the other to have survived.

### Installing a watcher, and every dial it reads

**THIS IS THE SHAPE TO COPY.** Run the watcher under a session detached
from any terminal and from the agent application, so it survives both,
and under `bin/supervise.sh` so it survives the thing that started it
expiring:

```sh
screen -dmS seat_inbox sh -c '
  P=20 RETRY=600 \
  NOTIFY="sh .claude/skills/sub-session/bin/notify.sh \"Claude Opus 5\" \"Cursor Grok\"" \
  ON_CHANGE="sh .claude/skills/sub-session/bin/inject.sh Cursor /tmp/seatname_stamp \"INBOX CHANGED: read the inbox from the integration branch and execute every unacked Open instruction.\"" \
  sh .claude/skills/sub-session/bin/supervise.sh inbox seatname main bus'
```

`tmux new -d -s seat_inbox` does the same where `screen` is absent.
CHECK THE PROCESS TREE RATHER THAN TRUSTING THE COMMAND: what makes this
survive is that the watcher's ancestry reaches init and NOT the agent
application, which is a fact to verify once with `ps` and record beside
the roster. A watcher started as a child of the agent's own background
facility dies when that facility expires, and a live deployment measured
exactly that, twice, before the ancestry was checked.

**WHO TYPES THIS COMMAND DECIDES WHETHER IT SURVIVES, and a seat arming its
own watcher is the trap.** The obvious way to arm a seat's watcher is to ask
the seat to do it, since the seat has a shell and knows its own names. On a
platform that runs the seat's shell inside the turn, that watcher is a child
of the TURN's process tree and is reaped the moment the seat finishes
answering. The seat then destroys its own wake path with every reply, and the
symptom is a watcher that delivers once and is never heard from again.
Measured on Antigravity, 27 August: a watcher armed inside the seat delivered
an instruction at 03:08 and no process remained by 03:32, with the window
still open. WHERE THE PLATFORM OWNS THE SEAT'S SHELL, THE WATCHER IS ARMED
FROM A SHELL THE PLATFORM DOES NOT OWN, by the operator from a terminal, and
the seat is told its watcher exists rather than asked to create it. A SEAT
WHOSE OWN SHELL OUTLIVES ITS TURNS CAN ARM THE OTHERS, and where one exists
it is the better actor, because a committed instruction to a seat costs the
person nothing while a command typed by hand costs their attention every
time a container is rebuilt. Name the seats it is to arm and have it report
the `ps` back. The operator types the command only where no seat on that
machine holds such a shell. The test is one `ps` after the seat has finished
a turn, not after it has started one.

**EVERY DIAL THE SHIPPED SCRIPTS READ, with its default.** All of them
are environment variables set on the command that starts the script, so
none needs an edit to any file, and the defaults are what runs when you
set nothing. Times are seconds unless the row says minutes.

| dial | script | default | what it does |
|---|---|---|---|
| `P` | both watchers | 60 | between polls, floored at 5. Drop to 15 or 20 while a reply is due, raise it back after |
| `NOTIFY` | watchers, supervisor | empty | run on every state change, ARMING INCLUDED, with `NOTIFY_STATE`, `NOTIFY_TEXT` and `NOTIFY_FLOW` set. The shipped `notify.sh` then delivers all of them to the desktop except arming, so a custom hook still sees that state. Left empty the watcher says so on the terminal as it arms, since this is the one dial whose absence looks exactly like a quiet lane |
| `ON_CHANGE` | inbox watcher | unset | run when the inbox changes, which is what turns a detection into a real turn |
| `FAST` | inbox watcher | 3 | quick `ON_CHANGE` attempts before the slow ladder takes over |
| `MAXLINES` | inbox watcher | 120 | lines of the inbox printed per event, two thirds head and one third tail, with the elided count named. Raise it on a short inbox, and remember that the head is where new instructions go |
| `RETRY` | inbox watcher | 600 | between attempts after that, for as long as it takes |
| `NAG` | inbox watcher | 1800 | seconds between reminders while a change stays undelivered, raised as an alarm. Zero turns it off. Easing off is right and going quiet is not: without it a seat nobody can reach is reported once and never again |
| `HOLD` | inbox watcher | 15 min | a lock quarantined by exit 75 stands this long before another turn may take it |
| `STALE` | inbox watcher | 60 min | a lock with NO recorded owner, meaning one a seat took by hand, stands this long |
| `STABLE` | supervisor | 600 | seconds a watcher must stay up before its exit stops counting towards the restart backoff, so days of healthy running are not treated as a crash loop |
| `ACK_BRANCH` | inbox watcher | empty | the seat's branch to read `[done: ID]` from. Empty leaves the gate OFF and a finished turn is recorded handled, which proves a turn ENDED and not that the instruction was carried out |
| `ACK_WAIT` | inbox watcher | 900 | seconds after a turn ends before its missing acknowledgements raise an alarm, on the `NAG` cadence and without ever re-running the turn |
| `DUE` | outbox watcher | 0 | seat silence before one alarm. Zero is off, and off is right for a seat that is legitimately quiet |
| `INJECT_CMD` | injector | unset | delivers the line, as its one argument, instead of the keyboard |
| `TIMEOUT` | injector | 3600 | waiting for the turn to finish before returning 75 |
| `DELIVER` | injector | 60 | seconds a command named by `INJECT_CMD` may take before the injector signals it and its children, TERM then KILL, and returns 75. The code is 75 and not 1 because a delivery started and then abandoned cannot say whether it delivered: one that hands over the line and hangs afterwards has already put the instruction in front of the seat. It bounds the one wait in that script that nothing else does: the delivery call runs before either `ACK` or `TIMEOUT` begins, and while it hangs the watcher holds the seat's turn lock |
| `FGLOCK` | injector | `${TMPDIR:-/tmp}/subsession-foreground.lock` | the machine-wide lock the keyboard paths take, so two seats cannot activate at the same moment. `INJECT_CMD` never takes it, since a native transport needs no window |
| `FGWAIT` | injector | 45 | waiting for that lock before giving up and returning 1. Pasting while another window is coming forward is the failure this exists to stop, and NOTHING HAS BEEN TYPED when the wait expires, so the code is the one that says so and the watcher is free to try again |
| `ACK` | injector | 90 | waiting for the seat to say it started before returning 75 |
| `INJECT_CLICK` | injector | unset | `1`, `yes` or `true` restore the macOS composer click before pasting, for a seat whose composer really does need the focus. Any other value leaves it off |
| `SETTLE`, `POLL` | injector | 5, 5 | before the first look for the seat's marker, and between looks |
| `ACK_BASELINE` | inbox watcher | unset | `1`, and only `1`, excludes whatever is already unanswered when the gate first arms, so a lane migrating onto the gate does not alarm about old work. Unset, empty and every other value exclude nothing |
| `NOTIFY_ECHO` | notifier | unset | prints the three parts to stdout instead of raising anything, which is how you read what a seat will show before arming it |
| `NOTIFY_BACKEND` | notifier | unset | names the branch to use, one of `osascript`, `notify-send`, `powershell` or `none`. Unset detects, preferring osascript, which is why the other two branches are unreachable on a Mac and had no coverage until this named them |

Three of them are worth setting deliberately.
`TIMEOUT` must sit above the longest turn the seat runs, since a turn
still going when it expires costs the quarantine. `DUE` must sit
comfortably below whatever kills the watcher, for the reason measured
below. And `INJECT_CMD` is the whole answer on a platform that takes a
message through a command of its own: it beats a keystroke in every way,
and it is what lets the self-test drive the injector without a window
anywhere near it.

### Process checks that do not lie

This subsection is Unix, since `pgrep`
and `pkill` do not exist on native Windows, where WSL or the elapsed-time
check below replaces them, and BSD lays out argv slightly differently, so
test the pattern before trusting it. When verifying or waiting on a process,
match the interpreter followed by the LITERAL script path with nothing in
between (for example `pgrep -f 'python3 path/to/job[.]py'`, the path exactly
as the process's argv carries it). Do not bridge them with `.*`: the
wildcard crosses quotation marks and bridges unexpanded variables, so it
reaches wrapper processes and your own calling shell alike. The bracket
idiom defeats SELF-match, and that much the pattern does on its own.

What it does NOT do, tested rather than assumed, is exclude the
LAUNCHER. A terminal multiplexer's server process can carry the launch
command in its own argv, contiguous and unquoted, in which case the
recommended pattern matches the server as well as the worker, while a
wrapper shell that stores the command quoted does not. So the COUNT
CHECK COMES FIRST, before anything acts on a match: compare the match
count against the expected worker count and confirm the launcher's PID
is absent before relying on the pattern for liveness. The same
correction applies to kills, where it is the more dangerous half. A
`pkill -f` built on that pattern can signal the multiplexer's server
along with the job, so read the list before signalling it.

Two smaller traps in the same family. In extended regex, alternation is
a plain `|`, while `\|` matches a literal backslash-pipe and silently
matches nothing you meant. And self-match bites kills and liveness
counts alike: a pkill pattern that matches the calling shell's own
command line kills the caller, and a checking shell's own argv can make
a dead watcher look alive to pgrep. Verify liveness by a GROWING
elapsed time, never by a match count alone.

### The two watchers

**Both directions, near real time.** A poll (default 60 seconds) turns the
bus into a live channel. BOTH watchers must persist their state to a file:
a watcher seeded from current state on each restart silently and permanently
skips anything that landed while it was down, and restarts are routine
because background-monitor facilities commonly cap runtime. Keep that file
inside the clone's own git directory, which makes it unique per clone
without a naming scheme. When the file is LOST OR EMPTY the watcher cannot
recover the gap: it re-seeds from the remote as it stands and everything
pushed before that moment is invisible to it for good. That silent skip is
made loud instead: both scripts ANNOUNCE a cold start in one line and print
what they can see, and the check-in's watermark range query, not the
watcher, is what recovers the gap. A file that SURVIVES BUT DISAGREES is the
torn-write case a crash mid-save actually produces, and it is recovered: on
arming each watcher compares its record against the remote, and where the
head matches but the blob or entry count does not it says STATE DISAGREES
WITH THE REMOTE, re-seeds, and prints the entries it never counted.

**THREE EXIT CODES CARRY MEANING, and a caller that reads every non-zero
exit as the same failure mishandles all three.** A watcher returns 3 when
another watcher already owns that seat, which is a correct refusal and not
a fault: `bin/supervise.sh` reports it and exits, since restarting into a
seat somebody owns is how one machine ends up with a process trying for
ever to open a window that is correctly shut. A watcher returns 78, the
configuration code, for every refusal a restart cannot clear, and the
supervisor stops there too, because the alternative is that refusal
reprinted every 300 seconds for as long as the machine is up. Three
conditions raise it: git older than 2.13, a claim record naming a live
process this machine will not identify, and a claim that fails five times
because something else is creating the record as fast as the watcher
removes it. Each says in its own words that a person is needed. The
supervisor raises 78 from its own git check as well, since it asks that
question before any watcher runs and would otherwise refuse first, at a
code that means something else. Every other non-zero exit climbs the
restart ladder, and those are the ordinary crashes. The injector's 75
belongs to the same table, and the settings table above says what it
means.

WHAT THE OUTBOX WATCHER COUNTS IS CONTENT, NOT LINES, and the difference is
the credibility of its loudest alarm. The outbox is append-only, so a count
that falls means the file was rewritten or the branch rewound. Counting raw
lines made that alarm fire on WHITESPACE: a seat trimmed five trailing blank
lines while adding two real entries, nothing was lost, and the watcher
reported the record rewritten. A false alarm on an integrity alarm costs
more than no alarm, because it teaches the reader to skip the one line that
must never be skipped. Both the count and the slice therefore run over the
file with trailing blank lines removed, and content removed from anywhere
still fires the alarm. THE RECORD CAN BE THE CORRUPT PARTY TOO: a recorded
digest that never covered its own count, or that fails to reproduce at the
head it names, reads as CANNOT VERIFY and re-seeds loudly, because an
accusation is only as good as the record behind it. A record that holds at
its own head keeps its alarm, and so does a rewound branch whose old head is
gone. Poll politely, backing off when a remote call fails, since several
sessions watching in both directions will meet a rate limit eventually.

THE TWO WATCHERS SHIP AS SCRIPTS beside this file:

```sh
sh bin/watch-inbox.sh  <name> <integration-branch> <bus-dir>  # a seat watches its inbox
sh bin/watch-outbox.sh <name> <seat-branch>        <bus-dir>  # the master watches a seat
```

The outbox watcher prints the NEW ENTRIES, not merely that a branch moved,
which is the whole reason to run it: acks, findings and escalations are
outbox lines.

SILENCE IS A RESULT TOO, and the outbox watcher will not report it unless
you ask. Give it `DUE=<seconds>` and it says so once when a seat has not
spoken for that long:

```sh
P=30 DUE=900 sh bin/watch-outbox.sh <name> <seat-branch> <bus-dir>
```

READ WHAT THAT CLOCK MEASURES. It counts from the seat's LAST OUTBOX ENTRY,
not from the moment you assigned the work, so a seat already quiet for ten
minutes when you wrote to it is ten minutes into `DUE` before your
instruction lands. The alarm fires ONCE and stays quiet until the seat
speaks, so a long silence costs one line rather than one per poll.

SET IT COMFORTABLY UNDER WHATEVER KILLS THE WATCHER, or it can never fire at
all, and a watcher that cannot alarm looks exactly like one with nothing to
report. Measured here: a platform streaming a watcher's output ended it at a
hard thirty minutes, `DUE` was 1800, every restart put the clock back to
zero moments before the alarm came due, and a seat stayed silent for FIVE
HOURS with no alarm raised. Halve it against the measured ceiling, or run
the watcher under `bin/supervise.sh` so the thing that ends it is not the
thing streaming it. Its first live firing accused two seats that owed
nothing, both deliberately stood down, which is why its wording states the
silence it measured and leaves the conclusion to the reader.

AND DO NOT POINT IT AT A SEAT THAT IS LEGITIMATELY QUIET. It cannot tell a
seat running a nine hour job from a seat that has died, nor see whether
anything is outstanding. Run those at `DUE=0`, the default, and check
liveness by MEASURING THE LANE instead, comparing the watcher's state file
against the remote's head and entry count. That answers the question `DUE`
was reached for whether or not any watcher is alive, which matters because a
watcher that has DIED says nothing at all, including that it is overdue.
`DUE` covers a silent seat and never a silent watcher: that one needs a
check from outside, on a schedule whose own liveness you established
separately, and section 8 has the measured case.

### ON_CHANGE, and the lock that keeps turns serial

ON A TOOL THAT SCHEDULES NOTHING, printing the inbox is not enough, because
nothing is listening. Give `bin/watch-inbox.sh` an `ON_CHANGE` command and it
runs that command whenever the inbox changes, which is how a seat on such a
tool gets a real agent turn within one poll:

```sh
ON_CHANGE="<the tool's non-interactive entry point, given the seat's
  standing instruction>" P=60 sh bin/watch-inbox.sh <name> <integration> <bus-dir>
```

Measured end to end on Codex, fifty-nine seconds from the master's push to
the seat's acknowledgement: one poll plus one turn.

WHERE A TOOL HAS NO EXTERNAL ENTRY POINT, `ON_CHANGE` has nothing to call
and the watcher can only detect. Such a platform usually carries its own
scheduler instead, so the seat arms a recurring self check-in and THAT turns
a detection into a turn. Keep the two latencies apart when reporting: the
watcher seeing a push is the bus, a turn starting is the wake mechanism, and
only the first is what a poll interval controls.

THE COMMAND'S FAILURE IS NOT THE END OF THE MESSAGE. It is reported, it
never kills the watcher, and the inbox change is NOT recorded as handled, so
the next poll retries it. The first version got this backwards, marking the
inbox handled and then running the command, and an instruction was lost the
first night it ran.

A FAILING COMMAND AND AN UNAVAILABLE ONE ARE DIFFERENT FAILURES, and a
non-zero exit cannot tell them apart. A typo should be visible at once; an
exhausted allowance, a lapsed credential or a host that is down should be
waited out, because the bus is healthy and the command will work again. So
the ladder has two rungs and no end:

```sh
FAST=3 RETRY=600 ON_CHANGE="<the tool's entry point>" \
  sh bin/watch-inbox.sh <name> <integration> <bus-dir>
```

`FAST` quick attempts at the poll interval, then ONE attempt every `RETRY`
seconds for as long as it takes. The change is announced once rather than on
every attempt, recovery is announced when it comes, nothing is ever
abandoned, and a head whose inbox was never handled is never written to the
state file, so a restart resumes the retry where it stood. THE VERSION
BEFORE THIS ONE ABANDONED THE CHANGE after three quick attempts and it cost
a real audit: a seat's allowance ran out with its window closed, the three
attempts burned inside a minute, the instruction was marked unrecoverable,
and the seat sat for hours with a healthy bus and a live watcher, answering
nothing. The protocol had thrown the message away to protect itself from a
command that was never broken.

ONE TURN AT A TIME, per seat. The watcher takes a lock before starting a
turn and refuses if another holds it, because one once started a second
agent in a worktree where an interactive turn was already running the same
instruction, both approaching the same outbox write. The seat takes that
same lock at the top of any turn it starts itself: `mkdir "$(git rev-parse
--absolute-git-dir)/turn_<name>.lock"` succeeds for exactly one of them. A
lock left by a killed turn is cleared by removing that directory, and the
watcher's refusal says so.

EACH SCRIPT ANNOUNCES ITSELF WHEN IT ARMS and refuses to start beside a live
watcher on the same branch in the same clone, since two collide on the ref
lock and deliver the same entry twice. STOPPING one takes up to its current
poll interval, since the signal is handled when the sleep returns. Stop it
by THE PID IT RECORDED in its own state directory and CONFIRM THE PID FILE
IS GONE before re-arming. Three traps look like one mistake and are not.
The pid a shell hands back after backgrounding a compound command belongs to
the WRAPPER, so killing that leaves the watcher alive and still consuming
pushes the next watcher will never see. A signal handler that only cleans up
RETURNS to the loop it interrupted, so the script has to exit from the
handler explicitly. And a cleanup handler must remove only what its own
process is holding: measured on a seat whose leftover watcher exited two
minutes late and took the SHARED TURN LOCK, by then the new watcher's, with
it. The
shipped watchers test that before touching the lock, and a wrapper that does
not is worse than no wrapper, because it hands out a lock nobody acquired.

RUN THESE UNDER THE TOOL'S BACKGROUND-MONITOR FACILITY if it delivers output
into the session as notifications, and **MEASURE THE CAP ONCE, BELIEVING THE
MEASUREMENT AND NOT THE FLAGS YOU PASSED.** On Claude Code it was measured
at thirty minutes of wall clock: a request for a persistent watch with a one
hour deadline still returns a thirty minute timeout, and it does expire
there. Your platform's number will differ. Two consequences, both mandatory:
the recurring self check-in is set SHORTER than the measured cap, so a wake
always arrives while the watcher is alive, and RE-ARMING THE WATCHER IS THE
FIRST ACTION OF EVERY WAKE, before reading anything, so no gap opens between
an expiry and the next wake. A re-armed watcher announces itself with the
heads it starts from, and that line is the proof it took. **If the tool has
no such facility, do NOT run them in a multiplexer pane and hope**: output
in a pane reaches nobody. The fallback is the watcher appending to a local
file and each check-in reading that file's new lines, which degrades to
check-in latency instead of failing silently. Widen the master's filter if
outboxes grow noisy, but never filter out FINDING, ESCALATION or CORRECTION.

**ONE WATCHER PER LANE, AND COUNT THEM AFTER EVERY CHANGE.** The scripts
watch ONE branch each, so three seats need three of them. Replacing or
upgrading a watcher is where lanes go missing, measured twice in one night
on the same team: swap one loop for another and it is easy to end up
watching what you were debugging and nothing else. After any change, list
the lanes the team has and the watchers that are live, and check the lists
match.

**RUN THE WATCHER IN THIS SECTION, NOT A CHEAPER ONE.** A master that writes
its own loop reporting only that a branch head moved has built something
that looks like the watcher and does none of its work. The scripts stream
the NEW ENTRIES, which is the reason to run them: an ack, a finding and an
escalation all arrive as outbox lines and a head SHA carries none of them.
Measured on a live team, a master watching only head movement left an
answered instruction open for the better part of an hour, told its user it
was still waiting, and sat on the answer that unblocked the next decision.
The same failure has a second half: WHEN A PUSH ARRIVES, READ THE RANGE
SINCE YOUR WATERMARK, NEVER THE TAIL. One push routinely carries several
entries, so reading the last line shows the newest and hides the rest, which
is where the ack usually is. The watchers count records and print the
difference; a master reading by hand does the same arithmetic on purpose.

### The self-test

`bin/selftest.sh` SYNTAX CHECKS ALL SEVEN SHIPPED SCRIPTS AND EXERCISES
ALL SEVEN against a throwaway bare repository and a pair of clones.
`bin/master-check.sh` is the one that needs care, since it pushes
rehearsal refs to whatever origin the tree it runs in happens to have,
so the two cases that drive it hand it origins nobody owns: a bare
repository the suite creates, and a path carrying no repository at all.
It needs no GNU coreutils, so stock macOS is not a special case, and it
prints its own numbered cases and its own pass and fail counts, which is
the only place worth reading them from: a list of cases kept in prose
beside a suite that grows drifts behind it silently, and this one had.

WHAT IT COVERS is every failure this protocol has actually paid for, and
nothing hypothetical. The ordinary loop end to end in both directions,
including a watcher that starts before the branch it watches exists. The
restart cases, since watchers restart routinely and a restart that replays
or skips is how entries go missing. The malformed inputs, a poll interval
that is not a number, an entry with no trailing newline, a git too old for
the state file. The remote misbehaving under a live watcher: a fetch that
fails after a push was seen, a branch deleted, a branch that returns at the
commit it had when it vanished. `ON_CHANGE` starting a real turn, failing,
easing off and recovering by itself. The turn lock, both when its owner is
alive and when its owner is gone. `DUE`, `NOTIFY`, the injector holding its
lock to the end of the turn and completing from an installation path
containing a space, a delivery command that fails, the supervisor adopting
an orphan and restarting one that died, the pointers not having drifted
from this file, and every default in the settings table above still
being the default the scripts use.

TWO PROPERTIES OF THE SUITE ITSELF ARE WORTH KNOWING, because both were
defects first. It drives the injector through `INJECT_CMD` pointed at a
log, so it cannot reach a chat application on any machine, and it forces
`NOTIFY_ECHO` so it cannot put its own fixtures on the operator's screen.
Before that it did both, on a live seat, in the middle of a campaign.

Run it after editing anything under `bin/`, and on a new platform before
trusting the scripts there. Budget a quarter of an hour and expect more on a
loaded machine: fourteen minutes and forty-seven seconds on the machine that
wrote it, eighteen minutes and thirty-eight seconds on a busy cloud
container. Almost all of that is real watchers sleeping between real polls,
so the wall clock answers to the poll intervals and to how promptly the
machine wakes them, not to how fast it computes. A version that took thirty
minutes here was doing none of that: one case was waiting out a signal it
had already sent, which is a defect and not a property of the suite.

### Wake-up pokes

**Master to sub-session.** Where the platform can deliver into another
session, one poke per sub-session is set up, and THE SEAT CREATES ITS OWN
where the platform allows it, handing the identifier back: a poke created by
anyone except its target is trusted only after its first fire is confirmed
by a push, since one measured here echoed the wrong binding and spawned a
throwaway session on every fire.

**EVERY SEAT HAS A WAKE PATH AND THE MASTER HAS FIRED IT ONCE, or that seat
is being woken by the user and neither side knows it.** This is the most
expensive silent failure in the protocol and it went undetected here for
days. A seat whose container is reclaimed when it goes idle cannot keep a
watcher, so a push reaches its remote and nothing tells it: the master
writes an instruction, the seat answers hours later when a person happens
to type into it, and from the master's side that is indistinguishable from
a seat that was simply slow. The user carried every wake by hand while both
sessions recorded a working bus. The platform's own delivery was ADVERTISED
on that seat the whole time, named in its session record, and nobody had
TESTED it; when it was finally called it accepted the call, returned an id
and started a throwaway session somewhere else. So at setup, for EACH seat,
name the mechanism that will wake it, FIRE IT ONCE BEFORE ANY REAL WORK,
and record in the ledger which mechanism each seat has.

**AND A PUSH IS NOT A RECEIPT.** This is the trap under the trap, and the
master fell into it the same night it wrote the rule above. It fired a poke,
saw the seat push two minutes later, and recorded that the poke had worked.
The seat had been woken by the user six minutes earlier and the round was
three quarters done before the poke existed. A push caused by a poke and a
push caused by a person look identical from the master's side, exactly as a
slow seat and an unwoken one do. THE ONLY RECEIPT IS THE SEAT QUOTING THE
POKE'S OWN TEXT BACK, so put a nonce in the poke and require it in the
outbox entry that answers. Until one entry carries it, that seat is
user-woken, and the ledger says so. THE NONCE HAS TO BE THIS POKE'S, since
a seat with a wake of its own answers that one and quotes ITS text, which
is a receipt for the seat's mechanism and not for the master's. AND A
NONCE ALONE IS FORGEABLE, which is not a hypothetical: a seat here quoted
one it had read out of the stored routine without ever receiving it, and
declared that it had. THE RECEIPT IS THE PAIR, the nonce and the seat's
own record of the arrival: on the host measured here that is the
notification's id and the time it was queued, set against the routine's
own fired-at. Either half alone is either forgeable or ambiguous. A
MISSING RECEIPT IS ALSO NOT A FAILURE, since
a poke can be delayed well past its due time, so waiting is the first
response to silence and re-firing is the second.

**AND THE WAKE MAY LAND IN A QUEUE RATHER THAN IN THE CONVERSATION.** On
one host measured here it arrives as an unread notification, and the
instruction appears only when the seat READS its notifications. A seat that
does not drain that queue is deaf while the delivery works perfectly, and
from the master's side that silence is the same silence as no delivery at
all. So the starter prompt tells the seat to drain its queue at the top of
every turn, and the first poke tests that habit as much as the transport.
Three shapes cover every tool measured:
a watcher the seat runs itself, where a background process survives the
seat going idle; the platform's cross-session delivery, where the host
exposes an API that fires into a named session; and a line the user pastes,
where it offers neither. THE THIRD IS A REAL ANSWER and section 8 says so,
but it has to be CHOSEN rather than arrived at, because a team that thinks
it has the first and actually has the third looks healthy from inside and
runs at the speed of the person.

THE POKE PROMPT NAMES NO TASK. It tells the sub-session to check its runner,
read its inbox from <integration>, execute every unacked Open instruction,
checkpoint and PUSH, and then RESTORE THE POSTURE THE POKE WOKE: a live
session re-arms its check-ins, a stood-down session reports and stands down
again unless told otherwise, because a poke that re-arms unconditionally
undoes a stand-down, which section 9 names the biggest budget lever. Finding
nothing to do is itself reported in one line and pushed. A poke naming a
specific task is a trap: fired again after that task is done, the woken
session correctly finds nothing to do and sleeps, while the master waits for
a reply that never comes. Stored prompts may be uneditable once created, so
write it task-free the first time from the template in section 7; where it
IS editable the editor may have to be the RECEIVER, one platform refusing
the master that created it, so the seat maintains its own shell and the
content of any one wake rides the appended text or the inbox.

THE POKE PROMPT STATES THE READER'S IDENTITY, because a poke can arrive into
a context that remembers nothing: the sub-session's name, its branch, the
inbox and outbox paths, the hard limits, and an instruction to read this
skill and the repository's rules first. "Your branch" without naming it only
works for a session that still remembers, which is the case a poke exists
to handle.

ONE DELIVERY PER STORED EVENT. A firing consumes the stored message, so a
poke is a consumable: re-firing replays something already delivered and it
is discarded. Measured on one platform in one day, three separate pokes each
fired once all woke the session, and two re-firings of already-delivered
events were accepted, created nothing and never arrived. What separates them
is not established, so take the operational rule and leave the mechanism
open: create, fire once, and to poke again CREATE A NEW POKE. Delete the
spent one so exactly one live recall path exists, and at stand-down leave
that one UNFIRED, since a spent poke is not a recall path however plainly it
sits in the trigger list.

ON ONE PLATFORM THE MANUAL FIRE PATH IS DEAD OUTRIGHT, proved by a
controlled pair after a renewal rule had been built on the wrong diagnosis:
firings of a seat-created poke, fresh and spent alike, were accepted,
returned an execution identifier and delivered nothing, while a ONE-SHOT
trigger carrying the seat's session identifier and a fire time a minute or
two ahead arrived in about half a minute. So the wake that works there is
the one-shot, created fresh per wake with the round's context as its prompt,
and the receipt is the trigger record: `last_fired_at` appears on delivery
and stays absent on a fire that went nowhere, so a wake can be falsified in
seconds without waiting for the seat. A one-shot per push is not a timed
check-in: it fires once, and only when there is something to deliver.

THE PUSH AND THE WAKE ARE ONE MOTION wherever the user has withdrawn the
timed layer: nothing wakes such a seat but a fired poke or a running
injector, so a master that pushes an instruction fires the wake in the same
breath and counts delivery only from the seat's answering push. Both halves
failed silently on a live team in one evening: an instruction pushed with no
fired poke sat unread, and a REPLACEMENT SEAT brought up without re-arming
its predecessor's supervisor and injector missed the next instruction the
same way. A replacement seat is a new seat: bring-up repeats the full
liveness arming of section 7 before or with its first instruction.

EVERY WAKE MECHANISM MEASURED SO FAR REACHES ONLY ITS OWN PLATFORM. A Codex
master wakes another Codex task on the same local application server and
addresses nothing on Claude Code, Cursor or another machine; a Claude Code
master wakes another Claude Code session and no more. In the MIXED team this
protocol exists for, being able to wake your own kind is not being able to
wake the team: every seat still needs its OWN armed inbox watcher, or a
person. The cost of assuming otherwise is unbounded, because a silent seat
on another tool waits until somebody notices.

THE POKE WORKS UPWARD TOO, AND LEAVING IT OUT IS THE LARGEST AVOIDABLE DELAY
LEFT. The mechanism is symmetric, and without it an escalation climbs at the
master's own cadence or at the speed of a person noticing. So at setup the
master creates ONE task-free poke pointed at ITSELF and gives its identifier
to every seat, to be fired only on an ESCALATION line and never for routine
reporting, since a master woken for every checkpoint is the budget failure
section 9 prevents. The seat fires it, writes the escalation, pushes, and
says in its own window that it did all three.

A FIRED POKE IS VERIFIED, NEVER ASSUMED, AND THE PUSH IS THE ONLY PROOF.
"The call succeeded" means only that it was accepted: neither dropped poke
above recorded a firing time, though every scheduled trigger in the same
listing did. One cheap early warning is worth taking where the platform
offers it: if the firing call reports which session it delivered into,
compare the identifying part against the target's own session id, since both
dropped firings reported an unfamiliar id and the delivered ones reported
the target's. Treat a mismatch as a drop and a match as no more than
encouraging, then ARM a check-in to watch the branch for a push within a
bounded time rather than intending to watch it.

If the firing call fails at the TRANSPORT layer, with a timeout or a reset
rather than a refusal, you cannot tell whether the message was stored and
delivered before the connection broke. Retrying is safe, since a second
delivery is discarded anyway, and it proves no more than the first attempt.
If nothing lands, build a new poke, fire that once, then escalate to the
user. NOTHING in the protocol may block on a poke landing: when a recalled
session does not answer, the master says so, does the work itself or without
it, and records that the session never woke. WHERE THE PLATFORM DELIVERS
NOTHING BETWEEN SESSIONS the recall path is not a poke at all, but the next
instruction waiting under Open plus a person pasting the relay line from
part one of `APPENDIX.md`, and the ledger says which is in force. Design so
this is rarely needed.

### Stand-down

A sub-session leaves cleanly, on the master's instruction,
and only then: a final checkpoint and push, a closing outbox entry naming
anything still open and the branch's merge state, then CANCEL every armed
watcher, work check-in and reminder, and confirm the disarm in that closing
entry. A STAND-DOWN STOPS WORK AND NEVER LIVENESS: the seat keeps exactly
one check-in armed, stretched to hours rather than minutes, whose whole job
is to fetch, read Open, execute what a fresh instruction assigns, and
otherwise re-arm without pushing a word. Five measured hours bought this
rule: a seat that had disarmed everything on instruction sat unreachable
beside an open instruction, on a poke channel whose delivery nothing could
confirm, until a person asked why it was quiet. NOTHING MAY DISARM THAT
LAST CHECK-IN, an instruction included: a seat told to disarm it is holding
a conflicting instruction, so it skips that part, says so in its outbox,
and arms the check-in anyway. Retirement otherwise stands as section 9's
biggest budget lever, because the work cadence, the watchers and the
reminders all die, and one long-interval read costs less than one silent
day. THE USER MAY WITHDRAW THE TIMED LAYER ENTIRELY, choosing allowance
over latency: seats then keep no check-in at all, waking duty moves to
the caller's pokes and to the human, and the choice is recorded in the
ledger. It is the user's choice alone, never the master's or the seat's,
because what it spends is silence and what it saves is the user's money.
BEFORE the stand-down completes, the master leaves a working recall path,
because between its liveness ticks a stood-down session cannot be reached
any other way. Where the platform delivers between sessions, that
path is exactly ONE task-free and UNFIRED poke, and the master creates a
fresh one if the standing poke has already been fired. Where the platform
does not, it is the next instruction written under Open, so that a relayed
line finds work waiting rather than an empty inbox.

The master then brings the outbox onto <integration>, by merging the
branch or by committing a snapshot of the file, and the closing entry
names that merge state. An audit trail left on a branch nobody merges
is not part of the repository's history, however firmly the design
notes claim it is, and "ready for the master to merge" still leaves it
unmerged.

### Surviving the machine

**Compute survival.** Run every long job inside a survivor the
platform cannot reap, tmux, screen or the equivalent, chosen per the
platform notes in `APPENDIX.md` (bare `nohup` dies on some tool shells),
one log file per block, launched by a runbook script so a dead runner
restarts with one command. Never run long jobs in the session's
foreground.

**Anchor the working directory.** A compile chain or tool that cd's
somewhere leaves every later repo-relative command running from the
wrong place, and the failure repeats however many times it has been
seen in one session. Start each repo-relative command from an
absolute anchor (`cd <repo-root> && ...`) or use absolute paths.

**Re-assert the environment after every rebuild.** A container or
machine that is rebuilt comes back without the settings the previous
session relied on: the commit identity, the hook path, the tool
configuration, the virtual environment, the credential helper. None of
those losses announces itself, and the first sign is usually a commit
authored by the wrong name or a gate that quietly stopped running.
Keep the re-assertion as runnable commands somewhere a fresh session
will read them, the ledger protocol's machine-setup section,
in the companion protocol linked from `README.md`, where the repository
runs one, re-run them at the top of any session that finds
itself in a fresh container, and then VERIFY instead of assuming:
print the identity back, and confirm the hook actually fires.

## 4. Work design rules

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

## 5. Verification discipline

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

## 6. Multi-sub-session setups

- Each sub-session gets its own name, branch, inbox, outbox, lane and
  poke. There is no sub-session-to-sub-session channel: anything one
  sub-session needs another to know goes through the master (who can
  quote outbox entries into another inbox). Sub-sessions may READ each
  other's branches and outboxes freely.
- The master runs one outbox watcher per sub-session and keeps a short
  roster (name, branch, lane, current assignment) in the ledger.
  **THE WATCHER IS THE PRIMARY SIGNAL AND A SCHEDULED SELF CHECK-IN IS ONLY
  THE FALLBACK.** A master whose tool schedules wakes easily will be tempted
  to run on the timer alone, and it works, badly: the reply is already
  pushed and the master reads it whenever its own clock next fires, so every
  report waits half a cadence on average and a whole one at worst. Arm the
  watchers BEFORE dispatching the first instruction that expects a reply,
  and prove one fires, the same deliberate test the monitor rule demands.
  THE TELL that this was skipped is a gap between a sub-session's outbox
  commit time and the time the master read it: if the master keeps learning
  about pushes from its own timer rather than from an event, the watcher is
  missing or dead. Keep the scheduled check-in anyway, so a dead watcher
  degrades into lateness instead of silence, and set its cadence SHORTER
  than the platform's measured monitor cap rather than long: a watcher that
  expires at thirty minutes under a check-in armed for two hours leaves an
  hour and a half of pure silence, which is the failure the watcher exists
  to prevent. Re-arm the watcher at the top of every wake.
- Partition by independence: give each sub-session work whose outputs and
  inputs do not depend on another sub-session's in-flight work. Where a
  dependency is unavoidable, sequence it through <integration>: sub-session A's
  work merges to <integration> first, sub-session B merges <integration>
  inward, continues.
- A third sub-session is rarely worth its cost unless the work is
  genuinely parallel, since every seat spends usage and coordination
  whether or not it is busy. The master should say so when asked to add
  a session that would idle.

## 7. Setup: exact steps and starter prompts

**User setup.**

1. Copy this folder into the repository, commit, push. Then add ONE
   pointer file at the path each tool scans. That is
   `.claude/skills/sub-session/SKILL.md` for Claude Code, and
   `.agents/skills/sub-session/SKILL.md` for Cursor, Codex and anything
   else following the `AGENTS.md` convention, each carrying this file's
   front matter and a few lines: which file to read, how to find it when
   the relative path does not resolve, and what else ships beside it.
   The folder ships both as templates, and only the relative path
   changes. One copy of the protocol, so no copy can go stale. Any other
   tool: point the sessions at `SKILL.md` directly, per section 8.
2. PRE-AUTHORISE THE PROTOCOL'S OWN CALLS, once, before anything runs. A
   tool that asks a human to approve each call will ask on every wake-up,
   every stand-down and every watcher restart, which turns a mechanism meant
   to save attention into a drain on it. Put the recall and liveness calls
   on the tool's allow list: on Claude Code that is a `permissions.allow`
   entry per MCP tool in `.claude/settings.json`, committed so a rebuilt
   container keeps it. The protocol makes seven kinds of call, each granted
   by its own tool name where the tool has it: creating, firing, deleting,
   listing and updating stored triggers, scheduling check-ins and reminders,
   and querying a session's status. Grant those named calls, one entry per
   tool name: a blanket rule over the whole server is both a wider grant
   than the protocol needs and, measured in practice, not honoured by every
   permission matcher, so a server-level shorthand that replaces the named
   entries can silently bring every approval prompt back. On a tool with no
   scheduler and no cross-session delivery the protocol makes no such calls,
   so this step is empty there and skipping it is correct.
3. Open the master session on the repository, paste the master
   prompt. Open one session per sub-session, paste the sub-session prompt
   with its name and first assignment (ask the master to draft these).
   ON A TOOL WHOSE UNATTENDED PATH IS A COMMAND LINE, a seat does not
   come up by pasting into a chat window at all. Hand the same prompt to
   the tool's non-interactive entry point instead, `codex exec` on Codex,
   and the seat creates its branch, creates its outbox and starts working
   exactly as a pasted one would. It costs the chat window: that seat is
   visibility level three until an injector is added.
4. From then on, how often anyone relays a line depends on the tool.
   Where the platform delivers between sessions, relay is the
   exception, for a sub-session that has gone silent. Where it does
   not, relay is the normal beat, and part one of `APPENDIX.md` gives
   the two lines a person pastes.

In all three prompts every angle bracket is a fill-in: replace the
whole bracket, description and all, with the value it describes. Short
ones carry the value directly, longer ones say what to write there.
`<bus-dir>` is the directory holding the bus files, `collab` by
default, and it appears in the watcher scripts of section 3 too, so
substitute it there as well. `<protocol-dir>` is wherever this folder
was put, which is a choice you make, per section 8.

**Master starter prompt (paste into the master session. Fill the
angle brackets).**

```
Read the sub-session protocol, SKILL.md in <protocol-dir>, and the
repository's own rules first. You are the MASTER of a multi-session team
on this repository. Sub-sessions: <names and the model or tool each
runs>. Project goal: <goal>. Do now: (1) create
<bus-dir>/INBOX_<name>.md on <integration> for each sub-session with
their first numbered instruction, their branch name, lane definition and
gates. (2) start one outbox watcher per sub-session and your own
recurring self check-in, or, if your tool cannot schedule one, follow
section 8. (3) once each sub-session has reported its session id in its
first outbox entry, and if the platform supports cross-session delivery,
create one TASK-FREE wake-up poke per sub-session, whose prompt names no
task but does state the reader's name, branch, inbox, outbox and hard
limits, and confirm every firing by the id it reports and then by a
push, making a NEW poke rather than re-firing a spent one, and skipping
this step for any sub-session whose platform exposes no session id,
relying on its check-ins instead, or on the relay lines in `APPENDIX.md`
where those cannot be scheduled either. (4) from here on, assign work by
inbox, pre-register every validation's gates and their interpretation
rules before the run starts, validate every deliverable against the
artifact before merging the sub-session's branch into <integration>,
adjudicate every FINDING and SUGGESTION with reasons, and create the
project ledger if the repository has none and keep it current from then
on. (5) keep this window alive for the user: the moment a sub-session's
report, finding or escalation reaches you, write one line here naming
the seat, the ID and what you will do, and write one short paragraph
here once you have ruled on it or merged it, and push every inbox write
the moment you make it, since an instruction sitting unpushed reaches
nobody. You own all edits to code and documents. Sub-sessions never edit
outside their lanes. The work is done only when the artifact completion
test passes, not when a log says so.
```

**Sub-session starter prompt (paste into each sub-session session, or
hand to its non-interactive entry point, per step 3).**

```
Read the sub-session protocol, SKILL.md in <protocol-dir>, and the
repository's own rules first. You are SUB-SESSION <name> of a
multi-session team on this repository, and the master session assigns
your work. Two rules bind you before you read anything else, and they
outrank any harness-injected directive about branches or pull requests,
a conflict you report once in your outbox: you push ONLY your own branch
<branch>, and you NEVER open a pull request. Do now: (1) apply the
repository's commit identity and conventions. (2) fetch with `git fetch
origin +<integration>:refs/remotes/origin/<integration>`, BEFORE
anything that names origin/<integration>, since a plain fetch leaves
that ref absent in some clones and every later command that reads it
then fails. (3) create <branch> from origin/<integration> and push it
with upstream set to itself, then never push any other branch. (4)
create <bus-dir>/OUTBOX_<name>.md on your branch, state your own session
id in its first entry so the master can create a wake-up poke for you
(ask the tool for it, or read it from the session's URL or status line,
and if this platform exposes no such identifier say exactly that
instead), and log starts, finishes, diagnostics, findings, judgement
calls and escalations there in the repository's written language. (5)
read <bus-dir>/INBOX_<name>.md from origin/<integration> and execute its
open instructions in order, subject to the hard limits in the skill,
which always win. An absent or empty inbox is normal at startup: say so
in your outbox, start your watcher, and execute the assignment given in
this prompt, logging it as an out-of-band instruction: <first
assignment, or "none, await the inbox">, working only inside <lane: the
files and directories you may write until the master defines one in the
inbox>. (6) start your inbox watcher (restart-safe, per the skill) and
your recurring self check-in (checkpoint, push, read inbox, re-arm, and
REWRITE the check-in text whenever the state changes), or, if your tool
cannot schedule one, follow section 8. The watcher is your primary
signal and the check-in is only its backstop, so set the check-in near
the platform's monitor cap, in tens of minutes, and NEVER on a timer
tighter than the event you are waiting for. Where the thing that starts
your watcher can itself expire, which on several tools it does on a
fixed schedule, run the watcher under `bin/supervise.sh` and run that
under a session detached from any terminal and from the application, so
it survives both. (6a) END EVERY TURN BY WRITING ITS COMPLETION MARKER,
the last act before you stop: if the turn was started by an injected
line that named a token, write exactly that token to the file the line
named. That marker is how anything waiting on you learns you are done,
and a turn that finishes without writing it is a turn that, to
everything outside your window, never ended. (6b) TAKE THE SEAT'S TURN
LOCK AT THE TOP OF ANY TURN YOU BEGIN YOURSELF, before any other work,
and release it at the end: `mkdir "$(git rev-parse
--absolute-git-dir)/turn_<name>.lock"` succeeds for exactly one holder.
Your watcher takes that same lock for the turns it starts, so this is
what keeps a turn a person typed and a turn a watcher started from
running side by side over one inbox. NO TOOL DOES THIS FOR YOU. It was
measured missing on a live seat, whose manually started turn held no
lock at all while its watcher was free to inject another beside it, so
treat it as the first line of every turn rather than as advice. (7)
alongside execution, run the standing shadow review described in the
skill: verify the master's work independently, pre-flight any new code
the master pushes before running it, run a proactive named-lens review
sweep whenever a running block leaves your attention idle, and report
findings, editing nothing outside your lane. (8) keep your own chat
window alive for the user: when an instruction reaches you, write one
line there first, naming the ID, the time and what you are about to do,
and when you finish it write one short paragraph there saying what you
did, how it came out, and which commit and outbox entry carry the
evidence, and do this on unattended and poke-driven turns too, since
those are the turns the user has no other way to see. Those two lines
belong to INSTRUCTIONS AND STATE CHANGES ONLY. A check-in or a poll that
finds nothing new writes NOTHING in your window: no iteration number, no
confirmation that you looked, no note that all is well. A window filled
with reports of nothing is a window in which the next real arrival is
invisible. Push every outbox write the moment you make it, because an
entry left unpushed is invisible to the master, and when a push closes
an instruction put `[done: ID]` in the COMMIT SUBJECT, the first line:
the acknowledgement gate reads subjects alone, and a marker only in the
outbox or the body is invisible to it. Your assignment ends only when
its artifact completion test passes. Your check-in chain stays armed
until the master stands you down. You leave your branch for the master
to merge. Report to the user in the language the repository uses for
conversation.
```

**Wake-up poke prompt (stored once per sub-session, fired once each
time it is created. See section 3).**

```
Recall poke from the master. This prompt names NO task on purpose: the
task lives in the inbox, and a poke that names one goes stale the moment
that task is done. Do not conclude from this text that there is nothing
to do. Your identity, restated so this works from a cold context: you
are SUB-SESSION <name> on <repository>. Your branch is <branch> and it
is the only branch you ever push. Your inbox is
<bus-dir>/INBOX_<name>.md on origin/<integration>. Your outbox is
<bus-dir>/OUTBOX_<name>.md on your own branch, written only by you,
append-only, each line timestamped from the clock. Your hard limits
still bind: <the limits, restated>. If your context is empty, read the
sub-session protocol, SKILL.md in <protocol-dir>, and the repository's
own rules before acting. Do now, in order: (1) write ONE LINE IN THIS
CHAT WINDOW saying the poke arrived and the time, before anything else,
since this turn is unattended and that line is the only sign the user
has that it happened. (2) run `git fetch origin
+<integration>:refs/remotes/origin/<integration>` and read your inbox
from origin/<integration>, using that explicit refspec because a plain
fetch leaves you reading nothing in some clones. (3) check your runner
is alive and restart it if it is dead. (4) execute EVERY instruction
under `## Open instructions` that your outbox has not already acked, not
only the
ones newer than your watermark, since the instruction you were recalled
for is usually one that was already open when you stood down, (5) append
your report to the outbox and PUSH your branch at once, `[done: ID]` in
the commit subject for anything the turn closed, so the master can see
that the wake landed, and write one more short line in this window
saying what you did and where the evidence is. (6) restore the posture
this poke woke: if you were live, re-arm your check-ins, and if you had
been stood down, stand down again unless the instruction says otherwise.
If `## Open instructions` holds nothing you have not acked, write exactly
that in one
outbox line, push it anyway, and say the same line in this window:
silence is never an acceptable answer to a poke, in either place.
```

**The guided start.** Everything above can be driven by hand, and the
master should instead drive it as one guided sequence, so the user
types as little as possible. The sequence, which the master follows
the moment the user says to set the team up:

1. SET UP SILENTLY. Run steps 1 and 2 above (folder committed,
   protocol calls pre-authorised), create the bus files and the
   ledger if the repository lacks them, start the master's own
   outbox watchers so the handshake below measures the link and
   never the master's idle cadence, push, and only then speak. Where
   a tool's allow-list is a user-interface action instead of a
   committed file, this is the one click to ask the user for up
   front, named plainly.
2. ASK ONE FACT AND EMIT THE STARTER PROMPT. Ask which tool the new
   seat will run on, since the wake mechanism, the survival notes of
   section 8 and the later role proposal all depend on it. Then emit the
   sub-session starter prompt complete and copy-paste ready, with every
   placeholder filled: name, branch, bus paths, integration branch, hard
   limits, and the lane's environment bootstrap where the seat needs one, a
   venv to build or a PATH to set, so its pre-flight can pass. Add one line
   telling the new sub-session to report its own view of the handshake to
   the user in its own chat window. Tell the user: paste this into the new
   session on the other platform, then say one word here when done.
3. HANDSHAKE, automatically, when the user says done. Where a
   headless CLI will carry the wake, first verify its login with a
   print-mode smoke turn, the failure mode that is measured and not
   hypothetical. The master then writes a numbered no-op instruction
   to the new inbox whose only task is its own acknowledgement,
   records its own push time, and watches the sub-session's branch.
   The sub-session acks and pushes. The master reports in ITS
   window: link up or not, and the ROUND TRIP on the master's own
   clock, inbox push to ack detected, with the watcher poll
   intervals beside it so the user can read what the number
   includes. The two one-way lags are reported only where both
   seats are known time-synchronised, because each subtracts one
   machine's clock from another's and skew reads as latency. The
   sub-session reports its own read-to-ack view in its own window,
   so the user sees the link from both ends without asking. A
   handshake that does not complete within a few poll intervals is
   debugged before any work is assigned, using the wake ladder and
   watcher rules of section 3. THE ROUND TRIP IT MEASURES IS THE
   TEAM'S LATENCY FLOOR, and the master writes it into the ledger
   beside the roster, since every later judgement about whether the
   bus is slow is a comparison against this number.
4. OFFER THE FORK. Ask the user exactly one question: start the work
   now, or add another sub-session first. Adding one repeats steps 2
   and 3 for the next seat, each on its own branch and bus pair.
5. ASSIGN ROLES WHEN THE TEAM PASSES ONE. With two or more
   sub-sessions, the master proposes a division of labour before any
   assignment, matched to what each platform is good at, compute
   next to real hardware, review on the strongest available model,
   long documents where the tool holds files well, states it in one
   short table in its window, and asks the user to confirm or
   adjust. Roles are recorded in the ledger with the roster, and the
   user can rearrange them at any time by telling the master.

The user's whole part in a guided start is pasting one prompt per
sub-session and answering one fork question, everything else is the
master's to do and to report.

## 8. Running this on any tool

The protocol asks three things of a tool: a shell with git and push
access to a shared remote, a session that comes back to the same clone,
and a way for a person to paste text into it. Everything else is
acceleration.

WHAT EACH TOOL ACTUALLY GIVES YOU IS IN PART ONE OF
[`APPENDIX.md`](APPENDIX.md), and it is the one file to open before
bringing up a seat on a tool you have not used before.

It carries where the skill file goes on each tool and which of them can
schedule a reminder or wake another session. It carries how to run a
seat on a tool with neither, the two lines a person pastes when nothing
else can move the loop, how to make a still chat window move, and what a
batch scheduler changes for a compute seat. It also carries the platform
failures a live deployment paid to learn: which shells reap detached
children, what replaces tmux on stock macOS, how headless authentication
differs from the graphical session, and what a sleeping laptop does to
every timer on it.

A HEADLESS COMMAND LINE TOOL NEEDS NEITHER A SCHEDULER NOR A POKE, and
this is the cheapest unattended seat there is. Where a tool answers a
prompt as a process, THE PROCESS IS THE TURN, so a detached watcher whose
change command is that tool closes the loop with no window, no
accessibility grant and nobody present. Measured on 1 September, twice in
succession, thirty seconds from the master's push to the seat's push, with
the watcher surviving both. Two things decide whether it works. Arm the
watcher from a shell the tool does NOT own, exactly as for a window seat,
since a watcher started from inside a headless turn dies with that turn.
And give the turn the authority to act: a permission MODE alone was
measured running, reporting and writing nothing, so the change command
carries the tool's explicit allowance for the writes and the git calls the
seat's work needs. `APPENDIX.md` carries the measured recipe.

THE FLOOR THIS LOWERS IS THE WINDOW, NOT THE LOGIN. A detached WATCHER
inherits the session that armed it, and a SCHEDULER does not. Measured the
same day on macOS: the same tool, the same absolute path and a corrected
PATH answered `logged in` from a terminal and `not logged in` under the
system cron daemon, which does not inherit the desktop login the tool's
account uses, so every fired turn failed at authentication and produced
nothing. Before putting a seat behind a scheduler rather than a watcher,
run the tool's own authentication check from that scheduler and read the
answer, since a turn that cannot authenticate still exits and still looks
like a turn that ran.

THE CONFIGURATION TO ASSUME WHEN IN DOUBT is the poorest one: no
scheduler, no cross-session delivery, a person relaying one line. Nothing
in this protocol is lost there, because every instruction, report,
finding and ruling is a committed file that any session reads on its next
turn. What is lost is only speed.

## 9. Economy: the smallest budget that keeps the guarantees

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

## 10. Why this shape (design notes)

The reasoning under these decisions is in part two of
[`APPENDIX.md`](APPENDIX.md): why the bus is committed files and not a
side channel, why every file has exactly one writer, why the master
adjudicates instead of voting, and why the liveness stack exists at all.
Read it before you change the protocol, so you know what a change costs.

One line of it belongs here rather than there, because it decides how
you test. REVIEWING THE PROTOCOL AND REVIEWING A RUN OF IT FIND
DIFFERENT THINGS, and neither substitutes for the other. Reading these
files finds what is missing, contradictory or unclear in them. Operating
them finds what they never anticipated. Most of the rules here came from
the second kind.
