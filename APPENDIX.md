# Appendix

The two parts of this protocol you read once and then leave alone.
`SKILL.md` is the file a session loads on every turn, and it names this
one wherever it matters. Nothing here is needed to run a team that is
already running.

- **Part one, platform notes.** Everything the protocol needs from a
  tool, what each tool actually gives you, and the failures that only
  show up on real machines. Read the two tables for the tool you are
  on, and the recipe below them if that tool has one, not the whole
  thing.
- **Part two, why this shape.** The reasoning under the decisions
  everything else follows from. Read it before you change the protocol,
  so you know what a change costs.

## Part one: platform notes

### What the protocol needs from a tool

The protocol asks three things of a tool. It needs a shell with git
and push access to a shared remote, it needs each session to come back
to the work later, and it needs a way to reach a session that is not
looking. ONLY THE FIRST IS UNIVERSAL, and the protocol is built so
that the other two degrade instead of breaking.

**Nothing here depends on a scheduler for correctness.** Every piece of
state the team owns is a committed file: the instruction, the report, the
finding, the ruling, the watermark, the ledger. A session that missed a
check-in, slept through a poke or lost its whole context does not lose work,
because its next turn begins by reading the same files any replacement would
read. What a scheduler and a wake-up channel buy is LATENCY. Safety never
rested on them. On a tool that has neither, the loop still closes, just at
human pace, and that is the configuration to assume when in doubt. Read
correctness strictly here: it means nothing is LOST, not that the team
drives itself. With nothing scheduled, nothing moves until a person relays a
line, a dead runner stays dead until someone looks, and the one closure rule
that counts check-ins counts relayed turns instead.

**Where the protocol file goes.** The two roles are told to read this
file first, so the only per-tool question is the path. Except on
Claude Code, which fixes it, put the folder anywhere in the repository
and point the tool at that path.

READ THE LAST COLUMN CAREFULLY, BECAUSE IT ANSWERS TWO DIFFERENT
QUESTIONS. On two rows it names a POKE, a message delivered into a
session a person already has open, which is the only kind that moves a
window. Everywhere else it names the command a watcher runs to START A
TURN, which does the work and pushes and leaves the chat window exactly
where it was. Both close the loop and only one of them can be seen, so
the cells say which, and section 2's visibility levels are the scale
they refer to.

| Tool | How the file is loaded | Scheduler | Cross-session wake |
|---|---|---|---|
| Claude Code | folder at `.claude/skills/sub-session/`, loads as a skill | yes | yes, a stored poke |
| Claude Code CLI, `claude -p` | the same folder, and the skill loads the same way | NO, nothing in its help schedules | NO outbound poke, and none is needed: a DETACHED WATCHER whose `ON_CHANGE` is a headless turn closes the loop by itself. Measured 1 September, twice in a row, thirty seconds each from the master's push to the seat's push, watcher surviving both with PPID 1 |
| Cursor | a skill at `.agents/skills/<name>/SKILL.md`, or a rule file in `.cursor/rules/` set to apply always | no | `cursor-agent` started by an inbox watcher. It runs and pushes, and it does NOT move the chat window, so this is visibility level three unless an injector is added |
| Codex and other AGENTS.md tools | a skill at `.agents/skills/<name>/SKILL.md`, or one line in `AGENTS.md` pointing at the file | no | `codex queue --thread <task id> --message` as the injector's `INJECT_CMD`, which delivers into the task the operator is already watching. `codex exec` is the headless fallback where no task holds the seat: measured end to end, a seat brought up that way created its branch and its outbox, stated its session id and acked a handshake 59 seconds after the inbox push, pushed only its own branch and opened no pull request, but it moves no chat window, so an exec seat is visibility level three |
| opencode | a skill at `.agents/skills/<name>/SKILL.md` | no | `opencode run --dir <path>`, which is also what its pointer test used. Add `--auto` or it stops at the first approval. Headless like the grok row below it, so an opencode seat is visibility level three unless an injector is added |
| grok CLI | a skill at `.agents/skills/<name>/SKILL.md` | no | `grok -p '<instruction>' --output-format plain --cwd <path> --max-turns 20 --always-approve`. THE ONE TURN FORM IS A SMOKE TEST ONLY: measured, `--max-turns 1` answers PONG and does NOT follow a pointer far enough to do protocol work, so a watcher armed with it looks healthy and finishes nothing. Measured returning its answer on stdout and exiting zero. The earlier note that it needs an account before it will run a turn at all is WITHDRAWN, it was measured wrong. Its answer goes to stdout and no window moves, so a grok seat is visibility level three unless an injector is added |
| Anything with a shell | paste `SKILL.md` into each session as its briefing | maybe | usually not |

### The master's side, rehearsed on seven tools

**WHAT THE MASTER NEEDS, WHICH IS NOT WHAT A SEAT NEEDS.** The table above
answers a seat's question, how the file loads and whether the tool can be
woken. The master's question is different, and nobody had asked it, because
the master had always been the same tool. A seat needs to RECEIVE a wake and
a master needs to SEND one, and a master needs a scheduler more than a seat
does: a seat is woken by its inbox watcher, while a master with no scheduler
and no arriving event simply sits, however healthy its watchers are.

`bin/master-check.sh` rehearses the master half on any tool, in a temporary
clone, and prints the four questions no script can answer. Run it once per
platform you might put a master on, and add a block below.

**THE SEVEN MASTER ROWS, ALL MEASURED, none inferred.** They are
REHEARSALS, `bin/master-check.sh` run on each tool, and not production
masters: the live master of this deployment has only ever been Claude
Code, which is what the README means when it says the master half is
untested across platforms. Round trip is the script's own figure, from
the master's inbox push to its watcher printing the seat's entry, with
the poll interval beside it, since a five second poll and a twenty
second poll are not comparable numbers.

| Platform | Round trip | Scheduler | Wake another session | Pre-authorisation | Watcher survives |
|---|---|---|---|---|---|
| Claude Code local | not timed | yes, stored triggers and a monitor, THIRTY MINUTE cap | yes, a stored poke, fired on demand | yes, a committed `permissions.allow` | yes, under a detached `screen` or `tmux` whose ancestry reaches init |
| Claude Code web | 10s at 5s | recurring MINIMUM ONE HOUR, one-shot at one minute | yes, a stored trigger, delivering only when CREATED FROM the session it wakes, see the poke paragraphs below | partly, the allow list covers platform calls and not shell | by ancestry yes, but the CONTAINER is reclaimed on idle, so no |
| Codex Desktop | 59s at 20s | yes, a native recurring heartbeat, exercised at about 330s | yes, another Codex task on the same local app-server | yes | yes |
| Cursor | 39s at 20s | NOT EXERCISED, so unclaimed | no, its local helper types into the SAME window | no committed analogue | yes, under `screen` |
| Antigravity | 10s at 5s, re-measured 11s at 5s | yes, a native cron honouring 60s, the finest measured, and a one-shot at one second | no, its message tool reaches only its own subagents | yes, sandboxed commands run unprompted | DEPENDS ON HOW IT IS STARTED, see below |
| opencode 1.18.20 and 1.18.23 | 10s at 5s | no such command in its help | NO. `run -s` and `attach` exist and were not aimed at a window, and the command in the row above is a HEADLESS TURN answering on stdout, which is visibility three and not a wake | a FLAG, `--auto`, default off, not persisted | YES, measured: a watcher it starts is PPID 1 with no opencode ancestor once the turn ends |
| grok CLI 1.0.5 | 10s at 5s | no such command in its help | NO, and the command in the row above is that headless turn: it answers on stdout and moves no window, which is visibility three | a FLAG, `--always-approve`, not written to its config | YES, measured: a watcher it starts is PPID 1 with no grok ancestor once the turn ends |

