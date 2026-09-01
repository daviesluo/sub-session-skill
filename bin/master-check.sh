#!/bin/sh
# Copyright 2026 Zheng Luo (Davies Luo). Licensed under the Apache License
# 2.0, whose text is the LICENSE file in this package. Keep this notice
# when you copy the script.
#
# master-check.sh <name> [bus-dir]
#
# Rehearses the MASTER half of the protocol on whatever tool you are running,
# and prints a report. Run it once per platform you might put a master on.
#
#   sh bin/master-check.sh opencode
#
# WHY THIS EXISTS. Every platform note in this package was written from the
# SEAT side: how the skill loads, whether the tool can be woken, whether a
# watcher survives. The master's needs are different and nobody had asked
# about them, so the seat half of the protocol was tested on four tools and
# the master half on one. A seat needs to RECEIVE a wake and a master needs
# to SEND one, and those are different capabilities on every tool measured.
#
# WHAT IT CAN AND CANNOT DECIDE. The mechanical half is shell work and this
# script does it: throwaway branches, an inbox written and pushed, a watcher
# armed, a seat played back, and a loop measured. THAT LOOP IS SYNTHETIC AND
# MASTER-SIDE: this script writes the seat's acknowledgement itself, in its own
# temporary clone, so what it times is push plus the master's outbox watcher.
# It is not delivery to a seat, not an agent running a turn, and not a seat
# pushing, and a number from it must never stand beside an end-to-end
# measurement in the ledger. The other half is not
# shell work at all. Whether the tool can schedule its own wake, deliver a
# message into another session, or pre-authorise its own calls are facts
# about the AGENT, and no script can answer them. Those are printed as
# questions for the agent to answer WITH EVIDENCE IT RAN, and a report that
# guesses at them is worth less than no report.
#
# IT TOUCHES NO LIVE BUS, BUT IT DOES PUSH. Everything happens on two branches
# named after the rehearsal, `rehearsal/<name>-integ` and
# `rehearsal/<name>-seat`, and it deletes them when it is done. Those pushes go
# to the REAL remote, because being able to push is the master capability under
# test, and a seat's own hard limit is to push nothing but its own branch. So a
# seat told to run this is having its lane widened, the instruction that
# assigns it must say so by name, and whoever runs it needs branch DELETE
# permission as well as push or the two branches stay behind.
set -u

# NO PAGER, EVER. `git show` and `git log` page when stdout is a terminal, and
# a watcher's stdout IS a terminal whenever it runs where this protocol tells
# you to run it, inside screen or tmux. Measured on a live seat: the watcher
# printed its inbox, git handed the output to `less`, and the process sat at
# `(END)` for ever with nobody at the keyboard. It looked alive to `ps` and
# delivered nothing. A background process must never invoke a pager, so this is
# set once here rather than as a flag on each call, which would leave the next
# git call somebody adds unguarded.
GIT_PAGER=cat; export GIT_PAGER
GIT_TERMINAL_PROMPT=0; export GIT_TERMINAL_PROMPT
NAME=${1:?usage: master-check.sh <name> [bus-dir]}
BUS=${2:-collab}

# EVERY RUN GETS ITS OWN REFS, so a run that cannot clean up cannot poison the
# next one. The first version used a fixed pair of names. When the cleanup was
# refused, which is a real class of platform this package now documents, the
# leftover branch sat at an old commit and the NEXT run's push to the same ref
# was a non-fast-forward and was rejected. The script then reported "could not
# push a branch, so this tool cannot be a master at all", which is the worst
# answer it can give and it was giving it, by default, on exactly the platforms
# whose cleanup it had just documented as impossible. The litter a failed
# cleanup leaves is now inert.
#
# THE RUN ID IS NOT UNIQUE ACROSS MACHINES and the older comment here claimed
# it was. Seconds plus a pid collide readily between two hosts or two
# containers, where pid namespaces hand out the same small numbers, so two
# rehearsals started in the same second under the same NAME could target the
# same remote refs. A few random characters cost nothing and remove the class.
rand6=$( (head -c 16 /dev/urandom 2>/dev/null || date +%s%N 2>/dev/null || echo $$) |
         cksum | cut -d' ' -f1 )
RUN="$(date +%s)-$$-${rand6}"
INTEG="rehearsal/$NAME-$RUN-integ"
SEAT="rehearsal/$NAME-$RUN-seat"
HERE=$(cd "$(dirname "$0")" && pwd)
P=${P:-5}

# IT WORKS IN A TEMPORARY CLONE AND NEVER IN YOUR TREE. The first version did
# the rehearsal in the live working tree, and that was wrong twice over: it
# switched branches under whatever the operator had in progress, and its own
# control run then failed for a reason that had nothing to do with the
# platform, because a relative bus path resolved against the directory the
# script happened to be started from. A clone removes both. The push still
# goes to the REAL remote, because being able to push is the master capability
# under test.
ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
case $ROOT in ''|-*) echo "master-check must run inside a git working tree"; exit 1;; esac
REMOTE=$(git -C "$ROOT" remote get-url origin 2>/dev/null)
case $REMOTE in '') echo "master-check needs an origin remote to push a rehearsal branch to"; exit 1;; esac

