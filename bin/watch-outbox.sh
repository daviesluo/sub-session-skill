#!/bin/sh
# Copyright 2026 Zheng Luo (Davies Luo). Licensed under the Apache License
# 2.0, whose text is the LICENSE file in this package. Keep this notice
# when you copy the script.
#
# watch-outbox.sh <name> <seat-branch> <bus-dir>
#
# Watches a seat's branch and prints the NEW outbox entries as they land.
# Restart-safe: it keeps its state beside the clone's git directory, so a
# restart neither replays nor skips.
#
#   sh watch-outbox.sh a sub/a collab        # resting poll, 60 seconds
#   P=20 sh watch-outbox.sh a sub/a collab   # tighter, while a reply is due
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
NAME=${1:?usage: watch-outbox.sh <name> <seat-branch> <bus-dir>}
BRANCH=${2:?usage: watch-outbox.sh <name> <seat-branch> <bus-dir>}
BUS=${3:?usage: watch-outbox.sh <name> <seat-branch> <bus-dir>}
P=${P:-60}                # base poll in seconds, start with P=20 while a reply is due
# DUE turns SILENCE into an event. A watcher that only speaks when a seat
# pushes cannot tell you that a seat which owed you a reply never sent one,
# and the master then finds out from the user rather than from the bus.
# IT MEASURES SILENCE SINCE THE SEAT LAST SPOKE, which is a different clock
# from the time since you assigned the work: a seat that went quiet ten
# minutes before you wrote to it is already ten minutes into DUE. It also
# knows nothing about whether anything is outstanding, so a seat you have
# deliberately stood down reports its own idleness once. Run those at DUE=0.
# It fires ONCE and stays quiet until the seat speaks again.
#
# DUE MUST BE COMFORTABLY SHORTER THAN THE THING THAT KILLS THIS WATCHER, or
# it can never fire at all. Measured on a live deployment: the platform
# streaming the watcher's output has a hard thirty minute ceiling, DUE was set
# to 1800, and every restart reset the clock to zero moments before the alarm
# was due. A seat stayed silent for FIVE HOURS and not one alarm was raised,
# on a watcher that was working perfectly. Halve it against the measured
# ceiling, or supervise the watcher so it is not the streamer that ends it.
#
# AND IT IS THE WRONG TOOL FOR A SEAT THAT IS LEGITIMATELY QUIET. It cannot
# tell a seat running a nine hour job from a seat that has died, so pointing
# it at one produces either a false alarm every period or nothing useful.
# Where a seat is working and will speak at a known event, run it at DUE=0
# and check liveness by measuring the lane instead.
DUE=${DUE:-0}
case $DUE in ''|*[!0-9]*) echo "DUE must be whole seconds, ignoring it"; DUE=0;; esac
case $P in ''|*[!0-9]*) echo "P must be whole seconds, using 60"; P=60;; esac
[ "$P" -lt 5 ] && P=5
# A HEADLESS TURN MOVES NOTHING THE USER CAN SEE, and the master side was
# silent for longer than the seat side because this watcher had no hook at
# all: a seat could reply and the only thing that ever noticed was a stream
# nobody was reading. NOTIFY runs on every state change with NOTIFY_STATE set
# to one of the four this watcher can reach, armed, finished, failed or alarm,
# and NOTIFY_TEXT set to one line about it. It never emits `started`, which is
# a seat beginning a turn and belongs to the inbox side. `bin/notify.sh` is the shipped recipe. THE TEXT NEVER
# REPEATS THE SEAT'S NAME, because the notification's own first line already
# carries who is talking to whom. Its output is discarded and its failures
# ignored, because a broken view must never be able to break the bus.
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
fingerprint_in() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum 2>/dev/null | cut -c1-16
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 2>/dev/null | cut -c1-16
  else cksum 2>/dev/null | cut -d" " -f1
  fi
}
# THE FIRST k RECORDS, DIGESTED. This is what makes append-only checkable: the
# records this watcher has already reported must still be exactly those records.
# WHEN THE BODY CANNOT COVER k THE ANSWER IS `short`, NEVER A HASH. awk's NR<=k
# passes the whole body when k exceeds it, so a digest taken then covered fewer
# records than its count claimed, was stored looking exact, and fired the
# append-only alarm later on a file nobody had touched. Measured 27 August on a
# live seat. A recording that cannot cover its count now says so in the one
# word the caller is required to catch, so the poisoned record can no longer be
# written silently.
prefix_digest(){
  if [ "$(body "${2:-}" | awk 'END{print NR}')" -lt "${1:-0}" ]; then
    printf 'short\n'
  else
    body "${2:-}" | awk -v k="${1:-0}" 'NR<=k' | fingerprint_in
  fi
}
FP=$(fingerprint "$0")
B="$BRANCH"; F="$BUS/OUTBOX_$NAME.md"
G=$(git rev-parse --absolute-git-dir 2>/dev/null)
# see the note in the inbox watcher: an old git echoes the unknown option
# EXIT 78 IS EX_CONFIG, and it means THIS MACHINE CAN NEVER RUN THIS WATCHER.
# The supervisor reads it and stops. A restart cannot make git newer, so the
# ordinary code would have this refusal printed every 300s for the life of the
# machine, which is a log nobody reads reporting a fault nobody fixes. 75 is
# already EX_TEMPFAIL in the injector, so the two codes that leave the shell
# come from one table.
case $G in ''|-*) echo "this watcher needs git 2.13 or newer, because it keeps its state beside the answer to git rev-parse --absolute-git-dir. Check with git --version. Nothing here retries: install a newer git and start the watcher again."; exit 78;; esac
S="$G/outbox_watch_$NAME"
# WRITE THE STATE ATOMICALLY. `echo ... > "$S"` truncates first and writes
# second, so a crash between the two leaves a torn file that the next start
# reads as empty. It then cold-seeds from the remote as it stands and skips
# everything pushed while it was down, for good. A rename within one directory
# is atomic on POSIX, so the file a restart finds is either the old state or
# the new one and never half of either. Codex found this: the skip is
# announced, but under `bin/supervise.sh` the restart is unattended and the
# announcement reaches a log nobody is reading at that moment.
# THE COUNT IS TAKEN OVER A CANONICAL BODY, which is the file with its
# TRAILING BLANK LINES REMOVED, and every count and every slice below goes
# through this one function so they can never disagree.
#
# WHY. The count used to be raw lines, and the append-only alarm compared raw
# counts. A seat that tidied five blank lines off the end of its outbox while
# adding two real entries therefore made the file SHORTER, and the watcher
# reported that the outbox had been rewritten or the branch rewound. Measured
# 27 August on a live seat: 3040 to 3038, nothing lost, every fetch a
# fast-forward, and the alarm that exists to mean "your record is corrupt"
# fired on whitespace. A false alarm on an integrity alarm is worse than no
# alarm, because it teaches the reader to skip the one line that must never be
# skipped. Blank lines are not entries, so they are not counted.
#
# A COUNT IS NOT AN APPEND-ONLY CHECK, and this file used to claim it was.
# Remove one entry and add another and the count is unchanged, so a rewrite of
# everything already delivered passed as "no new outbox entries". Measured by
# the Codex seat on a seeded remote: entries one and three were replaced, the
# count held at three, and the watcher said nothing. The count is kept because
# it is what slices the new entries, and the append-only property is checked
# separately, by digesting the records already delivered and requiring them to
# still be there byte for byte.
body(){ git show "${1:-origin/$B}:$F" 2>/dev/null |
  awk '{ l[NR]=$0; if ($0 ~ /[^ \t\r]/) k=NR } END{ for(i=1;i<=k;i++) print l[i] }'; }
