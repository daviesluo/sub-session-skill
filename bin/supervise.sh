#!/bin/sh
# Copyright 2026 Zheng Luo (Davies Luo). Licensed under the Apache License
# 2.0, whose text is the LICENSE file in this package. Keep this notice
# when you copy the script.
#
# supervise.sh inbox|outbox <name> <integration-or-seat-branch> <bus-dir>
#
# Keeps a watcher alive across the two ways it dies quietly. Run this instead
# of the watcher wherever the thing that starts the watcher can itself go
# away, which on several platforms it does on a fixed schedule:
#
#   P=30 DUE=900 sh bin/supervise.sh outbox seatname seat/branch bus
#   P=20 ON_CHANGE="..." NOTIFY="..." sh bin/supervise.sh inbox me main bus
#
# TWO SILENT FAILURES, both measured on live deployments, and neither of them
# announces itself.
#
#   1. THE WATCHER WAS A CHILD OF THE THING STREAMING IT. Many agent tools run
#      a background command through a facility with a HARD CEILING on how long
#      it may live, thirty minutes on one measured platform, and a flag that
#      claims to make it persistent does not raise that ceiling. When the
#      facility times out it takes the watcher with it, and the seat goes
#      silent with nothing in any log saying why.
#   2. AN ORPHANED WATCHER KEEPS RUNNING AND REACHES NOBODY. The reverse case
#      is worse, because it looks healthy. The streamer died, the watcher
#      survived, and it goes on polling and ADVANCING ITS STATE FILE while its
#      output goes to a pipe with no reader. Every entry it consumes is an
#      entry the next watcher will never show anyone.
#
# So this adopts before it starts: an older watcher whose output can no longer
# reach anyone is killed, deliberately, and this one takes over.
#
# IT NOTIFIES TOO, through the same NOTIFY hook the watchers use, for four
# STATES from FIVE PLACES, and the two numbers differ for a reason worth
# knowing: `started` when it adopts an orphan, `slowing` once a watcher has
# failed to stay up three times, `failed` from EITHER this script's own git
# guard OR a watcher that returned 78, both meaning this machine cannot run
# the watcher, and `armed` when a watcher stands down because another already
# owns the seat. The stand-down used to raise
# `finished`, which the state table defines as a turn ending with its report
# on the seat's branch: a supervisor that never started a watcher has no turn
# and no report, and `armed` is both suppressed at the desktop and the honest
# description of a supervisor that did not arm. It never sets NOTIFY_FLOW,
# because neither event is a message crossing between sessions.
#
# RESTARTING IS SAFE, and that is the whole reason this works. The watchers
# keep their state beside the clone's git directory, so a restart replays
# nothing and skips nothing, and it delivers whatever landed while it was
# down. That property is load-bearing here: without it a supervisor would be
# a way of losing entries on a schedule.
set -u

KIND=${1:?usage: supervise.sh inbox|outbox <name> <branch> <bus-dir>}
NAME=${2:?usage: supervise.sh inbox|outbox <name> <branch> <bus-dir>}
BRANCH=${3:?usage: supervise.sh inbox|outbox <name> <branch> <bus-dir>}
BUS=${4:?usage: supervise.sh inbox|outbox <name> <branch> <bus-dir>}

case $KIND in
  inbox)  SCRIPT=watch-inbox.sh;  STATE=inbox_watch_$NAME ;;
  outbox) SCRIPT=watch-outbox.sh; STATE=outbox_watch_$NAME ;;
  *) echo "supervise.sh takes inbox or outbox, not $KIND"; exit 1 ;;
esac

HERE=$(cd "$(dirname "$0")" && pwd)
[ -f "$HERE/$SCRIPT" ] || { echo "supervise.sh cannot find $HERE/$SCRIPT"; exit 1; }

notify() {
  [ -n "${NOTIFY:-}" ] || return 0
  NOTIFY_STATE=$1 NOTIFY_TEXT=$2 sh -c "$NOTIFY" >/dev/null 2>&1 || true
}

