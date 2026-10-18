## 3. Liveness: check-ins, watchers and wake-up pokes

Contents:

- 3. Liveness: check-ins, watchers and wake-up pokes
- Self check-ins
- Installing a watcher, and every dial it reads
- Process checks that do not lie
- The two watchers
- ON_CHANGE, and the lock that keeps turns serial
- The self-test
- Wake-up pokes
- Stand-down
- Surviving the machine


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

