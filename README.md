# sub-session

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.0.1-brightgreen.svg)](#version)
[![Self-test](https://github.com/daviesluo/sub-session-skill/actions/workflows/selftest.yml/badge.svg)](https://github.com/daviesluo/sub-session-skill/actions/workflows/selftest.yml)
[![Tools](https://img.shields.io/badge/runs%20on-Claude%20Code%20%C2%B7%20Cursor%20%C2%B7%20Codex-lightgrey.svg)](#it-runs-anywhere-and-mixing-tools-is-the-point)

**Run Claude Code, Codex and Cursor as one team on one repo, with git as the only message bus.**

One master session holds judgement and is the only one that merges. One or more
sub-sessions run long jobs or review everything independently, each on its own
branch. They talk through two markdown files per seat, and every file has exactly
one writer, so push races and overwritten work cannot happen: the bus is plain
git, so it survives crashes, works across machines and vendors, and leaves the
whole conversation in your history.

![A master shell pushes an instruction; a second shell standing in for a seat
receives it, writes an outbox reply, and a three-line notification
prints.](docs/demo.gif)

## Install

```sh
npx skills add daviesluo/sub-session-skill
# or: npx skills add daviesluo/sub-session-skill -a claude-code
#     npx skills add daviesluo/sub-session-skill -a cursor
#     npx skills add daviesluo/sub-session-skill -a codex
```

That finds one skill (`sub-session`) and copies the package, including `bin/`
with executable bits, into `.claude/skills/sub-session` (or the matching
scanned path for the agent you pick). On Claude Code 2.1.275 or later you can
instead install the same skill as a plugin:

```
/plugin install sub-session --marketplace daviesluo/sub-session-skill
```

Then tell your main session: "You are the master. Set up a sub-session team."
It creates the bus files, prints a starter prompt for the seat, and measures
the link.

Optional, about 15 minutes: `cd .claude/skills/sub-session && sh bin/selftest.sh`.

Installing the folder by hand, and how pointers relate to scanned paths, is
[further down](#how-the-skill-loads).

## Quickstart (60 seconds)

1. Run the install command above.
2. In your main session, say: "You are the master. Set up a sub-session team."
3. Paste the starter prompt it prints into a second session — another tool, or
   another window on the same tool.
4. Tell the master you are done. It sends a no-op handshake; the seat
   acknowledges; both windows report the measured lag.

## When to use it

- A long job (training run, data rebuild, big migration) has to run while you
  keep editing.
- You want a second model, ideally from another vendor, to review every change.
- You already juggle several agent windows and are tired of copy-pasting
  between them.

**When not to use it:** helper subagents that live inside one session. Use
your tool's built-in subagents for that. This protocol is for real sessions,
each on a real platform, each with its own branch.

## Compared to Claude Squad and OpenRig

Cells for Claude Squad and OpenRig are taken from those projects' READMEs
(fetched 2026-10-18; re-checked the same day). A cell nobody can verify from
the README is marked "not stated in README". In-tool subagents are not in
this table.

| | sub-session | [Claude Squad](https://github.com/smtg-ai/claude-squad) | [OpenRig](https://github.com/mvschwarz/openrig) |
|---|---|---|---|
| Agents it can run | anything with a shell; loading checked on Claude Code, Codex, Cursor, opencode, grok | Claude Code, Codex, Gemini, Aider and other local agents (`cs -p "<program>"`) | Claude Code and Codex sessions, terminal nodes, Pi / Oh My Pi via RPC runners |
| Mix vendors in one team | yes | yes (one per instance) | yes ("Claude Code and Codex in the same rig") |
| How it runs | 7 POSIX shell scripts, no daemon | terminal TUI on tmux + git worktrees; needs tmux and gh | local daemon + CLI + TUI + MCP server on tmux, SQLite; Node.js 22/24; macOS/Linux (Windows via WSL2) |
| Seats on different machines | yes, any shared git remote | not stated in README (describes "local agents" in tmux) | not stated in README. RigBundle "share topologies across machines" shares team definitions, not a live cross-machine team |
| Isolation per agent | own branch | own git worktree / branch per task | not stated in README as per-seat branches |
| Messages between agents | committed `INBOX` / `OUTBOX` files | not stated in README (human attaches to each session) | `rig send` / MCP tools (`rig_send`, `rig_chatroom_send`), queue |
| Resume after crash or stop | state is commits | pause (`c`) / resume (`r`) a session; crash recovery not stated | `rig down --snapshot` then `rig up` restores; per-node outcome (resumed / fresh-primed / …) |
| Audit trail of the conversation | git history | not stated in README | not stated as a conversation history (it mentions `bundle-audit.jsonl` for installs and audited permission changes only) |
| Single merge authority | enforced (master only) | not stated in README ("review changes before applying them") | not stated in README (roles like lead/builder/reviewer exist) |
| License | Apache-2.0 | AGPL-3.0 | Apache-2.0 |

## The problem

One session cannot compute for two days and edit documents at the
same time, and nobody checks its work. Adding sessions the naive way
invites push races, overwritten files and silent divergence, and
running them on different platforms usually means a human carrying
messages between windows all day. This protocol removes the chaos
structurally by giving every file and branch exactly one writer, and
it shrinks the human's part to the platform floor: no relay at all
where the tools allow it, one pasted line where they do not.

## The shape of a team

![The user's normal control point is one master session, though they can
speak to any seat directly. Between the master and the three sub-session
seats sits the git remote, the only thing any two sessions share: every
inbox lives on the integration branch, and every outbox lives on the
branch of the seat that owns it. The master writes numbered instructions
down into INBOX_a.md, INBOX_b.md and INBOX_c.md, one per seat. Each seat
appends results, findings and escalations to its own outbox,
OUTBOX_a.md, OUTBOX_b.md or OUTBOX_c.md, and pushes only its own branch.
Seat a is a compute seat running long jobs on a detached runner, seats b
and c are review seats doing independent verification and a second
unrelated reading, and each sits on whichever tool suits its job,
Cursor, Claude Code and Codex in the example.](team.svg)

**Four terms carry the rest of this page.** A **seat** is one sub-session: a
real session on a real platform, with a branch, an inbox and an outbox
of its own. Its **lane** is the file set it may write, everything else in
the tree being read-only to it. The **integration branch** is the one the
master owns and merges into, `main` in most repositories and `develop`
or `trunk` in some. The **bus files** are two markdown files per seat,
`INBOX_<name>.md` and `OUTBOX_<name>.md`, in a directory of your
choosing: **every inbox lives on the integration branch and is written
only by the master, and every outbox lives on the branch of the seat
that owns it and is written only by that seat.** That last sentence is
the whole bus, and everything below rests on it.

The master is the normal control point, and the user can always speak to
a seat directly, which is why every session answers in its own window. It
holds judgement, edits, adjudication and the project ledger, a running
record of what is done and what remains that the companion protocol at
the foot of this page defines, and **it is the only session allowed to
merge**. Each sub-session owns one branch and one outbox and touches
nothing else, so two writers never meet and a push race cannot happen.

## How the skill loads

**To try it, the [install](#install) one-liner is enough.** The rest of
this section is for installing the folder by hand, or for understanding
how a tool finds the protocol.

Clone https://github.com/daviesluo/sub-session-skill and open it with
your tool. That repository is this folder and nothing else, so the two
pointers below land at the paths the tools scan, and whichever route a
tool takes it reaches one `SKILL.md`, so no copy can go stale against
another.

| Tool | Where it looks | How a session reaches it |
|---|---|---|
| Claude Code | `.claude/skills/sub-session/SKILL.md` | `/sub-session`, a registered skill |
| Cursor, Codex, other `AGENTS.md` tools, with a pointer at `.agents/skills/sub-session/SKILL.md` | that path | a registered skill, `$sub-session` or `/sub-session` |
| The same tools where no pointer sits at a scanned path, the folder embedded deeper in a host repository | one line in `AGENTS.md` | the model reads the file. There is no slash command |
| Anything else with a shell | nothing to scan | paste `SKILL.md` in as the session's briefing |

Loading was checked on real installs of Claude Code, Codex, Cursor,
opencode and grok, and a Codex seat ran the whole protocol on this layout
with a fifty-nine second round trip. A pointer at a scanned path registers
a skill you can invoke by name; a line in `AGENTS.md` makes the model read
the file and registers nothing. Both routes work, and the deployment this
package grew up in ran on the second one. No tested CLI needed a restart,
so if yours cannot find the skill, restart it before debugging anything
else.

**To install it in a repository of your own by hand,** copy this folder in
somewhere that is not itself a scanned path, add one pointer at the path
your tool does scan, and **delete the two that came with the folder**.
A pointer is `SKILL.md`'s own front matter plus a few lines naming
`SKILL.md`, and the two shipped here are the template: copy one out and
fix its relative path, which is the only part that changes. **The order
matters.** Drop the folder straight onto `.claude/skills/sub-session/` and
`SKILL.md` is already at the scanned path, so writing a pointer there
overwrites the protocol. Either put the folder at a path of your own and
point at it, or put it on the scanned path and add no pointer at all.
What you keep is two paths and one copy of the protocol. The
`references/` files next to `SKILL.md` are part of that copy; they have
to travel with it.

Then run the self-test, before you trust the watchers on this machine:

```sh
cd path/to/sub-session && sh bin/selftest.sh
```

It syntax checks all seven shipped scripts and exercises all seven
against throwaway repositories. Each numbered case establishes the
behaviour its own fixture drives, and a case that guards a repair is
written to fail on the code as it stood before that repair, since a case
that passes either way proves nothing. It prints its own numbered cases
and its own totals, and needs no GNU coreutils, so stock macOS is not a
special case. Budget a quarter of an hour and expect more on a loaded
machine: almost all of that is real watchers sleeping between real polls.

## The guided start

Setting the team up is one scripted sequence the master drives, and
the user's whole part is pasting one prompt per seat and answering
one question.

1. The user tells the master to set the team up. The master installs
   the folder, creates the bus files described above and pushes them,
   and pre-authorises the protocol's own calls, which means adding the
   handful of commands a wake-up, a stand-down and a watcher restart
   need to whatever that tool uses to approve commands, so no dialog can
   interrupt one. Section 7 of `SKILL.md` names those calls and says how
   to tell it took; the pasteable starter prompts are in
   [`references/setup.md`](references/setup.md).
2. The master emits the first sub-session's starter prompt, complete
   and copy-paste ready. The user pastes it into a session on the
   other platform and says one word back.
3. The master runs a handshake: a no-op instruction goes to the new
   seat's inbox, the seat acknowledges, and both sides report in
   their own chat windows that the link is up and what the measured
   lag is in each direction, with the master naming what would
   shrink a lag that sits above the platform's floor.
4. The master asks the one question: start work, or add another
   seat. Adding one repeats steps 2 and 3.
5. With two or more seats, the master proposes a division of roles
   matched to platform strengths, compute next to real hardware,
   review on the strongest model, and the user confirms or adjusts.

If the master cannot drive this, which happens on a tool with no shell
of its own and on a seat whose platform blocks the setup calls, the same
five steps work by hand. Create the bus files and push them, paste the
starter prompt from [`references/setup.md`](references/setup.md) with its
seven placeholders filled in at all sixteen of the places they appear,
including the two long ones that wrap across lines and are easy to miss.
Then send the handshake yourself by appending one no-op instruction to
the seat's inbox and pushing it. The seat's acknowledgement lands in its
outbox on the remote either way, and the gap between the two pushes is
the same measured lag. Nothing in the protocol needs the automation,
which only removes typing.

## What you get

- **Roles with hard edges.** The master assigns, adjudicates and
  merges. Sub-sessions execute and review, on their own branches,
  and never open pull requests or push anything else.
- **A second pair of eyes on everything.** Sub-sessions carry a
  standing review duty over the whole project, the master's own work
  included, and the master adjudicates every finding with reasons.
- **A duplex bus at the platform floor.** The shipped watchers carry
  both directions, and with `ON_CHANGE` set an inbox push starts a real
  agent turn within one poll. Measured end to end on Codex: fifty-nine
  seconds from the master's push to the seat's acknowledgement, one poll
  plus one turn. Where a tool has no watcher and no way to start a turn
  from one, one line pasted by a human still moves the loop.
- **Liveness that assumes failure.** Self check-ins, watchers in
  both directions, stored wake-up pokes with a proven escalation
  ladder (manual poke, scheduled one-shot, human relay), runbooks
  that restart a dead runner with one command, and survival rules
  for platforms that reap background processes.
- **Reporting that is honest about what the user can see.** Every
  handled message produces two lines in the session's own transcript,
  one on arrival and one on completion, and a look that finds nothing
  stays silent. Where a seat's unattended turns run headless, those
  lines land in the turn's transcript and the window the user is
  watching does not move, so each seat states at setup which of three
  visibility levels it can offer, the master never reads a still window
  as evidence, and the next human turn opens with a digest of everything
  that ran unwatched.
- **Three shipped scripts the platforms do not give you.** An injector
  puts the turn in the seat's own window, a notifier gives the team one
  notification format, and a supervisor keeps a watcher alive through the
  ceilings and orphanings that kill them quietly. The section below has
  the design and the costs.
- **A bus tuned for the shortest round trip.** Writes are pushed the
  moment they are made, the poll tightens while a reply is due, and a
  message is acted on in the turn it arrives. The handshake measures the
  loop, so a link that later runs slow is a defect with a checklist
  instead of a shrug.
- **Verification nobody can argue with afterwards.** A run's
  acceptance gates are written down before it starts, so the bar is
  never renegotiated once the result is in. Completion is tested
  against the artifact and never against a line in a log. New code is
  pre-flighted before compute is spent on it, and one remedy changes
  one thing, so the outcome says which thing worked.
- **A budget that scales with what it protects.** Shell watchers cost
  no tokens and carry the routine signal. Cheap fresh sessions do the
  watching that needs judgement. The expensive master wakes on events
  and on the human, never on a timer tighter than the event it is
  waiting for, and a session whose work is finished is retired rather
  than left idling.

## Notifications and direct injection

A team whose whole conversation lives in committed files is invisible to
the person paying for it. The work lands as commits while the chat window
sits still, and a still window reads as a dead session. Measured here: a
master pushed an instruction, the seat acknowledged it three minutes later,
and the person watching asked whether it had been sent at all. The link was
perfect and looked dead.

### Direct injection: the seat's own window does the work

Injection types the instruction into the seat's chat window and presses
enter, so a real, visible turn runs where the user is already looking.
**This is the default on any seat with a desktop window**, and a headless
entry point is the fallback for a seat with none.

**The injector waits, and that is the whole design.** Injection is
asynchronous: the keystroke returns when enter is pressed while the turn
runs on inside the application. An injector that returned there would drop
the watcher's lock with its own turn still going, and the next change would
start a second turn beside it. So it blocks until the seat reports
completion, and it waits on a token minted per injection rather than on a
timestamp, because a shared stamp file cannot say whose turn finished.

| outcome | what it means | what the watcher does |
|---|---|---|
| finished | the seat echoed the token | records the change handled |
| **may still be running** | the outcome is unknown: the wait timed out, a delivery was abandoned mid-flight, or typing failed part way through the line | **keeps the lock, starts nothing beside it**, until the `HOLD` quarantine expires and reclaim can free it |
| never typed | no grant, wrong app, no window, or another seat held the machine-wide lock for the whole wait | retries freely, nothing is running |

The middle row is the safety argument. These are the failures that cannot
say what happened, and retrying one could put a second turn beside a live
one or a second instruction beside a half-typed one, so they share an exit
code of their own and the watcher treats it unlike every other failure. The
bottom row is the opposite claim and has to earn it: 1 is returned only
where nothing can have reached the seat.

Four ways to reach a seat, best first: the tool's own delivery command
addressed by identifier, a CLI in a named multiplexer session, a desktop
window the seat owns alone, and a headless entry point. Never a window a
person also works in by hand. `bin/inject.sh` carries the per-platform
focus, paste and clipboard behaviour, each step of it answering a measured
failure.

### Notifications: one format, and the arrow means traffic

Every state change except arming raises one notification, three lines every
time: who, what state, and one line of detail. One shape for the whole team,
so nobody works out whose convention they are reading.

```text
Claude Opus 5 → Cursor Grok
started
an inbox change arrived, starting a turn

Cursor Grok → Claude Opus 5
finished
the turn ended, its report is the seat's to push

Claude Opus 5
alarm
nothing new in 1800s
```

| first line | state | what it tells you |
|---|---|---|
| master → seat | `started` | an inbox change reached a seat and a turn began |
| seat → master | `finished` | the turn ended, its report is on the seat's branch |
| one name, no arrow | `alarm` | a link has gone quiet and a person is needed |

**The arrow appears only where a message actually crossed between sessions.**
The seven states are armed, started, finished, failed, slowing, recovered
and alarm, and the ones that carry an arrow are the ones about the work,
while the rest are about the link itself and belong to one session alone. An
arrow on those would claim a message moved when none did. The direction is
declared by the caller and never inferred from the state name, since the
same name means an arrival on one watcher and a departure on another.

**One rank decides how loud each state is, and every backend renders that
same rank in its own medium.** `failed` and `alarm` are urgent, a person
is needed. `slowing` and `recovered` are notices, the link changed state
by itself. The rest are the ordinary heartbeat and stay quiet. A sound is
not an icon and the media cannot be made equal, but the order can be, so
a person watching two platforms learns the rule once.

A silent seat and a working one look identical, so nothing fires on a poll
that saw no change. A window reporting nothing sixty times an hour is a
window in which the next real arrival is invisible, which is the failure all
of this exists to fix.

### Supervision: the watcher outlives whatever started it

Two silent failures, both measured. **A watcher dies with whatever streams
it**, because many agent tools run background commands through a facility
with a hard lifetime ceiling, thirty minutes on one platform, and a flag
promising persistence does not raise it. And the reverse, worse because it
looks healthy: **an orphaned watcher keeps polling and advancing its state
file** while its output reaches nobody, so every entry it consumes is one
the next watcher never shows anyone.

The supervisor adopts before it starts, killing an older watcher whose
output can no longer reach anyone, and restarts on exit with an escalating
backoff. That is safe only because the watchers keep their state beside the
clone's git directory: a restart replays nothing, skips nothing, and
delivers whatever landed while it was down. Without that property a
supervisor would be a way of losing entries on a schedule.

Sections 2 and 3 of the protocol carry the commands for all three
(`SKILL.md` and [`references/bus.md`](references/bus.md),
[`references/liveness.md`](references/liveness.md)), and the settings
table in section 3 names every dial each one reads.

## It runs anywhere, and mixing tools is the point

The bus is git and nothing else. A session needs a shell, git 2.13 or
newer, push access to a shared remote, and permission to read the command
lines of its own processes, which the Requirements section below sets out.
The git version matters for one reason: 2.13 is where `git rev-parse
--absolute-git-dir` arrives, and that is the one modern call the watchers
make. Schedulers, headless CLIs, background monitors and
cross-session wake-ups lower latency where they exist, and none of them
is load-bearing: every instruction, report, finding and ruling is a
committed file that any session reads on its next turn.

Because that is all the bus is, the master and each seat can sit on
different tools, and the per-tool notes in `APPENDIX.md` come
from running it that way: which shells reap `nohup` children,
what replaces tmux on stock macOS, how headless authentication
differs from the GUI, and what a batch scheduler changes for a
compute seat on a cluster.

## What is in here

| File | What it is |
|---|---|
| `SKILL.md` | The protocol a session loads first: roles, the bus rule, setup, and one-level links into `references/`. The body is kept under 500 lines. |
| `references/` | The rest of the protocol, unchanged: bus details, liveness (including the settings table), work design, verification, multi-seat, setup prompts, any-tool notes, economy, design notes. |
| `APPENDIX.md` | The two parts you read once and then leave alone: what each tool actually gives you, with the failures a live deployment paid to learn, and the reasoning under the design. |
| `README.md` | This page. |
| `.agents/skills/sub-session/SKILL.md`, `.claude/skills/sub-session/SKILL.md` | Two pointers, each `SKILL.md`'s own front matter plus a few lines: which file to read, how to find it if the relative path does not resolve, and what else is in the package. They are what makes the skill load on every tool that scans either path, from one copy of the protocol, and they are the template to adapt when installing the folder elsewhere. |
| `EXAMPLE.md` | A worked inbox and outbox pair, so the shapes are concrete before you write your own. |
| `bin/watch-outbox.sh` | The master runs this one. It watches a seat's branch and prints the new outbox entries as they land, not merely that the branch moved, because an ack, a finding and an escalation are all outbox lines and a head SHA carries none of them. Set `DUE=<seconds>` and it also reports silence, once, when a seat has not spoken for that long. |
| `bin/watch-inbox.sh` | The seat runs this one. It watches the integration branch and prints its inbox when it changes, and with `ON_CHANGE` set it starts a real agent turn instead of printing into a room with nobody in it. A failed turn is retried, then eased off, never abandoned. Set `NOTIFY` and every state change reaches a window a person is actually watching, and leave it empty and the watcher says so as it arms, since an unwired watcher and a quiet lane look the same from outside. |
| `bin/inject.sh` | Delivers one line into a seat's running conversation, then waits for that turn to finish, identified by a nonce it mints. It types and presses enter by default. Set `INJECT_CMD` and it hands the line to a command instead, which is better wherever the platform has a real delivery route. Point a watcher's `ON_CHANGE` at it and the seat's own window does the work, where the person paying for it can see. See the section below: this is the preferred path, not an extra. |
| `bin/supervise.sh` | Runs a watcher and keeps it running. It adopts and kills an orphan whose output can no longer reach anyone, and restarts on exit with an escalating backoff. Use it wherever the thing that starts a watcher can itself expire, which on several tools it does on a fixed schedule. |
| `bin/notify.sh` | The `NOTIFY` recipe, shipped rather than described. One desktop notification per state change except arming, in the team's single format, on macOS, Linux or Windows, ranked for loudness by the rule above. On a machine with no notifier it says so on every state and still exits zero, because a view of the work must never be able to stop the work. Set `NOTIFY_ECHO` and it prints the three parts instead, which is how you see what a seat will show before arming it. |
| `bin/master-check.sh` | Rehearses the master half of the protocol on whatever tool you are running, and prints a report plus four questions no script can answer. Run it once per platform you might put a master on. **It pushes two branches to your real remote**, `rehearsal/<name>-integ` and `rehearsal/<name>-seat`, and deletes them at the end, because being able to push is the capability under test. A seat told to run it is having its lane widened, so the instruction that assigns it has to say so by name, and the operator needs branch delete permission as well as push. |
| `bin/selftest.sh` | Syntax checks all seven and exercises all seven against throwaway repositories, handing `bin/master-check.sh` an origin nobody owns, since it pushes rehearsal refs to whatever origin it finds. It needs no GNU coreutils, so it passes on stock macOS. The case and assertion counts are printed by the run itself, which is the only place worth trusting them from. |
| `scripts/check-skill-coverage.sh` | Proves every non-empty line of the v1.0 `SKILL.md` still appears in today's `SKILL.md` or `references/`. Not one of the seven protocol scripts. |
| `docs/demo.gif` | The short recording at the top of this page. |
| `.claude-plugin/` | Claude Code marketplace and plugin manifests, so `/plugin marketplace add daviesluo/sub-session-skill` can resolve this skill. |
| `team.svg` | The diagram above. |
| `LICENSE`, `NOTICE` | Apache 2.0 and the notice that has to travel with any redistribution. |

## Using it

Installed and self-tested per the table above, the working loop is:

1. Tell the master session to set the team up, and follow the guided
   start. It brings up one seat at a time and measures the link before
   you assign anything real.
2. Assign work by inbox, harvest by outbox, adjudicate every finding
   with reasons, merge a lane when its gates pass.
3. Retire a seat the moment its work is done. Section 9 of the protocol
   ([`references/economy.md`](references/economy.md)) explains why that
   one habit dominates the running cost, and section 5
   ([`references/verification.md`](references/verification.md)) keeps
   the results honest while you do it.

## What it does not do

It does not open a seat the user has not approved, and it does not create
one on its own initiative. The master proposes a seat and waits, because
opening a session spends the user's allowance and puts a window on their
screen. Every seat is a real session on a real platform, listed wherever
that platform lists sessions and writing to a branch nobody else writes
to. Helper agents that live and die inside one session are useful and are
not seats, and the protocol never reports one as a seat.

It does not call model providers directly, run hidden subprocesses, or
manufacture a capability the host tool lacks. What a seat's own watcher
starts is the seat owner's choice: an `ON_CHANGE` configured with a
headless command line runs that command line, and its output lives in the
watcher's log and in what it commits. Where a platform cannot wake another
session, the protocol says so and falls back to one line a person pastes.

## The companion protocol

Continuity across time belongs to the ledger protocol, whose repository is
https://github.com/daviesluo/ledger-skill: one live ledger, a hook that
keeps it moving with the work, and a resume ritual for the next session
on any platform. This protocol covers sessions running at the same
time, that one covers platforms taking turns, and the two are designed
to run together. Each sub-session's outbox is its lane-owned ledger in
that protocol's sense, so a team that loses a seat overnight resumes it
from the repository in the morning. Running both costs one config line
per seat, given in section 2 of `SKILL.md`: leave it out and that
protocol's hook refuses every seat's first checkpoint.

## Requirements

A shell, git 2.13 or newer, push access to a shared remote, and
permission to read the command lines of this session's own processes
with `ps -o args= -p`, per session. The git version matters: the watcher
scripts locate their state file with `git rev-parse --absolute-git-dir`
and refuse to start without it. **The fourth is easy to miss, and a
sandbox can withhold it:** where process identity is hidden, a watcher
cannot tell its own kind from a stranger, so it refuses to adopt or to
arm beside an unreadable owner rather than guessing, and the self-test
reports that refusal. Run it outside the sandbox and the same build runs
clean. Everything else is optional acceleration.

## Version

**1.0.1, October 2026.** Packaging and documentation revision of the
1.0 protocol (September 2026). The protocol text is the same; it now
lives in `SKILL.md` plus `references/`. This repository also gained a
Claude Code marketplace manifest, a self-test workflow, and the demo
at the top of this page. Notes: [`docs/release-notes-v1.0.1.md`](docs/release-notes-v1.0.1.md).

**What is in it.** The protocol, a bus made of committed git files, and seven
scripts. Two watchers carry the two directions of that bus. An injector puts
a turn in a seat's own window and waits for it to finish. A notifier gives
the whole team one notification format. A supervisor keeps a watcher alive
through the two ways it dies quietly. A rehearsal proves the master half of
the protocol on a platform before a team trusts it there. A self-test
syntax checks all seven, exercises all seven against throwaway
repositories, and prints its own counts.

**Where it has run.** As a live team across Claude Code, Cursor, Codex and
Antigravity. Every rule here that reads like a hard rule is one that a run
broke without, and every number quoted in this file and in `APPENDIX.md` was
measured on one of those runs rather than reasoned about.

Copies of this folder drift: when updating one, check its version
line against https://github.com/daviesluo/sub-session-skill.

Licensed under the Apache License 2.0, whose text is the `LICENSE`
file in this folder. Copyright 2026 Zheng Luo (Davies Luo).
