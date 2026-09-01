#!/bin/sh
# Copyright 2026 Zheng Luo (Davies Luo). Licensed under the Apache License
# 2.0, whose text is the LICENSE file in this package. Keep this notice
# when you copy the script.
#
# watch-inbox.sh <name> <integration-branch> <bus-dir>
#
# Watches the integration branch for changes to this seat's inbox and prints
# the inbox whenever it changes. Restart-safe: it keeps its state beside the
# clone's git directory, so a restart neither replays nor skips.
#
#   sh watch-inbox.sh a main collab          # resting poll, 60 seconds
#   P=20 sh watch-inbox.sh a main collab     # tighter, while a reply is due
#
# One per branch per clone. It refuses to start beside a live one.
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
NAME=${1:?usage: watch-inbox.sh <name> <integration-branch> <bus-dir>}
INTEG=${2:?usage: watch-inbox.sh <name> <integration-branch> <bus-dir>}
BUS=${3:?usage: watch-inbox.sh <name> <integration-branch> <bus-dir>}
P=${P:-60}                # base poll in seconds, start with P=20 while a reply is due
case $P in ''|*[!0-9]*) echo "P must be whole seconds, using 60"; P=60;; esac
[ "$P" -lt 5 ] && P=5
# A FAILING COMMAND AND AN UNAVAILABLE ONE ARE DIFFERENT FAILURES and the
# first version of this treated both as the first. After three quick
# attempts it abandoned the change for good, which is right for a command
# with a typo in it and WRONG for one that will work again: an exhausted
# allowance, a lapsed credential, a host that is down. Measured on a live
# Codex seat, three attempts at P=20 burned in under a minute and the
# instruction was never retried again, on a bus that was healthy throughout.
# So the ladder now has a second rung instead of an end: FAST quick attempts,
# then a slow retry every RETRY seconds, for as long as it takes.
FAST=${FAST:-3}           # quick attempts before easing off
RETRY=${RETRY:-600}       # seconds between attempts after that
# AND A SEAT NOBODY CAN REACH KEEPS SAYING SO. The ladder above eased off
# correctly and then went SILENT: the slowing line and its notification fired
# exactly once, at the attempt where the ladder changed, and every failure
# after that printed nothing and raised nothing. Measured on a live team: a
# watcher whose injector had lost its Accessibility grant said one sentence at
# two in the morning and then retried quietly every ten minutes for hours,
# while the person waiting for that seat had no signal at all and the seat's
# own allowance came back unnoticed. Backing off is right and going quiet is
# not, so an undelivered change raises an alarm every NAG seconds for as long
# as it stays undelivered. Zero turns the reminder off.
NAG=${NAG:-1800}          # seconds between reminders while a change is stuck
# THE ACKNOWLEDGEMENT GATE, and it is OFF unless ACK_BRANCH names a branch.
# A turn that ends proves a turn ended. It does not prove the instruction was
# carried out: a seat that starts, fails quietly and stops returns the same
# zero as one that did the work, so the change is recorded handled and nobody
# learns otherwise until a person reads the outbox. With ACK_BRANCH set, the
# change is not consumed until the seat's own outbox says so, which turns
# silence from an ambiguous success signal into durable unfinished state.
# OFF BY DEFAULT ON PURPOSE. This alters when a change becomes handled, and
# lanes already running should not have that changed underneath them.
ACK_BRANCH=${ACK_BRANCH:-}   # seat branch carrying the acknowledgements, empty = gate off
ACK_WAIT=${ACK_WAIT:-900}    # seconds after a turn ends before missing acks alarm
case $FAST in ''|*[!0-9]*) echo "FAST must be whole attempts, using 3"; FAST=3;; esac
case $RETRY in ''|*[!0-9]*) echo "RETRY must be whole seconds, using 600"; RETRY=600;; esac
case $NAG in ''|*[!0-9]*) echo "NAG must be whole seconds, using 1800"; NAG=1800;; esac
[ "$FAST" -lt 1 ] && FAST=1
[ "$RETRY" -lt "$P" ] && RETRY=$P
# A HEADLESS TURN MOVES NOTHING THE USER CAN SEE, and calling that a
# platform fact and writing it down is not the same as fixing it. Whatever
# the seat is doing, working or dead, the person watching deserves a sign.
# NOTIFY is run on every state change with two variables set, NOTIFY_STATE
# being one of armed, started, finished, failed, slowing, recovered or
# alarm, and NOTIFY_TEXT being one line about it. `bin/notify.sh` beside
# this file is the shipped recipe, and pointing at it is what keeps one
# format across a whole team:
#
#   NOTIFY="sh .../bin/notify.sh 'Claude Opus 5' 'Cursor Grok'"
#
# THE TEXT NEVER REPEATS THE SEAT'S NAME, because the notification's own
# first line already carries who is talking to whom. Its output is
# discarded and its failures are ignored, because a broken notifier must
# never be able to break the bus.
NOTIFY=${NOTIFY:-}
# THE THIRD ARGUMENT IS THE DIRECTION and it is given only when a message
# actually crossed: `in` for one arriving from the peer, `out` for one going
# back to it. The notifier cannot work this out for itself, because the same
# state means an arrival on one watcher and a departure on another, and
# guessing it printed a finished task as though it were a new one.
notify() {
  [ -n "$NOTIFY" ] || return 0
  NOTIFY_STATE=$1 NOTIFY_TEXT=$2 NOTIFY_FLOW=${3:-} sh -c "$NOTIFY" >/dev/null 2>&1 || true
}
# WHICH VERSION OF ITSELF THIS PROCESS IS RUNNING, printed once when it arms.
# A watcher is a shell that read its script at start, so an updated file on disk
# changes nothing until the process is restarted, and a clone holding an inward
# merge may not even have the updated file. Measured: corrections were committed
# and pushed while the machine that shows notifications carried on with the old
# ones, and nobody could tell by looking. A fingerprint makes a stale process
# visible in one glance instead of invisible.
fingerprint() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" 2>/dev/null | cut -c1-8
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" 2>/dev/null | cut -c1-8
  else cksum "$1" 2>/dev/null | cut -d" " -f1
  fi
}
FP=$(fingerprint "$0")
G=$(git rev-parse --absolute-git-dir 2>/dev/null)
# a git older than 2.13 echoes the option it does not know and exits 0, so
# test the SHAPE of the answer: an empty or option-looking value is a refusal
# EXIT 78 IS EX_CONFIG, and it means THIS MACHINE CAN NEVER RUN THIS WATCHER.
# The supervisor reads it and stops. A restart cannot make git newer, so the
# ordinary code would have this refusal printed every 300s for the life of the
# machine, which is a log nobody reads reporting a fault nobody fixes. 75 is
# already EX_TEMPFAIL in the injector, so the two codes that leave the shell
# come from one table.
case $G in ''|-*) echo "this watcher needs git 2.13 or newer, because it keeps its state beside the answer to git rev-parse --absolute-git-dir. Check with git --version. Nothing here retries: install a newer git and start the watcher again."; exit 78;; esac
S="$G/inbox_watch_$NAME"
# ONE TURN AT A TIME, per seat. The watcher's own children are serial because
# it waits for each one, but nothing stopped it starting a turn while an
# INTERACTIVE turn was already running in the same worktree. Measured once:
# two agents executed the same instruction concurrently and were both
# approaching the same outbox write. mkdir is the portable atomic
# test-and-set, and THE SEAT TAKES THIS SAME LOCK at the top of a turn it
# starts itself. A lock left behind by a killed turn is cleared by removing
# the directory, which the refusal message names.
LOCK="$G/turn_$NAME.lock"   # one per clone, survives restarts
STALE=${STALE:-60}        # minutes before a lock with no live owner is taken
case $STALE in ''|*[!0-9]*) echo "STALE must be whole minutes, using 60"; STALE=60;; esac
# THE QUARANTINE HAS ITS OWN, SHORTER CLOCK, and conflating the two cost a live
# seat an hour and a half. STALE guards a lock a seat took BY HAND at the top of
# its own turn: nothing is known about that turn, an interactive one may
# genuinely be running, and reclaiming it early runs two turns at once. The 75
# quarantine is a different risk, because the injector has ALREADY waited its
# full TIMEOUT, an hour by default, before saying it cannot tell. Charging STALE
# on top of that means two hours before anything moves. Measured on 26 August: a
# poke the seat declined left a quarantined lock, the next instruction had
# arrived six minutes earlier and was still unread an hour and a half later, and
# the seat was demonstrably alive and working throughout.
HOLD=${HOLD:-15}          # minutes a 75 quarantine stands before it can be taken
case $HOLD in ''|*[!0-9]*) echo "HOLD must be whole minutes, using 15"; HOLD=15;; esac
# A LOCK OUTLIVES THE TURN THAT TOOK IT, and then it blocks every turn
# after it, for ever. Measured on a live Codex seat: a turn was killed at
# 06:08 holding this directory, and from then the watcher refused to start
# anything, so an audit pushed an hour later was never even attempted. The
# refusal message said to remove the directory by hand and nobody was
# watching. So the holder is now RECORDED and its death is detectable.
# A lock with a recorded owner that is gone is taken at once. A lock with
# NO recorded owner is taken only after STALE minutes, because a seat may
# have taken it by hand at the top of its own turn, and reclaiming that one
# early would run two turns at once, which is the accident this prevents.
# THE AGE CLOCK MUST START WHEN THE LOCK WAS QUARANTINED, NOT WHEN IT WAS
# TAKEN, and getting that wrong silently cancelled the whole exit-75 fix.
# The directory is created when the turn STARTS. A turn that runs the
# shipped injector can take an hour before it reports that it may still be
# running, and STALE defaults to sixty minutes, so measuring the directory's
# age meant the lock was already reclaimable the instant it was held, and
# the very next poll could start a second turn beside a live one. So the 75
# path drops a `hold_since` file, and its age is measured against HOLD.
lock_is_dead() {
  if [ -f "$LOCK/pid" ]; then
    q=$(cat "$LOCK/pid" 2>/dev/null)
    [ -n "$q" ] && kill -0 "$q" 2>/dev/null && return 1
    return 0
  fi
  if [ -f "$LOCK/hold_since" ]; then
    [ -n "$(find "$LOCK/hold_since" -maxdepth 0 -mmin +"$HOLD" 2>/dev/null)" ]
    return
  fi
  # no pid and no held marker: a lock a seat took by hand at the top of its
  # own turn, so the directory's own age is all there is to go on
  [ -n "$(find "$LOCK" -maxdepth 0 -mmin +"$STALE" 2>/dev/null)" ]
}
# WRITE THE STATE ATOMICALLY. `echo ... > "$S"` truncates first and writes
# second, so a crash between the two leaves a torn file that the next start
# reads as empty. It then cold-seeds from the remote as it stands and skips
# everything pushed while it was down, for good. A rename within one directory
# is atomic on POSIX, so the file a restart finds is either the old state or
# the new one and never half of either. Codex found this: the skip is
# announced, but under `bin/supervise.sh` the restart is unattended and the
# announcement reaches a log nobody is reading at that moment.
save_state(){ printf '%s\n' "$*" > "$S.new" && mv -f "$S.new" "$S"; }
# EVERY INSTRUCTION ID UNDER `## Open instructions`, which is not a new
# contract but the one the seat is already given: execute every instruction
# under Open that its outbox has not acked. An ID acked in an earlier turn
# already satisfies it, so this asks for nothing extra.
# ONE ID GRAMMAR, SHARED BY BOTH SIDES, AND A WHOLE TOKEN RATHER THAN A PREFIX.
# The old pair disagreed. `[A-Za-z]*-[0-9]*' stopped at the digits, so `CDX-2A'
# and `CDX-2B' both collapsed to a PHANTOM `CDX-2', while the acknowledgement
# pattern demanded `]' straight after the digits and so matched neither
# `[done: CDX-2A]' nor `[done: CDX-2B]'. Those two identifiers are real and
# live in this repository's own cdx inbox, so with the gate on they were an
# obligation no seat could ever discharge, beside a phantom that could never
# be raised. Verified both halves on the shipped grammar before changing it.
# AND THE GRAMMAR MATCHES THE CONTRACT THE PROTOCOL WRITES DOWN. Section 1
# says a seat name starts with a LETTER, which allows `seat2`, while this
# used to accept letters alone before the hyphen and left that name
# documented as legal and unreadable in practice.
IDGRAM='[A-Za-z][A-Za-z0-9_]*-[0-9][0-9]*[A-Za-z0-9]*'
# AND THE IDENTIFIER IS NOT FOLLOWED BY ANY FIXED PUNCTUATION, which the first
# attempt at this fix assumed. Requiring a colon after it looked tidier and was
# measured against the live inboxes before shipping: the cdx Open section holds
# thirty four identifier lines and only ten are written `- ID:', the rest being
# `- ID (TITLE...'. That version would have dropped twenty four obligations in
# one lane while looking stricter, which is the defect this whole pass is about.
# AND AN UNREADABLE INBOX IS NOT AN EMPTY ONE. `git show' failing inside the
# pipeline used to yield no identifiers, which reads downstream as "nothing is
# owed" and walks into the acknowledged branch. It returns non-zero now and
# every caller treats that as unknown rather than as none.
open_ids(){
  raw=$(git show "origin/$INTEG:$BUS/INBOX_$NAME.md" 2>/dev/null) || return 1
  [ -n "$raw" ] || return 1
  open=$(printf '%s\n' "$raw" | awk '/^## Open instructions/{o=1; next} /^## /{o=0} o')
  # AND A BULLET THAT IS NOT AN IDENTIFIER IS UNKNOWN, NOT ABSENT. A seat named
  # against the grammar, or an instruction written without one, used to leave
  # this pipeline empty, which reads downstream as "nothing is owed" and walks
  # straight into the acknowledged branch. Counting the bullets that carry no
  # identifier is what tells the caller the difference.
  # It is reported as one obligation nobody can discharge, which is the safe
  # direction: the gate keeps saying so until a person looks.
  good=$(printf '%s\n' "$open" | grep -cE "^- $IDGRAM" || true)
  all=$(printf '%s\n' "$open" | grep -c '^- ' || true)
  # THE SENTINEL IS NOT AN IDENTIFIER. Printed as `UNPARSABLE-2` it matched
  # IDGRAM itself, so a commit subject carrying `[done: UNPARSABLE-2]` in a
  # seat's own branch discharged it and the gate went quiet with the malformed
  # bullets still there. It carries a character no identifier can, so nothing
  # a seat can write will ever acknowledge it.
  [ "$all" -le "$good" ] || printf 'UNPARSABLE(%s)\n' "$((all-good))"
  printf '%s\n' "$open" | grep -oE "^- $IDGRAM" | sed 's/^- //' | sort -u
}
# WHICH OF THEM THE SEAT HAS ANSWERED, read from its own branch and read only.
# This is one extra fetch by THIS watcher, not a dependency on the outbox
# watcher, whose failure must never be able to stall delivery.
#
# THE COMMIT SUBJECT IS THE ONLY AUTHORITY, AND NOTHING ELSE IS ONE.
# Reading the whole commit body and the whole outbox with OR semantics accepted
# a marker found anywhere in either, which is two independent ways to be lied
# to rather than belt and braces. Demonstrated by a reader: an outbox sentence
# reading "the literal marker [done: QQ-1] would mean completion, but no work
# was performed" moved the state to handled and printed ACKNOWLEDGED. A commit
# body discussing a marker does the same. A SUBJECT IS STRUCTURED AND SHORT and
# a seat does not discuss an identifier there, it releases one.
# Measured across the live lanes before narrowing it: every marker on
# compute/local, sub/agy and sub/cdx already sits in a subject, twenty one,
# three and twenty six of them, so this costs those seats nothing. sub/rev acks
# in its outbox alone and is stood down, and if it returns it writes subjects.
acked_ids(){
  git fetch -q origin "+$ACK_BRANCH:refs/remotes/origin/$ACK_BRANCH" 2>/dev/null || return 1
  git log --format='%s' -n 500 "origin/$ACK_BRANCH" 2>/dev/null |
    grep -oE "\[(done|skipped): *$IDGRAM\]" |
    sed 's/.*: *//; s/\]//' | sort -u
}
# THE BASELINE, without which this would alarm about a backlog on its first
# poll and be switched off within a day. Measured on the live lanes before
# shipping: rev had REV-3 and REV-7 and agy had AGY-2 sitting in Open with no
# acknowledgement anywhere in 1,554 and 1,587 commits of branch history. The
# work was done and the marker was never written, which is a real bookkeeping
# gap and NOT something a watcher armed today should shout about. The set that
# is already unanswered when the gate first arms is recorded once and excluded
# from then on, so this speaks only about turns it actually watched. The
# remedy for the baseline is the protocol's own: move a finished instruction
# to the Closed section.
missing_acks(){
  want=$(open_ids) || { echo FETCHFAILED; return 0; }
  have=$(acked_ids) || { echo FETCHFAILED; return 0; }
  printf '%s\n' "$want" | while read -r id; do
    [ -n "$id" ] || continue
    printf '%s\n' "$have" | grep -qx "$id" && continue
    grep -qx "$id" "$S.ackbase" 2>/dev/null && continue
    printf '%s ' "$id"
  done
}
# one watcher per branch per clone. Two collide on the ref lock and deliver
# the same entry twice, and re-arming without stopping the old one is how a
# second instance appears.
# A LIVE PID IS NOT A WATCHER. `kill -0` proves only that some process owns
# that number, and pid numbers are reused, so an unrelated process whose pid
# happens to sit in the state file locked this seat out of arming for good.
# Measured by the Codex seat. The recorded pid has to look like the watcher it
# claims to be before it can refuse anybody.
  # AND THE MATCH IS A WHOLE ARGUMENT WHOSE BASENAME IS THE SCRIPT, not a
  # substring of the command line. `*"watch-inbox.sh "*` also matched `not-watch-inbox.sh` and
  # `/p/x/watch-inbox.sh.bak`, so an unrelated live process could be signalled by the
  # supervisor or stood aside for by a watcher. The command line is walked as
  # words: one word whose basename is exactly this script, with the seat name
  # as the very next word. Residual and stated rather than hidden: a script
  # name inside an unquoted `sh -c` payload still tokenises the same way, and
  # ps cannot separate that from a real launch.
  # Exit 0 is ours, 1 is positively another process, 2 is UNREADABLE.