save_state(){ printf '%s\n' "$*" > "$S.new" && mv -f "$S.new" "$S"; }
# A LIVE PID IS NOT A WATCHER. `kill -0` proves only that some process owns
# that number, and pid numbers are reused, so an unrelated process whose pid
# happens to sit in the state file locked this seat out of arming for good.
# Measured by the Codex seat. The recorded pid has to look like the watcher it
# claims to be before it can refuse anybody.
# AND THE SEAT NAME IS AN ARGUMENT, NOT A SUBSTRING. `*"$NAME"*` accepted any
# command line the name appeared anywhere inside, so a watcher for `cdx2` read
# as the watcher for `cdx`: the supervisor would have killed a live neighbour
# and the outbox watcher would have stood aside for one. Both scripts take the
# seat name as their FIRST argument, so that is what is compared, which also
# means no launcher spelling has to be enumerated.
# Exit 0 is ours, 1 is positively somebody else's, 2 is UNREADABLE. Arming on
# an unreadable identity is how a second watcher started beside a live one on a
# machine whose sandbox refused `ps`, and two watchers on one outbox each eat
# entries the other never shows anyone.
  # AND THE MATCH IS A WHOLE ARGUMENT WHOSE BASENAME IS THE SCRIPT, not a
  # substring of the command line. `*"watch-outbox.sh "*` also matched `not-watch-outbox.sh` and
  # `/p/x/watch-outbox.sh.bak`, so an unrelated live process could be signalled by the
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
    case ${w##*/} in watch-outbox.sh) want=1 ;; esac
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
# shape of a live incident, two watch-outbox.sh processes against one seat with a
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
           echo "an outbox watcher for $NAME is already running as pid $cur, so this one stands down rather than watching beside it"; rmdir "$S.claiming" 2>/dev/null; exit 3
         elif [ "$own" = 2 ] && kill -0 "$cur" 2>/dev/null; then
           # AND THE LIVENESS IS RE-READ BEFORE REFUSING FOR EVER. `kill -0`
           # says alive, then `ps` says nothing, and those are two different
           # instants: a process that exits between them makes the identity
           # unreadable for the ordinary reason, and the record is simply
           # stale. Refusing 78 there turns a routine race into a supervisor
           # that stops until a person comes. Measured by the Codex seat with
           # a `ps` that killed the pid before returning empty. Still alive on
           # the second look means the machine really will not identify it.
           echo "$S.pid records pid $cur, which is alive and whose identity this machine will not report, so this REFUSES to arm. Arming anyway is how two watchers end up on one outbox, each consuming entries the other never shows anyone. Stop that process, or clear $S.pid once you know what it is. Nothing here retries: this needs a person."; rmdir "$S.claiming" 2>/dev/null; exit 78
         elif [ "$own" = 2 ]; then
           # AND THE SENTENCE MATCHES THE BRANCH. Widening the refusal above
           # made this path reachable a second way, and it kept the message
           # written for the first: it called a pid that had just gone "alive
           # but is not a watch-outbox.sh", and printed an empty command line
           # after "It is running:". An operator then looks for a live foreign
           # process that does not exist. This path says what happened.
           echo "$S.pid records pid $cur, which answered as alive and then went while this was identifying it, so the record is stale and this arms over it. Nothing needs doing here: that is one owner exiting as the next one starts."
         else
           echo "$S.pid records pid $cur, which is alive but is not a watch-outbox.sh for $NAME. Treating the record as stale and arming, rather than staying out of the way of a process that has nothing to do with this seat. It is running: $(ps -o args= -p "$cur" 2>/dev/null | head -1)"
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
# AND THE RECORD IS RELEASED ONLY WHILE IT STILL NAMES THIS PROCESS, for the
# reason the inbox watcher carries in full: an unconditional removal deletes a
# SUCCESSOR's claim and leaves a live watcher with no record.
release_pid(){ [ "$(cat "$S.pid" 2>/dev/null)" = "$$" ] && rm -f "$S.pid"; return 0; }
trap 'release_pid' EXIT
trap 'release_pid; exit 0' INT TERM
last=$(awk 'NR==1{print $1}' "$S" 2>/dev/null)
n=$(awk 'NR==1{print $2}' "$S" 2>/dev/null)
case $n in *[!0-9]*) n=;; esac   # a corrupt count re-seeds loudly
# THE THIRD FIELD MARKS WHICH COUNT THE RECORD HOLDS, and it exists so that
# changing what is counted cannot cost a watcher its history. A record written
# before the canonical body counted raw lines including trailing blanks, which
# is a LARGER number, so the first comparison after an upgrade would look like
# a shrink and raise the alarm this change exists to stop raising. The count is
# therefore recomputed at THE HEAD THE RECORD ALREADY DELIVERED, which is exact
# and loses nothing, instead of re-seeding at the current head, which would
# silently skip whatever arrived in between.
fmt=$(awk 'NR==1{print $3}' "$S" 2>/dev/null)
dg=$(awk 'NR==1{print $4}' "$S" 2>/dev/null)
if [ -n "${n:-}" ] && [ "${fmt:-}" != b ] && [ -n "${last:-}" ]; then
  git fetch -q origin "+$B:refs/remotes/origin/$B" 2>/dev/null || true
  if git rev-parse --verify -q "$last^{commit}" >/dev/null 2>&1; then
    was=$(body "$last" | awk 'END{print NR}')
    [ -n "$was" ] && n=$was
  fi