**THE ANTIGRAVITY WATCHER CELL IS CONDITIONAL, AND THE FLAT NO IT USED TO READ
WAS WRONG IN A WAY THAT MATTERED.** A second rehearsal on that platform read
the process tree rather than the command typed, and the two cases separate:

    82504 10068 sh .claude/skills/sub-session/bin/watch-inbox.sh agy main cloud
    52261     1 SCREEN -dmS agy_inbox ...  ->  52272 supervise.sh  ->  52607 watch-inbox.sh

A watcher started directly from the agent's own command tool is a child
of the language server, which is a child of the application, so it dies
with the window. The same watcher, started from a terminal into a
detached `screen` under `bin/supervise.sh`, reaches init and survives.
The old cell said only the first of those, which would tell an operator
that platform cannot host a watcher at all. It can, through the launcher
the package already ships.

**EIGHT THINGS THE TABLE CANNOT HOLD, and each one cost something to learn.**

CODEX HAS A NATIVE DELIVERY ROUTE AND IT BEATS THE KEYBOARD.
`codex queue --thread <stable-task-id> --message '<line>'` puts a turn into an
EXISTING task, visibly, with no window activation, no accessibility grant and
no focus to lose. Set it as `INJECT_CMD` and the keyboard path is never
reached. Two things learned by using the keyboard there first. A seat whose
clone is a LINKED WORKTREE cannot hold a relative `.git/<name>_stamp` at all,
because `.git` is a file pointing elsewhere, so the paste landed, the seat ran,
its acknowledgement went nowhere and the injector waited out its whole timeout
reporting a failure that had not happened. THE STAMP THEREFORE LIVES OUTSIDE
EVERY WORKING TREE, at a plain temporary path that belongs to no lane and that
any process on the machine can write, and the launcher passes that path. And
queue exit zero proves ENQUEUE and not completion, which is exactly why the
queue is the injector's delivery command instead of the watcher's `ON_CHANGE`:
the nonce wait is the second phase, so nothing is recorded as handled until the
seat has said the turn finished. BE PRECISE ABOUT WHAT THAT BUYS. The nonce
proves a turn RAN AND ENDED in the seat. It does not prove the instruction was
carried out, and a seat that echoes the nonce and does nothing else is recorded
as handled. Requiring the seat's outbox to carry `[done: ID]` before the inbox
blob advances is the phase after this one and it is NOT shipped. What closes
that loop today is the master's own outbox watcher and somebody reading it.

A SEAT ON CLAUDE CODE ON THE WEB IS WOKEN BY THE PLATFORM, NEVER BY A
WATCHER, and getting this wrong costs the user their evening. That container
goes away when the seat goes idle, so nothing it launches is alive when the
master pushes. What works is cross-session delivery through ONE of the two
calls that appear to offer it, and the difference is the whole of this
paragraph:

    create_trigger + persistent_session_id + run_once_at   DELIVERS
    fire_trigger on the same stored routine                 DOES NOT

Create the routine bound to the seat's session with `run_once_at` a minute or
two ahead, carrying the instruction text, and read `last_fired_at` back off
the routine afterwards. FORCING a stored routine returns an execution id that
is not a session and starts a throwaway instead. TREAT THE INBOUND FLAG IN
THE SESSION RECORD AS A CLAIM AND NOT AS A CAPABILITY. Measured here,
twice, and the second measurement is the one that matters. For several
days the master pushed instructions to such a seat, the
seat answered only when a person typed into it, and both sides recorded a
healthy bus while the user was the transport. Then the master created the
routine, FORCED it, and read the seat's next push as the receipt. The seat
went and looked: the forced fire had started a THROWAWAY session, a different
id in a different container on a different model, which ran for ninety-seven
seconds and went idle, while `persist_session` and the session id in the
routine were both ignored. The push the master had read as its receipt was
caused by the user six minutes earlier. Two things keep this invisible: the
default session listing EXCLUDES trigger-fired runs, so the throwaways do not
appear unless you look up the id the fire returned, and each one is a fresh
clone with no history that can push the seat's branch while the seat is
mid-round, since the turn lock is a directory in one container and excludes
nothing across containers. So use the scheduled call, and until an outbox
entry QUOTES THE NONCE THE POKE CARRIED, that seat is user-woken and the
ledger says so. `last_fired_at` proves the PLATFORM fired, never that the
seat woke. A SCHEDULED FIRING DOES HONOUR THE BINDING THE FORCED ONE
IGNORES, measured 1 September in both directions: a one-shot created with
`persistent_session_id` and `run_once_at` reached the seat on time and the
seat answered quoting the prompt's own words, and the seat then woke the
MASTER the same way. GIVE IT A REAL LEAD, AND WAIT LONGER THAN YOU
THINK BEFORE CALLING IT DEAD. Measured 1 September: a one-shot created
sixty-five minutes ahead fired twelve seconds late, and one created two
minutes and thirteen seconds ahead fired four minutes and twenty-nine
seconds late, well past its own due time and long past the one-minute
granularity the tool documents. SHORT LEADS ARE DELAYED, NOT DROPPED. So
leave minutes rather than seconds, and do not read a missing
`last_fired_at` as a failure until several minutes past due. Two failures
of one species remain on this call: forcing a stored routine returns an id
and delivers nothing, and the inbound flag reads available whether or not
anything arrives. AN ACCEPTED CALL IS NOT A DELIVERY, AND A MISSING
RECEIPT IS NOT A FAILURE. Both are settled by the seat's own arrival
record and by nothing else, in either direction.

AND THE WAKE DOES NOT ARRIVE AS A TURN, IT ARRIVES AS A QUEUED
NOTIFICATION, which is the half of the contract neither side had. What
lands is a notice saying there is one unread scheduled-trigger
notification, and the instruction itself appears only when the session
reads its notifications. A SESSION THAT DOES NOT DRAIN THAT QUEUE IS DEAF
WHILE THE DELIVERY WORKS PERFECTLY, and from the other side that is the
same silence as no delivery at all. It binds the master as much as the
seat, which is how it was found: the seat's wake reached this master as an
unread count and nothing more.

A SECOND GATE SITS BEHIND THE ALLOW LIST on Claude Code on the web. An auto-mode
classifier refused a `git push --delete` and a read-only `wc -l` loop with
"Blocked by classifier", and no committed file addresses it, so an unattended
wake needing a shell call can still be stopped by something no settings file
pre-authorises.