looks_like_us() {
  cmd=$(ps -o args= -p "$1" 2>/dev/null) || return 2
  [ -n "$cmd" ] || return 2
  want=0
  for w in $cmd; do
    if [ "$want" = 1 ]; then
      [ "$w" = "$NAME" ] && return 0
      want=0
    fi
    case ${w##*/} in watch-inbox.sh) want=1 ;; esac
  done
  return 1
}
# THE RECORD IS CLAIMED IN ONE STEP, not tested and then written ten lines
# later. Two watchers started together both passed the old check and both then
# wrote, so both ran and the file named one of them. Measured by the review
# seat: forty simultaneous double-starts on one name produced one such pair,
# one in forty, and a copy with a two second
# sleep between the old check and the old write produced two armed watchers
# EVERY time, neither refusing, the pid file naming one. That is the exact
# shape of a live incident, two watch-inbox.sh processes against one seat with a
# supervisor believing it had one.
#
# `set -C` IS THE ATOMIC MOVE HERE, AND A SYMLINK IS NOT, which cost a run to
# learn. The first repair claimed the name with `ln -s` and made the record a
# LINK whose target was the pid, and every reader of it still used `cat`: the
# suite's own stop helper read empty, killed nothing, and three restart cases
# failed because the watcher they meant to replace was still running. Under
# `set -C` the redirection opens with O_EXCL, so it creates the name or fails
# in one step exactly as the link did, AND THE FILE STAYS A FILE, so every
# reader anywhere keeps working unchanged. Driven under sh, bash and dash
# before it went in.
# AND REPLACING A RECORD IS NOT WHAT `set -C` MAKES ATOMIC. It makes CREATING
# one atomic and says nothing about the path taken when the create fails: two
# starters that both fail against the same STALE record both decide it is
# stale, the first removes it and claims, and the second then runs the removal
# it had already decided on and deletes the first one's LIVE claim before
# claiming for itself. Both watchers run, which is the defect this whole guard
# exists to prevent, arrived at by a different road. Found by the codex seat,
# which also noted that no case can catch it while every trial starts with no
# record at all.
#
# SO THE INSPECT, THE REMOVAL AND THE CREATE HAPPEN UNDER ONE HOLDER. `mkdir`
# is the atomic a POSIX shell has, and this package already uses it for the
# turn lock. The record is RE-READ after the door closes, so what is inspected
# is what is removed, and a starter that arrives while another is inside finds
# a live watcher on its next read and stands down. The fast path, an absent
# record, never opens the door at all.
claim_i=0
while :; do
  ( set -C; echo $$ > "$S.pid" ) 2>/dev/null && break
  door=0
  while [ "$door" -lt 90 ] && ! mkdir "$S.claiming" 2>/dev/null; do
    sleep 1; door=$((door + 1))
  done
  if [ "$door" -ge 90 ]; then
    # A DOOR NOBODY IS BEHIND IS WORSE THAN NO DOOR. Ninety seconds is longer
    # than any inspection here can take, so this one was left by something that
    # died holding it.
    echo "$S.claiming has been held for ${door}s, longer than any arming takes, so it is being treated as left behind by a process that died holding it."
    rm -rf "$S.claiming" 2>/dev/null
    continue
  fi
  cur=$(cat "$S.pid" 2>/dev/null)
  case $cur in
    ''|*[!0-9]*) : ;;                       # unreadable or not a pid: stale
    *) if kill -0 "$cur" 2>/dev/null; then
         looks_like_us "$cur"; own=$?
         if [ "$own" = 0 ]; then
           echo "an inbox watcher for $NAME is already running as pid $cur, so this one stands down rather than watching beside it"; rmdir "$S.claiming" 2>/dev/null; exit 3
         elif [ "$own" = 2 ] && kill -0 "$cur" 2>/dev/null; then
           # AND THE LIVENESS IS RE-READ BEFORE REFUSING FOR EVER. `kill -0`
           # says alive, then `ps` says nothing, and those are two different
           # instants: a process that exits between them makes the identity
           # unreadable for the ordinary reason, and the record is simply
           # stale. Refusing 78 there turns a routine race into a supervisor
           # that stops until a person comes. Measured by the Codex seat with
           # a `ps` that killed the pid before returning empty. Still alive on
           # the second look means the machine really will not identify it.
           echo "$S.pid records pid $cur, which is alive and whose identity this machine will not report, so this REFUSES to arm. Two watchers on one inbox each start turns the other knows nothing about. Stop that process, or clear $S.pid once you know what it is. Nothing here retries: this needs a person."; rmdir "$S.claiming" 2>/dev/null; exit 78
         elif [ "$own" = 2 ]; then
           # AND THE SENTENCE MATCHES THE BRANCH. Widening the refusal above
           # made this path reachable a second way, and it kept the message
           # written for the first: it called a pid that had just gone "alive
           # but is not a watch-inbox.sh", and printed an empty command line
           # after "It is running:". An operator then looks for a live foreign
           # process that does not exist. This path says what happened.
           echo "$S.pid records pid $cur, which answered as alive and then went while this was identifying it, so the record is stale and this arms over it. Nothing needs doing here: that is one owner exiting as the next one starts."
         else
           echo "$S.pid records pid $cur, which is alive but is not a watch-inbox.sh for $NAME. Treating the record as stale and arming, rather than staying out of the way of a process that has nothing to do with this seat. It is running: $(ps -o args= -p "$cur" 2>/dev/null | head -1)"
         fi
       fi ;;
  esac
  # The owner is gone, or is something else entirely. Drop the record and go
  # round: whoever creates the name next is the one watcher, and the loser of
  # that race comes back here and reads the winner's live pid.
  # AND ONLY THE RECORD THAT WAS INSPECTED IS REMOVED. Inside the door nothing
  # else is replacing it, and the compare keeps that true if the door is ever
  # widened.
  [ "$(cat "$S.pid" 2>/dev/null)" = "$cur" ] && rm -f "$S.pid"
  rmdir "$S.claiming" 2>/dev/null
  claim_i=$((claim_i + 1))
  if [ "$claim_i" -gt 5 ]; then
    echo "could not claim $S.pid after $claim_i attempts, so something is creating it as fast as this removes it. Nothing was started. Look at what else is arming this seat. Nothing here retries: this needs a person."
    exit 78
  fi
