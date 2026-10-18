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

**Where the rest of the contract lives.** Each link is one level from
this file. The text in those files is the original section, unchanged.

- Opening map: [references/preamble.md](references/preamble.md)
- 1. Roles: [references/roles.md](references/roles.md) (also below)
- 2. Bus: [references/bus.md](references/bus.md) (exclusive-writer rule below)
- 3. Liveness: [references/liveness.md](references/liveness.md)
- 4. Work design: [references/work-design.md](references/work-design.md)
- 5. Verification: [references/verification.md](references/verification.md)
- 6. Multi-seat: [references/multi-seat.md](references/multi-seat.md)
- 7. Setup and starter prompts: [references/setup.md](references/setup.md)
- 8. Any tool: [references/any-tool.md](references/any-tool.md)
- 9. Economy: [references/economy.md](references/economy.md)
- 10. Design notes: [references/design-notes.md](references/design-notes.md)

This file and the files it links under `references/` are the complete
contract. Both sides read the opening and the roles first, then the
user (or the master) tells each session its role and its name. Nothing
else needs to be agreed in advance. Open a linked file when the work
reaches that section; do not act on a section from memory of an older
copy of this file.

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

The rest of section 2 (instruction and report protocols, latency,
visibility, notifications, injection) is unchanged in
[references/bus.md](references/bus.md). Read it before writing an
instruction or a report.

## 3. Liveness: check-ins, watchers and wake-up pokes

Unchanged at [references/liveness.md](references/liveness.md), including
the settings table. Read it before arming a watcher, check-in or poke.

## 4. Work design rules

Unchanged at [references/work-design.md](references/work-design.md).
Read it before assigning or executing a long job.

## 5. Verification discipline

Unchanged at [references/verification.md](references/verification.md).
Read it before gating a result.

## 6. Multi-sub-session setups

Unchanged at [references/multi-seat.md](references/multi-seat.md).
Read it before adding a second seat.

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

**Master, sub-session and wake-up poke prompts** are the unchanged
blocks in [references/setup.md](references/setup.md). Paste from there,
with every angle-bracket placeholder filled, including the two long
ones that wrap across lines.

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

Unchanged at [references/any-tool.md](references/any-tool.md). Open it,
and part one of [`APPENDIX.md`](APPENDIX.md), before a new tool.

## 9. Economy: the smallest budget that keeps the guarantees

Unchanged at [references/economy.md](references/economy.md). Read it
before setting a check-in cadence or leaving a finished seat idling.

## 10. Why this shape (design notes)

Unchanged at [references/design-notes.md](references/design-notes.md).
Read it before changing the protocol.