AND THAT GATE DECIDES WHICH WAKE A SEAT CAN ARM FOR ITSELF. Measured by the
review seat: `create_trigger` carrying a `cron_expression` came back "Blocked
by classifier" in its container, while one-shots bound to the same session
passed. So a seat there arms a BANK OF INDEPENDENT ONE-SHOTS rather than one
recurring routine, and it does not chain them: a fired routine carries no
`mcp__*` tools, which the create call says in its own warning, so a
self-renewing chain whose renewal needs `create_trigger` ends at its second
link. Four one-shots an hour apart, each carrying the whole round-runner,
each independent, is the shape the classifier accepts. THE CHAIN FLAW IS
NARROWER THAN THE WARNING READS, and both sides of this team got it wrong
before one of them tested it: the warning that a routine's sessions carry no
`mcp__*` tools is about sessions the routine creates FRESH. A firing that
lands in a LIVE PERSISTENT SESSION inherits that session's own tool surface,
so a bank armed there renews itself normally, proved by arming the next link
from inside a fired turn. A self-renewing chain ends at its second link only
in the fresh-session case. The bank is still a floor under the master's own
wake rather than a replacement for it, since a firing costs a turn whether or
not there is work and a wake fired at the push costs one only when there is.
THE PEER MESSAGE TOOL IS NOT THE OTHER-SESSION ROUTE ON THIS PLATFORM,
and reaching for it first costs a turn. Measured 27 August: the master's
peer messaging tool refused a seat's `session_...` identifier with "No
agent named ... is reachable", and its own listing showed no reachable
agents at all, because that tool addresses sessions on the SAME MACHINE
and every cloud seat is a separate container. The route that works is
the stored trigger the row above names: create one bound to the target's
`session_...` identifier with NO schedule, which the platform accepts as
a poke-only routine, then fire it on demand. The create call returns the
routine and the fire call returns the target's own session identifier,
which is the acknowledgement that it was accepted. Three consequences. A
master must not conclude from an empty peer listing that a seat is
unreachable. One routine is a reusable channel exactly as it stands,
because the fire call accepts per-message text that the target reads
after the stored prompt, measured twice in one day, 29 August, each
firing carrying a live ruling. And the stored prompt obeys writer
discipline the platform itself enforces, measured the same day from both
ends: an edit is refused from every session except the one the routine
delivers into, the master's update failing where the seat's succeeded,
so A STORED POKE PROMPT IS MAINTAINED BY THE SEAT IT BINDS. The seat
keeps it a generic shell, fetch, read the whole of Open, execute what
the outbox has not acked, report and push, and the content of any one
wake rides the fire call's appended text or the inbox, because a shell
that names one task goes stale the moment that task closes, and a later
firing then delivers an instruction superseded days before. AND THE POKE
IS CREATED BY THE SESSION IT WAKES, which the same lane paid five more
silent hours to learn. A poke routine the master created against the
seat's session identifier LOOKED bound, echoing the binding in every
call, and carried an environment identifier in its job configuration:
each fire spawned a fresh throwaway session in that environment instead
of waking the seat, spent allowance on a session that did nothing, and
returned the throwaway's identifier as the unfamiliar session core the
master kept logging. The routine the seat then created from inside
itself carries no environment identifier and delivers. So the ownership
rule has both halves, creation and maintenance: where the platform lets
a session create its own poke, the target creates it and hands the
identifier to whoever will fire it, and a poke anyone else created is
trusted only after a first fire is confirmed by a push. The id-mismatch
warning above is upgraded by the same measurement: every mismatch logged
on this lane was a throwaway's identifier and a true drop, and no
delivered fire ever returned one. AND ACCEPTANCE IS NOT DELIVERY. The
fire call proves the platform took the message, and only the target
acting on it proves it arrived, which is the same distinction the
injector draws between a paste that returns and a turn that runs. THE
AMBIGUITY IS STRUCTURAL, not a gap in attention: a routine bound to a
persistent session records no last run, by design, because it wakes its
bound session instead of creating one, so a fire that landed and a fire
that vanished return the same shape and the master holds no receipt to
check. Measured 30 August, five silent hours: the binding was correct
throughout, the fire reported an unfamiliar session core, nothing
arrived, and only the seat's own account settled it. So the compensating
control is NORMATIVE rather than advice: after any poke the master arms
a bounded self check-in and reads the seat's BRANCH as the only delivery
signal, and the id-mismatch warning above stays what it is, a warning
that can never confirm. MEASURED 27 August, which is what promoted the
cell above from unexercised: a master on this platform poked a review
seat in a different container with a ruling that told it to land a held
edit first, and about five minutes later that seat pushed a commit doing
exactly that, across the one file it owned and the two the ruling had
just added to its lane. No window moved and no keyboard was involved.

THE ONE HOUR MINIMUM CHANGES THE CADENCE, not just the convenience. Section 3
prescribes a check-in of twenty to twenty-five minutes, and where the recurring
minimum sits above that the check-in exists only as a chain of one-shots that
re-arm each other, with the hourly trigger as the only backstop under a dropped
link. Section 3 also calls scheduled reminders lossy, so such a chain with
nothing under it ends silently at its first dropped link.

TWO SMALLER FACTS THAT DO NOT FIT A CELL. Antigravity's pre-authorisation is
not only per invocation: its preferences hold persistent prefix-based tool
authorisations, so a command shape can be approved once for good, which no
other platform here offers. And the Claude Code web container has NO `screen`
and does have `tmux`, so section 3's canonical arming block needs its
documented tmux substitution there as the primary form and not as a fallback.

A WATCHER THAT DIES WITH THE TURN IS THE ANTIGRAVITY CASE and it is not a
scheduling problem. Measured: a watcher armed from inside one of that seat's
own turns delivered at 03:08 and no process remained by 03:32, with the window
still open. Armed instead from a terminal, its ancestry reads watch-inbox to
supervise to a shell to login to SCREEN to launchd, with no application process
anywhere in it, and it survives. WHO TYPES THE ARMING COMMAND is the variable,
which is why section 3 now says so.

WHETHER A REHEARSAL CLEANS UP AFTER ITSELF IS A PROPERTY OF THE CREDENTIAL,
NOT OF THE SCRIPT, and the two kinds of machine here differ completely.
`master-check.sh` pushes two throwaway `rehearsal/*` branches and deletes them
when it is done, and it names them uniquely per run so a refused delete cannot
poison the next run. Measured 27 August on both kinds. On the Mac, with the
operator's own git credentials, both refs were pruned cleanly and the remote was
left as it was found. From every container here the proxy answers HTTP 403 and
no branch can be deleted at all, so each run leaves TWO more refs on the shared
remote and the pile grows without limit: eight had accumulated before anyone
looked. THE CONSEQUENCE FOR A MASTER IS PRACTICAL. Run the rehearsal from the
machine that holds real credentials where you have one, and where you do not,
expect the litter, read the enumeration the refused delete prints, and get a
credentialed seat to clear it. A refused delete is not a failed rehearsal and
must not be reported as one, which is a distinction the script now makes in its
own output.

FIVE macOS SURFACES NO TEST CAN REACH, measured on a real machine 27
August because every case covering them is a fake. They are recorded
together because each one is a place where the fixture and the operating
system could differ. A FOCUS MODE SILENTLY SWALLOWS THE ALARM, and this
is the one that changes how the notifier may be used. Under Do Not
Disturb or any Focus, `osascript` returns ZERO, the call looks
successful from the script, and the banner and its sound are suppressed
into the drawer where nobody is looking. So a desktop notification is a
convenience and NEVER a hard alarm: anything that must reach a person
needs a second channel that a focus mode cannot mute. THE PASTE TIMING
HAS ABOUT A 2.4 TIMES MARGIN. The application reads the pasteboard
within 0.15 to 0.25 seconds of the keys being posted, and the injector
waits 0.6 before restoring, so the restore cannot land in the gap except
under extreme load. The margin is worth knowing before anyone tunes that
delay down to make injection feel faster. THE TRUNCATION IS CORRECT ON
THE REAL BACKEND. Sixty four-byte emoji, 240 bytes, clipped to 104 bytes
plus the ellipsis, no split code point, and the banner rendered cleanly.
The byte walker does what it claims where it matters. THE FINGERPRINT
USES `shasum` HERE. Stock macOS ships `shasum` and `cksum` and NOT
`sha256sum`, so the second rung of the fallback is the one that runs on
every Mac, and the first rung is effectively Linux only. A machine that
CHANGES its hash tool between a recording and a comparison re-seeds
instead of accusing: the recorded digest fails to reproduce at its own
head under the new tool as well, so the outbox watcher reports a corrupt
record, loud and convicting nobody. Verified against the fallback chain
by review. The fifth, the pasteboard, is severe enough to sit with the
injector rather than in this list.

A MASTER STILL WORKS WITHOUT A SCHEDULER, an outbound wake or a
pre-authorisation. The bus is committed files, so it assigns, adjudicates and
merges regardless. What it loses is the ability to wake a silent seat without a
person, and on four of the seven platforms above that is the actual situation.
The ten second round trip on four of them says the bus itself is never the
bottleneck.

### Unattended seats: what runs with nobody watching