done
# only ever release a lock THIS process took: an unconditional rmdir on exit
# would free a lock another turn is holding, which is worse than not locking
held=0
# AND THE RECORD IS RELEASED ONLY WHILE IT STILL NAMES THIS PROCESS. The
# removal was unconditional, so a watcher exiting after its record had been
# replaced deleted its SUCCESSOR's claim and left a live watcher with no
# record, which the next starter then reads as a free seat. Measured by the
# codex seat in fixtures for both watchers. The turn-lock cleanup on the same
# two lines already said only ever release a lock THIS process took, and the
# pid record was the one thing on them that did not.
release_pid(){ [ "$(cat "$S.pid" 2>/dev/null)" = "$$" ] && rm -f "$S.pid"; return 0; }
trap 'release_pid; [ "$held" = 1 ] && { rm -f "$LOCK/pid" "$LOCK/hold_since"; rmdir "$LOCK" 2>/dev/null; }' EXIT
trap 'release_pid; [ "$held" = 1 ] && { rm -f "$LOCK/pid" "$LOCK/hold_since"; rmdir "$LOCK" 2>/dev/null; }; exit 0' INT TERM
last=$(awk 'NR==1{print $1}' "$S" 2>/dev/null)
blob=$(awk 'NR==1{print $2}' "$S" 2>/dev/null)
# a two field state file predates this and means the change was handled
mode=$(awk 'NR==1{print ($3=="" ? "handled" : $3)}' "$S" 2>/dev/null)
# the fourth field is when a turn ENDED without its acknowledgements yet, and
# it is absent for every mode except `ended`
ended_at=$(awk 'NR==1{print ($4=="" ? 0 : $4)}' "$S" 2>/dev/null)
case ${ended_at:-x} in *[!0-9]*) ended_at=0 ;; esac
ack_nag=0
# `git rev-parse` ON A PATH THAT DOES NOT EXIST ECHOES THE ARGUMENT BACK, which
# is the same trap this script already warns about for --absolute-git-dir and
# which the blob read fell into anyway. Left unchecked, `blob` becomes the
# literal string `origin/main:collab/INBOX_a.md`, the loop then compares that
# garbage against the same garbage every poll, and a watcher pointed at the
# WRONG PATH sits silent for ever instead of saying the path is wrong. Test the
# SHAPE of the answer, as the git-version check below does.
blob_at(){ b=$(git rev-parse "origin/$INTEG:$BUS/INBOX_$NAME.md" 2>/dev/null)
           case $b in *[!0-9a-f]*|'') printf '' ;; *) printf '%s' "$b" ;; esac; }