# THE SUPERVISOR ASKS GIT THE SAME QUESTION THE WATCHER DOES, AND IT ASKS FIRST,
# so this guard and not the watcher's 78 is what a real old-git machine meets.
# Measured by the Codex seat with a fake old git: the shipped supervisor exited
# 1 here with only its usage line, never started a watcher, and raised nothing,
# so the 78 branch below was reachable only from the suite's fake watcher. The
# diagnosis belongs wherever the refusal actually happens, so it is given here
# too, and notify() is defined above this point for that reason alone.
G=$(git rev-parse --absolute-git-dir 2>/dev/null)
case $G in
  ''|-*)
    echo "WATCHER $NAME CANNOT RUN ON THIS MACHINE: supervise.sh must run inside the clone the watcher watches, and it needs git 2.13 or newer for git rev-parse --absolute-git-dir. Check with git --version. No restart can change that, so nothing is started and nothing retries."
    notify failed "$NAME cannot run on this machine, so this supervisor stopped"
    exit 78 ;;
esac
S="$G/$STATE"


# ---- adopt ---------------------------------------------------------------
# A LIVE PID IS NOT AN IDENTITY. `kill -0` proves only that SOME process owns
# that number today, and pid numbers are reused. Measured by the Codex seat: an
# unrelated `sleep` whose pid happened to sit in the state file was announced
# as an orphaned watcher and killed. A supervisor that kills a stranger is
# worse than one that does nothing, so the recorded pid must look like the
# watcher it claims to be before anything is signalled.
# AND THE SEAT NAME IS AN ARGUMENT, NOT A SUBSTRING. `*"$NAME"*` accepted any
# command line the name appeared anywhere inside, so a watcher for `cdx2` read
# as the watcher for `cdx`: the supervisor would have killed a live neighbour
# and the outbox watcher would have stood aside for one. Both scripts take the
# seat name as their FIRST argument, so that is what is compared, which also
# means no launcher spelling has to be enumerated.
# Exit 0 is ours, 1 is positively somebody else's, 2 is UNREADABLE, which is
# never evidence of either.
  # AND THE MATCH IS A WHOLE ARGUMENT WHOSE BASENAME IS THE SCRIPT, not a
  # substring of the command line. `*"$SCRIPT "*` also matched `not-$SCRIPT` and
  # `/p/x/$SCRIPT.bak`, so an unrelated live process could be signalled by the
  # supervisor or stood aside for by a watcher. The command line is walked as
  # words: one word whose basename is exactly this script, with the seat name
  # as the very next word. Residual and stated rather than hidden: a script
  # name inside an unquoted `sh -c` payload still tokenises the same way, and
  # ps cannot separate that from a real launch.
  # Exit 0 is ours, 1 is positively another process, 2 is UNREADABLE.