**THE TRANSPORT BOUNDARY IS PART OF THE RESULT, not a footnote to it.** Every
outbound mechanism measured here reaches sessions of ITS OWN platform: a Codex
master wakes another Codex task on the same app-server, and a Claude Code
master wakes another Claude Code session. NONE of them addresses a session on
a different tool or a different machine. So in the MIXED team this protocol
exists for, a master that can wake its own kind still cannot wake the others,
and every seat needs its own armed inbox watcher or a human relay. The cost of
forgetting this is unbounded: a silent external seat with no watcher of its own
waits until a person notices.

**AND WATCHER SURVIVAL IS NOT MEASURED BY THE SUITE.** `bin/selftest.sh`
exercises watcher behaviour inside its own shell. It never closes an
application and never walks a process ancestry, so it is not evidence that a
watcher outlives its launcher. That property is measured per platform, per
LAUNCHER, by reading `ps` after the window closes, and it is claimed above
only where somebody did that.

**AN UNATTENDED SEAT NEEDS NO WINDOW AND NO PERSON, MEASURED END TO END.**
The arrangement is the opposite way round from the one that fails: not a
watcher started from inside a headless turn, which dies with it, but a
DETACHED watcher whose `ON_CHANGE` IS the headless turn. Measured on 1
September in a throwaway pair of clones, with `tmux` standing in for `screen`:

```sh
ON_CHANGE="cd <seat-clone> && claude -p \"<the seat's standing instruction>\" \
  --permission-mode dontAsk \
  --allowedTools 'Read,Write,Edit,Bash(git:*),Bash(date:*)'" \
  P=5 sh bin/supervise.sh inbox <name> <integration> <bus>
```

AND THE PROMPT IS IN ESCAPED DOUBLE QUOTES FOR A REASON. Single quotes read
naturally around a prompt until the prompt contains an apostrophe, and the
one printed here did: `seat's` closed the quote, and the whole value then
failed `sh -n -c` with a syntax error at `Bash(git:*)`, so the command never
reached Claude at all. Found by the Codex seat, which was running the lines
this file tells a reader to paste. Anything offered as pasteable is checked
by pasting it.

FLAGS FIRST OR THE PROMPT EATS ONE. `-p` takes the NEXT argument as the
prompt, so `claude -p --permission-mode dontAsk '<instruction>'` consumes the
flag and then complains that no prompt was given. Put the prompt immediately
after `-p`, or feed it on stdin. Measured by a seat that lost three deliveries
and a ten minute backoff to it.

The master pushed an instruction, the watcher saw it, the turn read the inbox
from `origin/<integration>`, appended to its outbox, committed with `[done:
ID]` and pushed its own branch. THIRTY SECONDS from push to push, TWICE in a
row with nothing touched between them, and the watcher was still there
afterwards with PPID 1.

**A SCHEDULER IS NOT A SUBSTITUTE FOR A WATCHER HERE, AND AUTHENTICATION IS
WHY.** A detached watcher inherits the session that armed it; the system cron
daemon does not. Measured on macOS on 1 September: the same absolute binary,
with PATH corrected and checked, answered `loggedIn true` from a terminal and
`loggedIn false` from cron, because that daemon does not carry the desktop
login the tool's account uses. Both fired turns exited in about two seconds
having done nothing. `env -i` from the terminal still authenticated, so the
cause is the session rather than the variable list. A user LaunchAgent, which
does run inside the login session, is the untested alternative.

**AND `--permission-mode dontAsk` ALONE IS THE TRAP THIS ROW EXISTS TO NAME.**
With that flag and no tool list, the same turn RAN, read the inbox, reported
what it had been asked to do, and wrote nothing: `Edit` and `Write` were denied
outright rather than prompted, and the turn correctly refused to route around
the denial through `Bash`. A watcher armed that way looks healthy on every
poll and leaves its instruction open for ever. The tool list is not a
convenience, it is what makes the turn able to act.

FIVE CLIS WERE ASKED FOR A LINE THAT EXISTS ONLY IN THE CANONICAL
`SKILL.md`, through the skill invocation and never by naming a file. The
line used at the time was a planted sentinel and the trim removed it, so a
reader repeating this takes any sentence unique to `SKILL.md` and absent
from both pointers, which is what the seat that re-ran it did.
Claude Code, Codex, Cursor, opencode and grok each returned it, which is
what says a pointer is FOLLOWED rather than merely found. Amp and Gemini
CLI both find the skill at the `.agents` path and could not be taken
further here, Amp for want of credits and Gemini because its sign-in
needs a real terminal, so neither is established either way. Those are
facts about accounts and not about the layout.

### Staying alive: watchers, windows and wake paths

**A THIRD WAY TO STAY LIVE, on tools that have no external entry point.**
The two mechanisms above assume one of them: either a watcher can start a
turn from outside through `ON_CHANGE`, or a person pastes a line. There is
a third arrangement and it was missed until a seat ran on one. An
integrated agent environment may expose NO external command line at all
while carrying its own scheduler, able to wake its own session on a timer.
There the watcher and the waking are separate jobs: `bin/watch-inbox.sh` runs
as a background task and detects the change, and the agent's own recurring
check-in is what turns that detection into a turn.

KNOW WHAT THAT SCHEDULER IS BEFORE YOU RELY ON IT. Measured on Antigravity:
it runs IN MEMORY inside the editor's language server, registers no crontab
and no launchd job, and fires only while the application is open. The
watcher it started was a child of that same language server, so closing the
window killed the whole tree. A scheduler like this buys liveness WITHIN a
session's lifetime and none across it, which is the opposite of what a
scheduler usually promises. THE BOUNDARY IS CLOSING AND NOT LOOKING AWAY,
measured by that seat on request: the language server, the in-memory scheduler
and the watcher all survive the window being backgrounded, minimised or out of
focus, and they die only when the window is CLOSED or the application is quit.
An operator who minimises a seat has not killed it, and one who quits the
application to tidy the desktop has. Ask the seat for its watcher's parent
process before trusting a window you are about to close: a seat whose only
wake path is internal, on a platform that exposes no identifier the
master can poke, goes dark the moment the window does and stays dark
until a person reopens it. That is a fine arrangement if you know it,
and a silent one if you do not.

THE ACCESSIBILITY GRANT IS NOT THE HARD PART OF AN INJECTOR, and finding
that it was already granted is what exposed the real question. On the
machine running this deployment, Codex, Codex Computer Use, Cursor and
Claude all held the accessibility permission already, so typing into any
of those windows was available at zero cost. IT IS STILL THE WRONG TOOL
BESIDE A HEADLESS PATH, and that is a rule about configuration and not
about injection. The Codex seat's turns were started by `codex exec`
from a detached watcher, and its GUI window ran nothing: inject a line
there while that is true and a SECOND agent starts, on the same inbox
and the same outbox, holding none of the watcher's locks, because a
watcher can only lock the turns it starts itself. The remedy is to move
the seat ONTO injection and remove the headless entry point, not to keep
both and choose carefully. One path per seat. Ask where the turns run
before reaching for the injector. Where they run somewhere else, either
move them into the window or leave them headless with a notification,
and say which, because the failure is having both.

A SEAT THAT SURVIVES ITS WINDOW CAN STILL GO SILENT, and the cause is
worth separating from the platform, because the first reading here blamed
the wrong layer. A Codex seat was asked to prove it would survive its
window closing. It reported that its inbox watcher ran under a detached
screen session, the chain being watcher to shell to login to SCREEN with
PPID 1, and it called its own confidence high rather than absolute since
it could not observe the close from inside the window. The window closed,
an instruction was pushed, and nothing reached its branch for twenty-one
poll intervals. The first conclusion drawn was that the process tree had
not been sufficient. Then `screen -ls` was run on the machine and the
session was still there, Detached, exactly as claimed. THE TREE WAS
SUFFICIENT. What had failed was the command the watcher starts, and then
the watcher's own policy about failure.