fi
cold=0
# THE COLD SEED TAKES THE DIGEST WITH THE COUNT, over the same fetched body,
# so the append-only watch begins at the arming and not at the first delivery.
# Seeding only the count left the whole compare unarmed until something new
# arrived: in that window a same-count force-push and a shrink both reported
# as no new entries, measured by the review seat on a three-entry branch, and
# arming on a branch that already has history is the ordinary case.
[ -z "$n" ] && { git fetch -q origin "+$B:refs/remotes/origin/$B" 2>/dev/null
  n=$(body | awk 'END{print NR}'); cold=1; dg=$(prefix_digest "$n")
  echo "outbox watcher cold start, seeded at $n entries: anything pushed before now is invisible to it, recover with the range query"; }
# A RECORD WRITTEN BEFORE THE DIGEST EXISTED CARRIES NO FOURTH FIELD, and an
# absent digest must not read as a rewrite. It is computed at the head the
# record already delivered, which is the same repair the third field gets, and
# it loses nothing: everything up to that head is what this watcher reported.
# A GENUINE COLD START IS NOT THAT CASE and skips this block: it holds no
# record, claims nothing and has nothing to verify, and the cold-start line
# above has already said what it cannot see. Without the guard every first
# arming accused an empty head, in the voice of the one alarm that must
# never cry wolf.
if [ "$cold" = 0 ] && [ -z "${dg:-}" ] && [ -n "${n:-}" ]; then
  git fetch -q origin "+$B:refs/remotes/origin/$B" 2>/dev/null || true
  if [ -n "${last:-}" ] && git rev-parse --verify -q "$last^{commit}" >/dev/null 2>&1; then
    dg=$(prefix_digest "$n" "$last")
  else
    # THE HEAD THIS RECORD DELIVERED IS GONE, so what those records WERE is
    # unknowable. Digesting the CURRENT body here would record today's content
    # as though it were yesterday's, which is a claim about history made out of
    # the present, and the append-only alarm would then never fire on anything
    # that changed before this moment. Measured by the Codex seat with an
    # unresolvable head and two replacement entries: the watcher armed, said
    # there was nothing new, and persisted the digest of the replacements.
    # It says so instead, and leaves the digest unset so the first poll seeds
    # it openly rather than silently.
    echo "CANNOT VERIFY THE OUTBOX HISTORY: the state file names head $last, which is not in this clone, so the $n entries it claims to have delivered cannot be read back. The append-only check is OFF until the next push seeds it, and anything rewritten before now will not be caught. Read $F whole and reconcile it against your own record."
    echo "OUTBOX as it stands now:"; body
    dg=
  fi