# AN INBOX IS NOT A SHORT FILE, and this watcher used to print the whole of it
# on a cold start and again on every change. In the repository this protocol
# was built for, `cloud/INBOX_local.md` is 2,949 lines and its Open section
# once reached 2,233, which is why section 3 has a placement rule at all. Three
# thousand lines per event buries the one line worth reading and fills a
# supervised log. Head and tail, with the gap named and the path repeated, so
# the reader can go and get the rest. HEAD IS THE LARGER HALF because new
# instructions go at the TOP of Open, while the tail is where acknowledgements
# and closed work accumulate.
MAXLINES=${MAXLINES:-120}
case $MAXLINES in ''|*[!0-9]*) echo "MAXLINES must be whole lines, using 120"; MAXLINES=120;; esac
[ "$MAXLINES" -lt 20 ] && MAXLINES=20
show_inbox(){
  raw=$(git show "origin/$INTEG:$BUS/INBOX_$NAME.md" 2>/dev/null) ||
    { echo "(no inbox at that path yet)"; return; }
  case $raw in '') echo "(the inbox at that path is empty)"; return;; esac
  # THE CAP IS ON LINES AND ALSO ON EACH LINE. Capping records alone let a
  # single enormous record through whole: measured at two megabytes on one
  # line, printed in full with no elision marker, under both shells. A log is
  # bounded by bytes, not by newlines, so a record over WIDE bytes is cut and
  # says how many it dropped, which is the same promise the line cap makes.
  printf '%s\n' "$raw" |
    LC_ALL=C awk -v cap="$MAXLINES" -v wide=2000 \
                 -v where="$BUS/INBOX_$NAME.md on $INTEG" '
      function clip(s,   L) { L = length(s)
        if (L <= wide) return s
        return substr(s, 1, wide) sprintf(" ... [%d more bytes on this line, elided]", L - wide) }
      { n++; line[n] = $0 }
      END {
        if (n <= cap) { for (i = 1; i <= n; i++) print clip(line[i]); exit }
        h = int(cap * 2 / 3); t = cap - h
        for (i = 1; i <= h; i++) print clip(line[i])
        printf "... %d lines elided by the watcher, read %s for them ...\n", n - cap, where
        for (i = n - t + 1; i <= n; i++) print clip(line[i])
      }'
}
[ -z "$blob" ] && { git fetch -q origin "+$INTEG:refs/remotes/origin/$INTEG" 2>/dev/null
  blob=$(blob_at)
  [ -n "$blob" ] || echo "NO INBOX AT $BUS/INBOX_$NAME.md ON $INTEG. The watcher will keep polling and will pick it up the moment it appears, but if that path is a typo it will wait for ever. Check the name against what the master actually writes."
  echo "inbox watcher cold start: changes before now are invisible to it, and the check-in's watermark range query is what recovers them. The current inbox follows, capped at $MAXLINES lines, so it is at least in this log:"
  show_inbox
  # A COLD START WITH A WORKING ON_CHANGE MUST NOT EAT WHAT IS ALREADY THERE.
  # Recording the inbox it finds as handled was the older behaviour and it cost
  # two deliveries in one night: an instruction pushed BEFORE a watcher armed
  # was consumed by the arming itself, the seat looked healthy, and the master
  # had to push a second, contentless change to shake it loose. Both times.
  # Codex reproduced it deliberately afterwards.
  #
  # SO THE SEED IS SKIPPED WHERE A TURN CAN ACTUALLY BE STARTED, which makes
  # the first poll see a change and deliver once. The objection this answers is
  # real and is why the seed existed: a watcher restarting in a loop under
  # supervise.sh would start a turn per restart. It cannot, because the state
  # file written by that first delivery survives the restart, so the next arm
  # is not a cold start at all. What still fires per restart is a clone whose
  # state file keeps coming back EMPTY, which is a broken clone announcing
  # itself loudly instead of silently swallowing instructions, and the louder
  # failure is the better one.
  #
  # WITH NO ON_CHANGE the seed stays, because there is nothing to start: the
  # inbox is already in the log above, and re-printing it every restart would
  # be noise with no delivery attached.
  [ -z "${ON_CHANGE:-}" ] || { blob=; echo "and this watcher can start a turn, so that inbox is treated as UNDELIVERED and the first poll will deliver it rather than recording it as handled"; }; }