SO THE LESSON IS ABOUT THE RETRY LADDER, not the platform. The command
was `codex exec` against an exhausted allowance. It failed, the watcher
retried it twice more within a minute at `P=20`, and the version of this
protocol shipped that day then ABANDONED the change for good. That is
right for a command with a typo in it and wrong for one that will work
again in an hour, and a non-zero exit cannot tell the two apart.
The bus was healthy throughout, the seat was alive throughout, and the
instruction was thrown away by the one component that was supposed to be
protecting it. `bin/watch-inbox.sh` now has a second rung instead of an
end: `FAST` quick attempts, then one attempt every `RETRY` seconds for as
long as it takes, announcing the change once rather than on every attempt
and announcing recovery when it comes.

TWO THINGS STILL FOLLOW FOR ANY SEAT BEHIND A CLOSED WINDOW. Test a
survival claim by actually closing the thing and pushing, because a
process tree answers whether the WATCHER lives and says nothing about
whether the TURN can start. And write down the exact command a person
will run to tell the two apart, because both produce identical silence on
the bus and both logs live only on the seat's own machine, where the
master has no reach. Here that is `screen -ls` for the session and the
tail of the watcher's log for the retry lines, and the master says which
answer means what rather than leaving the user to interpret it.

ARM THE WATCHER SO IT OUTLIVES WHATEVER IS STREAMING IT. Measured here, on
the master's own side: the outbox watcher was started as a child of the
background monitor that carried its output, that monitor reached its
timeout, and the watcher died with it. Nothing announced the death. The bus
stayed up, the seat pushed three replies over forty minutes, and the master
learned about all three from the user. The orphan case is worse. A watcher
whose streamer died but which was not itself killed keeps polling and keeps
writing its state file, so every sign of health you can check is green while
its output reaches nobody. Three rules follow, and the first is the one that
holds when the others cannot. MAKE THE WATCHER'S STATE FILE
AUTHORITATIVE, so that a restart replays nothing, skips nothing, and
delivers whatever landed while it was down: then a streamer dying costs a
delay rather than a message. Second, restart the watcher automatically
when it exits. Third, when you re-arm, TAKE OVER any watcher already
running for that seat instead of refusing to start beside it, because the
one already there may be the orphan.

RAISING THE STREAMER'S TIMEOUT IS NOT AMONG THEM, though it was the first
answer tried. Measured here: the streaming layer was asked for an hour and
for a session-length watch, reported back a thirty minute limit, and killed
the watcher on schedule anyway. A ceiling a host imposes is not a dial you
own. Plan for the streamer dying on its own timetable and make the restart
lossless, rather than trying to make the death not happen.

DUE DOES NOT COVER THIS, and it is worth being clear why. A dead watcher
says nothing at all, including that it is overdue, so the one signal built
to turn silence into an event is the signal that dies with it. Silence has
to be checked by something outside the watcher whose own liveness you have
established separately. That is the same rule as the one about scheduled
jobs above, arriving from the other direction: every wake path needs a
second path that can report the first one missing.

THE CONSEQUENCE IS TWO DIFFERENT LATENCIES, and conflating them will make
a healthy link look broken. Measured on Antigravity: the watcher saw two
inbox pushes 16 and 27 seconds after they landed, at `P=20`, which is the
bus behaving exactly as it does everywhere else. The agent turn did not
start for another seven minutes, because nothing was scheduled to start
it and the log sat there correctly recording a change nobody had acted
on. DETECTION LATENCY IS THE BUS. TURN LATENCY IS THE WAKE MECHANISM.
Report both, and when a seat on such a platform looks slow, check which
of the two is actually slow before touching the poll interval.

A seat like this is worth having: it was the only one of four measured
tools at visibility level one, its window updating itself in real time
with no injector, where the two with external entry points were both at
level three. The trade is exactly that. A tool a watcher can drive tends
to run where nobody can see it, and a tool you can see tends to insist on
driving itself.

A POINTER LAYOUT REQUIRES A FILE READ BY CONSTRUCTION, which is a
limit worth knowing before choosing one. A tool whose headless mode
denies file reads it cannot prompt about will fail to follow a pointer
however the pointer is written, and it fails in a way that reads like
the model ignoring instructions rather than like a permission being
refused. Antigravity CLI says it outright, "a tool required the
read_file permission that headless mode cannot prompt for, so it was
auto-denied", and a tool that says less would just answer wrongly. If a
pointer test fails on a tool, check its headless permission defaults
before concluding anything about the layout.

That is also a caution about diagnosing your own tests. On Antigravity
the permission denial turned out NOT to be the cause: repeating the run
with permissions skipped still returned `NO_SUCH_SKILL`, and so did
asking for the skill by name, so the real answer is that the tool does
not read `.agents/skills` at all. Two plausible causes were visible and
the loud one was the wrong one, which is the ordinary shape of this kind
of failure. Rule out discovery before you reason about pointers, since a
tool that never found the skill tells you nothing about how it would
have followed one.

One install note worth carrying: `command -v` is not the availability
test on macOS. It came back empty for Codex, whose binary is inside
`/Applications/Codex.app/Contents/Resources/`, and again for Claude Code
CLI, which is a Homebrew cask at `/opt/homebrew/bin/claude`. Check the
application bundles and the Homebrew Cellar and Caskroom before
concluding a tool is not installed.

On Cursor the rule file is the whole of the setup. Put this at
`.cursor/rules/sub-session.mdc`:

```
---
description: Sub-session protocol, read before acting as master or sub-session
alwaysApply: true
---

This repository runs the sub-session protocol. Cursor does not load
`.claude/skills/`, so read <protocol-dir>/SKILL.md in full before
acting as the master or as a sub-session, and do not assume you have
already read it.
```

On Codex and other tools that read `AGENTS.md`, one line in that file
does the same job:

```
This repository runs the sub-session protocol: read
<protocol-dir>/SKILL.md in full before acting as the master or as a
sub-session.
```

The front matter at the top of `SKILL.md` is Claude Code's loader
metadata. Every other tool ignores it, and nothing in the protocol
reads it. The prompts in section 7 carry `<protocol-dir>` for this
reason: fill it with wherever the folder actually sits, and a session
on any tool can find the contract from its first line.

### Recipes from live runs

**Mixed tools are the normal case, and the protocol treats them as such.**
The bus is git, so the master can run on one tool and each sub-session on
another, in different models, on different machines, with different context
windows. That is a feature worth using deliberately: a reviewer that shares
no context, no vendor and no failure modes with the session it reviews
catches things a second session of the same tool does not. The only
requirements are that every session reads `SKILL.md` and that the master is
the session with the strongest editing access, since it is the one that
writes.

**When there is no scheduler and no wake channel.** Cron, `at` and
Windows Task Scheduler can run a shell command, but on most tools they
cannot give a session a turn, and a session that is not taking a turn
cannot be reached by anything except the person in front of it. So the
portable wake is ONE LINE A HUMAN PASTES, and the protocol is designed
to need it rarely. The two roles do different work, so there are two
lines. To a sub-session:

```
Check your inbox and continue: say in one line here what you are about
to check, then fetch the integration branch with an explicit refspec,
read your inbox file, execute everything under Open that you have not
acked, append your report to your outbox, push, and say in one line
what you did, with the numbers if there are any and which commit and
outbox entry carry the evidence, or that there was nothing to do.
```

To the master:

```
Check the sub-sessions and continue: say in one line here what you are
about to check, then read the roster from the ledger,
fetch each sub-session branch with an explicit refspec, read each
outbox from its branch and treat everything past the copy on the
integration branch as unread, bring each outbox up to date on the
integration branch, rule on every finding still unruled, write the
next instruction into each inbox and move anything acked to Closed,
push the integration branch, and say in one line what arrived from
which seat, what you ruled and what you assigned.
```

The minimum viable configuration is therefore: two sessions, a shared
remote, the inbox and outbox files, and a person who relays the right
line when they want the other side to move. No watchers, no check-ins,
no pokes. Everything else in section 3 is latency reduction bought
with tokens, and section 9 prices it.

