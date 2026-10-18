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