# A STATE FILE CAN BE WRONG WITHOUT LOOKING WRONG, and the atomic write above
# only removes ONE cause of that. Codex found the hole: a record whose head is
# the CURRENT head and whose blob is a plausible but incorrect value arms
# silently. The head never changes, so the watcher has no reason to look at the
# real inbox, and it sits there for ever having handled nothing. An empty file
# is caught by the cold start; this one is not.
#
# So the recorded blob is CHECKED AGAINST THE REMOTE once, at arm. If it
# disagrees, nothing is known about whether that inbox was handled, and the
# safe reading is that it was not: clearing `last` makes the first poll take
# the change path, which surfaces the inbox and runs ON_CHANGE exactly once.
# A PRINTED-ONLY CHANGE IS PENDING AGAIN THE MOMENT SOMEBODY CAN ACT ON IT.
# The previous watcher had no ON_CHANGE and printed into a stream nobody read.
# This one can start a turn, so the change it inherited was never delivered to
# anything, and clearing `last` makes the first poll take the change path.
if [ "${mode:-handled}" = printed ] && [ -n "${ON_CHANGE:-}" ]; then
  echo "THE LAST CHANGE WAS PRINTED AND NOT DELIVERED, by a watcher with no ON_CHANGE. This one can start a turn, so it is treated as pending and read once now."
  last=