say(){ printf '%s\n' "$*"; }
say "MASTER REHEARSAL for $NAME. A temporary clone, two throwaway branches, and"
say "nothing in your working tree is touched."
say ""

W=$(mktemp -d) || exit 1
# A CLEANUP THAT CANNOT SAY WHY IT FAILED LEAVES THE OPERATOR GUESSING, and
# the litter is reproducible: after two rehearsals the remote carried four
# `rehearsal/*` branches and nobody had cleaned either pair. The first version
# sent the deletion's stderr to /dev/null and printed only "remove them by
# hand", so refused, offline and unauthorised all read the same. On at least
# one platform the deletion is refused by a host gate outside this package, and
# a seat there cannot clear its own litter even by hand, which is a fact worth
# printing rather than hiding. BRANCH DELETE PERMISSION IS A REQUIREMENT OF
# THIS SCRIPT, beside push.
# NOTHING WAS PUSHED, SO THERE IS NOTHING TO DELETE. Measured against an
# unreachable remote: the clone failed, the script exited, and this then tried
# to delete two branches from a working directory that no longer existed, told
# the operator to remove by hand two refs that had never been created, and
# printed a `cannot change to` error as though the remote had refused. A first
# run against a new remote begins with its most confusing possible output. The
# flag is set by the first push that reaches the remote, so cleanup runs when
# there is litter and stays quiet when there is none.
cleanup_rehearsal(){
  [ -n "${WPID:-}" ] && kill "$WPID" 2>/dev/null
  [ "${PUSHED:-0}" = 1 ] || { rm -rf "$W"; return 0; }
  sleep 1
  if ! delerr=$(git -C "$W/c" push -q origin --delete "$INTEG" "$SEAT" 2>&1); then
    say "NOTE  could not delete $INTEG and $SEAT from the remote, remove them by hand."
    say "      The remote said: ${delerr:-nothing at all, which usually means the push was blocked before it left this machine}"
    say "      This run's refs are unique to it, so the leftovers are inert and"
    say "      the next run is unaffected. Every rehearsal ref now on the remote:"
    git -C "$W/c" ls-remote --heads origin 'refs/heads/rehearsal/*' 2>/dev/null |
      sed 's#.*refs/heads/#      #' || say "      could not list them either"
  fi
  rm -rf "$W"
}
# AND A CANCELLED REHEARSAL STOPS. A handler on INT and TERM runs and then
# RETURNS, so this used to tidy its directory and carry straight on to the
# seat checkout, the pushes and the polling loop. Measured: TERM after the
# watcher started, one cleanup, and every later step still ran. EXIT keeps
# the cleanup, and the two signal traps exit, which fires EXIT once.
trap 'cleanup_rehearsal' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# A SLOW FIRST FETCH IS NOT AN UNREACHABLE REMOTE, and this reported both the
# same way while throwing away the one line that told them apart. Measured on
# a 469 MiB repository of 14,817 objects: the quiet clone died around a hundred
# seconds, a visible clone of the same URL finished in 97.5, and the rehearsal
# it was gating then passed in sixteen. An operator reading "cannot reach the
# remote at all" goes looking at their network and their credentials, neither of
# which was ever wrong. So try twice, and keep what git said either way.
clone_err="$W/clone.err"
if ! git clone -q "$REMOTE" "$W/c" 2>"$clone_err"; then
  say "note  first clone of $REMOTE failed, retrying once: $(tr '\n' ' ' < "$clone_err" | cut -c1-200)"
  rm -rf "$W/c"
  if ! git clone -q "$REMOTE" "$W/c" 2>"$clone_err"; then
    say "FAIL  could not clone $REMOTE twice, so this tool cannot reach it. git said: $(tr '\n' ' ' < "$clone_err" | cut -c1-300)"
    say "      A large repository can exceed the time this allows. Clone it by hand once and run this again if that is what happened."
    exit 1
  fi
fi
cd "$W/c" || exit 1
git config user.name "master rehearsal"
git config user.email rehearsal@example.invalid
G=$(git rev-parse --absolute-git-dir)

# ---- can this tool do the master's git work at all -----------------------
start=$(date +%s)
git checkout -q -B "$INTEG"
mkdir -p "$BUS"
printf '## Open instructions\n\n- %s-R1 (ack [done: %s-R1]): a no-op whose only task is its own acknowledgement.\n' "$NAME" "$NAME" > "$BUS/INBOX_$NAME.md"
git add "$BUS/INBOX_$NAME.md" >/dev/null 2>&1
git commit -q -m "master rehearsal: inbox for $NAME" >/dev/null 2>&1
# BOTH PUSHES REPORT WHY THEY FAILED. The earlier fix captured the DELETE's
# stderr and left these two discarding theirs, so the one failure that actually
# fires was the one that could not say what happened.
if pusherr=$(git push -q -u origin "$INTEG" 2>&1); then
  PUSHED=1
  say "PASS  wrote an inbox and pushed an integration branch"