A WATCHER IS NOT A SCHEDULED JOB, though the table above sets both
columns side by side. It is a shell loop, so it runs wherever a
detached process runs, scheduler or not. What it needs is a reader,
and on a tool that cannot deliver its output into a turn the pattern
in section 3 supplies one: the watcher appends to a local file, and
the session reads that file's new lines at the start of its next turn,
relayed or otherwise. That is worth doing on Cursor or Codex, since it
turns "read the whole inbox again" into "read the three lines that
changed", which is what the economy section is about.

**A duplex channel without a scheduler: the headless-CLI watcher.** A
tool with no scheduler can still receive master instructions unattended
when it ships a headless command-line agent (Cursor's `cursor-agent`,
installed as both `cursor-agent` and `agent`, Codex's exec mode, or
equivalent). A detached shell watcher watches the inbox exactly the way
the section 3 inbox watcher does, `git ls-remote` to spot the push, the
explicit-refspec fetch, then `git rev-parse` of
`<bus-dir>/INBOX_<name>.md` on origin/<integration>. It runs on the same
base interval the section 3 watchers use, sixty seconds at rest and
tightened to fifteen or twenty while a reply is due, and the fetch is
what makes the rev-parse move, since a bare rev-parse of a
remote-tracking ref never changes without it. On a change it runs ONE
headless agent turn, whose prompt tells the agent who it is, to read the
inbox against the acked watermarks in its outbox, execute anything new,
and push its outbox. Rules learned in production, each from a real
failure:

- Store the consumed-blob marker ONLY when the agent turn returns
  rc=0. A watcher that stores it unconditionally eats the ping when
  the turn fails, and the master waits on silence. Slow the retries
  the way the section 3 watchers do, since a deterministic failure,
  expired auth or an exhausted quota would otherwise re-run a paid
  agent turn every poll: after `FAST` quick attempts, one attempt
  every `RETRY` seconds, with a `NAG` alarm raised while the change is
  still unhandled. THE WATCHER NEVER ABANDONS THE CHANGE, which this
  paragraph claimed for a while that it did. It slows down and keeps
  complaining, which is what case 17 drives, and the blob is not
  recorded as consumed until a turn returns zero.
- Headless auth does not inherit from the GUI. Log the CLI in
  explicitly, smoke-test with a print-mode turn, then measure the
  loop with a no-op ping instruction that asks only for its own
  acknowledgement and for whether the turn was watcher-started.
- Serialise agent turns, never two at once. PERSIST the consumed-blob
  marker to a file the way the section 3 watchers persist theirs, and
  seed it from the current blob ONLY when that file is absent, which is
  a genuine cold start and is announced in one line. Seeding from
  current on every start looks like it prevents replay and actually
  hides, permanently, whatever landed while the watcher was down. That
  is the same silent skip section 3 spends a state file to avoid, and
  it has bitten a live deployment. Replay is prevented by the
  instruction protocol instead: the seat executes what its outbox has
  not acked, so a re-delivered instruction is recognised and skipped.
- The watcher loop itself needs the same survival treatment as the
  compute job: run it detached inside tmux or screen with the
  platform's stay-awake wrapper, never bare in a tool shell, or it
  joins the class of reaped children it exists to replace.
- A watcher-started turn is a DESCENDANT of the watcher's own
  detached session, so an instruction that restarts the watcher must
  be sequenced to survive its own executor: push the ack first, start
  the fresh detached session next, quit the old session last.
- A headless turn can execute PART of an instruction and stop, which
  is worse than not starting: the master sees an instruction taken
  and assumes it ran. Two rules close it. The agent prompt says an
  instruction is finished only when every step is done, and the ack
  reports each numbered step as done, skipped or failed. A turn that
  ends early writes PARTIAL first, names the step that stopped, and
  leaves the instruction open. Watchers enforce the same shape by
  marking an event consumed only on a successful turn.
- Give the team an ESCALATION LANE that does not wait for the next
  scheduled wake. A sub-session that needs the master within minutes
  writes a line whose first words say so, pushes at once, and asks
  the human to ping the master in the same breath. On platforms
  where nothing can wake a session on demand, the human IS the fast
  path for emergencies, and saying that plainly beats pretending the
  bus is instant.
- Headless and poke-driven turns are INVISIBLE in the platform's chat
  window: the human watching that window sees nothing move while the
  work lands as commits, and silence reads as failure. Section 2 sets
  the duty, an arrival line and a completion line in the session's own
  window for every message handled, and this is how it is met on a tool
  whose unattended turns write into a transcript nobody is watching.
  MANDATORY: the unattended turn still writes both lines, and at every
  human-given turn the sub-session OPENS with a short digest of
  everything its unattended turns did since the previous human turn,
  before handling the new request, so a user who was away reads one
  summary instead of scrolling. OPTIONAL per platform: an unattended
  turn ends by posting a native notification where one exists (on
  macOS, `osascript -e 'display notification "..." with title "..."'`),
  so completion is visible without opening anything.

Measured end to end on Cursor: up to one poll interval to detect a push and
about two minutes more for the agent turn. That is the time to the WORK
landing, not to anything appearing in the window a user watches, which is a
separate question answered by the three levels in section 2. This fills the
wake column for any tool with such a CLI. The human relay stays as the
fallback.

**Making a still window move: the local injector.** Where a seat's
unattended turns are invisible, a script on that machine can type into
the chat application and create a real turn. On macOS this is
AppleScript through the Accessibility permission, which the user grants
once in the system settings. THE GRANT GOES TO THE APPLICATION THAT
SENDS THE KEYSTROKES, which is the terminal the watcher runs in, and NOT
to the application being typed into. Getting that backwards costs an
evening: activating a window needs only Automation, which is what the
operator is prompted for and grants, so the window comes forward and the
composer stays empty with no dialog and no error anywhere a person is
looking. macOS caches the decision per process, so the terminal must be
quit and reopened after the grant, and any watcher started from the old
one restarted. On Windows the equivalent is UI Automation or a macro
tool. On Linux under X11 it is `xdotool`, and under Wayland it depends
on the compositor and often cannot be done at all. In a browser tab it
takes an extension or a driver such as Playwright, which is markedly
more fragile. On a remote host, in a container or in continuous
integration there is no interface to drive and no injector is possible,
which is the honest answer, and a workaround here would be a fiction.
Whatever the mechanism, give it a target it can IDENTIFY, never bare
keystrokes to whatever has focus, and have it write its own line into
the outbox as well, so the record survives an injection that lands in
the wrong place.

THE SHIPPED `bin/inject.sh` DOES NOT MEET THAT BAR ON A DESKTOP WINDOW.
It activates an application and types into whichever conversation is
frontmost, selecting no thread, and NOTHING IT CHECKS AFTERWARDS CAN TELL
IT WHICH CONVERSATION RECEIVED THE PASTE: the nonce it waits on proves a
turn ran, not where. So an application showing a different conversation
receives the instruction there, and the intended seat is never woken while
the injector waits out its acknowledgement. That is a real limit and not a
footnote: use it only where the seat owns a window nobody else touches, and
never where
a person also works in that window by hand. A seat that cannot be given a
window of its own belongs on the headless path with `bin/notify.sh`.

TWO THINGS ABOUT THE INJECTOR ARE COMMONLY MISREAD. The first is
direction. It is tempting to describe this as one platform driving
another, a master on tool X typing into a seat on tool Y, and that is
not what happens. The injector runs where the WINDOW is, on the seat's
own machine, under that machine's operating system and that
application's permissions. Which tool the master runs on has nothing to
do with whether it works. The master only writes a bus file and pushes,
exactly as it does for every other message, and something local turns
that into a keystroke. So the question is never "can tool X drive tool
Y", it is "does anything on this machine have permission to type into
this window", and the answer is per operating system and per
application.