owns_watcher() {
  cmd=$(ps -o args= -p "$1" 2>/dev/null) || return 2
  [ -n "$cmd" ] || return 2
  want=0
  for w in $cmd; do
    if [ "$want" = 1 ]; then
      [ "$w" = "$NAME" ] && return 0
      want=0
    fi
    case ${w##*/} in "$SCRIPT") want=1 ;; esac
  done
  return 1
}
if [ -f "$S.pid" ]; then
  old=$(cat "$S.pid" 2>/dev/null || true)
  if [ -n "${old:-}" ] && kill -0 "$old" 2>/dev/null; then
    owns_watcher "$old"; own=$?
    if [ "$own" = 2 ]; then
      echo "REFUSING to adopt $NAME: $S.pid records pid $old, that pid is alive, and this machine will not say what it is. An unreadable identity is not permission to kill it and not permission to start a second watcher beside it. Nothing was killed and no watcher was started."
      exit 1
    fi
    if [ "$own" = 0 ]; then
      echo "ADOPTING $NAME: an older watcher is alive as pid $old and its output goes nowhere, so this takes over"
      notify started "adopting $NAME from an orphaned watcher"
      kill "$old" 2>/dev/null || true
      i=0
      while kill -0 "$old" 2>/dev/null && [ "$i" -lt 15 ]; do sleep 1; i=$((i+1)); done
      kill -9 "$old" 2>/dev/null || true
      # AND ONLY THE ADOPTED WATCHER'S RECORD IS CLEARED. This removal was
      # unconditional, so between killing the old watcher and clearing its
      # record a new watcher could claim the name and have its claim deleted
      # here, leaving a live watcher no record and the seat looking free to the
      # next starter. Same window the two watchers carried in their exit traps,
      # found in all three by the codex seat.
      [ "$(cat "$S.pid" 2>/dev/null)" = "$old" ] && rm -f "$S.pid"
    else
      # REFUSING IS THE SAFE DIRECTION. Nothing here knows what that process
      # is, and starting a second watcher beside an unknown one is the other
      # thing this script exists to prevent, so it does neither and says so.
      echo "REFUSING to adopt $NAME: $S.pid records pid $old, that pid is alive, and it is not a $SCRIPT for $NAME. Nothing was killed and no watcher was started. It is running: $(ps -o args= -p "$old" 2>/dev/null | head -1)"
      echo "Look at that process. If the record is simply stale, remove $S.pid by hand and run this again."
      exit 1
    fi
  else
    rm -f "$S.pid"
  fi
fi

# ---- keep it up ----------------------------------------------------------
# A LIFETIME COUNT IS NOT CONSECUTIVE INSTABILITY. The ladder used to climb on
# a counter that never reset, so three exits separated by days of healthy
# running backed off exactly as far as three crashes in a row, and slowed
# recovery at the moment a supervisor is meant to speed it. A watcher that
# stayed up past STABLE seconds has demonstrated it can run, so the ladder
# starts again from there.
STABLE=${STABLE:-600}
n=0
while :; do
  up0=$(date +%s)
  sh "$HERE/$SCRIPT" "$NAME" "$BRANCH" "$BUS" 2>&1
  rc=$?
  up=$(( $(date +%s) - up0 ))
  if [ "$up" -ge "$STABLE" ] && [ "$n" -gt 0 ]; then
    echo "WATCHER $NAME had been up ${up}s before this exit, past the ${STABLE}s stability window, so the restart ladder starts again rather than carrying $n old exits forward."
    n=0
  fi
  # EXIT 3 MEANS ANOTHER WATCHER ALREADY OWNS THIS SEAT, and restarting into
  # that is how one machine ends up with a process trying for ever to open a
  # window that is correctly shut. Measured by the review seat: two supervisors
  # started on one name leave the loser climbing the ladder indefinitely, and
  # every time the live watcher exits for any reason BOTH restart into the race
  # at once. A supervisor whose watcher stood down has nothing to supervise.
  if [ "$rc" = 3 ]; then
    echo "WATCHER $NAME STOOD DOWN: another watcher already owns this seat, so this supervisor has nothing to keep alive and is exiting. Nothing was killed. If that other watcher is the one you meant to replace, stop it and start this again."
    notify armed "$NAME already had a watcher, so this supervisor stood down"
    exit 0
  fi
  # AND EXIT 78 MEANS THE MACHINE ITSELF CANNOT RUN THE WATCHER, which no
  # restart can change: git older than 2.13 is the case that raises it. The
  # ladder's slowest rung is 300s, so without this branch such a refusal is
  # reprinted twelve times an hour for as long as the machine is up. A person
  # is needed, which is what the urgent rank is for.
  if [ "$rc" = 78 ]; then
    echo "WATCHER $NAME CANNOT RUN ON THIS MACHINE: it refused with 78, the code for a platform that does not meet its requirements, and no restart can change that. Its own message above says what to install. This supervisor is exiting rather than reprinting that message every ${nap:-300}s."
    notify failed "$NAME cannot run on this machine, so this supervisor stopped"
    # 78 AND NOT 1, because this is the same condition the guard above refuses
    # with, and a launcher reading this status cannot tell two codes apart when
    # the cause is one thing. The supervisor propagates the refusal it was told.
    exit 78
  fi
  n=$((n + 1))
  # Escalate, so a watcher that cannot start AT ALL cannot flood the log or
  # the notifier. Two quick tries cover a transient, then it backs off.
  case $n in 1|2) nap=10 ;; 3|4) nap=60 ;; *) nap=300 ;; esac
  echo "WATCHER $NAME EXITED rc=$rc, restart $n in ${nap}s. Its state file survives, so nothing is replayed and nothing is skipped."
  [ "$n" = 3 ] && notify slowing "$NAME has exited $n times, restarting every ${nap}s"
  sleep "$nap"
done