else
  say "FAIL  could not push $INTEG. The remote said:"
  say "      ${pusherr:-nothing at all, which usually means the push was blocked before it left this machine}"
  say "      That is a statement about PUSH PERMISSION on this remote, which is"
  say "      the master's first requirement. It is not about the agent."
  exit 1
fi
pushed=$(date +%s)

# ---- the master's own watcher, the script a seat never runs --------------
P=$P DUE=0 sh "$HERE/watch-outbox.sh" "$NAME" "$SEAT" "$BUS" > "$W/watch.log" 2>&1 &
WPID=$!
sleep 3
if grep -q ARMED "$W/watch.log" 2>/dev/null; then
  say "PASS  armed an outbox watcher, and it printed its own fingerprint"
else
  say "FAIL  the outbox watcher did not arm:"
  sed 's/^/      /' "$W/watch.log" 2>/dev/null | head -4
fi

# ---- play the seat once, which makes the loop complete and not real -------
# The acknowledgement below is written by THIS script. Nothing here proves a
# seat exists, so the interval it produces is the master-side Git and watch
# loop and is labelled that way wherever it is printed.
git checkout -q -B "$SEAT" "$INTEG"
printf -- '- rehearsal ack [done: %s-R1]\n' "$NAME" > "$BUS/OUTBOX_$NAME.md"
git add "$BUS/OUTBOX_$NAME.md" >/dev/null 2>&1
git commit -q -m "master rehearsal: ack from $NAME" >/dev/null 2>&1
if ! pusherr=$(git push -q -u origin "$SEAT" 2>&1); then
  say "FAIL  could not push $SEAT, so the played-back seat half never"
  say "      happened and the watcher below is waiting for something that will"
  say "      never arrive. The remote said: ${pusherr:-nothing at all}"
fi
acked=$(date +%s)

i=0
while [ "$i" -lt 40 ]; do
  grep -q 'OUTBOX new entries' "$W/watch.log" 2>/dev/null && break
  sleep 2; i=$((i + 1))
done
seen=$(date +%s)
if grep -q 'OUTBOX new entries' "$W/watch.log" 2>/dev/null; then
  say "PASS  the watcher delivered the seat's entry, not merely that a branch moved"
  say ""
  say "SYNTHETIC MASTER-SIDE LOOP on this machine's clock, at a ${P}s poll."
  say "This script wrote the acknowledgement itself, so these intervals are"
  say "push plus watcher and NOT delivery to a seat or a turn being run:"
  say "  inbox push to ack push   $((acked - pushed))s"
  say "  ack push to watcher saw  $((seen - acked))s"
  say "  whole loop               $((seen - start))s"
  say "  That is this platform's master-side floor. Write it in the ledger."
else
  say "FAIL  the watcher never reported the entry within 80s, which is the master's"
  say "      primary signal and the thing a seat cannot check for you. The log:"
  sed 's/^/      /' "$W/watch.log" 2>/dev/null | tail -6
fi

# ---- what no script can answer ------------------------------------------
cat <<'ASK'

FOUR THINGS THIS SCRIPT CANNOT DECIDE, because they are facts about the agent
and not about the shell. Answer each with the evidence you ran, and say "no"
where the answer is no. A guess here is worth less than a blank.

  1. Can you SCHEDULE A RECURRING WAKE FOR YOURSELF, and what is the shortest
     interval it honours. A master needs this more than a seat does: a seat is
     woken by its inbox watcher, and a master with no scheduler and no
     arriving event simply sits, however healthy its watchers are.

  2. Can you DELIVER A MESSAGE INTO ANOTHER SESSION on this platform. This is
     the OUTBOUND direction, the one a master needs and a seat does not, and
     the one least often tested. Give the exact command and say whether it
     reached a turn somebody could see.

  3. Can you PRE-AUTHORISE your own calls so that no approval dialog
     interrupts an unattended wake, and where does that setting live.

  4. Does a watcher you start SURVIVE YOUR WINDOW CLOSING. Read the process
     tree with `ps` rather than trusting the command you typed, and say what
     the watcher's ancestry actually reaches. A watcher whose parent is the
     agent application dies with it.

WITHOUT 1, 2 AND 3 A MASTER STILL WORKS, more slowly: the bus is committed
files, so it still assigns, adjudicates and merges, and what it loses is the
ability to wake a silent seat without a person. Say which of the four you
have, and part one of APPENDIX.md gains a row.
ASK