The second is that A SEAT LIVING IN A TERMINAL IS THE EASY CASE, and
usually the better one. A CLI seat inside `tmux` takes
`tmux send-keys -t <session> '<line>' Enter`. For `screen`, put the text in
`line` and run
`screen -S <name> -p 0 -X stuff "$(printf '%s\r' "$line")"`, because WITHOUT
THE WINDOW SELECTOR AND THE CARRIAGE RETURN IT RETURNS ZERO AND SENDS
NOTHING: measured against a detached shell, which received no input and no
Enter from the shorter form this file used to print. Neither needs an
accessibility permission,
neither cares which application has focus, neither breaks when the
vendor moves a button, and both work over SSH on a machine with no
graphical session at all. Where a seat can be run as a CLI in a
multiplexer rather than in a desktop chat window, prefer that
arrangement for this reason alone: the same visibility costs a line of
shell instead of a permission dialog and a brittle script.

AND IT IS THE BEST FORM OF INJECTION RATHER THAN AN ALTERNATIVE TO IT.
`tmux send-keys -t <session>` names the target it is typing into, which is
exactly what the desktop injector cannot do, so the arrangement that costs
least also happens to be the only one that satisfies the identifiable
target rule above. Read the order as: a CLI seat in a named multiplexer
session first, a desktop window the seat owns alone second, and a headless
entry point with notifications where neither is available.

**Bringing up a Codex seat, from a run that did it.** Four things cost time
the first time and none of them is documented anywhere. THE APPLICATION IS
NOT CALLED WHAT YOU THINK when you go to drive it: the visible macOS process
answers to System Events as `ChatGPT`, not as `Codex`. The shipped injector
covers that gap, resolving the bundle identifier from the application name,
activating that application and driving the matching frontmost process, so
the process name by itself does not make `inject.sh Codex ...` fail. Check
the name the window server actually uses anyway before wiring any other
injector to it. Its companion limit
belongs in the same breath: the shipped injector selects no thread, and a
Codex window holds several, so an injection lands wherever the focus is and
can execute this repository's instruction in another workspace entirely.
`which codex` and
`command -v codex` both come back EMPTY on a Mac where Codex works, because
the binary lives inside the application bundle: look at
`/Applications/Codex.app/Contents/Resources/codex` and at
`~/.codex/plugins/.plugin-appserver/codex` before concluding the tool is not
installed. An unattended Codex seat does not come up by pasting the starter
prompt into a chat window, it comes up by handing that same prompt to
`codex exec`, which is the working non-interactive entry point. And set
`ON_CHANGE` when you run the shipped `bin/watch-inbox.sh`, since without it the
watcher prints the inbox and nothing is listening:

    # the approval flag is load-bearing, see the paragraph below. Use
    # --approve-for-me here: a seat under -s workspace-write cannot write
    # .git, and a persistent full-bypass command is refused outright
    ON_CHANGE="/Applications/Codex.app/Contents/Resources/codex exec \
      --approve-for-me \
      'read your inbox from origin/main and execute every open instruction
       your outbox has not acked, then push your branch'" \
      P=60 sh bin/watch-inbox.sh a main collab

With that in place the loop closes in fifty-nine seconds, one poll plus
one turn, and the seat creates its branch, creates its outbox and holds
branch discipline without further help.

**PREFER `codex queue` TO `codex exec`, and this is the later measurement
that supersedes the one above.** The command exec runs is a FRESH headless
child: it does the work correctly and the panel the operator is watching
never moves, so the seat looks dead to the only person who can tell it is
not. Codex Desktop also takes a message into the RUNNING session, which is
the route to use where the seat has a window:

    codex queue --thread <task id> --message '<one line>'

It is a plain shell command that reaches the running app through its
local server, starts no model session of its own, and delivers into the
panel the operator already has open. Wired as the injector's
`INJECT_CMD` against a twenty second poll, a push to the integration
branch reached a visible turn 34 seconds later, and a second observation
agreed at 35 seconds once a 1,058 second allowance outage was
subtracted. The seat then deleted its heartbeat and its idle model cost
went to zero.

The task id comes from the application's own task listing. THE MODEL IS NOT
HANDED ONE AT STARTUP, which is a different fact from the platform not
having one, and an earlier version of this file drew the wrong conclusion
from it: look in the application before deciding a seat cannot be
addressed. Two details of how a live seat did this are worth copying. It
kept the heartbeat running as a fallback until the event path had actually
passed, since an unproven path with no fallback is a silent seat. And it
gave the watcher its own isolated git state directory rather than sharing
the metadata of a live working tree, so a monitoring process could not
disturb the work it monitors.

Where a seat is genuinely headless, exec above is still the right answer,
and the seat is visibility level three. Never wire both on one seat: they
are two agents over one inbox holding none of each other's locks.

THE APPROVAL MODE IS THE PART THAT BITES, and it bites twice. First,
`codex exec -s workspace-write` looks like enough and is not: it denies
writes to `.git`, so the seat cannot create its branch and cannot push,
and what comes back is a polite report that the branch was not created
rather than an error you would chase. Second, the obvious remedy fails
for a DIFFERENT reason: a persistent watcher command carrying the full
sandbox bypass is refused by the platform's own safety review, so the
flag that works for a one-shot you type yourself will not work for the
command a watcher runs every poll. `--approve-for-me` is what a live
seat actually ran with. Read either refusal as an approval-mode problem
and not a protocol one. THE TWO SESSION IDENTIFIERS HERE ARE DIFFERENT
THINGS and an early note in this file conflated them. The DESKTOP seat,
the window a person types into, exposes no identifier the model can read,
so a Codex seat answers the starter prompt's session id question with
exactly the sentence the prompt provides for that case. A `codex exec`
child started by a watcher DOES print one, measured as
`session id: 01a03c57-4e18-7a51-bcf4-07ea2a93c4fc` on CLI
0.150.0-alpha.8. That identifier belongs to the fresh headless child and
names nothing that outlives it, so it cannot target or wake the desktop
parent and it is not a poke address. The master reaches a Codex seat
through the inbox either way.

### Real machines: long jobs, clusters and portability

**Facts a live deployment paid for, none of them in any manual.** A
laptop that sleeps FREEZES every `sleep` on it, so a watcher and a
check-in both stop and resume hours later believing no time passed, and
an SSH control socket to a remote host is dead when it wakes while
looking alive: reconnect through a wrapper that tests the socket, not
through a bare `ssh`. macOS ships neither `flock` NOR GNU `timeout`, so a
script that bounds a command with `timeout` fails there and a script that
locks with `flock` fails there. Bound a command portably by running it in
the background and killing it if it outlives the bound, which is what
`bin/selftest.sh` does. macOS has no `flock`, so a watcher that needs a
lock uses a lock DIRECTORY, `mkdir` being the atomic operation
everywhere. A facility that watches a file and runs a command on change
is not the same as one that gives a session a turn, and the first is
commonly mistaken for the second: test it once with a no-op and see
whether a turn actually starts. On a batch scheduler, the scheduler's
own binaries are often absent from a login shell's PATH, a wall clock
cannot be extended once a job is queued, and the first line a job logs
usually records its own startup and not its first real output, so a job
that has logged something has not yet produced anything.

**Long jobs when the tool cannot hold a process.** Many tools kill child
processes when a turn ends. Start long jobs detached and check them by a
growing elapsed time rather than by holding the turn open, and prefer a real
terminal multiplexer to bare `nohup`: some tool shells, Cursor's among them,
REAP nohup children the moment the turn ends, and the job dies silently. On
stock macOS there is no tmux, but `/usr/bin/screen` ships with the OS:
`screen -dmS <name> sh -c '<job>'` survives the turn's end and the app
quitting, and wrapping the job in `caffeinate -i` holds off idle sleep as
well, though a closed lid on battery still sleeps the machine. On Windows
either use WSL, where everything here applies unchanged, or run the job from
the human's own terminal and have the session read the log file it writes. A
job that only survives while a turn is open is not a long job.