fi
# THE SAME HOLE ON THIS SIDE. A record carrying the current head and a wrong
# entry COUNT arms silently and never re-counts, so entries already pushed are
# invisible for good. Checked once, at arm, against the remote.
# AND IT IS RETRIED IF IT COULD NOT RUN. This check happens once, at arm, and
# the poll loop below only acts when the head MOVES, so a fetch that failed
# here left a wrong count that nothing would ever revisit at an unchanged head:
# entries already pushed stayed invisible until somebody pushed again. When it
# cannot run, `recount` carries the debt into the loop, which discharges it on
# the first poll that reaches the remote.
recount=0
if [ -n "${last:-}" ] && [ -n "${n:-}" ]; then
  git fetch -q origin "+$B:refs/remotes/origin/$B" 2>/dev/null || recount=1
  head_now=$(git rev-parse "origin/$B" 2>/dev/null || true)
  [ -n "$head_now" ] || recount=1
  if [ "$recount" = 0 ] && [ "$head_now" = "$last" ]; then
    real=$(body | awk 'END{print NR}')
    if [ -n "$real" ] && [ "$real" != "$n" ]; then
      echo "STATE DISAGREES WITH THE REMOTE: the record says $n entries at head $last, and that head actually carries $real. Re-seeding the count from the remote and reporting the difference rather than sitting on a number that cannot be right."
      [ "$real" -gt "$n" ] && echo "OUTBOX entries this watcher had not counted:" && body | tail -n $((real - n))
      n=$real
      # AND THE REPAIR IS WRITTEN DOWN, or it is not a repair. The corrected
      # count lived only in this shell, so a supervisor restart read the old
      # number back off disk, printed the same entries again, and left the file
      # wrong once more. Measured by Codex: state said one entry against three
      # at the same head, and every restart reported the same two for ever.
      # Evidence repeated is evidence nobody trusts.
      save_state "$last" "$n" b "$dg"
    fi
  fi
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
if [ "$DUE" -gt 0 ]; then
  echo "outbox watcher ARMED on $B at head ${last:-none}, $n entries, P=$P, running script ${FP:-unknown}, and it will say so if nothing arrives within ${DUE}s"
  notify armed "watching $B, $n entries, polling every ${P}s, silent alarm at ${DUE}s"