fi
if [ -n "${last:-}" ] && [ -n "${blob:-}" ]; then
  # THE CHECK MUST KNOW WHETHER IT RAN. Fetch failure and a missing tracking
  # ref were both swallowed, so an unreachable remote left `actual` empty, the
  # comparison was skipped, and the recorded state was trusted in full. Codex
  # built the trap: a wrong-but-plausible blob at the current head, the
  # tracking ref deleted, origin unreachable at arm, then restored at the SAME
  # head. Neither watcher ever fetched again, because the loop only fetches
  # when the head MOVES, and `cur` equalled `last` for ever. Both state files
  # stayed byte-for-byte wrong and nothing was ever delivered or said. So a
  # reconciliation that could not read the remote is UNKNOWN, and unknown is
  # treated the same way a disagreement is.
  if ! git fetch -q origin "+$INTEG:refs/remotes/origin/$INTEG" 2>/dev/null; then
    echo "COULD NOT REACH THE REMOTE AT ARM, so the recorded state could not be checked against it. Nothing is known about whether that inbox was handled, and this watcher will not sit on a record it could not verify: it is treated as unhandled and read once as soon as the remote answers."
    last=
  else
    actual=$(git rev-parse "origin/$INTEG:$BUS/INBOX_$NAME.md" 2>/dev/null || true)
    head_now=$(git rev-parse "origin/$INTEG" 2>/dev/null || true)
    if [ -z "$head_now" ]; then
      echo "THE FETCH SUCCEEDED AND THE TRACKING REF IS STILL ABSENT, so the recorded head cannot be checked. Treated as unhandled and read once now."
      last=
    elif [ -n "$actual" ] && [ "$actual" != "$blob" ] && [ "$head_now" = "$last" ]; then
      echo "STATE DISAGREES WITH THE REMOTE: the record says inbox blob $blob at head $last, and that head actually carries $actual. Nothing is known about whether that inbox was handled, so it is treated as unhandled and read once now."
      last=
    fi
  fi
fi
echo "inbox watcher ARMED on $INTEG at head ${last:-none}, inbox blob ${blob:-none}, P=$P, running script ${FP:-unknown}"
# THE GATE SAYS WHETHER IT IS ON, because a safety property nobody can see is
# one nobody relies on, and a reader of this log has to be able to tell which
# of two meanings `handled` carries in it.
if [ -n "$ACK_BRANCH" ]; then
  # THE BASELINE IS OPT IN NOW, AND IT USED TO SWALLOW THE INSTRUCTION THAT
  # WOKE THE TURN. A reader armed the gate in an isolated fixture with one real
  # unacknowledged instruction present, `ZZ-1'. The baseline recorded `ZZ-1' as
  # already unanswered, the cold-start delivery ran, and the very next
  # resolution printed ACKNOWLEDGED and persisted handled with no
  # acknowledgement anywhere. The one instruction the gate existed to protect
  # was the one it excluded, because a cold start cannot tell a stale backlog
  # from the thing that is being delivered right now.
  # SO NOTHING IS EXCLUDED UNLESS AN OPERATOR SAYS SO. `ACK_BASELINE=1' takes
  # the old snapshot deliberately, which is the migration path for a lane with
  # a genuine unmarked backlog. Left unset, every Open identifier is owed, and
  # a lane with a backlog ALARMS rather than falsely completing. That is the
  # safe direction of failure and it is the whole point of the gate.
  # AND THE SUITE COULD NOT SEE THIS. Case 45 seeded the same unacknowledged
  # first instruction before arming and then asserted only on a SECOND one
  # added afterwards, so it stepped over the hole it was written to cover.
  # AND THE OPT IN IS THE VALUE 1, NOT ANY NON-EMPTY STRING. Every comment
  # and the operator message name ACK_BASELINE=1, and `-n` accepted 0 and
  # the empty-looking values a person reaches for to turn a thing OFF, so
  # ACK_BASELINE=0 excluded the outstanding work it was meant to keep.
  if [ "${ACK_BASELINE:-}" = 1 ] && [ ! -f "$S.ackbase" ]; then
    : > "$S.ackbase"
    base=$(missing_acks)
    case $base in
      FETCHFAILED*) rm -f "$S.ackbase"
        echo "the acknowledgement gate is ON for $ACK_BRANCH and could not read it to take a baseline, so it will take one on the first poll that can" ;;
      '') echo "the acknowledgement gate is ON, reading the commit subjects on $ACK_BRANCH: a turn is not recorded handled until every Open instruction carries [done: ID] or [skipped: ID] in a subject there. A marker anywhere else is invisible to it. Nothing is unanswered right now." ;;
      *) printf '%s\n' $base > "$S.ackbase"
         echo "the acknowledgement gate is ON: a turn is not recorded handled until every Open instruction carries [done: ID] or [skipped: ID] in a commit subject on $ACK_BRANCH. A marker anywhere else is invisible to it."
         echo "ALREADY UNANSWERED WHEN THIS ARMED, and therefore excluded from its alarms: $base. That work may well be done and the marker never written. Move those to the Closed section if they are finished, because this watcher will not mention them again." ;;
    esac
  elif [ ! -f "$S.ackbase" ]; then
    : > "$S.ackbase"
    echo "the acknowledgement gate is ON: a turn is not recorded handled until every Open instruction carries [done: ID] or [skipped: ID] in a commit subject on $ACK_BRANCH. A marker anywhere else is invisible to it. NOTHING IS EXCLUDED. If this lane carries instructions that were finished without a marker, it will alarm about them until they are marked or moved to the Closed section, and ACK_BASELINE=1 at arm time excludes whatever is unanswered at that moment instead."
  fi
else
  echo "the acknowledgement gate is OFF, so a turn that ends is recorded handled. That proves a turn ENDED and not that the instruction was carried out. Set ACK_BRANCH to the seat's branch to require its acknowledgement."
fi
# A DIAL THAT DEFAULTS TO EMPTY GOES WRONG SILENTLY, and this one goes wrong
# in the direction nobody checks: a watcher armed without NOTIFY still watches,
# still logs, still alarms into a terminal nobody has open. Measured on this
# team: one live seat ran for days with three dials exported and this one
# forgotten, and the master read its silence as a quiet lane. So the state of
# the dial is said out loud at arm time, where the operator is already looking.
if [ -n "$NOTIFY" ]; then
  echo "notifications are ON through: $NOTIFY"
else
  echo "NO NOTIFIER IS WIRED. Silence from here proves nothing: it reads the same whether the lane is quiet or this watcher was armed without one. Set NOTIFY to a command to get a sign on every state change, bin/notify.sh beside this script being the shipped one."