AND THIS APPLIES TO THE VERIFICATION RUN ITSELF, which is where it was
learned the expensive way. `bin/selftest.sh` takes about a quarter of an
hour, which is longer than many turns, and three consecutive runs of it
started with `nohup ... &` from an agent's own shell DIED PART WAY, at
cases 43, 25 and 32, each leaving a log that ends mid-case with no
totals line. Nothing announced it. The master read the last lines of one
of those logs, saw no failures in them, and reported the suite green to
the person waiting on it; the review seat then ran the same suite to
completion from its own clone and got three failures. `nohup` blocks
SIGHUP and does not save a child from a process group or a cgroup being
cleaned up when the turn's shell is reaped, so the fix is a SESSION of
its own. ON LINUX that is `setsid sh bin/selftest.sh > log 2>&1 < /dev/null
&`, whose session id equals its own pid and which no longer belongs to the
shell that started it. STOCK macOS SHIPS NO `setsid`, which the paragraphs
above already say of `flock` and GNU `timeout`, so there the session comes
from the tool those paragraphs name instead: `/usr/bin/screen -dmS
subsession_selftest sh -c 'exec sh bin/selftest.sh > log 2>&1'`. THEN CHECK
THAT IT REALLY DETACHED, THE WAY THAT PLATFORM ALLOWS. On Linux,
`ps -o sess= -p <pid>` for the run's own pid must come back equal to that
pid. On macOS that column is not the evidence: run as this file used to
print it, with no pid selector, it returned fifteen zeroes and identified
nothing, and even the detached screen process reported session zero. There
the evidence is `/usr/bin/screen -ls` showing `subsession_selftest` as
Detached, with that screen process carrying PPID 1. Either way, the check
worth making at the end is the totals line, and the alternative is assuming
the flag worked.

**Projecting a long campaign from its first completions.** The first
jobs to finish are the SHORTEST jobs when jobs run CONCURRENTLY, so a
wall-clock projection from the first N completions is then biased low
whenever job sizes differ (a serial first-come queue instead makes
the first completions a size-random sample, noisy but unbiased).
Project per size stratum and extrapolate the missing strata by the
observed scaling, stating the assumption: one real first-eight
projection read 20 hours on the shortest stratum and roughly three
times that once the missing strata were priced by the observed
scaling. The same structure makes completions arrive in
WAVES, so a liveness alarm on checkpoint age must tolerate a silence
of one full job length at the largest stratum before it calls the
runner dead.

**A sub-session on a compute cluster.** The strongest reason to mix
tools is that one of them sits next to real compute: a sub-session
whose tool runs on a machine with a batch scheduler, Slurm or any
other, can carry campaigns the master's environment never could. The
protocol needs three substitutions and nothing else.

- THE RUNNER IS A SCHEDULER JOB. Long work is submitted, `sbatch` or
  the local equivalent, never run in the session's own process, and
  the submission command with its returned JOB ID goes into the
  outbox the moment it exists. Liveness is a scheduler query by that
  id, `squeue`/`sacct` or equivalent, replacing the process checks of
  section 3, and "the queue is long" belongs in a report line rather
  than in the work. The scheduler answers only whether the job still
  runs: a job gone from the queue has merely ended, and whether it
  WORKED is answered by the artifact gates alone.
- ARTIFACTS COME HOME THROUGH GIT, PUSHED BY THE SESSION. Compute
  nodes commonly have no outbound network and no credentials, so the
  batch script never commits or pushes anything: the SESSION collects,
  commits and pushes after the job ends. The completion test stays
  artifact-over-log: a job is done when its output file exists, passes
  its pre-registered gates, and is committed and pushed on the
  sub-session's branch. An output too large to commit is recorded by
  its hash and byte size in the outbox together with the exact command
  that fetches it, so the master can verify without holding the file.
- RESUMABILITY IS THE SCHEDULER'S OWN. Jobs are written resumable exactly as
  section 4 demands, and the cluster's native forms, array jobs for
  replication grids, requeue-on-preemption, checkpoint files, satisfy the
  rule. A walltime limit is a planned interruption, so a job that cannot
  survive one is not ready to submit. And a job outlives the instruction
  that launched it: when that instruction is superseded or the sub-session
  stands down, cancel the job, `scancel` or the local equivalent, and record
  the cancellation in the outbox, since a forgotten job spends the user's
  allocation on an answer nobody is waiting for. Everything else is
  unchanged: the bus, the gates, the review duty and the economy rules apply
  to a cluster sub-session as to any other, and its check-in cadence follows
  section 9's two dials with the block length read from the QUEUED work, and
  where the scheduler publishes an estimated start, `squeue --start` on
  Slurm, the first check-in is paced from that estimate rather than from a
  fixed interval.

**Continuity between turns is the ledger skill's territory.** When a
sub-session's platform takes turns rather than running continuously,
usage limits included, the ledger discipline that keeps its task
resumable is a separate, composable skill named ledger. Run both. This
protocol governs how the team divides and verifies work, ledger governs
how any one seat survives its own interruptions.

**Shell and userland.** All seven shipped scripts are POSIX shell, with
no bashisms, and are meant to run under dash, bash, zsh or busybox
alike. The suite refuses to start if any of them fails `sh -n`. Two
portability traps are already handled in them and are worth knowing if
you write more: `wc -l` pads its output with spaces on BSD and macOS,
which silently empties a state file parsed by column, and a plain `git
fetch origin <branch>` never creates `origin/<branch>` in a clone whose
refspec does not cover it. `pgrep -f` exists on Linux and macOS with the
same flag but not on Windows outside WSL, where the elapsed-time check
is the fallback. `git ls-remote` is the one probe the shipped scripts
rely on and it behaves the same everywhere.

## Part two: why this shape

**Git files beat any side channel.** They are tool-agnostic, durable,
ordered and reviewed, so the collaboration's own history becomes part
of the repository's history. A chat log is none of those things, and a
queue or a database is a second system to keep alive.

**Exclusive writers, per file and per branch, remove a whole class of
failure.** No push races, no merge conflicts on the bus, no lost
appends. That is what lets two sessions commit every few minutes
without coordinating, and it is why the outbox is append-only and the
inbox has exactly one author.

**Master adjudicates.** One mind stays responsible for the tree while
still harvesting a second model's independent judgement. The seat's
review is advisory, loud and logged, the master's rulings are reasoned
and logged, so a disagreement makes the work better instead of forking
it.

**Reviewing the protocol and reviewing a run of it find different
things,** and neither substitutes for the other. Reading these files
finds what is missing, contradictory or unclear in them. Operating them
finds what they never anticipated: a finding going unruled, a reminder
arriving stale, a timer outliving its work, a watcher that survived the
signal meant to stop it. Most of the rules here came from the second
kind, which is the argument for running the protocol on something real
before trusting it with something that matters.

AND READING THE DIFF IS A THIRD KIND, which one night made unmistakable.
Three seats reviewed the same package the same evening: one read both
documents end to end and returned eleven disagreements between
sentences, one drove real operations and reproduced a live incident, and
one read only the hunks of that evening's commits. The third found two
defects neither of the others could have: a repair that made CREATING a
record atomic while leaving the path taken when the create FAILS able to
delete a live claim, and an exit trap that removed a record its process
no longer owned. Both were invisible to a reader, because the files
read correctly, and invisible to an operator, because the windows are
narrow enough that fifty trials missed them. A change is a third
artifact, beside the text and the running system, and it deserves its
own reader.

**The liveness stack exists because sessions and containers die without
warning.** Check-ins, watchers, pokes and resumable runbooks are four
answers to the same fact. The design goal is that any single death
costs at most a few minutes of recomputation and zero information.

---

Copyright 2026 Zheng Luo (Davies Luo). Licensed under the Apache
License 2.0, whose text is the `LICENSE` file beside this one.
