## 7. Setup: exact steps and starter prompts

Contents:

- 7. Setup: exact steps and starter prompts


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