else
  echo "outbox watcher ARMED on $B at head ${last:-none}, $n entries, P=$P, running script ${FP:-unknown}"
  notify armed "watching $B, $n entries, polling every ${P}s"
fi
quiet=$(date +%s); overdue=0
fail=0; waiting=0
while true; do
  if out=$(git ls-remote origin "refs/heads/$B" 2>/dev/null); then
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
        echo "the branch $B is BACK on the remote at $cur."
      else
        echo "the branch $B has APPEARED on the remote at $cur."
      fi
      waiting=0
    fi
    # a branch that was there and is now gone is a DIFFERENT event from
    # one that has not been created yet, and it is the loud one: nothing
    # will ever arrive until someone puts it back.
    if [ -z "$cur" ] && [ "$waiting" = 0 ]; then
      if [ -n "${last:-}" ]; then
        notify alarm "the branch $B is gone from the remote, nothing can arrive"
        echo "ALARM: the seat branch $B was on the remote at $last and is GONE. It was deleted, or this clone is watching the wrong remote. Nothing can arrive until it is back."
      else
        echo "waiting: $B does not exist on the remote yet"
      fi
      waiting=1
    fi
  else
    fail=$((fail+1)); cur=
  fi
  # THE DEBT FROM AN UNREACHABLE ARM, DISCHARGED ONLY AT AN UNCHANGED HEAD.
  # The first version of this ran whenever the remote came back, and at a head
  # that had MOVED it overwrote n, dg and the state file before the changed
  # head path below could compare the old prefix against the new one. That
  # path is where OUTBOX REWRITTEN and OUTBOX SHRANK are raised, so a rewrite
  # or a rewind during the outage was silently absorbed into a re-count and an
  # ordinary append lost its delivery notice. Measured by the Codex seat on a
  # three entry outbox: rewrite the first entry and append a fourth during the
  # outage and the watcher reported only the fourth, with no alarm.
  #
  # So the debt waits. At an unchanged head there is nothing for the other
  # path to do and the repair is safe; at a changed head the ordinary path
  # runs with its evidence intact and clears the debt itself once it has.
  if [ "${recount:-0}" = 1 ] && [ -n "$cur" ] && [ "$cur" = "$last" ]; then
    if git fetch -q origin "+$B:refs/remotes/origin/$B" 2>/dev/null; then
      recount=0
      real=$(body | awk 'END{print NR}')
      if [ -n "$real" ] && [ -n "${n:-}" ] && [ "$real" != "$n" ]; then
        echo "STATE DISAGREES WITH THE REMOTE: the record says $n entries and the branch carries $real. The remote was unreachable when this armed, so the count is being reconciled now rather than waiting for another push."
        [ "$real" -gt "$n" ] && echo "OUTBOX entries this watcher had not counted:" && body | tail -n $((real - n))
        n=$real; dg=$(prefix_digest "$n"); save_state "$last" "$n" b "$dg"
      fi
    fi
  fi
  if [ -n "$cur" ] && [ "$cur" != "$last" ]; then
    # A HEAD THAT MOVED DISCHARGES THE DEBT BY ITSELF, since everything the
    # recount would have repaired is re-derived below from the same fetch.
    recount=0
    if git fetch -q origin "+$B:refs/remotes/origin/$B"; then
      waiting=0
      # awk counts RECORDS, so a final entry written without its newline is
      # still counted. wc -l counts newlines and used to drop that entry,
      # then fuse it into the next one.
      m=$(body | awk 'END{print NR}')
      # THE RECORDS ALREADY REPORTED MUST STILL BE THOSE RECORDS. Checked
      # before the count, because a rewrite that keeps the count is invisible
      # to a count and is the worse of the two things that can have happened.
      nd=$(prefix_digest "$n")
      # THE GUARD READS THE RECORDED SIDE ALONE. A recorded `short` is a
      # recording that never covered its own count, so nothing can be checked
      # against it and saying so is the only honest report. The CURRENT side
      # is different: a body too short for the recorded count IS the outbox
      # having shrunk, the loudest thing this watcher exists to say, and the
      # first draft of this guard swallowed exactly that by testing both
      # sides. A short `nd` therefore falls through to the mismatch branch,
      # where m < n raises SHRANK as it always did.
      verdict=
      if [ "${dg:-}" = short ]; then
        verdict=corrupt
        echo "CANNOT VERIFY THE OUTBOX HISTORY: the recorded digest never covered its own count of $n, the recording defect the short marker names, so nothing about the delivered entries can be checked against it. Re-seeding at the current head: the append-only check restarts from here, and anything rewritten before now will not be caught."
      elif [ -n "${dg:-}" ] && [ "$nd" != "$dg" ]; then
        # ACCUSE THE HISTORY ONLY ON A RECORD THAT HOLDS AT ITS OWN HEAD. A
        # mismatch here has two explanations and only one is the seat's
        # fault: the branch really was rewritten or rewound, or the record
        # itself is corrupt, a count inflated past the body it described,
        # which a pre-marker recording could write and which fired this
        # alarm on an untouched file. One question the clone can answer
        # separates them: does the recorded digest reproduce at the head the
        # record says it delivered. A record that fails there never
        # described anything, so the file is re-read openly instead of the
        # seat being accused. A record that holds there makes the accusation
        # stick. And a rewound branch whose old head this clone cannot read
        # stays an alarm, since destroying the old head is what a rewind
        # does.
        if [ -n "${last:-}" ] \
           && git rev-parse --verify -q "$last^{commit}" >/dev/null 2>&1 \
           && [ "$(prefix_digest "$n" "$last")" != "$dg" ]; then
          verdict=corrupt
          echo "CANNOT VERIFY THE OUTBOX HISTORY: the recorded digest does not reproduce at $last, the head the record itself says it delivered, so the record is corrupt and convicts nobody. Re-seeding at the current head: the append-only check restarts from here. Read $F whole and reconcile it against your own record."
        elif [ "$m" -lt "$n" ]; then
          verdict=alarm
          notify alarm "the outbox SHRANK from $n entries to $m, and it is append-only"
          echo "OUTBOX SHRANK, $n entries to $m: it is append-only, so it was rewritten or the branch rewound. Read it whole and reconcile."
        else
          verdict=alarm
          notify alarm "the outbox was REWRITTEN under this watcher's record of $n entries"
          echo "OUTBOX REWRITTEN: the first $n entries are no longer the entries this watcher reported. It is append-only, so something rewrote history or force-pushed the branch. Read it whole and reconcile."
        fi
      fi
      if [ -n "$verdict" ]; then
        echo "OUTBOX as it stands now:"; body
        n=$m; dg=$(prefix_digest "$n")
      elif [ "$m" -gt "$n" ]; then
        notify finished "$((m-n)) new outbox $( [ $((m-n)) = 1 ] && echo entry || echo entries )" in
        echo "OUTBOX new entries:"; body | tail -n $((m-n)); n=$m; dg=$(prefix_digest "$n")
      elif [ "$cold" = 0 ]; then
        echo "sub-session pushed $cur (no new outbox entries)"
      fi
      cold=0
      last=$cur; save_state "$last" "$n" b "$dg"
    else
      # SAY THAT NOTHING WAS LOST, since that is the question a reader has
      # at the moment this line appears, and the answer is not obvious
      fail=$((fail+1)); notify failed "a fetch failed after a push was seen, retrying"; echo "fetch failed after a push was seen, will retry. The head is NOT recorded, so the entries are still waiting and nothing is lost."
    fi
  fi
  # SILENCE IS A RESULT TOO. Without this the watcher is mute exactly when a
  # seat has stopped answering, and the master learns it from the user.
  if [ "$DUE" -gt 0 ]; then
    if [ "$n" -gt "${seen:-$n}" ] || [ -z "${seen:-}" ]; then
      seen=$n; quiet=$(date +%s); overdue=0
    fi
    if [ "$overdue" = 0 ] && [ $(( $(date +%s) - quiet )) -ge "$DUE" ]; then
      # state the OBSERVATION and stop there. This watcher cannot see whether
      # anything is outstanding, so "the seat is not answering" was a
      # conclusion it had not established, and it accused two idle seats
      # that owed nothing the first night it ran.
      notify alarm "nothing new in ${DUE}s"
      echo "OVERDUE: nothing new from $NAME in ${DUE}s. This watcher is polling and the remote is answering, so the silence is the seat's own and not a delivery failure. If work is outstanding, check that the seat's watcher is alive, and, before concluding a seat cannot be poked at all, check the APPLICATION for a session or task identifier rather than the prompt the model was given: one platform was written off here as exposing none, and its desktop task listing resolves one. If the seat was stood down, this is expected and DUE=0 is the setting for it. Said once, and not again until the seat speaks."
      overdue=1
    fi
  fi
  nap=$((P + P * fail)); [ "$nap" -gt 600 ] && nap=600
  sleep "$nap"
done