fi
notify armed "watching $BUS/INBOX_$NAME.md on $INTEG, polling every ${P}s"
fail=0; waiting=0; tf=0; attempting=; retry_at=0; stuck_since=0; nag_at=0; said_locked=
while true; do
  # exit status, not empty output, is what says the remote failed: an
  # absent branch answers successfully with nothing, and backing off for
  # that turns a branch that is about to appear into a ten minute wait.
  if out=$(git ls-remote origin "refs/heads/$INTEG" 2>/dev/null); then
    fail=0; cur=$(printf '%s\n' "$out" | cut -f1)
    # a sighting clears the alarm, and it has to be tested HERE rather
    # than where the head changes: a branch restored at the commit it had
    # when it vanished never changes the head, so the return would never
    # be announced and a second disappearance would be silent.
    if [ -n "$cur" ] && [ "$waiting" = 1 ]; then
      # a branch seen for the FIRST time is not the same event as one that
      # came back, and calling both "BACK" misreads a new team's first
      # exchange as a recovery from a deletion that never happened.
      if [ -n "${last:-}" ]; then
        echo "the branch $INTEG is BACK on the remote at $cur."
      else
        echo "the branch $INTEG has APPEARED on the remote at $cur."
      fi
      waiting=0
    fi
    # a branch that was there and is now gone is a DIFFERENT event from
    # one that has not been created yet, and it is the loud one: nothing
    # will ever arrive until someone puts it back.
    if [ -z "$cur" ] && [ "$waiting" = 0 ]; then
      if [ -n "${last:-}" ]; then
        notify alarm "the branch $INTEG is gone from the remote, nothing can arrive"
        echo "ALARM: the integration branch $INTEG was on the remote at $last and is GONE. It was deleted, or this clone is watching the wrong remote. Nothing can arrive until it is back."
      else
        echo "waiting: $INTEG does not exist on the remote yet"
      fi
      waiting=1
    fi
  else
    fail=$((fail+1)); cur=
  fi
  if [ -n "$cur" ] && [ "$cur" != "$last" ]; then
    # NOTHING is recorded as seen until the fetch carrying it succeeds.
    # ls-remote and fetch are separate connections, and a failure between
    # them used to mark the head processed and lose the message for good.
    if git fetch -q origin "+$INTEG:refs/remotes/origin/$INTEG"; then
      waiting=0
      nb=$(blob_at)
      if [ "$nb" != "$blob" ]; then
        now=$(date +%s)
        # THE REMINDER FIRES FROM HERE, before the ladder decides whether to
        # attempt, so it speaks while the watcher is waiting out RETRY and
        # while a 75 is holding the lock. Those are exactly the two states in
        # which the old code said nothing at all.
        # NOT GATED ON THE ATTEMPT COUNT, and that was the first version's bug.
        # `tf` only advances when an attempt RUNS, and the worst case is
        # precisely the one where none can: a turn that returned 75 holds the
        # lock, nothing else starts, `tf` freezes at one, and the reminder that
        # exists for exactly this silence never fires. Codex measured it, with
        # a four second NAG deadline passing repeatedly inside eighteen seconds
        # of quarantine and not one reminder. The clock is the clock.
        if [ "$NAG" -gt 0 ] && [ "$stuck_since" -gt 0 ] && [ "$now" -ge "$nag_at" ]; then
          mins=$(( (now - stuck_since) / 60 ))
          echo "STILL UNDELIVERED after ${mins}m and $tf attempts: $NAME has not received this inbox change and is not being reached. The last attempt's output is above in this log. This is NOT abandoned, and it will keep being retried and keep saying so every ${NAG}s until it lands."
          notify alarm "not reached for ${mins}m, $tf attempts"
          nag_at=$((now + NAG))
        fi
        # announce a change ONCE, however many attempts it takes: a slow
        # retry that reprinted the inbox every interval would bury the
        # message it is trying to deliver
        if [ "$nb" != "$attempting" ]; then
          echo "INBOX CHANGED:"; show_inbox
          attempting=$nb; tf=0; retry_at=0; stuck_since=$now; nag_at=$((now + NAG))
        fi
        # ON A TOOL WITH NO SCHEDULER, printing is not enough: nothing is
        # listening. Set ON_CHANGE to the tool's non-interactive entry point
        # and this watcher starts a real agent turn within one poll, which is
        # what closes the loop on Codex and on any other exec-mode CLI.
        if [ -z "${ON_CHANGE:-}" ]; then
          # PRINTING IS NOT DELIVERING, and recording this as handled without
          # saying so is how a change disappears. A watcher with no ON_CHANGE
          # prints the inbox for a person to read, which is a real mode and
          # worth keeping, but if nobody is reading that stream the change is
          # simply gone. Worse, adding ON_CHANGE later does NOT replay it: the
          # blob is already recorded, so the new watcher believes the work was
          # done. Measured on a live Antigravity seat, whose instruction was
          # consumed exactly this way and sat unread while the seat looked
          # healthy. So the disposition is recorded beside the blob, and the
          # arm check below turns a printed-only change back into a pending one
          # the moment a watcher with ON_CHANGE takes over.
          echo "PRINTED ONLY: no ON_CHANGE is set, so nothing was started. If nobody is reading this stream, this change has reached no one."
          blob=$nb; mode=printed
        elif [ "$now" -lt "$retry_at" ]; then
          :   # inside the slow interval, and saying so every poll is noise
        elif ! mkdir "$LOCK" 2>/dev/null && ! { lock_is_dead && rm -rf "$LOCK" && mkdir "$LOCK" 2>/dev/null && { said_locked=; echo "the lock at $LOCK had no living owner, so this watcher has taken it over"; }; }; then
          # ONCE PER LOCK EPISODE, NOT ONCE PER POLL. This paragraph is long
          # because it has to name the two clocks that free the lock, and at a
          # twenty second poll it filled a log with forty identical copies of
          # itself inside fifteen minutes. Measured: an operator asked for the
          # last forty lines of a watcher's log to diagnose a failed delivery
          # and got forty copies of this and nothing else, so the one line that
          # said what had actually gone wrong had scrolled away. The reminder
          # above is what speaks while a change stays stuck; this says its
          # piece once and then lets the log carry information.
          [ -n "$said_locked" ] || echo "a turn is already running for $NAME and holds $LOCK, so this watcher is NOT starting a second one. The change stays unhandled and the next poll retries it. If that turn is gone, its owner is recorded in $LOCK/pid and this watcher reclaims the lock by itself, after $HOLD minutes when a turn was quarantined for being unable to say whether it finished, or after $STALE minutes for a lock taken by hand with no owner recorded."
          said_locked=1
        else
          held=1; said_locked=
          echo $$ > "$LOCK/pid"
          echo "starting a turn: $ON_CHANGE"
          notify started "an inbox change arrived, starting a turn" in
          # NOTHING IS RECORDED AS HANDLED UNTIL THE TURN THAT HANDLES IT
          # SUCCEEDS. Marking the inbox processed and then running the
          # command loses the instruction for good when the command fails,
          # which is the same defect as recording a head before the fetch
          # carrying it succeeded, in a second place.
          # THE EXIT CODE IS CAPTURED, not merely tested, because one value
          # of it changes what happens to the lock. Writing this as
          # `if sh -c ...; then` throws the code away, and a later reader of
          # `$?` gets the status of whichever branch ran instead.
          rc=0; sh -c "$ON_CHANGE" || rc=$?
          if [ "$rc" = 0 ]; then
            [ "$tf" -ge "$FAST" ] && { echo "RECOVERED after $tf failed attempts: whatever was unavailable has come back and this change is handled."; notify recovered "recovered after $tf failed attempts"; }
            echo "the turn finished"; blob=$nb; tf=0; retry_at=0
            stuck_since=0; nag_at=0
            if [ -n "$ACK_BRANCH" ]; then
              # THE TURN ENDED AND THAT IS NOT THE SAME AS THE INSTRUCTION
              # BEING CARRIED OUT. The change is NOT consumed here. It becomes
              # handled on a later poll, once the seat's branch says so.
              mode=ended; ended_at=$(date +%s); ack_nag=0
              echo "the turn ended and the change is NOT recorded handled yet, because the acknowledgement gate is on. Waiting for every Open instruction to carry [done: ID] or [skipped: ID] on $ACK_BRANCH."
            else
              mode=handled
            fi
            notify finished "the turn ended, its report is the seat's to push" out
          else
            tf=$((tf+1))
            # 75 IS NOT A FAILURE TO RETRY, so it must not be announced as
            # one. The block below holds the lock and pushes the next attempt
            # out to RETRY, which is the opposite of what "retrying" tells a
            # human reading a notification. Announcing both left Davies with
            # two notifications from ONE event saying opposite things: the
            # turn failed and will retry, and nothing will start. Only the
            # alarm below speaks for 75.
            if [ "$rc" = 75 ]; then
              echo "the turn returned 75, attempt $tf: it may still be running, so this is NOT retried on the next poll"
            elif [ "$tf" -lt "$FAST" ]; then
              echo "the turn exited non-zero, attempt $tf: this inbox change is NOT recorded as handled and the next poll retries it"
              notify failed "the turn failed, attempt $tf, retrying"
            else
              retry_at=$((now + RETRY))
              [ "$tf" = "$FAST" ] && notify slowing "retrying every ${RETRY}s after $tf failures"
              [ "$tf" = "$FAST" ] && echo "SLOWING DOWN after $tf failures, to one attempt every ${RETRY}s. This change is NOT abandoned and NOT lost: a command that is merely unavailable, an exhausted allowance or a host that is down, recovers by itself and the next attempt picks it up. A command that is actually broken now fails quietly instead of spinning, so fix it and the following attempt uses the fix."
            fi
          fi
          # EXIT 75 MEANS THE TURN MAY STILL BE RUNNING, and releasing the
          # lock here would let the retry run beside it. That is the accident
          # the lock exists to prevent, and an earlier version had it: every
          # failure released the lock, including the one failure that means
          # "I could not tell whether it finished". So the lock is KEPT.
          # Its owner is recorded as unknown rather than as this watcher, so
          # the stale reclaim of STALE minutes can eventually free it if the
          # turn really did die. Until then no second turn starts.
          if [ "${rc:-0}" = 75 ]; then
            # REMOVE the pid file rather than emptying it. lock_is_dead reads
            # an EMPTY pid file as proof of death and reclaims immediately,
            # which would hand the lock straight back on the next poll.
            # AND STAMP `hold_since` NOW. The age test measured the lock directory,
            # which was created when the turn STARTED, so with the shipped
            # TIMEOUT of an hour and STALE of sixty minutes the lock was
            # already reclaimable the instant it was held and the next poll
            # could start a second turn beside a live one. That cancelled
            # this whole branch. The clock runs from the quarantine.
            rm -f "$LOCK/pid"; : > "$LOCK/hold_since"
            retry_at=$((now + RETRY))
            echo "HOLDING $LOCK: the turn may still be running, so this watcher starts nothing beside it. The lock records no owner, and its ${HOLD} minute clock starts NOW rather than when the turn began, so nothing else runs until then. Clear the directory by hand to release it sooner, once you have looked at the seat and seen that no turn is running."
            notify alarm "cannot tell if the turn finished, holding the lock, nothing new starts"
            held=0
          else
            # rmdir only removes an EMPTY directory, so every file this
            # branch might have written has to go with it
            rm -f "$LOCK/pid" "$LOCK/hold_since"; rmdir "$LOCK" 2>/dev/null || true; held=0
          fi
        fi
      fi
      # THE HEAD IS RECORDED ONLY WHEN THE INBOX AT THAT HEAD WAS HANDLED.
      # A change still being retried is NOT handled, so its head is never
      # persisted and a restart retries it from the state file, which is
      # what makes the slow ladder safe to interrupt at any point.
      if [ "$nb" = "$blob" ]; then
        last=$cur; save_state "$last $blob ${mode:-handled} ${ended_at:-0}"
      fi
    else
      # SAY THAT NOTHING WAS LOST, since that is the question a reader has
      # at the moment this line appears, and the answer is not obvious
      fail=$((fail+1)); echo "fetch failed after a change was seen, will retry. The head is NOT recorded, so the change is still waiting and no message is lost."
    fi
  fi
  # ---- the acknowledgement gate resolves here, once per poll ----------
  # A TURN THAT ENDED IS NEVER RE-RUN. It ran. Running it again could repeat
  # whatever it did do, and the question here is not whether to retry but
  # whether the seat has said the instruction is finished. So this path only
  # ever advances the change to handled or says it is still unanswered.
  if [ -n "$ACK_BRANCH" ] && [ "${mode:-handled}" = ended ]; then
    miss=$(missing_acks)
    case $miss in
      FETCHFAILED*)
        echo "could not read $ACK_BRANCH to check acknowledgements, so the change stays unhandled and this will look again. Nothing is lost."
        ;;
      '')
        echo "ACKNOWLEDGED: every Open instruction now carries [done: ID] or [skipped: ID] on $ACK_BRANCH, so the change is handled."
        notify finished "the seat acknowledged its instructions in the repository" out
        mode=handled; ended_at=0; ack_nag=0
        [ -n "${last:-}" ] && save_state "$last $blob handled 0"
        ;;
      *)
        now=$(date +%s)
        if [ "$((now - ended_at))" -ge "$ACK_WAIT" ] &&
           { [ "$ack_nag" = 0 ] || [ "$((now - ack_nag))" -ge "$NAG" ]; }; then
          ack_nag=$now
          echo "STILL UNACKNOWLEDGED after $((now - ended_at))s: the turn for $NAME ended and $ACK_BRANCH does not carry an acknowledgement for $miss. The turn is NOT being re-run, because it ran. Either the seat failed quietly, or it finished and did not write the marker. Look at it."
          case $miss in *"UNPARSABLE("*) echo "One of those is not a real identifier. That many bullets under Open carry no identifier this watcher can read, so it cannot tell whether they are owed. An instruction ID is the seat's name, which starts with a letter, then a hyphen and a number. Fix the entry or the seat name and the count goes away." ;; esac
          notify alarm "$NAME ended a turn and never acknowledged $miss"
        fi
        ;;
    esac
  fi
  nap=$((P + P * fail)); [ "$nap" -gt 600 ] && nap=600
  sleep "$nap"
done
