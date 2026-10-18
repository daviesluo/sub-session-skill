## 1. Roles

Contents:

- 1. Roles


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

