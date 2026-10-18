#!/bin/sh
# Copyright 2026 Zheng Luo (Davies Luo). Licensed under the Apache License
# 2.0, whose text is the LICENSE file in this package. Keep this notice
# when you copy the script.
#
# Self-test for all seven shipped scripts.
#
# It runs THE SHIPPED SCRIPTS against a throwaway bare repository, so what
# it proves is what you install. Run it after any edit to any of them, and
# on a new platform before trusting them there.
#
#   sh selftest.sh            # from this folder
#
# Needs: sh, git, awk, sed. NOT GNU coreutils: it runs on stock macOS, which
# has no `timeout`. Budget a quarter of an hour and expect more on a loaded
# machine, since almost all of it is waiting for watchers to poll. Nothing has hung. Writes only inside a temporary
# directory it removes on exit, and reaches no remote anybody owns.

# AND IT COSTS A WHOLE RUN TO FORGET THIS ONE. Under `set -e` a foreground
# command that exits non-zero ends the script THERE, so `( ... ) ; rc=$?`
# never reaches the assignment and the case that meant to inspect a status
# instead kills the suite with it. That happened here, at case 55, to the
# assertion added to check exit 78: the run stopped at 78 with no totals line.
# A case that needs a non-zero status either backgrounds the command, which
# every other block in case 55 does, or puts it in a condition context:
#   rc=0; ( ... ) || rc=$?
# The guard at the end catches the death and says nothing here is a pass, so
# the run is never mistaken for green, but the run is still gone.
set -e
# AND THE SUITE NEVER INHERITS A REAL DELIVERY COMMAND. `inject.sh` takes the
# INJECT_CMD branch BEFORE the keyboard one, and the keyboard guard below
# only checks that the fake osascript is first on PATH. An operator running
# this from a shell that exports INJECT_CMD therefore sent every keyboard
# case's payload down their own live transport, and the case still passed.
# Each native fixture sets its own command explicitly, so clearing it here
# costs nothing and cannot reach anybody's seat.
#
# AND THE SAME ARGUMENT COVERS EVERY OTHER DIAL. A shell that had run an
# injector by hand still exports FGLOCK, and the suite then shares a lock file
# with whatever the operator was doing; one that exports P or ACK changes the
# timing the cases were written against. Every case sets what it needs, so
# inheriting any of these can only make the suite report on the shell it was
# started from. Measured: a seat's own FGLOCK, left over from an earlier probe
# in the same shell, decided a case-33 assertion on the run that reported it.
unset INJECT_CMD INJECT_CLICK FGLOCK FGWAIT FGSPAN FGHOLD \
      ACK SETTLE POLL TIMEOUT HOLD \
      P DUE NAG FAST RETRY STABLE ON_CHANGE ACK_BRANCH ACK_BASELINE \
      NOTIFY NOTIFY_ECHO NOTIFY_BACKEND NOTIFY_STATE NOTIFY_TEXT NOTIFY_FLOW \
      ACK_WAIT DELIVER MAXLINES STALE
HERE=$(cd "$(dirname "$0")" && pwd)
[ -f "$HERE/watch-outbox.sh" ] || { echo "run this from the folder holding the watchers"; exit 1; }

T=$(mktemp -d) || exit 1
# AND THE OPERATOR'S OWN GIT CONFIG STAYS OUT OF THIS RUN. Measured here: a
# machine carrying `commit.gpgsign true` in its global config sent every
# throwaway repository this suite creates through a signing service, and one
# 503 from that service killed the run mid-case with no totals line. Nothing
# under test has anything to do with the operator's identity, signing, default
# branch name or aliases, and a suite that answers to them is not the same
# suite on two machines. HOME points at the throwaway tree, so there is no
# ~/.gitconfig to read, and NOSYSTEM drops /etc/gitconfig as well. Every tool
# run from here is git, sh, awk, sed and this package's own scripts, none of
# which reads HOME, and the rehearsal cases push only to bare repositories
# created inside $T, so no credential is wanted either.
HOME=$T; export HOME
GIT_CONFIG_NOSYSTEM=1; export GIT_CONFIG_NOSYSTEM
# AND HOME IS NOT THE ONLY PLACE GIT LOOKS. It also reads
# $XDG_CONFIG_HOME/git/config, which survived the two lines above, and it obeys
# GIT_CONFIG_GLOBAL and the GIT_CONFIG_COUNT injection vars outright. Measured
# by the Codex seat against the first version of this block: an XDG config
# carrying commit.gpgsign and a failing signer stopped this suite before case
# one at status 128, which is the exact failure the block claims to prevent.
XDG_CONFIG_HOME=$T/xdg; export XDG_CONFIG_HOME
unset GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM GIT_CONFIG_COUNT GIT_CONFIG GIT_CONFIG_PARAMETERS 2>/dev/null || true
i=0; while [ "$i" -lt 32 ]; do unset "GIT_CONFIG_KEY_$i" "GIT_CONFIG_VALUE_$i" 2>/dev/null || true; i=$((i + 1)); done
# EVERY KILL IN HERE IS BEST EFFORT for the same reason as in `stop` below:
# this runs from the EXIT trap, where most of the recorded processes are
# already gone, and one non-zero kill would abort the cleanup before `rm`.
cleanup(){ for f in "$T"/master/.git/*_watch_*.pid "$T"/seat/.git/*_watch_*.pid; do
             [ -f "$f" ] && { kill "$(cat "$f" 2>/dev/null)" 2>/dev/null || true; }
           done
           kill $(cat "$T"/*.pid 2>/dev/null) 2>/dev/null || true
           sleep 1; rm -rf "$T"; }
# THE CLEANUP MUST NOT SWALLOW THE STATUS THAT REACHED IT. Written as
# `trap 'cleanup || true' EXIT`, the `|| true` made the trap's last command
# succeed, and the shell then reported THAT as the script's status. So an abort
# under `set -e` exited ZERO. Measured 27 August while adding case 39: an
# injector call returning its deliberate 75 killed the run, the suite printed a
# case heading and stopped, and it reported success. Anything reading only the
# exit code, a hook or a person in a hurry, would have called that a pass with
# a third of the cases never run. The status is captured before the cleanup and
# restored after it, and a run that never reached its totals says so and cannot
# exit zero, because a suite that stops early is not a suite that passed.
reached_totals=0
trap 'st=$?; cleanup || true
      if [ "$reached_totals" = 0 ]; then
        echo
        echo "THE SUITE STOPPED BEFORE ITS TOTALS, at status $st. Cases after the last one printed above never ran, so nothing here is a pass."
        [ "$st" = 0 ] && st=1
      fi
      exit $st' EXIT
trap 'cleanup || true; exit 130' INT TERM
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "  ok   $1"; }
bad()  { fail=$((fail+1)); echo "  FAIL $1"; }
check(){ if grep -q "$2" "$3" 2>/dev/null; then ok "$1"; else bad "$1"; fi; }
# stopping a watcher costs up to one poll interval, since the signal is
# handled when the sleep it is inside returns
stop(){ f="$1"; [ -f "$f" ] || return 0
        q=$(cat "$f" 2>/dev/null); [ -n "$q" ] || { rm -f "$f"; return 0; }
        # BEST EFFORT, and this is not defensive style but a measured repair.
        # OBSERVED, in an `sh -x` trace of a full run: case 34 stops a watcher
        # whose pid is stale, the trace shows `kill <pid>` and then `cleanup`
        # on the very next line, and cases 35 and 36 never run and no summary
        # is printed. What the guard prevents is therefore certain. WHY an
        # unguarded kill ends the script there is NOT established: the same
        # construct in isolation, at top level and inside a function, survives
        # `set -e` here. Reused pids and signalling something in the suite's
        # own tree are both open explanations. The guard is right either way,
        # and a partial run that looks green is worse than a red one.
        kill "$q" 2>/dev/null || true
        i=0; while kill -0 "$q" 2>/dev/null && [ "$i" -lt 40 ]; do sleep 1; i=$((i+1)); done
        kill -9 "$q" 2>/dev/null || true   # already gone is the normal case now
        rm -f "$f"; return 0; }
absent(){ if grep -q "$2" "$3" 2>/dev/null; then bad "$1"; else ok "$1"; fi; }
# A COMMAND THAT MAY LEGITIMATELY FAIL NEEDS `|| true`, AND THIS SUITE HAS
# PAID FOR IT THREE TIMES IN ONE NIGHT. It runs under `set -e`, which is
# right, but that means any bare command whose failure is ORDINARY takes the
# whole run with it. A `kill` on a process that has already exited ended a run
# after case 34 with no summary. A `grep` finding nothing in one file of a loop
# silently truncated the loop, so a check reported six dials as undefined that
# were defined two files later. Neither failure looked like a failure: one
# produced a partial run and the other produced a confident wrong answer. When
# adding a case, ask of every command whether failing is a NORMAL outcome, and
# guard it if it is.
#
# count occurrences without tripping set -e. `grep -c` exits 1 on zero
# matches, so the usual `|| echo 0` prints the count AND a zero, giving the
# two-line string "0\n0" where a number was wanted. A pipeline takes its
# exit from the last stage, so this one always succeeds and always yields
# one integer.
count(){ grep -o "$1" "$2" 2>/dev/null | wc -l | tr -d ' '; }
# macOS ships no GNU `timeout`, and a suite that needs coreutils fails on the
# platform half its readers are on. Bound a command the portable way instead:
# run it in the background and kill it if it outlives the bound. Every use
# below is a SAFETY NET around a command that should exit on its own, so
# reaching the bound already means the case failed.
bounded(){ s=$1; shift
           sh -c "$*" > "$T/bounded.out" 2>&1 &
           bp=$!
           i=0
           while kill -0 "$bp" 2>/dev/null && [ "$i" -lt "$s" ]; do sleep 1; i=$((i+1)); done
           if kill -0 "$bp" 2>/dev/null; then
             kill -9 "$bp" 2>/dev/null || true
             stop "$T/master/.git/outbox_watch_a.pid"
           fi
           # `wait` returns the CHILD'S exit status, and every use here bounds a
           # command that is SUPPOSED to fail, so without `|| true` this shell's
           # errexit kills the function before it prints what the child said.
           wait "$bp" 2>/dev/null || true
           cat "$T/bounded.out"; }

# --- the suite runs the SHIPPED scripts, so what it proves is what you
# --- install: check both are here and parse before anything else --------
# ALL SEVEN, not the two the suite started life with. A syntax error in the
# injector used to surface as a puzzling failure deep inside case 25, twenty
# minutes in, instead of as one line before anything ran. `master-check` was
# left out of this loop when it was added, so the NEWEST script was the one
# nothing parsed, which is the way round that costs the most.
for f in watch-inbox watch-outbox inject notify supervise master-check selftest; do
  [ -f "$HERE/$f.sh" ] || { echo "$f.sh is missing from this folder"; exit 1; }
  sh -n "$HERE/$f.sh" || { echo "$f.sh does not parse"; exit 1; }
done
# the suite runs the SHIPPED scripts, so what it proves is what you install
# hold the PATHS, not whole command lines: a command line expanded unquoted
# splits on the spaces in an installation path, and a package copied into
# "~/My Projects/sub-session" then fails every case before the first assertion
INSH="$HERE/watch-inbox.sh"
OUTSH="$HERE/watch-outbox.sh"
# WHAT THIS IS, SAID EXACTLY, because a suite that overstates itself is the
# same failure as a turn that says it is done. Seven scripts PARSE here and all
# seven are EXERCISED. master-check.sh was left out for a long time because it
# pushes rehearsal refs to whatever origin the tree it runs in happens to have,
# and that must never be a remote anybody owns. Case 49 drives it twice with
# that danger handled rather than avoided: once from a clone of a throwaway bare
# repository the suite creates, and once from a tree whose origin is a path with
# no repository on it at all.
# AND GREEN MEANS THE ENCODED SCENARIOS PASSED. It is not a certificate that
# the protocol was followed. No assertion here can show that an agent read
# every Open instruction in order, kept to its lane, pushed only its own
# branch, or did the work at all: the nonce cases pass against a seat that
# echoes a token and does nothing. Those properties close through the
# committed [done: ID] evidence, the acknowledgement gate, and a person
# reading the outbox. Named by the Codex seat, which was asked what a green
# run cannot establish rather than for more defects.
echo "exercising all seven shipped scripts, all seven of which parse"

# --- a bare remote, a master clone and a seat clone --------------------
# THE IDENTITY IS PER REPOSITORY AND NEVER EXPORTED. This used to export
# GIT_AUTHOR_* and GIT_COMMITTER_*, and a live seat paid for it: the variables
# survived in the shell that ran the suite and the NEXT real commit went out
# authored `selftest <selftest@example.invalid>`, on a repository whose first
# non-negotiable rule is who its commits are authored by. A suite must not be
# able to change the identity of work done after it. Configuring each throwaway
# clone instead cannot leak, because there is nothing in the environment to
# leak. `identify` is called on every repository this suite creates.
identify(){ git -C "$1" config user.name selftest
            git -C "$1" config user.email selftest@example.invalid; }
# and if a caller's environment already carries an identity, it would override
# the per-repository config, so it is cleared for this process only
unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL
cd "$T"
git init -q --bare origin.git
git clone -q origin.git master 2>/dev/null
identify "$T/master"
cd "$T/master"; git checkout -qb integration; mkdir -p collab
printf '## Open instructions\n' > collab/INBOX_a.md; printf 'x\n' > f.txt
git add -A; git commit -qm init; git push -q -u origin integration

# THE INJECTOR'S APPLESCRIPT IS AN UNQUOTED HEREDOC, so the shell expands the
# body before osascript ever sees it, and that is deliberate: the message id and
# the window title are interpolated. It also means a backtick or a $( ) anywhere
# in that body, including inside an AppleScript comment, is RUN BY THE SHELL. It
# happened: a comment reading "bounded by a timeout because `entire contents`
# walks the whole tree" made every injection print
# "inject.sh: line 467: entire: command not found", and the next such slip could
# execute something instead of failing loudly.
echo "0. the injector's AppleScript body carries nothing the shell would execute"
body=$(awk '/osascript <<OSA/{f=1;next} /^OSA$/{f=0} f' "$HERE/inject.sh")
if [ -z "$body" ]; then
  bad "could not read the AppleScript body, so this assertion proves nothing"
elif printf '%s' "$body" | grep -q '[`]'; then
  bad "a backtick in the AppleScript body: the shell will run it"
elif printf '%s' "$body" | grep -q '[$](' ; then
  bad "a command substitution in the AppleScript body: the shell will run it"
else
  ok "no backtick and no command substitution in the ${#body} byte body"
fi

echo "1. the master arms its outbox watcher before the seat branch exists"
( cd "$T/master" && P=2 sh "$OUTSH" a sub/a collab > "$T/ob.log" 2>&1 & echo $! > "$T/ob.pid" )
sleep 9
check "announces that it is waiting for the branch" "does not exist on the remote yet" "$T/ob.log"

check "announces that it armed, with the head and the poll interval" "outbox watcher ARMED" "$T/ob.log"
# A DIAL THAT DEFAULTS TO EMPTY GOES WRONG SILENTLY. A watcher armed without
# NOTIFY watches, logs and alarms into a terminal nobody has open, and one live
# seat ran that way for days while the master read its silence as a quiet lane.
check "and says outright that no notifier is wired, so its silence cannot be mistaken for a quiet lane" \
      "NO NOTIFIER IS WIRED" "$T/ob.log"
# A WATCHER IS A SHELL THAT READ ITS SCRIPT AT START, so an updated file on disk
# changes nothing until the process is restarted, and a clone holding an inward
# merge may not even have the updated file. Corrections were once committed and
# pushed while the machine showing the notifications carried on with the old
# ones, and nobody could tell by looking. The arm line now carries a fingerprint
# of the running script, and it has to MOVE when the script does, or it is
# decoration rather than evidence.
check "and says which version of itself it is running" "running script [0-9a-f]" "$T/ob.log"
fp_before=$(sed -n 's/.*running script \([0-9a-f]*\).*/\1/p' "$T/ob.log" | head -1)
cp "$HERE/watch-outbox.sh" "$T/wo_edited.sh"
printf '\n# a byte that changes the file\n' >> "$T/wo_edited.sh"
rm -f "$T/master/.git/outbox_watch_b"
( cd "$T/master" && P=2 DUE=0 sh "$T/wo_edited.sh" b sub/b collab > "$T/ob_fp.log" 2>&1 & echo $! > "$T/obfp.pid" )
sleep 4
stop "$T/master/.git/outbox_watch_b.pid"
fp_after=$(sed -n 's/.*running script \([0-9a-f]*\).*/\1/p' "$T/ob_fp.log" | head -1)
if [ -z "$fp_before" ] || [ -z "$fp_after" ]; then
  bad "no fingerprint printed, so this assertion cannot discriminate"
elif [ "$fp_before" = "$fp_after" ]; then
  bad "the fingerprint did not move when the script did, so it proves nothing"
else ok "and the fingerprint moves when the script does, so a stale process shows"; fi

echo "2. the seat creates its branch and writes its first outbox lines"
cd "$T"; git clone -q origin.git seat 2>/dev/null
identify "$T/seat"
cd "$T/seat"; git fetch -q origin '+integration:refs/remotes/origin/integration'
git checkout -qb sub/a origin/integration; mkdir -p collab
printf 'start a-1\n[done: a-1] watermark deadbee\n' > collab/OUTBOX_a.md
git add -A; git commit -qm ob; git push -q -u origin sub/a
t0=$(date +%s); while ! grep -q 'done: a-1' "$T/ob.log" 2>/dev/null; do
  sleep 1; if [ $(( $(date +%s) - t0 )) -gt 40 ]; then break; fi; done
d=$(( $(date +%s) - t0 ))
if [ "$d" -le 15 ]; then ok "picked the branch up in ${d}s without backing off"
else bad "took ${d}s, the watcher backed off while waiting for the branch"; fi
check "delivered both new lines" "start a-1" "$T/ob.log"
check "calls a first sighting an appearance" "has APPEARED" "$T/ob.log"
absent "does not call a branch it never saw one that came BACK" \
       "is BACK" "$T/ob.log"

echo "3. the seat pushes work that adds no outbox line"
cd "$T/seat"; echo code > w.py; git add -A; git commit -qm work; git push -q
sleep 9
check "reports the push and says there was nothing new" "no new outbox entries" "$T/ob.log"

echo "4. the outbox watcher restarts across a push it was down for"
stop "$T/master/.git/outbox_watch_a.pid"
cd "$T/seat"; printf 'FINDING-1 HIGH missed while the watcher was down\n' >> collab/OUTBOX_a.md
git add -A; git commit -qm f1; git push -q
( cd "$T/master" && P=2 sh "$OUTSH" a sub/a collab > "$T/ob2.log" 2>&1 & echo $! > "$T/ob2.pid" )
sleep 13
absent "does not announce a cold start, the state file survived" "cold start" "$T/ob2.log"
check "delivers the entry pushed while it was down" "FINDING-1" "$T/ob2.log"
stop "$T/master/.git/outbox_watch_a.pid"

echo "5. the outbox is rewritten, which the protocol forbids"
cd "$T/seat"; printf 'only line\n' > collab/OUTBOX_a.md
git add -A; git commit -qm rewrite; git push -q
( cd "$T/master" && P=2 sh "$OUTSH" a sub/a collab > "$T/ob3.log" 2>&1 & echo $! > "$T/ob3.pid" )
sleep 13
check "says loudly that the outbox shrank" "OUTBOX SHRANK" "$T/ob3.log"
stop "$T/master/.git/outbox_watch_a.pid"

echo "6. the seat watches its inbox"
( cd "$T/seat" && P=2 sh "$INSH" a integration collab > "$T/in.log" 2>&1 & echo $! > "$T/in.pid" )
sleep 9
check "announces its cold start" "cold start" "$T/in.log"
cd "$T/master"; printf '## Open instructions\n\n### a-1\nDo the thing.\n' > collab/INBOX_a.md
git add -A; git commit -qm a-1; git push -q
t0=$(date +%s); while ! grep -q 'Do the thing' "$T/in.log" 2>/dev/null; do
  sleep 1; if [ $(( $(date +%s) - t0 )) -gt 40 ]; then break; fi; done
d=$(( $(date +%s) - t0 ))
if [ "$d" -le 15 ]; then ok "delivered the instruction in ${d}s"
else bad "took ${d}s to deliver the instruction"; fi

echo "7. the master pushes something that is not the inbox"
# let the previous case's output finish landing before measuring anything:
# a line count taken mid-write makes this case fail for a reason that has
# nothing to do with what it tests, which it did once on an independent run
q=0; prev=-1
while [ "$q" != "$prev" ]; do prev=$q; sleep 2; q=$(wc -l < "$T/in.log"); done
# and count the ANNOUNCEMENT, not the lines: trailing output from an earlier
# case adds lines without ever claiming the inbox changed
before=$(count "INBOX CHANGED" "$T/in.log")
cd "$T/master"; echo noise >> f.txt; git add -A; git commit -qm noise; git push -q
sleep 8
after=$(count "INBOX CHANGED" "$T/in.log")
if [ "$before" = "$after" ]; then ok "stays quiet, the inbox did not change"
else bad "reported an unrelated push as an inbox change"; fi
stop "$T/seat/.git/inbox_watch_a.pid"

echo "8. the inbox watcher restarts"
cd "$T/master"; printf '## Open instructions\n\n### a-1\nDo the thing.\n\n### a-2\nSecond.\n' > collab/INBOX_a.md
git add -A; git commit -qm a-2; git push -q
( cd "$T/seat" && P=2 sh "$INSH" a integration collab > "$T/in2.log" 2>&1 & echo $! > "$T/in2.pid" )
sleep 13
absent "does not announce a cold start" "cold start" "$T/in2.log"
check "delivers the instruction added while it was down" "Second" "$T/in2.log"
stop "$T/seat/.git/inbox_watch_a.pid"

echo "9. an entry written without its trailing newline"
cd "$T/seat"; printf 'FINDING-9 HIGH no newline after me' >> collab/OUTBOX_a.md
git add -A; git commit -qm nonl; git push -q
( cd "$T/master" && P=2 sh "$OUTSH" a sub/a collab > "$T/ob4.log" 2>&1 & echo $! > "$T/ob4.pid" )
sleep 13
check "is still delivered, awk counts records and not newlines" "FINDING-9" "$T/ob4.log"
stop "$T/master/.git/outbox_watch_a.pid"

echo "10. the remote fails between seeing a change, then recovers"
mkdir -p "$T/shim"
cat > "$T/shim/git" <<'SHIM'
#!/bin/sh
for a in "$@"; do
  if [ "$a" = fetch ]; then echo "fatal: unable to access remote (simulated)" >&2; exit 128; fi
done
exec /usr/bin/git "$@"
SHIM
chmod +x "$T/shim/git"
# case 9 deliberately left its line unterminated, so this entry opens with a
# newline of its own, otherwise it fuses onto that line and is not a new record
cd "$T/seat"; printf '\nFINDING-10 HIGH must survive a failed fetch\n' >> collab/OUTBOX_a.md
git add -A; git commit -qm f10; git push -q
( cd "$T/master" && PATH="$T/shim:$PATH" P=5 sh "$OUTSH" a sub/a collab > "$T/ob5.log" 2>&1 & echo $! > "$T/ob5.pid" )
sleep 13
check "says the fetch failed instead of claiming there was nothing" "fetch failed" "$T/ob5.log"
absent "does not claim the push carried nothing" "no new outbox entries" "$T/ob5.log"
absent "and has not delivered it yet" "FINDING-10" "$T/ob5.log"
# the same watcher must recover on its own once the remote comes back
rm -f "$T/shim/git"
t0=$(date +%s); while ! grep -q 'FINDING-10' "$T/ob5.log" 2>/dev/null; do
  sleep 2; if [ $(( $(date +%s) - t0 )) -gt 90 ]; then break; fi; done
check "delivers the entry once the remote recovers, without being restarted" "FINDING-10" "$T/ob5.log"
stop "$T/master/.git/outbox_watch_a.pid"

echo "11. a git too old to know --absolute-git-dir"
mkdir -p "$T/shim"
cat > "$T/shim/git" <<'SHIM'
#!/bin/sh
if [ "$1" = rev-parse ] && [ "$2" = --absolute-git-dir ]; then echo "--absolute-git-dir"; exit 0; fi
exec /usr/bin/git "$@"
SHIM
chmod +x "$T/shim/git"
# bounded guards the suite: a watcher that wrongly starts here never returns.
# Export the shim onto PATH around the call rather than inlining it into the
# command string, where the quoting that keeps $PATH unexpanded also keeps it
# from ever expanding.
oldpath=$PATH; PATH="$T/shim:$PATH"; export PATH
out=$(bounded 8 "cd '$T/master' && P=5 sh '$OUTSH' a sub/a collab") || true
PATH=$oldpath; export PATH
rm -f "$T/master/.git/outbox_watch_a.pid"
if printf '%s' "$out" | grep -q "needs git 2.13 or newer"; then ok "refuses to start"
else bad "started anyway on an old git: $out"; fi
rm -f "$T/shim/git"

echo "12. a poll interval that is not a whole number of seconds"
# no timeout needed now that a watcher stops when told: start it, read its
# first line, stop it the same way every other case does
( cd "$T/master" && P=20s sh "$OUTSH" a sub/a collab > "$T/ob8.log" 2>&1 & echo $! > "$T/ob8.pid" )
sleep 6
check "falls back to the default instead of dying" "P must be whole seconds" "$T/ob8.log"
stop "$T/master/.git/outbox_watch_a.pid"

echo "13. a second watcher on the same branch in the same clone"
( cd "$T/master" && P=2 sh "$OUTSH" a sub/a collab > "$T/ob7.log" 2>&1 & echo $! > "$T/ob7.pid" )
sleep 7
out=$(bounded 8 "cd '$T/master' && P=5 sh '$OUTSH' a sub/a collab") || true
if printf '%s' "$out" | grep -q "already running"; then ok "refuses, one watcher per branch per clone"
else bad "a second watcher started: $out"; fi
stop "$T/master/.git/outbox_watch_a.pid"

echo "14. the seat branch is deleted from the remote under a live watcher"
rm -f "$T/master/.git/outbox_watch_a"      # fresh state, then seed it warm
( cd "$T/master" && P=2 sh "$OUTSH" a sub/a collab > "$T/ob9.log" 2>&1 & echo $! > "$T/ob9.pid" )
sleep 6
( cd "$T/master" && git push -q origin --delete sub/a )
t0=$(date +%s)
while ! grep -q "is GONE" "$T/ob9.log" 2>/dev/null; do
  sleep 2; if [ $(( $(date +%s) - t0 )) -gt 40 ]; then break; fi; done
check "says the branch is gone, not that it never existed" "is GONE" "$T/ob9.log"
absent "does not call a deleted branch one that does not exist yet" \
       "does not exist on the remote yet" "$T/ob9.log"
stop "$T/master/.git/outbox_watch_a.pid"

echo "15. ON_CHANGE turns a printing watcher into one that starts a turn"
rm -f "$T/seat/.git/inbox_watch_a" "$T/turn_ran"
( cd "$T/seat" && P=2 ON_CHANGE="echo ran > '$T/turn_ran'" sh "$INSH" a integration collab > "$T/in9.log" 2>&1 &
  echo $! > "$T/in9.pid" )
sleep 6
cd "$T/master"; printf -- '\n### a-9\nStart a turn.\n' >> collab/INBOX_a.md
git add -A; git commit -qm a-9; git push -q
t0=$(date +%s); while [ ! -f "$T/turn_ran" ]; do
  sleep 2; if [ $(( $(date +%s) - t0 )) -gt 45 ]; then break; fi; done
if [ -f "$T/turn_ran" ]; then ok "ran the command the tool would use to start a turn"
else bad "never ran ON_CHANGE"; fi
check "names the command it started, so a wrong one is visible" \
      "starting a turn" "$T/in9.log"
stop "$T/seat/.git/inbox_watch_a.pid"

echo "16. the branch goes, comes back at the SAME commit, and goes again"
rm -f "$T/master/.git/outbox_watch_a"
sha=$(cd "$T/seat" && git rev-parse sub/a)
# case 14 left the branch deleted, so put it back before deleting it again
( cd "$T/seat" && git push -q origin "$sha:refs/heads/sub/a" 2>/dev/null ) || true
sleep 1
( cd "$T/master" && P=2 sh "$OUTSH" a sub/a collab > "$T/ob10.log" 2>&1 & echo $! > "$T/ob10.pid" )
sleep 6
( cd "$T/seat" && git push -q origin --delete sub/a )
sleep 8
( cd "$T/seat" && git push -q origin "$sha:refs/heads/sub/a" )
sleep 8
( cd "$T/seat" && git push -q origin --delete sub/a )
sleep 10
g=$(count "is GONE" "$T/ob10.log")
b=$(count "is BACK" "$T/ob10.log")
if [ "$g" = 2 ]; then ok "alarms on BOTH disappearances, not just the first"
else bad "announced $g disappearances of two"; fi
if [ "$b" = 1 ]; then ok "announces the return, though the head never moved"
else bad "announced $b returns of one"; fi
stop "$T/master/.git/outbox_watch_a.pid"
( cd "$T/seat" && git push -q origin "$sha:refs/heads/sub/a" )

echo "17. a turn that fails is retried, eased off, and RECOVERS by itself"
# the command fails while a flag file is absent and works once it appears,
# which is what an exhausted allowance or a downed host looks like from
# here: the bus is healthy throughout and the command is merely unavailable
# THE COLD START NOW DELIVERS, so this case has to let it finish first. A
# watcher with ON_CHANGE no longer records the inbox it finds as handled, which
# is the fix for an instruction pushed before a watcher armed being eaten by
# the arming. Here that means the first poll runs ON_CHANGE against the
# CURRENT inbox, and if that attempt failed it would spend the failure budget
# this case needs for its own change. So the flag exists while the watcher
# arms, and is removed once the cold start has been handled.
rm -f "$T/seat/.git/inbox_watch_a"
touch "$T/ok_now"
( cd "$T/seat" && P=2 FAST=2 RETRY=6 ON_CHANGE="test -f '$T/ok_now'" \
  sh "$INSH" a integration collab > "$T/in10.log" 2>&1 & echo $! > "$T/in10.pid" )
t0=$(date +%s); while ! grep -q "the turn finished" "$T/in10.log" 2>/dev/null; do
  sleep 1; if [ $(( $(date +%s) - t0 )) -gt 30 ]; then break; fi; done
check "delivers the inbox it found at a cold start rather than eating it" \
      "the turn finished" "$T/in10.log"
rm -f "$T/ok_now"
cd "$T/master"; printf -- '\n### a-10\nThis turn fails until the flag appears.\n' >> collab/INBOX_a.md
git add -A; git commit -qm a-10; git push -q
t0=$(date +%s); while ! grep -q "SLOWING DOWN" "$T/in10.log" 2>/dev/null; do
  sleep 2; if [ $(( $(date +%s) - t0 )) -gt 45 ]; then break; fi; done
check "says the change is not recorded as handled" "NOT recorded as handled" "$T/in10.log"
check "eases off instead of abandoning the change" "SLOWING DOWN" "$T/in10.log"
absent "and never claims it gave up on it" "GIVING UP" "$T/in10.log"
# the announcement is made once, not on every attempt
# TWO, AND EXACTLY TWO. The cold start delivers what it finds, which is one
# announcement, and this case's own change is the second. What the assertion
# guards is unchanged: the retry ladder must not re-announce on every attempt,
# and at FAST=2 with RETRY=6 over the wait above it would reach five or six if
# it did. Counting one here would only mean the cold start had gone back to
# eating the inbox it found.
if [ "$(count 'INBOX CHANGED' "$T/in10.log")" = 2 ]; then
  ok "announces each change once rather than on every attempt"
else bad "announced $(count 'INBOX CHANGED' "$T/in10.log") changes where the cold start and this case make two"; fi
touch "$T/ok_now"                       # whatever was unavailable comes back
t0=$(date +%s); while ! grep -q "RECOVERED" "$T/in10.log" 2>/dev/null; do
  sleep 2; if [ $(( $(date +%s) - t0 )) -gt 45 ]; then break; fi; done
check "picks it up by itself once the command works again" "RECOVERED" "$T/in10.log"
check "and finishes the turn it had been retrying" "the turn finished" "$T/in10.log"
stop "$T/seat/.git/inbox_watch_a.pid"

# AND A SEAT NOBODY CAN REACH KEEPS SAYING SO. Easing off was right and going
# quiet was not: the slowing line and its notification fired once, at the
# attempt where the ladder changed, and every failure after that printed
# nothing and raised nothing. A live watcher whose injector had lost its
# Accessibility grant said one sentence and then retried in silence for hours
# while the person waiting for that seat had no signal. The reminder must
# repeat, must carry how long and how many attempts, and must reach the
# notifier as an alarm, since that is the state reserved for needing a person.
rm -f "$T/seat/.git/inbox_watch_a" "$T/nag.log" "$T/nagnote.log"
# THE NOTIFICATION IS RECORDED TO A FILE, because the watcher sends its
# notifier's output to /dev/null on purpose: a notifier that prints must never
# be able to fill the watcher's log. So NOTIFY_ECHO cannot be observed from
# there, and an assertion that reads the watcher's log for it fails against
# correct code. This is the same recording fixture cases 23 and 25 use.
( cd "$T/seat" && P=1 FAST=1 RETRY=2 NAG=4 \
  NOTIFY="printf '%s\n' \"\$NOTIFY_STATE\" >> '$T/nagnote.log'" \
  ON_CHANGE="false" \
  sh "$INSH" a integration collab > "$T/nag.log" 2>&1 & echo $! > "$T/nag.pid" )
sleep 4
cd "$T/master"; printf -- '\n### a-10b\nThis turn can never succeed.\n' >> collab/INBOX_a.md
git add -A; git commit -qm a-10b; git push -q
t0=$(date +%s); while [ "$(count 'STILL UNDELIVERED' "$T/nag.log")" -lt 2 ]; do
  sleep 2; if [ $(( $(date +%s) - t0 )) -gt 40 ]; then break; fi; done
stop "$T/nag.pid"; stop "$T/seat/.git/inbox_watch_a.pid"
n=$(count 'STILL UNDELIVERED' "$T/nag.log")
if [ "${n:-0}" -ge 2 ]; then
  ok "a change nobody can deliver is reported again and again, $n times here"
else
  bad "an undelivered change was reported $n times, so the watcher went quiet on it"
fi
check "and the reminder says how long it has been stuck" "attempts:" "$T/nag.log"
check "and names the seat that is not being reached" "is not being reached" "$T/nag.log"
absent "and still never claims it gave up" "GIVING UP" "$T/nag.log"
if [ "$(count '^alarm$' "$T/nagnote.log")" -ge 2 ]; then
  ok "and it reaches the notifier as an alarm every time, the state reserved for needing a person"
else
  bad "the reminder raised $(count '^alarm$' "$T/nagnote.log") alarms, so a phone stops hearing about a seat that is unreachable"
fi

echo "18. a turn is already running, so the watcher must not start a second"
rm -f "$T/seat/.git/inbox_watch_a" "$T/second_turn"
mkdir -p "$T/seat/.git/turn_a.lock"          # stand in for a live turn
( cd "$T/seat" && P=2 ON_CHANGE="echo ran > '$T/second_turn'" \
  sh "$INSH" a integration collab > "$T/in11.log" 2>&1 & echo $! > "$T/in11.pid" )
sleep 5
cd "$T/master"; printf -- '\n### a-11\nDo not run twice.\n' >> collab/INBOX_a.md
git add -A; git commit -qm a-11; git push -q
t0=$(date +%s); while ! grep -q "already running" "$T/in11.log" 2>/dev/null; do
  sleep 2; if [ $(( $(date +%s) - t0 )) -gt 40 ]; then break; fi; done
check "refuses while another turn holds the lock" "already running" "$T/in11.log"
if [ -f "$T/second_turn" ]; then bad "started a second turn anyway"
else ok "did not start a second turn"; fi

# AND IT SAYS SO ONCE, NOT ON EVERY POLL. Measured: an operator asked for the
# last forty lines of a watcher's log to diagnose a failed delivery and got
# forty identical copies of this one paragraph, at a twenty second poll inside
# fifteen minutes, so the line that said what had gone wrong had scrolled away.
# LET IT POLL SEVERAL MORE TIMES FIRST. The loop above breaks on the FIRST
# sighting, so asserting a count of one there would pass on the old code too,
# which printed on every poll and simply had not printed twice yet. At P=2 this
# is at least four more polls.
sleep 9
if [ "$(count 'is already running for a and holds' "$T/in11.log")" = 1 ]; then
  ok "and says the lock is held once rather than on every poll"
else
  bad "said the lock was held $(count 'is already running for a and holds' "$T/in11.log") times over five polls, which is the noise that hides everything else"
fi
stop "$T/seat/.git/inbox_watch_a.pid"
rmdir "$T/seat/.git/turn_a.lock" 2>/dev/null || true

echo "19. DUE turns silence into an event, once, and re-arms when the seat speaks"
rm -f "$T/master/.git/outbox_watch_a"
( cd "$T/master" && P=2 DUE=6 sh "$OUTSH" a sub/a collab > "$T/ob11.log" 2>&1 &
  echo $! > "$T/ob11.pid" )
t0=$(date +%s); while [ "$(count OVERDUE "$T/ob11.log")" -lt 1 ]; do
  sleep 1; if [ $(( $(date +%s) - t0 )) -gt 40 ]; then break; fi; done
check "says so when a seat has been silent for DUE seconds" "OVERDUE" "$T/ob11.log"
n1=$(count OVERDUE "$T/ob11.log"); sleep 10; n2=$(count OVERDUE "$T/ob11.log")
if [ "$n1" = "$n2" ]; then ok "says it ONCE rather than on every poll"
else bad "repeated the alarm, $n1 then $n2"; fi
cd "$T/seat"; printf 'FINDING-19 the seat speaks again\n' >> collab/OUTBOX_a.md
git add -A; git commit -qm a19; git push -q origin HEAD:refs/heads/sub/a
t0=$(date +%s); while ! grep -q "FINDING-19" "$T/ob11.log" 2>/dev/null; do
  sleep 1; if [ $(( $(date +%s) - t0 )) -gt 40 ]; then break; fi; done
check "delivers the entry that broke the silence" "FINDING-19" "$T/ob11.log"
t0=$(date +%s); while [ "$(count OVERDUE "$T/ob11.log")" -le "$n2" ]; do
  sleep 1; if [ $(( $(date +%s) - t0 )) -gt 40 ]; then break; fi; done
if [ "$(count OVERDUE "$T/ob11.log")" -gt "$n2" ]; then
  ok "arms again, so a SECOND silence is not swallowed"
else bad "never alarmed again after the seat spoke"; fi
stop "$T/master/.git/outbox_watch_a.pid"

echo "20. a DUE that is not a whole number of seconds"
( cd "$T/master" && P=2 DUE=soon sh "$OUTSH" a sub/a collab > "$T/ob12.log" 2>&1 &
  echo $! > "$T/ob12.pid" )
sleep 5
check "says so and carries on rather than dying" "DUE must be whole seconds" "$T/ob12.log"
absent "does not then promise an alarm it will never raise" \
       "will say so if nothing arrives" "$T/ob12.log"
stop "$T/master/.git/outbox_watch_a.pid"

echo "21. the shipped pointers have not drifted from the protocol"
# THE POINTER LAYOUT'S ONE PROMISE is that there is exactly one copy of the
# protocol, so nothing can go stale against anything else. The front matter
# is the exception it cannot keep by construction: each pointer carries its
# own copy, and a tool lists the skill by what the POINTER says. Edit the
# description in SKILL.md and the pointers silently describe the old one.
# That happened within an hour of the description being edited.
R=$(cd "$HERE/.." && pwd)
fm(){ awk 'NR==1&&$0!="---"{exit} NR==1{next} /^---$/{exit} {print}' "$1"; }
drift=0; found=0
for q in "$R/.agents/skills/sub-session/SKILL.md" "$R/.claude/skills/sub-session/SKILL.md"; do
  [ -f "$q" ] || continue
  found=$((found+1))
  [ "$(fm "$q")" = "$(fm "$R/SKILL.md")" ] || { drift=$((drift+1)); echo "     drifted: $q"; }
done
if [ "$found" = 0 ]; then ok "no shipped pointers in this install, nothing to drift"
elif [ "$drift" = 0 ]; then ok "every pointer's front matter matches SKILL.md, all $found of them"
else bad "$drift of $found pointers describe a protocol that has moved on"; fi
miss=0
for q in "$R/.agents/skills/sub-session/SKILL.md" "$R/.claude/skills/sub-session/SKILL.md"; do
  [ -f "$q" ] || continue
  grep -q '\.\./\.\./\.\./SKILL\.md' "$q" || { miss=$((miss+1)); echo "     no path to the canonical file: $q"; }
done
if [ "$miss" = 0 ]; then ok "and each one names ../../../SKILL.md, the file it stands for"
else bad "$miss pointers do not name the file they point at"; fi

echo "22. a lock whose owner is gone, and one whose owner is alive"
# THE THIRD DEFECT IN THIS AREA, and the one that actually cost an audit:
# a turn killed while holding the lock left the directory behind, and the
# watcher then refused to start anything for ever while the refusal
# message asked a human who was not watching to delete it by hand.
rm -f "$T/seat/.git/inbox_watch_a" "$T/dead_ran" "$T/live_ran"
rm -rf "$T/seat/.git/turn_a.lock"
mkdir -p "$T/seat/.git/turn_a.lock"
echo 999999 > "$T/seat/.git/turn_a.lock/pid"     # an owner that cannot exist
( cd "$T/seat" && P=2 ON_CHANGE="echo ran > '$T/dead_ran'" \
  sh "$INSH" a integration collab > "$T/in12.log" 2>&1 & echo $! > "$T/in12.pid" )
sleep 5
cd "$T/master"; printf -- '\n### a-12\nThe holder of that lock is gone.\n' >> collab/INBOX_a.md
git add -A; git commit -qm a-12; git push -q
t0=$(date +%s); while [ ! -f "$T/dead_ran" ]; do
  sleep 2; if [ $(( $(date +%s) - t0 )) -gt 40 ]; then break; fi; done
check "takes over a lock whose recorded owner is gone" "has taken it over" "$T/in12.log"
if [ -f "$T/dead_ran" ]; then ok "and runs the turn that lock was blocking"
else bad "never ran the turn, the stale lock still blocks it"; fi
stop "$T/seat/.git/inbox_watch_a.pid"
rm -rf "$T/seat/.git/turn_a.lock"

# the other half: a lock whose owner IS alive must still be refused, or
# reclaiming it would run two turns at once, which is what it prevents
rm -f "$T/seat/.git/inbox_watch_a"
mkdir -p "$T/seat/.git/turn_a.lock"; echo $$ > "$T/seat/.git/turn_a.lock/pid"
( cd "$T/seat" && P=2 ON_CHANGE="echo ran > '$T/live_ran'" \
  sh "$INSH" a integration collab > "$T/in13.log" 2>&1 & echo $! > "$T/in13.pid" )
sleep 5
cd "$T/master"; printf -- '\n### a-13\nThat holder is alive.\n' >> collab/INBOX_a.md
git add -A; git commit -qm a-13; git push -q
t0=$(date +%s); while ! grep -q "already running" "$T/in13.log" 2>/dev/null; do
  sleep 2; if [ $(( $(date +%s) - t0 )) -gt 40 ]; then break; fi; done
check "still refuses a lock whose owner is alive" "already running" "$T/in13.log"
if [ -f "$T/live_ran" ]; then bad "stole a live lock and ran a second turn"
else ok "and does not start a second turn beside it"; fi
stop "$T/seat/.git/inbox_watch_a.pid"
rm -rf "$T/seat/.git/turn_a.lock"

echo "23. NOTIFY gives a person something to look at, and cannot break the bus"
# A HEADLESS TURN MOVES NO WINDOW. Writing that down as a platform fact is
# not the same as fixing it, and a seat that is working looks exactly like
# a seat that is dead until something says otherwise.
rm -f "$T/seat/.git/inbox_watch_a" "$T/states" "$T/n_ran"
( cd "$T/seat" && P=2 NOTIFY="echo \$NOTIFY_STATE\|\$NOTIFY_FLOW >> '$T/states'" \
  ON_CHANGE="echo ran > '$T/n_ran'" \
  sh "$INSH" a integration collab > "$T/in14.log" 2>&1 & echo $! > "$T/in14.pid" )
sleep 4
check "fires as soon as the watcher arms" "armed" "$T/states"
check "and the inbox arm line names the notifier too" \
      "notifications are ON through" "$T/in14.log"
cd "$T/master"; printf -- '\n### a-14\nSomething to look at.\n' >> collab/INBOX_a.md
git add -A; git commit -qm a-14; git push -q
t0=$(date +%s); while ! grep -q finished "$T/states" 2>/dev/null; do
  sleep 2; if [ $(( $(date +%s) - t0 )) -gt 40 ]; then break; fi; done
check "says a turn STARTED, before it is known to succeed" "started" "$T/states"
check "and says it FINISHED" "finished" "$T/states"
# THE DIRECTION IS THE HALF THAT WAS WRONG. A task ARRIVES and the work goes
# BACK, and this watcher fired both without saying which, so the notifier
# guessed from the state and drew a completed task as though it were a new
# one. The states alone cannot catch that, so the flow is asserted here.
check "declares that a starting turn came IN from the peer" "^started|in$" "$T/states"
check "and that a finished one goes OUT to the peer" "^finished|out$" "$T/states"
absent "so a completion is never announced as an arrival" "^finished|in$" "$T/states"
stop "$T/seat/.git/inbox_watch_a.pid"

# a notifier that is broken must cost nothing: the bus outranks the view
rm -f "$T/seat/.git/inbox_watch_a" "$T/n2_ran"
( cd "$T/seat" && P=2 NOTIFY="this-command-does-not-exist" \
  ON_CHANGE="echo ran > '$T/n2_ran'" \
  sh "$INSH" a integration collab > "$T/in15.log" 2>&1 & echo $! > "$T/in15.pid" )
sleep 4
cd "$T/master"; printf -- '\n### a-15\nThe notifier is broken.\n' >> collab/INBOX_a.md
git add -A; git commit -qm a-15; git push -q
t0=$(date +%s); while [ ! -f "$T/n2_ran" ]; do
  sleep 2; if [ $(( $(date +%s) - t0 )) -gt 40 ]; then break; fi; done
if [ -f "$T/n2_ran" ]; then ok "a broken notifier does not stop the turn"
else bad "a broken notifier stopped the turn, the view outranked the bus"; fi
absent "and does not leak its own errors into the watcher's output" \
       "this-command-does-not-exist: not found" "$T/in15.log"
stop "$T/seat/.git/inbox_watch_a.pid"

echo "24. notify.sh speaks the team's one format and never breaks the bus"
# THE HOOK SHIPPED AND THE RECIPE DID NOT, so operators retyped an osascript
# one-liner with four levels of quoting and the seats that never got round to
# it stayed invisible. This is that recipe, shipped.
NOTSH="$HERE/notify.sh"
if [ ! -f "$NOTSH" ]; then bad "notify.sh is not shipped beside the watchers"; else
  # RUNNING THE TESTS MUST NOT NOTIFY THE PERSON RUNNING THEM. On a machine with
  # no notifier these cases were silent and nothing showed it; run on a desktop
  # they put the suite's own fixtures on the screen, and Davies received one
  # titled `B`, subtitled `started`, reading `x`. A test that interrupts its
  # operator is a defect however green it is.
  #
  # The delivery path is still exercised, against FAKE notifiers earlier on PATH,
  # which is the same trick this suite already uses for the injector. That tests
  # MORE than skipping delivery would, because the AppleScript escaping now runs
  # against something that records what it was handed.
  # ITS OWN DIRECTORY, NOT THE SHARED ONE. Putting these in `$T/fakebin`
  # restoring PATH afterwards was not enough, because the injector section adds
  # that same directory to PATH itself, so a fake osascript left lying in it
  # still changed which branch inject.sh took. A fixture is scoped by where it
  # LIVES, not only by when it is on the path.
  mkdir -p "$T/fakenotify"
  for fake in osascript notify-send; do
    printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s"\nexit 0\n' "$T/notified.log" \
      > "$T/fakenotify/$fake"
    chmod +x "$T/fakenotify/$fake"
  done
  NOTIFY_OLD_PATH="$PATH"
  PATH="$T/fakenotify:$PATH"; export PATH
  # EVERY exit status here is captured with `if`, never with `cmd; rc=$?`.
  # This suite runs under set -e, and two of the cases below assert that a
  # script returns NON-ZERO, which under set -e aborts the whole run before
  # the summary. That happened once, and the suite reported a bare EXIT 1
  # with no failing assertion named, which is the least useful way to fail.
  if NOTIFY_STATE=armed NOTIFY_TEXT=hello sh "$NOTSH" "Claude Opus 5" "Cursor Composer" \
       > "$T/n_out" 2> "$T/n_err"; then
    ok "exits zero even where the machine has no notifier"
  else bad "a missing notifier returned non-zero, so it could fail a turn"; fi
  # THE ARROW IS FOR TRAFFIC BETWEEN SESSIONS AND NOTHING ELSE. A message
  # crossing gets both sides; a watcher arming or a link falling silent is one
  # session's own business, and an arrow there says a message moved when none
  # did. NOTIFY_ECHO makes the rendered format inspectable on a machine with
  # no notifier, which is the only way this is testable at all.
  NOTIFY_ECHO=1 NOTIFY_STATE=started NOTIFY_FLOW=in NOTIFY_TEXT="LOCAL-41 arrived" \
    sh "$NOTSH" "Claude Opus 5" "Cursor Grok" > "$T/n_cross" 2>&1 || true
  check "points the arrow from the peer on a message coming IN" \
        "^Claude Opus 5 → Cursor Grok$" "$T/n_cross"
  check "and names the state on its own line" "^started$" "$T/n_cross"
  # THE ONE THAT WAS WRONG. Both directions used to render peer to self, so a
  # seat reporting back looked exactly like a seat being given work.
  NOTIFY_ECHO=1 NOTIFY_STATE=finished NOTIFY_FLOW=out NOTIFY_TEXT="the task is done" \
    sh "$NOTSH" "Claude Opus 5" "Cursor Grok" > "$T/n_back" 2>&1 || true
  check "and turns it round on a message going OUT" \
        "^Cursor Grok → Claude Opus 5$" "$T/n_back"
  absent "so work going back never reads as work coming in" \
         "^Claude Opus 5 → Cursor Grok$" "$T/n_back"
  # A WRONG ARROW IS WORSE THAN NO ARROW, so a caller that declares nothing
  # gets the plain title even on a state whose name sounds like a crossing.
  NOTIFY_ECHO=1 NOTIFY_STATE=finished NOTIFY_TEXT="no direction given" \
    sh "$NOTSH" "Claude Opus 5" "Cursor Grok" > "$T/n_nodir" 2>&1 || true
  absent "draws no arrow at all when the direction is not declared" "→" "$T/n_nodir"
  check "and falls back to the plain title" "^Cursor Grok$" "$T/n_nodir"
  NOTIFY_ECHO=1 NOTIFY_STATE=alarm NOTIFY_TEXT="the branch is gone" \
    sh "$NOTSH" "Claude Opus 5" "Cursor Grok" > "$T/n_own" 2>&1 || true
  absent "writes NO arrow on a session's own event" "→" "$T/n_own"
  check "and names only the session it belongs to" "^Cursor Grok$" "$T/n_own"
  # ARMING REACHES NOBODY. It is the most frequent notification a team raises
  # and the least informative, and it fires again on every watcher restart.
  # THE TWO STREAMS ARE KEPT APART HERE, and merging them made this assertion
  # fail on its own terms the first time it ran: arming still speaks on stderr,
  # to report a machine with no notifier at all, so `2>&1` captured that note
  # and read it as a delivery. What must be empty is STDOUT, which is where a
  # delivered notification goes.
  NOTIFY_ECHO=1 NOTIFY_STATE=armed NOTIFY_TEXT="watching the inbox" \
    sh "$NOTSH" "Claude Opus 5" "Cursor Grok" > "$T/n_armed" 2>"$T/n_armed_err" || true
  if [ -s "$T/n_armed" ]; then
    bad "arming still reaches the desktop, so every watcher restart buzzes"
  else ok "arming is not delivered, so a restart does not buzz a phone"; fi
  # A LABEL NAMES A PLATFORM AND A MODEL, and one word cannot be both.
  NOTIFY_STATE=armed NOTIFY_TEXT=x sh "$NOTSH" "Claude Opus 5" "Opus" \
    >/dev/null 2>"$T/n_label" || true
  check "says so when a label is one word, since it cannot name both" \
        "is one word" "$T/n_label"
  NOTIFY_STATE=armed NOTIFY_TEXT=x sh "$NOTSH" "Claude Opus 5" "Cursor Grok" \
    >/dev/null 2>"$T/n_label2" || true
  absent "and stays quiet when both halves are there" "is one word" "$T/n_label2"
  # every notification the same shape, so a wall of them reads at a glance
  NOTIFY_ECHO=1 NOTIFY_STATE=failed \
    NOTIFY_TEXT="$(printf 'one\n\n  two   three\tfour and a tail that runs on well past any sensible width for a desktop notification and then keeps going')" \
    sh "$NOTSH" "Codex GPT Sol" > "$T/n_long" 2>&1 || true
  if [ "$(awk 'NR==3{print length($0)}' "$T/n_long")" -le 110 ]; then
    ok "collapses and trims a ragged text so every notification is one shape"
  else bad "let a long ragged text through, so notifications wrap unevenly"; fi
  # a text carrying a quote or a backslash must not become a syntax error
  if NOTIFY_STATE=failed NOTIFY_TEXT='he said "run \it"' sh "$NOTSH" "Claude Opus 5" "Cursor Grok" \
       >/dev/null 2>"$T/n_err2"; then
    ok "survives a quote and a backslash in the text"
  else bad "a quote in the text made the notifier return non-zero"; fi
  # A MACHINE THAT CANNOT SHOW ANYTHING MUST SAY SO ON THE STATE THAT MATTERS.
  # The assertion here used to require silence on `started`, and it ran with the
  # fake notifiers on PATH, so HAVE was never empty and it passed on the broken
  # code and the fixed one alike. What it was guarding, a warning on every state
  # from a machine that CAN notify, is now impossible by construction: the
  # warning is reached only when no backend exists at all.
  #
  # `alarm` is the discriminating state. It is the one the protocol raises when
  # a seat has gone silent past its DUE, the one notification that means a
  # person is needed, and the old code swallowed it without a word on a machine
  # with no notifier.
  # THE CONDITION IS A MACHINE WHERE DETECTION FOUND NOTHING, and it is driven
  # by emptying PATH rather than by NOTIFY_BACKEND=none. `none` is a documented
  # value meaning raise nothing, so an operator who chose silence must not be
  # told to install a notifier. Asserting on `none` locked the test onto the
  # behaviour that had to be removed: repairing the script would have turned
  # this case red and read as a broken test.
  NOTIFY_STATE=alarm NOTIFY_TEXT=x PATH=/nonexistent \
    /bin/sh "$NOTSH" "Claude Opus 5" "Cursor Grok" >/dev/null 2>"$T/n_err3" && rc=0 || rc=$?
  check "says a machine with no notifier is running blind, on alarm and not only on arming" \
        "found no desktop notifier" "$T/n_err3"
  # A PROPERTY, NOT A REGRESSION GUARD, and it is labelled so rather than left
  # to look like one. The old notifier exited zero here too, so this cannot
  # fail on the behaviour the case above was written to catch. It is kept
  # because the property is load bearing, a view nobody can see must never be
  # able to stop the work, and because the day someone makes this path exit
  # non-zero is the day it earns its place.
  if [ "$rc" = 0 ]; then
    ok "and still exits zero, a standing property rather than a guard on this fix"
  else bad "a machine with no notifier made notify.sh exit $rc, which can stop a turn"; fi
  # AND A BACKEND THAT READS STDIN CANNOT HANG THE CALLER. Measured on a live
  # Mac: a shim earlier on PATH read stdin, notify.sh ran inside a screen
  # session whose stdin is a terminal that never ends, and the arming of two
  # watchers hung there. The notifier is a view of the work and the work must
  # never wait on it.
  # ALL THREE BACKENDS, because faking only one is how the third kept its
  # hang for a whole round while the file's comment claimed every backend was
  # covered. Measured by a seat: a powershell shim that reads stdin held the
  # notifier for six seconds while the other two returned at once.
  mkdir -p "$T/nstdin"
  for be in osascript notify-send powershell.exe; do
    printf '#!/bin/sh\ncat >/dev/null\n' > "$T/nstdin/$be"
    chmod +x "$T/nstdin/$be"
  done
  nstuck=""
  for be in osascript notify-send powershell; do
    PATH="$T/nstdin:$PATH" NOTIFY_BACKEND=$be NOTIFY_STATE=started NOTIFY_TEXT=x \
      sh "$NOTSH" "Claude Opus 5" "Cursor Grok" < /dev/zero > /dev/null 2>&1 &
    nsp=$!
    ni=0
    while kill -0 "$nsp" 2>/dev/null && [ "$ni" -lt 6 ]; do sleep 1; ni=$((ni+1)); done
    if kill -0 "$nsp" 2>/dev/null; then
      kill -9 "$nsp" 2>/dev/null; nstuck="$nstuck $be"
    fi
    wait "$nsp" 2>/dev/null || true
  done
  if [ -z "$nstuck" ]; then
    ok "no backend that reads stdin can hold the caller, checked on all three"
  else
    bad "these backends held notify.sh on a stdin that never ends:$nstuck, so a view of the work can stop the work"
  fi

  # AND CHOSEN SILENCE IS NOT A BROKEN MACHINE. `none` says raise nothing, so
  # it must produce no advice about installing anything, on any state.
  for st in armed started alarm; do
    NOTIFY_BACKEND=none NOTIFY_STATE=$st NOTIFY_TEXT=x \
      sh "$NOTSH" "Claude Opus 5" "Cursor Grok" >/dev/null 2>>"$T/n_none"
  done
  if [ -s "$T/n_none" ]; then
    bad "NOTIFY_BACKEND=none was told to install a notifier: $(head -c 90 "$T/n_none")"
  else
    ok "and an operator who asked for silence is not told to install anything"
  fi
  # AN UNKNOWN NAME COMPLAINS ONCE. It already prints its own precise error and
  # must not collect the generic one on top, since one mistake making two
  # messages teaches people to skim both.
  NOTIFY_BACKEND=nosuchthing NOTIFY_STATE=alarm NOTIFY_TEXT=x \
    sh "$NOTSH" "Claude Opus 5" "Cursor Grok" >/dev/null 2>"$T/n_bad"
  if [ "$(awk 'END{print NR}' "$T/n_bad")" = 1 ]; then
    ok "and an unknown backend name produces one message and not two"
  else
    bad "an unknown backend produced $(awk 'END{print NR}' "$T/n_bad") messages"
  fi

  # AND A MACHINE THAT CAN NOTIFY STAYS QUIET, which is the half the old
  # assertion was actually written for.
  NOTIFY_STATE=started NOTIFY_TEXT=x sh "$NOTSH" "Claude Opus 5" "Cursor Grok" \
    >/dev/null 2>"$T/n_err4"
  if [ -s "$T/n_err4" ]; then bad "warns about a missing notifier on a machine that has one"
  else ok "and says nothing at all where a notifier exists, whatever the state"; fi
  # AND THE DELIVERY PATH REALLY RAN, against the fakes rather than the desktop.
  # Without this the section above could pass while notify.sh delivered nothing
  # at all, and the escaping that a quote in the text has to survive would never
  # be exercised.
  if [ ! -s "$T/notified.log" ]; then
    bad "nothing reached a notifier at all, so the delivery path is untested"
  elif grep -q 'display notification' "$T/notified.log"; then
    ok "delivers a real script through the notifier, quote and backslash and all"
  else bad "reached a notifier without handing it a notification to display"; fi
  PATH="$NOTIFY_OLD_PATH"; export PATH
fi

echo "25. inject.sh holds the lock until the turn it started has finished"
# INJECTION IS ASYNCHRONOUS and that is the trap. The keystroke returns the
# moment enter is pressed while the turn runs on inside the application, so an
# injector that returned immediately would drop the watcher's lock with its
# own turn still going, and the next change would start a second turn beside
# it. That is the concurrency defect this protocol already paid for once,
# arriving by a new road.
INJSH="$HERE/inject.sh"
if [ ! -f "$INJSH" ]; then bad "inject.sh is not shipped beside the watchers"; else
  # THE SUITE MUST NOT DRIVE THE REAL APPLICATION, and until now it did. On a
  # desktop `inject.sh` prefers osascript, the suite faked only xdotool, so the
  # tests activated the actual chat application and PASTED THEIR OWN FIXTURES
  # INTO A LIVE SEAT. Measured: a seat recorded two of this suite's stamp
  # commands as instructions from its operator, in the middle of a campaign.
  #
  # FAKING THE KEYBOARD WAS THE WRONG ANSWER and two attempts at it failed on
  # details of a route nobody publishes: which of osascript and xdotool is
  # preferred, that the AppleScript arrives on stdin rather than in arguments,
  # that the line itself travels by clipboard. The right answer was a named
  # delivery command in `inject.sh`, which the suite sets here. It tests the
  # SAME path on every machine, it cannot reach an application at all, and it
  # exists for a reason beyond testing: a platform with a real delivery route
  # of its own can now be driven through it instead of through a keystroke.
  mkdir -p "$T/fakebin"
  printf '#!/bin/sh\nprintf "%%s\\n" "$1" >> "%s"\nexit 0\n' \
    "$T/typed.log" > "$T/fakebin/deliver"
  chmod +x "$T/fakebin/deliver"
  DELIVER="$T/fakebin/deliver"

  # A SEAT FINISHES BY ECHOING THE NONCE IT WAS GIVEN. This fake seat reads
  # the nonce out of what was typed, which is exactly what a real one does
  # from the injected line.
  rm -f "$T/typed.log"; : > "$T/stamp"
  ( sleep 3
    n=$(grep -o 'inj-[0-9]*-[0-9]*' "$T/typed.log" 2>/dev/null | tail -1)
    echo "$n" > "$T/stamp" ) &
  if INJECT_CMD="$DELIVER" SETTLE=1 POLL=1 TIMEOUT=30 \
       sh "$INJSH" Cursor "$T/stamp" "read the inbox" > "$T/inj1.log" 2>&1; then
    ok "waits for the seat to echo its nonce and then reports success"
  else bad "returned non-zero although the seat finished its turn"; fi
  check "hands the instruction to the delivery command" "read the inbox" "$T/typed.log"
  check "told the seat which nonce to echo when it is done" "inj-" "$T/typed.log"

  # THE NONCE IS WHY A BARE TIMESTAMP FILE WILL NOT DO. Another turn touching
  # the stamp must not finish this one, and a seat rewriting the same second
  # leaves both the bytes and a minute-resolution modification time unchanged,
  # so a genuinely fast turn would be missed by any mtime test.
  : > "$T/stamp"
  ( sleep 2; echo "a different turn entirely" > "$T/stamp" ) &
  rc=0
  INJECT_CMD="$DELIVER" SETTLE=1 POLL=1 TIMEOUT=6 \
    sh "$INJSH" Cursor "$T/stamp" "read the inbox" > "$T/inj2.log" 2>&1 || rc=$?
  if [ "$rc" != 0 ]; then
    ok "an unrelated turn touching the stamp does not finish this one"
  else bad "counted somebody else's stamp write as its own completion"; fi

  # EXIT 75 IS THE CONTRACT, and it is the finding that mattered. A plain
  # failure here made the watcher release its lock on a turn that might still
  # be running, so the retry could meet a live turn. 75 says so explicitly.
  if [ "$rc" = 75 ]; then
    ok "returns 75, telling the watcher the turn may still be running"
  else bad "returned $rc on timeout, so the watcher would release the lock"; fi
  check "and says the lock is held rather than the change merely retried" \
        "KEEPS ITS LOCK" "$T/inj2.log"
  absent "and does not add its own nonce to the stamp on the way out" \
         "inj-" "$T/stamp"

  # A PASTE THAT NEVER LANDED MUST NOT COST A WHOLE TIMEOUT. This script types
  # into whichever composer is frontmost and does not select a thread, so the
  # instruction can go to another window entirely. Measured on a live seat: it
  # went to the master's window, the seat never saw it, and the injector waited
  # out its full hour before the watcher quarantined a lock for another hour on
  # top. The seat is now asked to acknowledge FIRST, and the absence of that is
  # what shortens the wait.
  check "asks the seat to acknowledge before it does anything else" \
        "started" "$T/typed.log"
  rm -f "$T/typed.log"; : > "$T/stamp"
  t0=$(date +%s); rc=0
  INJECT_CMD="$DELIVER" SETTLE=1 POLL=1 ACK=4 TIMEOUT=45 \
    sh "$INJSH" Cursor "$T/stamp" "read the inbox" > "$T/inj3.log" 2>&1 || rc=$?
  el=$(( $(date +%s) - t0 ))
  if [ "$rc" != 75 ]; then
    bad "returned $rc on a paste nobody acknowledged, and only 75 is safe there"
  elif [ "$el" -ge 25 ]; then
    bad "waited ${el}s for an unacknowledged paste, so it still burns the whole timeout"
  else ok "gives up on an unacknowledged paste in ${el}s rather than the full timeout"; fi
  check "and names the focus as the likely cause, since that is what it is" \
        "frontmost" "$T/inj3.log"

  # AND AN ACKNOWLEDGED TURN IS NOT CUT SHORT. The acknowledgement contains the
  # nonce, so a substring test would read it as a completion and report a turn
  # finished the moment it began; an exact match is what separates them.
  rm -f "$T/typed.log"; : > "$T/stamp"
  ( sleep 2
    n=$(grep -o 'inj-[0-9]*-[0-9]*' "$T/typed.log" 2>/dev/null | tail -1)
    echo "$n started" > "$T/stamp" ) &
  t0=$(date +%s); rc=0
  INJECT_CMD="$DELIVER" SETTLE=1 POLL=1 ACK=4 TIMEOUT=20 \
    sh "$INJSH" Cursor "$T/stamp" "read the inbox" > "$T/inj4.log" 2>&1 || rc=$?
  el=$(( $(date +%s) - t0 ))
  if [ "$rc" = 0 ]; then
    bad "read the acknowledgement as a completion, so a live turn looks finished"
  elif [ "$el" -lt 15 ]; then
    bad "cut an acknowledged turn short after ${el}s, at ACK rather than at TIMEOUT"
  else ok "lets an acknowledged turn run to TIMEOUT, ${el}s, and does not finish it early"; fi

  # a chat box sends on the first enter, so a multi-line instruction must
  # arrive as ONE line or a fragment is submitted and the rest is left behind
  rm -f "$T/typed.log"; echo one > "$T/stamp"
  ( sleep 2; echo two > "$T/stamp" ) &
  INJECT_CMD="$DELIVER" SETTLE=1 POLL=1 TIMEOUT=30 \
    sh "$INJSH" Cursor "$T/stamp" "$(printf 'first\nsecond')" >/dev/null 2>&1 || true
  if [ "$(count 'first second' "$T/typed.log")" = 1 ] \
     && [ "$(count '^first\$' "$T/typed.log")" = 0 ]; then
    ok "flattens a multi-line instruction into one line before sending it"
  else bad "sent a multi-line instruction, so the chat box submits a fragment"; fi

  # THE OTHER HALF OF THE 75 CONTRACT LIVES IN THE WATCHER, and a contract
  # honoured at only one end is not a contract. An ON_CHANGE that exits 75
  # must leave the lock STANDING, because releasing it is what would let the
  # next poll start a turn beside one that may still be running.
  rm -f "$T/seat/.git/inbox_watch_a"
  rm -rf "$T/seat/.git/turn_a.lock"
  # NOTIFY is set so the notification stream is inspectable. Without it
  # `notify` is a no-op and an assertion about what was announced passes on
  # any code at all, which is the trap this suite exists to avoid.
  ( cd "$T/seat" && P=2 FAST=99 ON_CHANGE="exit 75" \
    NOTIFY="printf '%s|%s\n' \"\$NOTIFY_STATE\" \"\$NOTIFY_TEXT\" >> $T/in75.notify" \
    sh "$INSH" a integration collab > "$T/in75.log" 2>&1 & echo $! > "$T/in75.pid" )
  sleep 3
  cd "$T/master"; printf -- '\n### a-75\nA turn that cannot report.\n' >> collab/INBOX_a.md
  git add -A; git commit -qm a-75; git push -q
  t0=$(date +%s); while ! grep -q HOLDING "$T/in75.log" 2>/dev/null; do
    sleep 2; if [ $(( $(date +%s) - t0 )) -gt 40 ]; then break; fi; done
  check "the watcher says it is HOLDING the lock on a 75" "HOLDING" "$T/in75.log"
  if [ -d "$T/seat/.git/turn_a.lock" ]; then
    ok "and the lock is still standing, so no second turn can start"
  else bad "released the lock on a turn that may still be running"; fi
  # THE PID FILE MUST BE GONE, not merely empty, and asserting "not
  # non-empty" would have passed either way. lock_is_dead reads an EMPTY pid
  # file as proof of death and reclaims on the very next poll, which hands
  # the lock straight back and undoes the hold. Only with no pid file at all
  # does it fall through to the age test and stand for STALE minutes.
  if [ -e "$T/seat/.git/turn_a.lock/pid" ]; then
    bad "left a pid file behind, so the lock is reclaimed on the next poll"
  else ok "and removed the pid file, so the lock stands until it ages out"; fi
  # AND IT MUST NOT ANNOUNCE A RETRY IT WILL NOT DO. A 75 is non-zero, so the
  # ordinary failure branch used to fire first and send "the turn failed,
  # attempt 1, retrying" a moment before the hold sent "its lock is held".
  # Two notifications from ONE event, saying opposite things, and the first
  # one false: the hold pushes the next attempt out to RETRY rather than
  # retrying on the next poll. Davies read that pair on his phone and could
  # not tell what had happened, which is the whole cost of a wrong
  # notification. Only the alarm speaks for 75 now.
  if [ ! -s "$T/in75.notify" ]; then
    bad "sent no notification at all on a 75, so this assertion cannot discriminate"
  elif grep -q '^failed|' "$T/in75.notify"; then
    bad "announced a retry on a 75, which is the one code that does not retry"
  elif grep -q '^alarm|' "$T/in75.notify"; then
    ok "and announced only the alarm, since a 75 holds rather than retries"
  else bad "sent notifications on a 75 but no alarm among them"; fi
  # prove it: the watcher must NOT have started a second turn behind the hold
  if [ "$(count HOLDING "$T/in75.log")" = 1 ]; then
    ok "and held once rather than reacquiring and re-running every poll"
  else bad "took the lock again on a later poll, so the hold did nothing"; fi
  # THE CLOCK RUNS FROM THE QUARANTINE, NOT FROM ACQUISITION, and everything
  # above passed while that was wrong. The lock directory is created when the
  # turn STARTS; the shipped injector waits an HOUR before returning 75 and
  # STALE defaults to sixty minutes, so measuring the DIRECTORY meant the
  # lock was already reclaimable the instant it was held. This test could not
  # see it, because its ON_CHANGE returns in seconds.
  if [ -f "$T/seat/.git/turn_a.lock/hold_since" ]; then
    ok "and stamps the moment of quarantine, which is what STALE measures"
  else bad "no quarantine stamp, so STALE still runs from acquisition"; fi
  stop "$T/seat/.git/inbox_watch_a.pid"

  # the real shape: an ANCIENT lock directory whose quarantine is fresh
  touch -t 200001010000 "$T/seat/.git/turn_a.lock" 2>/dev/null || true
  rm -f "$T/seat/.git/inbox_watch_a" "$T/second_turn"
  ( cd "$T/seat" && P=2 STALE=30 ON_CHANGE="echo again > '$T/second_turn'" \
    sh "$INSH" a integration collab > "$T/in75b.log" 2>&1 & echo $! > "$T/in75b.pid" )
  sleep 3
  cd "$T/master"; printf -- '\n### a-75b\nArriving while a turn may still be live.\n' >> collab/INBOX_a.md
  git add -A; git commit -qm a-75b; git push -q
  sleep 10
  if [ -f "$T/second_turn" ]; then
    bad "reclaimed a lock directory older than STALE although the hold is fresh"
  else ok "refuses an ancient lock directory whose quarantine is still fresh"; fi
  stop "$T/seat/.git/inbox_watch_a.pid"
  rm -rf "$T/seat/.git/turn_a.lock"

  # THE QUARANTINE IS MEASURED AGAINST ITS OWN CLOCK, NOT AGAINST STALE, and
  # this pair is what separates the two. The injector has already waited its
  # full TIMEOUT before it says it cannot tell, so charging STALE on top means
  # two hours before anything moves, and a live seat sat behind exactly that
  # for an hour and a half.
  #
  # THE STAMP IS AGED BY A SPECIFIC AMOUNT AND THE TWO SETTINGS STRADDLE IT.
  # The first attempt backdated it to the year 2000, which is older than every
  # threshold, so both cases reclaimed and the pair could not tell the two
  # clocks apart at all. Ten minutes with HOLD at five and STALE at ten hours
  # can only be reclaimed by HOLD, and ten minutes with HOLD at ten hours and
  # STALE at one can only be reclaimed by STALE, so each case fails on the
  # behaviour the other one has.
  ago10=$(date -u -d '10 minutes ago' +%Y%m%d%H%M 2>/dev/null \
          || date -u -v-10M +%Y%m%d%H%M 2>/dev/null || echo '')
  if [ -z "$ago10" ]; then
    bad "cannot backdate a file on this date(1), so the quarantine clock is untested"
  else
  for case in reclaim refuse; do
    if [ "$case" = reclaim ]; then s=600; h=5; else s=1; h=600; fi
    rm -f "$T/seat/.git/inbox_watch_a" "$T/hold_turn"
    mkdir -p "$T/seat/.git/turn_a.lock"
    : > "$T/seat/.git/turn_a.lock/hold_since"
    rm -f "$T/seat/.git/turn_a.lock/pid"
    touch -t "$ago10" "$T/seat/.git/turn_a.lock/hold_since"
    # the DIRECTORY stays ancient in both cases, so anything that consults its
    # age rather than the stamp's reclaims in both and fails the refuse case
    touch -t 200001010000 "$T/seat/.git/turn_a.lock" 2>/dev/null || true
    ( cd "$T/seat" && P=2 STALE=$s HOLD=$h ON_CHANGE="echo again > '$T/hold_turn'" \
      sh "$INSH" a integration collab > "$T/inhold_$case.log" 2>&1 & \
      echo $! > "$T/inhold.pid" )
    sleep 3
    cd "$T/master"
    printf -- '\n### a-hold-%s\nArriving behind a ten minute quarantine.\n' "$case" >> collab/INBOX_a.md
    git add -A; git commit -qm "a-hold-$case"; git push -q
    sleep 10
    if [ "$case" = reclaim ]; then
      if [ -f "$T/hold_turn" ]; then
        ok "takes a quarantine older than HOLD, without waiting out STALE"
      else bad "a quarantine past HOLD still waited for STALE, so the clocks are one"; fi
    else
      if [ -f "$T/hold_turn" ]; then
        bad "a one minute STALE released a quarantine HOLD says is still fresh"
      else ok "and STALE no longer governs a quarantine, however short it is"; fi
    fi
    stop "$T/seat/.git/inbox_watch_a.pid"
    rm -rf "$T/seat/.git/turn_a.lock"
  done
  fi
fi

echo "26. supervise.sh adopts an orphan rather than running beside it"
# THE WATCHER DIES WITH WHATEVER STREAMS IT on platforms whose background
# facility has a hard ceiling, thirty minutes on one measured platform, and
# the reverse is worse: an orphaned watcher goes on polling and ADVANCING ITS
# STATE FILE while its output reaches nobody, so every entry it consumes is
# one the next watcher never shows anyone.
SUPSH="$HERE/supervise.sh"
if [ ! -f "$SUPSH" ]; then bad "supervise.sh is not shipped beside the watchers"; else
  if ! sh "$SUPSH" sideways a integration collab > "$T/sup0.log" 2>&1; then
    ok "refuses a kind that is neither inbox nor outbox"
  else bad "accepted a watcher kind it does not have"; fi

  # a live watcher whose reader has gone is killed and taken over, and the
  # replacement must actually deliver
  rm -f "$T/seat/.git/inbox_watch_a"
  ( cd "$T/seat" && P=2 sh "$INSH" a integration collab > "$T/orphan.log" 2>&1 &
    echo $! > "$T/orphan.pid" )
  sleep 4
  victim=$(cat "$T/seat/.git/inbox_watch_a.pid" 2>/dev/null || true)
  if [ -n "${victim:-}" ] && kill -0 "$victim" 2>/dev/null; then
    ok "the orphan is running and has recorded its pid"
  else bad "could not set up a live watcher to adopt"; fi
  ( cd "$T/seat" && P=2 sh "$SUPSH" inbox a integration collab > "$T/sup.log" 2>&1 &
    echo $! > "$T/sup.pid" )
  t0=$(date +%s); while ! grep -q ADOPTING "$T/sup.log" 2>/dev/null; do
    sleep 2; if [ $(( $(date +%s) - t0 )) -gt 40 ]; then break; fi; done
  check "says it is adopting, rather than starting a second watcher quietly" \
        "ADOPTING" "$T/sup.log"
  t0=$(date +%s); while kill -0 "$victim" 2>/dev/null; do
    sleep 1; if [ $(( $(date +%s) - t0 )) -gt 30 ]; then break; fi; done
  if kill -0 "$victim" 2>/dev/null; then
    bad "left the orphan alive, so two watchers now consume the same pushes"
  else ok "and the orphan whose output went nowhere is gone"; fi
  cd "$T/master"; printf -- '\n### a-26\nDelivered by the replacement.\n' >> collab/INBOX_a.md
  git add -A; git commit -qm a-26; git push -q
  t0=$(date +%s); while ! grep -q "a-26" "$T/sup.log" 2>/dev/null; do
    sleep 2; if [ $(( $(date +%s) - t0 )) -gt 40 ]; then break; fi; done
  check "the replacement delivers what landed after the takeover" "a-26" "$T/sup.log"
  stop "$T/sup.pid"; stop "$T/seat/.git/inbox_watch_a.pid"
fi

echo "27. the OUTBOX watcher notifies too, which it could not do at all"
# THE MASTER SIDE OF THIS BUS WAS SILENT FROM THE BEGINNING. watch-outbox.sh
# had no NOTIFY hook, so a seat could reply and the only thing that noticed
# was a stream nobody was reading. Half a notification system is the half
# that lets the person paying for it find out from somewhere else.
rm -f "$T/master/.git/outbox_watch_b" "$T/ostates" "$T/otexts"
( cd "$T/master" && P=2 DUE=8 \
  NOTIFY="echo \$NOTIFY_STATE >> '$T/ostates'; echo \$NOTIFY_TEXT >> '$T/otexts'" \
  sh "$OUTSH" b sub/b collab > "$T/ob27.log" 2>&1 & echo $! > "$T/ob27.pid" )
sleep 4
check "says it armed" "armed" "$T/ostates"
check "and the arm line in the log names the notifier it is wired to" \
      "notifications are ON through" "$T/ob27.log"
cd "$T/seat"; git checkout -q -b sub/b origin/integration 2>/dev/null || git checkout -q sub/b
mkdir -p collab; printf 'first line from b\n' > collab/OUTBOX_b.md
git add -A; git commit -qm b27; git push -q -u origin sub/b
t0=$(date +%s); while ! grep -q finished "$T/ostates" 2>/dev/null; do
  sleep 2; if [ $(( $(date +%s) - t0 )) -gt 40 ]; then break; fi; done
check "says a seat spoke, which is the event the master waits on" \
      "finished" "$T/ostates"
# the title carries who is talking to whom, so the body must not spend its
# one line repeating the seat's name back at the reader
absent "and its text does not repeat the seat name the title already carries" \
       "^b " "$T/otexts"
t0=$(date +%s); while ! grep -q alarm "$T/ostates" 2>/dev/null; do
  sleep 2; if [ $(( $(date +%s) - t0 )) -gt 40 ]; then break; fi; done
check "raises an alarm when the seat goes quiet past DUE" "alarm" "$T/ostates"
stop "$T/ob27.pid"; stop "$T/master/.git/outbox_watch_b.pid"

echo "28. the package driven from an installation path containing a space"
# INJECT.SH CLAIMED THIS WAS TESTED AND IT WAS NOT. Its own comment says the
# stamp path is single-quoted because "this package supports installation
# paths containing spaces, and it tests for them", and no case put the package
# anywhere near such a path. A claim about coverage that the suite does not
# back is worse than no claim, because it stops the next person looking.
#
# THE UNQUOTED FAILURE IS SPECIFIC AND WORTH NAMING: the injected line is
# SHELL SOURCE the seat runs, so `echo $NONCE > /Users/me/My Seats/stamp`
# redirects to `My` and passes `Seats/stamp` as an argument, which writes the
# token to the wrong file and leaves the injector waiting out its whole
# timeout on a turn that finished.
SPACED="$T/My Seats"
mkdir -p "$SPACED"
cp "$HERE"/*.sh "$SPACED/" 2>/dev/null
if [ -f "$SPACED/inject.sh" ] && [ -f "$SPACED/watch-inbox.sh" ]; then
  ok "the package copies into a directory whose name contains a space"
  SP_STAMP="$SPACED/seat chat stamp"
  rm -f "$SP_STAMP" "$T/sp.log" "$T/sp.delivered"
  # a delivery command that records the line, then plays the seat: it runs the
  # two commands the injector embedded, exactly as a real seat would
  cat > "$SPACED/deliver one.sh" <<'DEL'
#!/bin/sh
printf '%s\n' "$1" > "$SPDEST"
( sh -c "$(printf '%s' "$1" | sed 's/.*FIRST, before anything else, run: //; s/ Finally,.*//')"
  sleep 2
  sh -c "$(printf '%s' "$1" | sed 's/.*as the LAST act of this turn, run: //')" ) &
exit 0
DEL
  SPDEST="$T/sp.delivered" INJECT_CMD="sh \"$SPACED/deliver one.sh\"" \
    SETTLE=1 POLL=1 TIMEOUT=25 \
    sh "$SPACED/inject.sh" App "$SP_STAMP" "spaced path instruction" \
    > "$T/sp.log" 2>&1 && rc=0 || rc=$?
  # VERIFIED AGAINST THE DEFECT: unquote the stamp in the injected command
  # and ALL THREE assertions in this block fail. The injector returns 75 on a
  # turn that finished, the caller's stamp stays empty, and a file appears at
  # the first space. Every one of them is evidence.
  if [ "$rc" = 0 ]; then
    ok "the injector completes when its stamp path contains a space"
  else
    bad "returned $rc from a stamp path with a space, so the redirect split it"
  fi
  if [ -s "$SP_STAMP" ]; then
    ok "and the completion token reached the stamp the caller named"
  else
    bad "the stamp the caller named is empty, so the token went somewhere else"
  fi
  # AND NOTHING WAS WRITTEN AT THE TRUNCATED PATH. An unquoted redirect splits
  # at the FIRST space, so `$T/My Seats/seat chat stamp` would have redirected
  # to `$T/My` and passed the rest to echo as arguments.
  if [ -e "$T/My" ]; then
    bad "a file appeared at $T/My, so the redirect split at the first space"
  else
    ok "and nothing was written at the path an unquoted redirect would have split to"
  fi
  # the watchers hold PATHS and not command lines for the same reason
  ( cd "$T/master" && P=2 sh "$SPACED/watch-inbox.sh" a integration collab \
      > "$T/sp-watch.log" 2>&1 & echo $! > "$T/sp-watch.pid" )
  sleep 5
  check "and a watcher runs from that path too, arming normally" \
        "ARMED" "$T/sp-watch.log"
  stop "$T/sp-watch.pid"; stop "$T/master/.git/inbox_watch_a.pid"
else
  bad "could not copy the package to a spaced path, so this case proves nothing"
fi

echo "29. a delivery command that fails delivers nothing, and says so"
# INJECT_CMD REPLACES THE KEYBOARD ENTIRELY, so its failure is the whole
# delivery failing. That must be exit 1 and not 75: nothing was typed, nothing
# is running, and the watcher is free to retry at once. Returning 75 here
# would hold the seat's lock for HOLD minutes over a command with a typo.
rm -f "$T/badinject.log"
INJECT_CMD="sh -c 'echo no route to the app >&2; exit 3' --" \
  SETTLE=1 POLL=1 TIMEOUT=10 \
  sh "$INJSH" App "$T/never.stamp" "an instruction nobody receives" \
  > "$T/badinject.log" 2>&1 && rc=0 || rc=$?
# VERIFIED AGAINST THE DEFECT: with `exit 1` changed to `exit 75` this
# assertion fails and the two below it still pass, so the exit code is the
# only evidence in this case and the other two are context.
if [ "$rc" = 1 ]; then
  ok "returns 1 when the delivery command fails, so the watcher retries freely"
else
  bad "returned $rc from a failed delivery, and only 1 says nothing is running"
fi
check "and quotes what the delivery command said, so the cause is visible" \
      "no route to the app" "$T/badinject.log"
if [ -f "$T/never.stamp" ]; then
  bad "wrote a stamp although nothing was ever delivered"
else
  ok "and no stamp exists, since no turn was ever started"
fi

echo "30. the supervisor restarts a watcher that exits, and eases off"
# ADOPTION IS ONLY HALF OF WHAT IT IS FOR. The other half is the restart
# loop: a watcher killed by the facility streaming it must come back, and a
# watcher that cannot start at all must not spin. Case 26 covered adoption
# and left both untested.
rm -f "$T/sup30.log" "$T/master/.git/inbox_watch_z.pid"
( cd "$T/master" && P=2 sh "$SUPSH" inbox z integration collab \
    > "$T/sup30.log" 2>&1 & echo $! > "$T/sup30.pid" )
sleep 5
if [ -f "$T/master/.git/inbox_watch_z.pid" ]; then
  ok "the supervisor started a watcher underneath it"
  kill "$(cat "$T/master/.git/inbox_watch_z.pid")" 2>/dev/null
  t0=$(date +%s); while ! grep -q "WATCHER z EXITED" "$T/sup30.log" 2>/dev/null; do
    sleep 2; [ $(( $(date +%s) - t0 )) -gt 30 ] && break; done
  check "notices the watcher exited and says the state file survives it" \
        "WATCHER z EXITED" "$T/sup30.log"
  t0=$(date +%s); while [ ! -f "$T/master/.git/inbox_watch_z.pid" ]; do
    sleep 2; [ $(( $(date +%s) - t0 )) -gt 40 ] && break; done
  # VERIFIED AGAINST THE DEFECT: with the restart loop replaced by an exit,
  # this assertion fails while "notices the watcher exited" and the backoff
  # line both still pass. This one assertion is the case's evidence.
  if [ -f "$T/master/.git/inbox_watch_z.pid" ]; then
    ok "and brings it back, which is the whole reason to run a supervisor"
  else
    bad "the watcher never came back, so the supervisor supervises nothing"
  fi
  check "and names the backoff, so a spinning restart is visible in the log" \
        "restart 1 in 10s" "$T/sup30.log"
else
  bad "the supervisor never started a watcher, so its restart loop is untested"
fi
stop "$T/sup30.pid"; stop "$T/master/.git/inbox_watch_z.pid"

echo "31. the settings table in the protocol still matches the scripts"
# A TABLE OF DEFAULTS IS A PROMISE PEOPLE COPY FROM, and it is the kind of
# promise that rots silently: change a default in a script and the table goes
# on saying the old number, with nothing to notice. This package has already
# paid for that class of defect three times in documents nobody could check,
# so the one table it ships is checked by the suite instead of by attention.
#
# It reads section 3's table out of references/liveness.md (the
# unchanged section 3 after the SKILL.md split), pulls every
# `FOO=${FOO:-x}` default out of the scripts, and compares them. A dial
# with no such line is one read inline with no default, which the table
# records as unset. SKILL.md is the fallback when this install still
# keeps the table in the protocol file itself.
SK="$HERE/../references/liveness.md"
[ -f "$SK" ] || SK="$HERE/../SKILL.md"
[ -f "$SK" ] || SK="$HERE/../../../../references/liveness.md"
[ -f "$SK" ] || SK="$HERE/../../../../SKILL.md"
if [ ! -f "$SK" ]; then
  ok "no settings table beside this package, so there is no table to check"
else
  rm -f "$T/dial.bad"
  # every table row: dial names in column one, default in column three
  awk -F'|' '/^\| *`[A-Z_]+`/ {print $2 "\t" $3 "\t" $4}' "$SK" | tr -d '`' > "$T/dials.txt"
  rows=$(awk 'END{print NR}' "$T/dials.txt")
  if [ "${rows:-0}" -lt 10 ]; then
    bad "found only ${rows:-0} dial rows in the settings table, so the table moved or was lost"
  else
    ok "found $rows dial rows in the protocol's settings table"
    while IFS="$(printf '\t')" read -r names owners defaults; do
      i=0
      for n in $(printf '%s' "$names" | tr ',' ' '); do
        i=$((i+1))
        want=$(printf '%s' "$defaults" | cut -d, -f$i | sed 's/^ *//; s/ *$//; s/ min$//')
        # EVERY VALUE, NOT THE FIRST ONE. This read `sort -u | head -1`, so
        # when two shipped scripts defined one dial differently the case
        # compared the table against whichever value sorted first and called
        # it clean. Codex proved it: watch-outbox.sh moved to P=90 while
        # watch-inbox.sh and the table stayed at 60, and case 31 passed. That
        # is a test passing on the broken code, in the case written to stop
        # exactly that, so the comparison now fails on DISAGREEMENT as well as
        # on a wrong value, and says every value it found.
        # THE SAME SCOPE AS THE ATTRIBUTION CHECK BELOW. selftest.sh and
        # master-check.sh exercise the protocol rather than being part of it,
        # so their dials are their own business: master-check polls at 5 to
        # keep a rehearsal short, and counting that as the protocol
        # disagreeing with itself is a false alarm. Caught by this very check
        # the first time it ran, which is the check working.
        vals=$(cd "$HERE" && for s in ./*.sh; do
                 # THE LEADING PAREN IS NOT DECORATION. Stock macOS ships
                 # Bash 3.2 as /bin/sh, and its parser counts the `)` that
                 # closes a case PATTERN as the `)` that closes the enclosing
                 # $( ). Measured by the Codex seat on that machine:
                 # `/bin/sh -n bin/selftest.sh` failed here while
                 # `/bin/dash -n` passed, so the suite could not even be
                 # syntax-checked on the platform its own header says it runs
                 # on. `case x in (pat)` is POSIX and balances the parens.
                 case $s in (./selftest.sh|./master-check.sh) continue ;; esac
                 # `|| true` IS LOAD BEARING. grep returns 1 on a file with no
                 # match, and under `set -e` that kills the subshell in the
                 # middle of the loop, so only dials defined in the FIRST file
                 # survive. Measured: ACK came back because inject.sh sorts
                 # first, and P, FAST, RETRY, HOLD, STALE and DUE all read as
                 # "no script defines a default" because grep had already
                 # failed on inject.sh before reaching the watchers.
                 # THE WHOLE LINE, NOT UP TO THE FIRST BRACE. This matched
                 # `[^}]*}`, which stops at the first `}` and so cannot read a
                 # default that itself contains an expansion. Measured on
                 # FGLOCK, whose default is `${TMPDIR:-/tmp}/...`: the check
                 # extracted `${TMPDIR:-/tmp` and reported the table wrong when
                 # the table was right, which is a check failing on correct
                 # work. The line is taken whole and trimmed instead, so one
                 # level of nesting reads correctly. A default containing a
                 # literal `#` would lose its tail to the comment strip, and
                 # none does.
                 grep -h "^$n=\${$n:-" "$s" 2>/dev/null || true
               done)
        # AN EMPTY DEFAULT IS A DEFAULT, and this could not tell it from an
        # absent one. `ACK_BRANCH=${ACK_BRANCH:-}` sets the dial to the empty
        # string on purpose, the extraction below yields nothing, and the old
        # code read that as "no script defines a default" and demanded the
        # table say `unset`. It would have said something false. The raw
        # matches are kept so the two cases are distinguishable: no match at
        # all is absent, a match yielding nothing is empty.
        raw=$vals
        vals=$(printf '%s\n' "$raw" | sed "s/[[:space:]]*#.*$//; s/^$n=\${$n:-//; s/}$//" | sort -u)
        seen=$(printf '%s' "$vals" | grep -c . 2>/dev/null || true)
        [ -n "${seen:-}" ] || seen=0
        anyraw=$(printf '%s' "$raw" | grep -c . 2>/dev/null || true)
        [ -n "${anyraw:-}" ] || anyraw=0
        if [ "$seen" -gt 1 ]; then
          echo "$n: the shipped scripts disagree, defaults [$(printf '%s' "$vals" | tr '\n' ' ')], table says '$want'" >> "$T/dial.bad"
          continue
        fi
        got=$vals
        if [ -z "$got" ] && [ "$anyraw" -gt 0 ]; then
          # a shipped script DOES set this dial and its default is the empty
          # string, which the table writes as `empty`
          if [ "$want" != empty ]; then
            echo "$n: the shipped default is the empty string, table says '$want'" >> "$T/dial.bad"
          fi
        elif [ -z "$got" ]; then
          # no shipped default: the table must say unset, and some script
          # must still read the name, or the table documents nothing
          if [ "$want" != unset ]; then
            echo "$n: table says '$want' and no script defines a default" >> "$T/dial.bad"
          elif ! grep -q "\${$n:-" "$HERE"/*.sh 2>/dev/null; then
            echo "$n: no shipped script reads it at all" >> "$T/dial.bad"
          fi
        elif [ "$got" != "$want" ]; then
          echo "$n: script default '$got', table says '$want'" >> "$T/dial.bad"
        fi
      done
    done < "$T/dials.txt"
    if [ -s "$T/dial.bad" ]; then
      bad "the table disagrees with the scripts: $(tr '\n' ';' < "$T/dial.bad")"
    else
      ok "and every default in it is the default the scripts actually use"
    fi
    # AND THE OTHER DIRECTION. The loop above walks the TABLE, so a dial the
    # scripts read with no row at all was invisible to it. Adding
    # NOTIFY_BACKEND is what exposed that: the table went one short and
    # nothing said so. Every shipped default must have a row.
    rm -f "$T/dial.missing"
    # A DIAL READS ITS OWN NAME. `P=${P:-60}` is a dial a caller sets;
    # `STATE=${NOTIFY_STATE:-note}` is the script reading a dial into a local
    # name, and demanding a table row for that is how this check first
    # reported FLOW, STATE and TEXT as missing dials on a correct table. The
    # pattern below captures the name once and requires the braces to repeat
    # it, which separates the two exactly.
    for d in $(cd "$HERE" && for s in ./*.sh; do
                 case $s in (./selftest.sh|./master-check.sh) continue ;; esac
                 grep -hoE '^[A-Z_]+=\$\{[A-Z_]+:-' "$s" 2>/dev/null || true
               done | sed 's/\$.*//; s/=$//' | sort -u); do
      inner=$(grep -hoE "^$d=\\\$\\{[A-Z_]+:-" "$HERE"/*.sh 2>/dev/null |
              head -1 | sed 's/.*{//; s/:-$//')
      [ "$inner" = "$d" ] || continue          # an alias, not a dial
      # the name may sit anywhere in the first column, since one row can
      # carry two dials, as `SETTLE`, `POLL` does
      grep -q "^| .*\`$d\`.* |" "$SK" || echo "$d" >> "$T/dial.missing"
    done
    # AND THE ATTRIBUTION COLUMN, which nothing checked. The table could say a
    # dial belongs to the outbox watcher while both watchers defined it, and
    # this case stayed green because it read only the name and the default.
    # Codex found it by moving the P row and seeing nothing fail.
    rm -f "$T/dial.owner"
    while IFS="$(printf '\t')" read -r names owners _rest; do
      case $(printf '%s' "$owners" | sed 's/^ *//; s/ *$//') in
        'both watchers')        want='watch-inbox watch-outbox' ;;
        'watchers, supervisor') want='supervise watch-inbox watch-outbox' ;;
        'inbox watcher')        want='watch-inbox' ;;
        'outbox watcher')       want='watch-outbox' ;;
        injector)               want='inject' ;;
        notifier)               want='notify' ;;
        supervisor)             want='supervise' ;;
        *) echo "$names: the attribution '$owners' is not a phrase this check knows, so nothing verified it" >> "$T/dial.owner"; continue ;;
      esac
      for n in $(printf '%s' "$names" | tr ',' ' '); do
        # WHICH SCRIPTS READ IT, not which ones default it: the supervisor
        # reads NOTIFY inline with no default of its own and still owns it.
        # selftest and master-check exercise the protocol rather than being
        # part of it, so neither counts as an owner.
        got=$(cd "$HERE" && grep -l "\${$n:-" ./*.sh 2>/dev/null |
              sed 's|^\./||; s|\.sh$||' | grep -v '^selftest$' |
              grep -v '^master-check$' | sort | tr '\n' ' ' | sed 's/ $//')
        [ "$got" = "$want" ] || echo "$n: the table says '$owners' and the scripts that read it are [${got:-none}]" >> "$T/dial.owner"
      done
    done < "$T/dials.txt"
    if [ -s "$T/dial.owner" ]; then
      bad "the table names the wrong owner: $(tr '\n' ';' < "$T/dial.owner")"
    else
      ok "and every row names the scripts that actually read its dial"
    fi
    if [ -s "$T/dial.missing" ]; then
      bad "the scripts ship defaults the table never mentions: $(tr '\n' ' ' < "$T/dial.missing")"
    else
      ok "and every dial the scripts ship a default for has a row of its own"
    fi
  fi
fi


echo "32. a torn state file is announced and the inbox is surfaced, not skipped silently"
# THE STATE WRITE USED TO TRUNCATE FIRST AND WRITE SECOND, so a crash between
# the two left a file the next start read as empty. It then cold-seeded from
# the remote as it stands and skipped everything pushed while it was down, for
# good. Codex found it. The write is atomic now, so this case covers what a
# torn file from any other cause still does: announce loudly and put the
# current inbox in the log, rather than advancing quietly.
#
# ON_CHANGE IS DELIBERATELY NOT FIRED on a cold start. Firing it would turn
# every fresh clone into a turn, and under supervise.sh a repeatedly corrupt
# state would fire one on every restart. Surfacing the inbox in the log gives
# the operator the content without that loop.
rm -f "$T/seat/.git/inbox_watch_c" "$T/seat/.git/inbox_watch_c.pid" "$T/c32.log"
cd "$T/master"
printf '## Open instructions\n- C-1: a torn state file must not hide me\n' > collab/INBOX_c.md
git add -A; git commit -qm c32; git push -q origin integration
: > "$T/seat/.git/inbox_watch_c"          # the torn file: present, empty
( cd "$T/seat" && P=2 sh "$INSH" c integration collab > "$T/c32.log" 2>&1 & echo $! > "$T/c32.pid" )
sleep 6
check "says plainly that a cold start cannot see what came before" \
      "cold start" "$T/c32.log"
check "and puts the current inbox in the log rather than only naming the gap" \
      "a torn state file must not hide me" "$T/c32.log"
check "and names the range query as the thing that actually recovers it" \
      "watermark range query" "$T/c32.log"
stop "$T/c32.pid"; stop "$T/seat/.git/inbox_watch_c.pid"

# A LONG INBOX IS THE NORMAL CASE AND IT USED TO BE PRINTED WHOLE. In the
# repository this protocol was built for the seat inbox is 2,949 lines, so a
# cold start wrote three thousand lines into a supervised log and the change
# worth reading was somewhere in the middle. The cap must keep the HEAD, since
# new instructions go at the top of Open, keep a tail, and SAY how much it
# dropped: a silent truncation reads as a short inbox.
rm -f "$T/seat/.git/inbox_watch_c" "$T/seat/.git/inbox_watch_c.pid" "$T/c32b.log"
cd "$T/master"
{ printf '## Open instructions\n- C-2 FIRST LINE OF A LONG INBOX\n'
  i=0; while [ "$i" -lt 400 ]; do echo "- filler line $i"; i=$((i + 1)); done
  printf -- '- C-3 LAST LINE OF A LONG INBOX\n'; } > collab/INBOX_c.md
git add -A; git commit -qm c32b; git push -q origin integration
( cd "$T/seat" && P=2 MAXLINES=60 sh "$INSH" c integration collab > "$T/c32b.log" 2>&1 & echo $! > "$T/c32b.pid" )
sleep 6
stop "$T/c32b.pid"; stop "$T/seat/.git/inbox_watch_c.pid"
# THE HEAD AND THE TAIL ALONE PROVE NOTHING, and Codex measured that: the old
# watcher printed the WHOLE inbox, so both were present and both assertions
# passed on the behaviour this case exists to catch. What discriminates is what
# is MISSING, so the middle is asserted absent in the same breath.
check "keeps the head of a long inbox, where new instructions go" \
      "C-2 FIRST LINE OF A LONG INBOX" "$T/c32b.log"
check "and keeps the tail" "C-3 LAST LINE OF A LONG INBOX" "$T/c32b.log"
absent "and drops the middle, which is the half that discriminates" \
       "filler line 200" "$T/c32b.log"
check "and says how many lines it dropped, so a cut inbox cannot read as a short one" \
      "lines elided by the watcher" "$T/c32b.log"
check "and names the file to read for the rest" "INBOX_c.md on integration" "$T/c32b.log"
cl=$(awk 'END{print NR}' "$T/c32b.log")
if [ "${cl:-0}" -lt 100 ]; then
  ok "and the whole event is $cl lines rather than the 402 the inbox holds"
else
  bad "a 402 line inbox produced a $cl line log, so the cap did not hold"
fi

# AND THE WRITE ITSELF LEAVES NO DEBRIS. An atomic save renames a temporary
# into place, so a leftover .new would mean the rename never happened.
if [ -e "$T/seat/.git/inbox_watch_c.new" ]; then
  bad "the atomic save left its temporary behind, so the rename did not happen"
else
  ok "the atomic state save leaves no temporary file behind"
fi

# A GATE FOR A PLATFORM THIS MACHINE CANNOT RUN. Stock macOS ships Bash 3.2 as
# /bin/sh, and its parser counts the `)` closing a case PATTERN as the `)`
# closing an enclosing $( ). The Codex seat measured it on that machine:
# `/bin/sh -n bin/selftest.sh` failed while `/bin/dash -n` passed, so the suite
# could not be syntax-checked at all on the platform its header claims. Neither
# dash nor a modern bash reproduces it, so no run here can catch a relapse.
# What a run here CAN do is refuse the shape: `case x in (pat)` is POSIX,
# balances the parens, and is what every case inside a substitution must use.
echo "37. the shell shapes stock macOS cannot parse are refused"
# WHAT THIS CAN AND CANNOT DO, stated rather than implied. Stock macOS ships
# Bash 3.2 as /bin/sh, and its parser counts the `)` closing a case PATTERN as
# the `)` closing an enclosing $( ). The Codex seat measured it there:
# `/bin/sh -n bin/selftest.sh` failed while `/bin/dash -n` passed, so the suite
# could not be syntax-checked at all on the platform its header claims. NO
# SHELL ON THIS MACHINE REPRODUCES THAT, so no run here can prove the fix. A
# first attempt at a byte-level scanner for the shape produced two false
# positives on `case` statements at top level, and a lint nobody can trust is
# worse than no lint, so it was withdrawn rather than tuned.
#
# What is left is worth having and is honest about its reach: every shipped
# script must parse under EVERY shell this machine has, and the two multi-line
# substitutions that actually carry a `case` must use the POSIX `(pat)` form
# that balances the parens. The general gate belongs on a Mac.
shells=""
for s in /bin/sh /bin/dash /bin/bash /usr/bin/bash; do
  [ -x "$s" ] || continue
  case " $shells " in (*" $s "*) continue ;; esac
  shells="$shells $s"
done
rm -f "$T/parse.bad"
for s in $shells; do
  for f in "$HERE"/*.sh; do
    "$s" -n "$f" 2>/dev/null || echo "$(basename "$s") cannot parse $(basename "$f")" >> "$T/parse.bad"
  done
done
if [ -s "$T/parse.bad" ]; then
  bad "a shipped script does not parse: $(tr '\n' ';' < "$T/parse.bad")"
else
  ok "all seven scripts parse under every shell here:$shells"
fi
# AND THE TWO SUBSTITUTIONS THAT CARRY A CASE USE THE BALANCED FORM. These are
# the exact sites that failed on Bash 3.2, so they are checked by name.
if [ "$(count 'case [$]s in [(][.]/selftest' "$HERE/selftest.sh")" = 2 ]; then
  ok "and both case patterns inside a substitution use the paren form Bash 3.2 can parse"
else
  bad "a case pattern inside a substitution lost its leading paren, which stock macOS Bash 3.2 cannot parse"
fi
# THE HEADER'S PLATFORM CLAIM IS ONLY WORTH WHAT SOMETHING CHECKS.
if grep -q 'stock macOS' "$HERE/selftest.sh"; then
  ok "and the header still claims stock macOS, which a Mac must confirm before release"
else
  bad "the header no longer claims stock macOS, so either restore the claim or drop this case"
fi


echo "33. the injector's keyboard branch classifies its failures correctly"
# INJECT_CMD IS WHAT KEEPS THE SUITE AWAY FROM A REAL APPLICATION, and it also
# means the shipped macOS branch never runs here. Codex found that: the
# classification that decides between "nothing was typed, retry at once" and
# "a turn may be running, hold the lock" had no coverage at all, and getting
# it wrong in one direction starts a second turn beside a live one while the
# other quarantines a healthy seat for HOLD minutes.
#
# THE FAKE LIVES IN A DIRECTORY OF ITS OWN and PATH is restored after. The
# first attempt at faking tools in this suite put them somewhere a later
# section also adds to its path, so the fake went on deciding which branch ran
# six sections later. One directory per fixture, used and then dropped.
KBD="$T/fake-kbd"
mkdir -p "$KBD"
# A CLIPBOARD THAT REMEMBERS, because the injector now checks that its own
# line actually reached the pasteboard before it pastes. The first fake was a
# black hole: pbcopy swallowed the write and pbpaste read back the same fixed
# string, so every injection looked like a clipboard that had REFUSED the
# line, and the case would have been green against an injector that never
# pasted at all. A fixture that cannot hold a value cannot test one.
cat > "$KBD/pbcopy" <<PB
#!/bin/sh
cat > "$KBD/clip"
PB
cat > "$KBD/pbpaste" <<PB
#!/bin/sh
if [ -f "$KBD/clip" ]; then cat "$KBD/clip"
else printf 'whatever the user had on the clipboard'; fi
PB
# the fake speaks whatever the case puts in OSA_ERR and exits OSA_RC, which is
# how one script covers every branch of the classification
cat > "$KBD/osascript" <<OSA
#!/bin/sh
# IT RECORDS THAT IT WAS CALLED. An assertion about a paste NOT happening
# cannot read a stamp this fake never writes, so it reads this instead.
echo called >> "$KBD/osa.calls"
cat > /dev/null 2>&1 || true
echo "\$OSA_ERR" >&2
exit "\${OSA_RC:-0}"
OSA
chmod +x "$KBD/pbpaste" "$KBD/pbcopy" "$KBD/osascript"

SAVED_PATH=$PATH
PATH="$KBD:$PATH"; export PATH
# AND ITS OWN FOREGROUND LOCK. FGLOCK defaults to a MACHINE-WIDE path, so on
# any machine actually running seats a live injector holds it for the whole
# paste and these probes wait out FGWAIT and return 75 without ever reaching
# the classification they exist to test. Measured by the Cursor seat: four
# assertions here came back red on a working Mac and green in a container,
# which is a suite reporting on the machine rather than on the code. Every
# other lock case already passes its own; this was the last one that did not.
FGLOCK="$T/case33.lock"; export FGLOCK
FGWAIT=3; export FGWAIT
# REFUSE RATHER THAN RISK. If the fake is not what `osascript` resolves to,
# the injector would drive a REAL application, which is the incident this
# suite already caused once on a live seat. Check before running anything.
if [ "$(command -v osascript)" != "$KBD/osascript" ]; then
  bad "the fake osascript is not first on PATH, so this case is skipped rather than risking a real application"
else
  ok "the fake keyboard backend shadows any real one, so nothing can reach an application"

  # AND THIS CASE OWNS ITS LOCK. Every other lock case passes FGLOCK
  # explicitly; this one used the default and was therefore decided by
  # whatever else was running on the machine. The guard is here so that a
  # later edit dropping the export is caught rather than showing up as four
  # red assertions on somebody's working laptop.
  case ${FGLOCK:-} in
    "$T"/*) ok "and the case holds its own foreground lock, so no live seat can decide it" ;;
    *) bad "case 33 is using the foreground lock at ${FGLOCK:-the machine-wide default}, so a live injector on this machine decides these assertions" ;;
  esac

  # (a) NO ACCESSIBILITY GRANT. Nothing was typed, so the watcher must be free
  # to retry at once: exit 1.
  rm -f "$T/k1.stamp"
  OSA_RC=1 OSA_ERR="execution error: osascript is not allowed assistive access. (1002)" \
    SETTLE=1 POLL=1 ACK=3 TIMEOUT=6 \
    sh "$INJSH" App "$T/k1.stamp" "an instruction" > "$T/k1.log" 2>&1 && rc=0 || rc=$?
  if [ "$rc" = 1 ]; then
    ok "a missing accessibility grant returns 1, so the watcher retries at once"
  else
    bad "a missing accessibility grant returned $rc, and only 1 says nothing was typed"
  fi
  check "and says what the operator has to grant" "Accessibility" "$T/k1.log"

  # (b) THE APPLICATION IS NOT RUNNING. Also nothing typed: exit 1.
  rm -f "$T/k2.stamp"
  OSA_RC=1 OSA_ERR="execution error: Application isn't running. (-600)" \
    SETTLE=1 POLL=1 ACK=3 TIMEOUT=6 \
    sh "$INJSH" App "$T/k2.stamp" "an instruction" > "$T/k2.log" 2>&1 && rc=0 || rc=$?
  if [ "$rc" = 1 ]; then
    ok "an application that is not running returns 1, since no keystroke can have landed"
  else
    bad "an application that is not running returned $rc rather than 1"
  fi

  # (c) A FAILURE IT DOES NOT RECOGNISE. This is the dangerous one. A paste
  # that got halfway is a turn that may be running, so calling it "nothing was
  # typed" is how a retry meets a live turn. It must be 75.
  rm -f "$T/k3.stamp"
  OSA_RC=1 OSA_ERR="execution error: something nobody has documented (-1728)" \
    SETTLE=1 POLL=1 ACK=3 TIMEOUT=6 \
    sh "$INJSH" App "$T/k3.stamp" "an instruction" > "$T/k3.log" 2>&1 && rc=0 || rc=$?
  if [ "$rc" = 75 ]; then
    ok "an unrecognised failure returns 75, so the watcher holds rather than retrying into a live turn"
  else
    bad "an unrecognised failure returned $rc, and anything but 75 risks a second turn"
  fi
  check "and says plainly that it cannot tell whether anything was typed" \
        "CANNOT say whether anything was typed" "$T/k3.log"

  # (c2) A WINDOW WITH NOTHING TO TYPE INTO. The AppleScript raises this
  # before the clipboard is set and before any paste, and its own text says
  # nothing was typed, so it belongs with (a) and (b) at exit 1. It had no
  # pattern in the classifier and fell to (c)'s catch-all, which told the
  # watcher the outcome was unknown: measured on a live Cursor seat, the lock
  # was held for fifteen minutes with nobody holding it and the instruction
  # never arrived. Reverting the pattern makes this 75 and this block red.
  rm -f "$T/k3b.stamp"
  OSA_RC=1 OSA_ERR="execution error: no text input was focused, the accessibility tree offered no text area this window would take focus on, and the composer click is off, so nothing was typed. Focus the seat's composer once, or set INJECT_CLICK=1 (-2700)" \
    SETTLE=1 POLL=1 ACK=3 TIMEOUT=6 \
    sh "$INJSH" App "$T/k3b.stamp" "an instruction" > "$T/k3b.log" 2>&1 && rc=0 || rc=$?
  if [ "$rc" = 1 ]; then
    ok "a window with no text input to type into returns 1, since the refusal happens before the clipboard is even set"
  else
    bad "a refusal raised before any paste returned $rc, so the watcher quarantines a seat that nothing was delivered to"
  fi
  check "and hands the operator the remedy the script already knows" \
        "INJECT_CLICK=1" "$T/k3b.log"
  absent "without claiming it cannot tell, which is what sent it to the catch-all" \
         "CANNOT say whether anything was typed" "$T/k3b.log"

  # (d) A WARNING ON A SUCCESSFUL RUN IS NOT A FAILURE. An earlier version
  # failed on any output at all, which turned a harmless warning into "nothing
  # was typed", released the lock and retried. Exit zero with noise on stderr
  # must still count as typed, so the wait runs and times out at 75.
  rm -f "$T/k4.stamp"
  OSA_RC=0 OSA_ERR="warning: some deprecation nobody can act on" \
    SETTLE=1 POLL=1 ACK=3 TIMEOUT=5 \
    sh "$INJSH" App "$T/k4.stamp" "an instruction" > "$T/k4.log" 2>&1 && rc=0 || rc=$?
  # THE OUTPUT OF A SUCCESSFUL RUN IS REPORTED VERBATIM, whatever it is. On the
  # macOS path a zero exit now returns the composer's accessibility value, so a
  # warning and a read-back arrive by the same channel and neither may be
  # swallowed: an earlier version failed on any output at all, which turned a
  # harmless warning, and a partial delivery that DID type, into "nothing was
  # typed", released the lock and retried. Assert that the text SURVIVES rather
  # than that it matches one phrase, since the phrase has already changed once.
  check "whatever a successful paste reports is passed through, not swallowed" \
        "some deprecation nobody can act on" "$T/k4.log"
  if [ "$rc" = 75 ]; then
    ok "and the turn is waited for, reaching 75 on silence rather than 1 on the warning"
  else
    bad "a warning on a successful paste ended as $rc, so it was read as nothing typed"
  fi

  # (e) THE PERSON'S OWN CLIPBOARD IS PUT BACK. The script has always claimed
  # this in a comment and nothing checked it, so an injection that ate what
  # somebody had copied would have shipped green.
  # BYTE FOR BYTE, TRAILING NEWLINES INCLUDED. The old injector restored the
  # clipboard too, through `saved=$(pbpaste)`, so a fixture without trailing
  # newlines passed on the broken behaviour and the defect shipped: measured at
  # 15 bytes in and 13 out on text ending in two newlines. The fixture now ends
  # in two, which is the only form of this assertion that discriminates.
  # AND IT COMPARES THE BYTES. `wc -c` alone passed a mutation that returned
  # the same fifteen bytes in a different case, while claiming byte for byte.
  printf 'operator text\n\n' > "$T/k4b.expected"
  cp "$T/k4b.expected" "$KBD/clip"
  rm -f "$T/k4b.stamp"
  OSA_RC=0 OSA_ERR="" SETTLE=1 POLL=1 ACK=2 TIMEOUT=3 \
    sh "$INJSH" App "$T/k4b.stamp" "an instruction" > /dev/null 2>&1 || true
  if cmp -s "$T/k4b.expected" "$KBD/clip"; then
    ok "and the clipboard comes back byte for byte, trailing newlines included"
  else
    bad "the restored clipboard differs from the original bytes: $(wc -c < "$KBD/clip" | tr -d ' ') bytes against 15"
  fi

  # (f) A CLIPBOARD THAT REFUSES THE WRITE. Measured on a live Antigravity
  # seat: the window came forward and the composer stayed empty. Pasting
  # anyway sends WHATEVER THE PERSON LAST COPIED into a chat window and
  # presses enter on it, which is worse than doing nothing, and the old code
  # sent pbcopy's failure to /dev/null and pasted regardless.
  rm -f "$KBD/osa.calls"
  cat > "$KBD/pbcopy" <<'PB'
#!/bin/sh
cat > /dev/null
exit 1
PB
  chmod +x "$KBD/pbcopy"
  rm -f "$T/k5.stamp"
  OSA_RC=0 OSA_ERR="" SETTLE=1 POLL=1 ACK=3 TIMEOUT=5 \
    sh "$INJSH" App "$T/k5.stamp" "an instruction" > "$T/k5.log" 2>&1 && rc=0 || rc=$?
  if [ "$rc" = 1 ]; then
    ok "a clipboard that refuses the line returns 1, since nothing can have been typed"
  else
    bad "a refused clipboard returned $rc, and anything but 1 means it pasted something it could not name"
  fi
  check "and names the pasteboard rather than blaming the application" \
        "could not put the instruction on the clipboard" "$T/k5.log"
  # THE ABSENT STAMP PROVES NOTHING, because the fake osascript never writes
  # one, so that assertion passed on the old injector which DID paste. What
  # discriminates is whether the application was driven at all, so the fake
  # records every invocation and this requires none.
  if [ -s "$KBD/osa.calls" ]; then
    bad "a refused clipboard still drove the application $(awk 'END{print NR}' "$KBD/osa.calls") times, which is the paste it was meant to prevent"
  else
    ok "and the application was never driven, so the person's own clipboard never reached a composer"
  fi
fi
PATH=$SAVED_PATH; export PATH
unset FGLOCK FGWAIT
# AND THE FIXTURE IS GONE, so it cannot decide a branch in a later case the
# way the first attempt at this did.
rm -rf "$KBD"
if [ "$(command -v osascript 2>/dev/null)" = "$KBD/osascript" ]; then
  bad "the fake keyboard backend is still on PATH after its case, which is how it leaked last time"
else
  ok "and the fake backend leaves PATH the way it found it"
fi


echo "34. the supervisor forces a kill and climbs its backoff ladder"
# CASE 26 ADOPTED A COOPERATIVE WATCHER AND CASE 30 SAW ONLY THE FIRST RESTART,
# so neither reached the forced kill nor the second rung of the ladder. Codex
# found both. A watcher that ignores TERM is not hypothetical: that is what a
# shell sitting inside `sleep` does when its trap only cleans up and returns.
#
# THE FAKE WATCHER LIVES BESIDE A COPY OF THE SUPERVISOR, because supervise.sh
# resolves the script it runs from its OWN directory. Copying both into a
# scratch directory is what lets a fake be substituted without touching the
# shipped tree.
SUPDIR="$T/fake-sup"
mkdir -p "$SUPDIR"
cp "$SUPSH" "$SUPDIR/supervise.sh"
# a watcher that records its pid where the supervisor looks, then ignores TERM
# ITS EXIT CODE IS 4 AND MUST NEVER BE 3. It was 3, an ordinary non-zero exit
# when this case was written, and 3 was given a meaning later: another watcher
# already owns this seat, on which the supervisor stands down instead of
# restarting. The ladder this case exists for then never ran and both its
# assertions failed. Found by the review seat running the suite to completion
# against a head this master had reported green from a run that was killed part
# way. An exit code is a set like any other, and giving one a new meaning means
# sweeping every producer of it.
cat > "$SUPDIR/watch-inbox.sh" <<'FW'
#!/bin/sh
G=$(git rev-parse --absolute-git-dir 2>/dev/null)
echo $$ > "$G/inbox_watch_$1.pid"
if [ -f "$G/deaf" ]; then trap '' TERM; while :; do sleep 1; done; fi
exit 4
FW
chmod +x "$SUPDIR/watch-inbox.sh"

# (a) FORCED KILL. The orphan ignores TERM, so the supervisor must escalate.
rm -f "$T/master/.git/inbox_watch_y.pid" "$T/sup34a.log"
: > "$T/master/.git/deaf"
( cd "$T/master" && sh "$SUPDIR/watch-inbox.sh" y >/dev/null 2>&1 & )
sleep 2
orphan=$(cat "$T/master/.git/inbox_watch_y.pid" 2>/dev/null)
if [ -n "${orphan:-}" ] && kill -0 "$orphan" 2>/dev/null; then
  ok "a watcher that ignores TERM is running as pid $orphan"
  rm -f "$T/master/.git/deaf"        # the replacement must be able to exit
  ( cd "$T/master" && P=2 sh "$SUPDIR/supervise.sh" inbox y integration collab \
      > "$T/sup34a.log" 2>&1 & echo $! > "$T/sup34a.pid" )
  t0=$(date +%s); while kill -0 "$orphan" 2>/dev/null; do
    sleep 2; [ $(( $(date +%s) - t0 )) -gt 40 ] && break; done
  if kill -0 "$orphan" 2>/dev/null; then
    bad "the deaf orphan survived adoption, so its output still reaches nobody"
    kill -9 "$orphan" 2>/dev/null
  else
    ok "and the supervisor escalates past TERM until it is actually gone"
  fi
  check "and says it is adopting rather than starting a second watcher quietly" \
        "ADOPTING y" "$T/sup34a.log"
  # (b) THE LADDER. The fake exits 3 every time, so restarts accumulate: two at
  # ten seconds, then the second rung. Reaching the third rung would cost the
  # suite five minutes of waiting for one `case` arm, so it is not exercised.
  t0=$(date +%s); while ! grep -q "restart 3 in 60s" "$T/sup34a.log" 2>/dev/null; do
    sleep 3; [ $(( $(date +%s) - t0 )) -gt 60 ] && break; done
  check "the first two restarts are quick, at ten seconds" \
        "restart 1 in 10s" "$T/sup34a.log"
  check "and the third eases off to sixty, so a watcher that cannot start cannot flood" \
        "restart 3 in 60s" "$T/sup34a.log"
  stop "$T/sup34a.pid"; stop "$T/master/.git/inbox_watch_y.pid"
else
  bad "could not start a TERM-ignoring watcher, so the forced kill stays untested"
fi
rm -rf "$SUPDIR" "$T/master/.git/deaf"

echo "35. every notifier backend, not only the one this machine happens to have"
# DETECTION PREFERS osascript, so on a Mac the Linux and Windows branches are
# unreachable and their formatting had no coverage at all: the urgency mapping
# on one, the doubled quote on the other. Codex found it. NOTIFY_BACKEND names
# the branch, which is the same repair that made the injector testable, and it
# tests the same code on every machine instead of one branch per platform.
NB="$T/fake-notif"
mkdir -p "$NB"
for tool in notify-send powershell.exe osascript; do
  cat > "$NB/$tool" <<'FN'
#!/bin/sh
printf '%s\n' "$@" >> "$NBLOG"
FN
  chmod +x "$NB/$tool"
done
SAVED_PATH=$PATH
PATH="$NB:$PATH"; export PATH

# (a) LINUX. No subtitle field, so the state folds into the title and an alarm
# is critical rather than normal.
NBLOG="$T/n-linux.log"; export NBLOG; rm -f "$NBLOG"
NOTIFY_BACKEND=notify-send NOTIFY_STATE=alarm NOTIFY_FLOW=in \
  NOTIFY_TEXT="the branch is gone" sh "$NOTSH" 'Claude Opus 5' 'Cursor Grok' >/dev/null 2>&1
# `.*` and not `.` between the parts: the arrow and the separator are
# multi-byte, and with LANG unset grep counts BYTES, so a single dot cannot
# span either and the assertion would fail on a correct implementation.
check "the Linux backend folds the state into the title, since it has no subtitle" \
      "Claude Opus 5.*Cursor Grok.*alarm" "$NBLOG"
check "and raises an alarm at critical urgency rather than normal" \
      "critical" "$NBLOG"
NBLOG="$T/n-linux2.log"; export NBLOG; rm -f "$NBLOG"
NOTIFY_BACKEND=notify-send NOTIFY_STATE=started NOTIFY_FLOW=in \
  NOTIFY_TEXT="a turn is starting" sh "$NOTSH" 'Claude Opus 5' 'Cursor Grok' >/dev/null 2>&1
absent "and leaves an ordinary state at normal urgency" "critical" "$T/n-linux2.log"

# (b) WINDOWS. A single quote inside the text would end the PowerShell string
# early, so it is doubled. This is the branch nothing had ever executed.
NBLOG="$T/n-win.log"; export NBLOG; rm -f "$NBLOG"
NOTIFY_BACKEND=powershell NOTIFY_STATE=failed \
  NOTIFY_TEXT="the seat's own turn failed" sh "$NOTSH" 'Claude Opus 5' 'Cursor Grok' >/dev/null 2>&1
check "the Windows backend doubles a single quote so the script cannot end early" \
      "seat''s own turn failed" "$NBLOG"

# (c) AND A NAME IT DOES NOT KNOW is refused loudly rather than silently
# picking a branch the caller did not ask for.
err=$(NOTIFY_BACKEND=telepathy NOTIFY_STATE=note NOTIFY_TEXT=x \
      sh "$NOTSH" 'Claude Opus 5' 'Cursor Grok' 2>&1 >/dev/null) && rc=0 || rc=$?
case $err in
  *"names no backend"*) ok "an unknown backend name is refused, and says so" ;;
  *) bad "an unknown backend name was accepted silently, so a typo picks a branch at random" ;;
esac
if [ "${rc:-0}" = 0 ]; then
  ok "and it still exits zero, because a view of the work must not stop the work"
else
  bad "an unknown backend name returned $rc, so a typo in NOTIFY can break a turn"
fi
PATH=$SAVED_PATH; export PATH
rm -rf "$NB"
unset NBLOG


echo "36. the suite cannot change the identity of a commit made after it"
# A LIVE SEAT PAID FOR THIS ONE. The suite used to `export GIT_AUTHOR_NAME` and
# friends. The variables survived in the shell that ran it, and the next real
# commit on that machine went out authored `selftest <selftest@example.invalid>`
# on a repository whose first non-negotiable rule is who its commits are
# authored by. The identity is per repository now, so there is nothing in the
# environment to leak, and this case holds that.
for v in GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL; do
  eval "val=\${$v:-}"
  if [ -n "${val:-}" ]; then
    bad "$v is set to '$val' while the suite runs, so it will outlive it and author somebody else's commit"
  else
    ok "$v is unset, so it cannot follow the suite out and author a later commit"
  fi
done
# AND THE PROOF THAT MATTERS IS A COMMIT, not the absence of a variable. A
# third repository with an identity of its own must keep it.
OTHER="$T/somebody-else"
rm -rf "$OTHER"; mkdir -p "$OTHER"
( cd "$OTHER" && git init -q . && git config user.name "Somebody Else" &&
  git config user.email somebody@example.invalid &&
  printf 'x\n' > f && git add f && git commit -qm "not the suite's commit" ) >/dev/null 2>&1
who=$(git -C "$OTHER" log --format='%an <%ae>' -1 2>/dev/null)
if [ "$who" = "Somebody Else <somebody@example.invalid>" ]; then
  ok "a repository with its own identity keeps it, which is what leaked before"
else
  bad "a later commit was authored '$who', so the suite reached outside itself"
fi
rm -rf "$OTHER"

echo "38. the seat tidies trailing blank lines while adding an entry"
# THE ALARM THIS PROTECTS is the append-only one, and it fired on whitespace.
# Measured on a live seat, 27 August: the outbox went from 3040 raw lines to
# 3038 because five trailing blanks were trimmed while two real entries were
# added, every fetch was a fast-forward, and the watcher reported that the file
# had been rewritten or the branch rewound. Nothing had been lost. The pair
# below is what discriminates: tidying must deliver, and a real removal must
# still alarm. Counting raw lines passes neither half.
cd "$T"; git init -q --bare origin38.git
git clone -q origin38.git s38 2>/dev/null
cd "$T/s38"; git config user.email s@example.invalid; git config user.name s
mkdir -p collab
# three entries, then FIVE trailing blank lines that are not entries
printf -- '- one\n- two\n- three\n\n\n\n\n\n' > collab/OUTBOX_a.md
git add -A; git commit -qm seed >/dev/null 2>&1
git push -q origin HEAD:refs/heads/sub/a 2>/dev/null
cd "$T"; git clone -q origin38.git m38 2>/dev/null
cd "$T/m38"; git config user.email m@example.invalid; git config user.name m
( cd "$T/m38" && P=2 sh "$OUTSH" a sub/a collab > "$T/ob38.log" 2>&1 & echo $! > "$T/ob38.pid" )
t0=$(date +%s); while ! grep -q ARMED "$T/ob38.log" 2>/dev/null; do
  sleep 1; [ $(( $(date +%s) - t0 )) -gt 25 ] && break; done
# the trailing blanks must not have been counted as entries in the first place
check "does not count trailing blank lines as entries" "ARMED on sub/a at head .*, 3 entries" "$T/ob38.log"
# now trim the blanks AND add one real entry: raw lines fall 8 to 4
cd "$T/s38"; printf -- '- one\n- two\n- three\n- four is new\n' > collab/OUTBOX_a.md
git add -A; git commit -qm tidy >/dev/null 2>&1
# NAME THE BRANCH ON EVERY PUSH. This clone's local branch is whatever git
# init chose, and only the first push named sub/a, so a bare `git push` here
# went nowhere and the watcher was blamed for missing what was never sent.
git push -q origin HEAD:refs/heads/sub/a 2>/dev/null
t0=$(date +%s); while ! grep -q 'four is new' "$T/ob38.log" 2>/dev/null; do
  sleep 1; [ $(( $(date +%s) - t0 )) -gt 25 ] && break; done
check "delivers the new entry even though the file got shorter" "four is new" "$T/ob38.log"
if grep -q "OUTBOX SHRANK" "$T/ob38.log" 2>/dev/null; then
  bad "raised the append-only alarm on trimmed whitespace, which is the false alarm"
else
  ok "does not raise the append-only alarm on trimmed whitespace"
fi
# AND THE ALARM IS NOT SIMPLY OFF. Removing a real entry must still fire it.
cd "$T/s38"; printf -- '- one\n- two\n' > collab/OUTBOX_a.md
git add -A; git commit -qm truncate >/dev/null 2>&1
git push -q origin HEAD:refs/heads/sub/a 2>/dev/null
t0=$(date +%s); while ! grep -q "OUTBOX SHRANK" "$T/ob38.log" 2>/dev/null; do
  sleep 1; [ $(( $(date +%s) - t0 )) -gt 25 ] && break; done
check "still alarms when real entries are removed" "OUTBOX SHRANK" "$T/ob38.log"
stop "$T/m38/.git/outbox_watch_a.pid"

echo "39. the foreground lock, every way it can be wrong"
# THE LOCK IS NEW AND ITS EDGES ARE WHERE A MUTEX HURTS. A seat measured the
# happy path on a real machine, a second injector waiting and giving up without
# stealing the window. What nobody had exercised is what happens when the lock
# is left behind: a mutex whose holder died and which nobody breaks turns one
# crashed injection into a seat that can never be injected into again, which is
# worse than the contention it was added to prevent.
# THE SUITE RUNS UNDER `set -e` AND THE INJECTOR RETURNS 75 ON PURPOSE, so every
# call here captures its status with `&& rc=0 || rc=$?`. Written without that
# guard the first call killed the whole run: case 39 printed its heading, the
# suite exited with status 0 and NO TOTALS LINE, which reads like a pass to
# anything that only checks the exit code. Case 33 already had the guard and
# that is where the form comes from.
LK="$T/fake-lock"
mkdir -p "$LK"
cat > "$LK/osascript" <<OS
#!/bin/sh
# leaves a marker so a case can tell "the injector ran the backend" from
# "the injector printed the right sentence and did nothing", and records the
# interval it held the keyboard so an overlap between two injectors shows
printf '%s\n' "\$\$" >> "$LK/ran"
# WHO OWNS THE FOREGROUND WHILE THE KEYBOARD WORK RUNS. Without this a case
# can only time the SECOND injector, and being quick proves nothing: an
# injector that never took the lock, or released it before doing anything,
# leaves the second one just as quick.
[ -n "\${FGLOCK:-}" ] && readlink "\$FGLOCK" > "$LK/heldby" 2>/dev/null
[ -n "\${FGSPAN:-}" ] && printf 'in %s %s\n' "\$\$" "\$(date +%s)" >> "\$FGSPAN"
[ -n "\${FGHOLD:-}" ] && sleep "\$FGHOLD"
[ -n "\${FGSPAN:-}" ] && printf 'out %s %s\n' "\$\$" "\$(date +%s)" >> "\$FGSPAN"
# DRAIN STDIN ONLY FOR THE HEREDOC FORM. The injector calls osascript two
# ways: with -e, where the script is an argument and nothing is piped, and
# once with a heredoc, which must be drained or the writer takes SIGPIPE.
# An unconditional \`cat\` blocks for ever on the -e form, because stdin is
# whatever the suite inherited. That HUNG A WHOLE RUN for eighteen minutes on
# the rich-clipboard probe, which calls \`osascript -e 'clipboard info'\`, and a
# fixture that hangs is worse than one that fails because it reads as slowness.
case "\$*" in
  *-e*) : ;;
  *) cat >/dev/null 2>&1 ;;
esac
echo "fake composer"
exit 0
OS
cat > "$LK/pbcopy" <<OS
#!/bin/sh
cat > "$LK/clip"
OS
cat > "$LK/pbpaste" <<OS
#!/bin/sh
if [ -f "$LK/clip" ]; then cat "$LK/clip"; fi
OS
chmod +x "$LK/osascript" "$LK/pbcopy" "$LK/pbpaste"
OLDPATH=$PATH
PATH="$LK:$PATH"; export PATH
FG="$T/fglock"
inj39(){ FGLOCK="$FG" ACK=1 TIMEOUT=2 SETTLE=1 POLL=1 sh "$INJSH" "$@"; }

# (a) a lock whose holder is GONE must be broken rather than waited out
rm -f "$FG"; ln -s "999999.inj-999999-1" "$FG"; : > "$LK/ran"
t0=$(date +%s)
FGWAIT=20 inj39 FakeApp "$T/fgstamp" 'hello' > "$T/fg_a" 2>&1 && rc=0 || rc=$?
d=$(( $(date +%s) - t0 ))
check "breaks a lock whose holder is gone, and says whose it was" \
      "broke a foreground lock left by pid 999999" "$T/fg_a"
if [ "$d" -lt 15 ]; then ok "and does it at once rather than waiting out FGWAIT"
else bad "waited ${d}s for a lock nobody holds"; fi
if [ -s "$LK/ran" ]; then ok "and went on to drive the application, so the lock was really taken"
else bad "printed the right sentence and never reached the backend, which any mutant can do"; fi

# (b) an owner we cannot read is WAITED OUT, never broken. The old version
# deleted such a lock on sight, which is how a live lock in its first
# moment got removed by a second injector.
rm -f "$FG"; ln -s "not-a-pid" "$FG"
t0=$(date +%s)
FGWAIT=3 inj39 FakeApp "$T/fgstamp" 'hello' > "$T/fg_b" 2>&1 && rc=0 || rc=$?
d=$(( $(date +%s) - t0 ))
check "names an unreadable lock owner rather than deleting the lock" \
      "names an owner it cannot read" "$T/fg_b"
# 1, NOT 75, AND THE DIFFERENCE COSTS A HEALTHY SEAT. Nothing has been typed
# when the foreground wait expires and the injector knows it, so the code is
# the one that says exactly that. 75 quarantines THIS seat for HOLD minutes
# because ANOTHER seat holds a machine-wide lock, which is the second half of
# the three hour incident recorded in inject.sh. Named by the review seat.
if [ "$rc" = 1 ]; then ok "and returns 1 for a lock it could not read, since nothing was typed here"
else bad "returned $rc for a lock it could not read, where 1 says what actually happened"; fi
if [ -L "$FG" ]; then ok "and the lock it could not read is still there"
else bad "it removed a lock whose owner it could not read, which is the deletion this case exists for"; fi
if [ "$d" -ge 3 ]; then ok "and waited the full FGWAIT before saying so"
else bad "gave up after ${d}s of a 3s wait"; fi

# (c) a lock held by a LIVE process must be waited for, then declined
rm -f "$FG"
sleep 60 & holder=$!
ln -s "$holder.inj-$holder-1" "$FG"
t0=$(date +%s)
FGWAIT=3 inj39 FakeApp "$T/fgstamp" 'hello' > "$T/fg_c" 2>&1 && rc=0 || rc=$?
d=$(( $(date +%s) - t0 ))
kill $holder 2>/dev/null || true
check "waits for a live holder and then says it typed nothing" \
      "waited 3s for the foreground and another injector still holds it" "$T/fg_c"
if [ "$rc" = 1 ]; then ok "and returns 1, which is the code the watcher really does retry on"
else bad "returned $rc where 1 is the contract's own answer for nothing typed"; fi
# AND THE MESSAGE MUST NOT PROMISE WHAT THE CODE USED TO DENY. It said 75 meant
# the watcher would retry; the watcher's own code says a 75 is held and NOT
# retried, and announcing both put two notifications from one event in front of
# a person saying opposite things.
absent "and says nothing about returning 75, which the watcher does not retry" \
       "Returning 75" "$T/fg_c"
if [ "$d" -ge 3 ] && [ "$d" -lt 10 ]; then ok "and waited about FGWAIT, neither giving up at once nor hanging"
else bad "waited ${d}s where FGWAIT was 3"; fi
if [ -L "$FG" ]; then ok "and left the live holder's lock alone"
else bad "it removed a lock a live process was holding"; fi

# (d) the lock must not outlive the injector that took it
rm -f "$FG"; : > "$LK/ran"
FGWAIT=5 inj39 FakeApp "$T/fgstamp" 'hello' > "$T/fg_d" 2>&1 && rc=0 || rc=$?
if [ -e "$FG" ] || [ -L "$FG" ]; then bad "the lock survived the injector, so the next one waits for a ghost"
else ok "releases the lock when the injector exits"; fi
if [ -s "$LK/ran" ]; then ok "and it had taken one, so the release is not vacuous"
else bad "released nothing because it never drove the application"; fi

# (e) A PATH THAT CANNOT BE CREATED IS NOT CONTENTION. 75 quarantines the
# watcher for a turn that may be running, and a directory that does not
# exist has no turn behind it. This must be 1, and must not blame another
# injector for a configuration error that will never clear.
t0=$(date +%s)
FGLOCK="$T/no-such-dir/deeper/lock" FGWAIT=20 ACK=1 TIMEOUT=2 SETTLE=1 POLL=1 \
  sh "$INJSH" FakeApp "$T/fgstamp" 'hello' > "$T/fg_e" 2>&1 && rc=0 || rc=$?
d=$(( $(date +%s) - t0 ))
if [ "$rc" = 1 ]; then ok "returns 1 for a lock path that cannot be created"
else bad "returned $rc for an impossible path, where 75 would quarantine the watcher for nothing"; fi
check "and names the path rather than blaming another injector" \
      "cannot create its foreground lock at $T/no-such-dir/deeper/lock" "$T/fg_e"
if grep -q "another injector" "$T/fg_e" 2>/dev/null; then
  bad "it blamed another injector for a path that does not exist"
else ok "and says no other injector is involved"; fi
if [ "$d" -lt 10 ]; then ok "and says so at once rather than waiting out FGWAIT"
else bad "waited ${d}s on a path that can never appear"; fi

# (f) A NAME THAT IS NOT ONE OF OUR SYMLINKS IS NEVER REMOVED. The first
# version released with rm -rf on the caller-named path, so pointing the
# dial at a real directory erased it. Measured by the Codex seat.
VIC="$T/victim"
rm -rf "$VIC"; mkdir -p "$VIC"; echo keep > "$VIC/sentinel"; echo not-a-pid > "$VIC/pid"
FGLOCK="$VIC" FGWAIT=3 ACK=1 TIMEOUT=2 SETTLE=1 POLL=1 \
  sh "$INJSH" FakeApp "$T/fgstamp" 'hello' > "$T/fg_f" 2>&1 && rc=0 || rc=$?
if [ -f "$VIC/sentinel" ]; then ok "refuses a lock path holding something that is not its own symlink"
else bad "it deleted a directory it was pointed at, which is the data loss this case exists for"; fi
if [ "$rc" = 1 ]; then ok "and returns 1, since nothing there will clear by itself"
else bad "returned $rc where the path is permanently unusable"; fi
check "and says what it refused and that it removed nothing" \
      "not one of its own symlinks" "$T/fg_f"

# (g) TWO INJECTORS MUST NOT DRIVE THE KEYBOARD TOGETHER, which is the whole
# reason the lock exists. Each fake backend records the interval it held
# the keyboard, and the intervals must not overlap.
rm -f "$FG"; SPAN="$T/fgspan"; : > "$SPAN"
FGSPAN="$SPAN" FGHOLD=2 FGWAIT=30 FGLOCK="$FG" ACK=1 TIMEOUT=3 SETTLE=1 POLL=1 \
  sh "$INJSH" FakeApp "$T/fgstamp1" 'one' > "$T/fg_g1" 2>&1 &
g1=$!
FGSPAN="$SPAN" FGHOLD=2 FGWAIT=30 FGLOCK="$FG" ACK=1 TIMEOUT=3 SETTLE=1 POLL=1 \
  sh "$INJSH" FakeApp "$T/fgstamp2" 'two' > "$T/fg_g2" 2>&1 &
g2=$!
wait $g1 2>/dev/null || true
wait $g2 2>/dev/null || true
# FIRST IN AND LAST OUT PER INJECTOR, not the last call of each. The
# injector drives the backend several times per delivery, so keeping only
# the latest interval measures the tail of each run: two injectors racing
# through interleaved calls can finish with adjacent tails and pass a test
# that only compares those. The critical section is the whole span.
ov=$(awk '$1=="in"{ if (!($2 in fin)) fin[$2]=$3 }
  $1=="out"{ lout[$2]=$3 }
  END{n=0; for (p in fin) { for (q in fin) { if (p<q) {
        if (fin[p] < lout[q] && fin[q] < lout[p]) n++ } } } print n+0}' "$SPAN")
spans=$(grep -c '^in ' "$SPAN" 2>/dev/null || echo 0)
if [ "$spans" -ge 2 ]; then ok "both injectors reached the keyboard, so the case has something to compare"
else bad "only $spans injector reached the keyboard, so an overlap could not have shown"; fi
if [ "${ov:-1}" = 0 ]; then ok "and their keyboard intervals do not overlap, which is what the lock is for"
else bad "$ov pair of injectors drove the keyboard at the same time"; fi
PATH=$OLDPATH; export PATH

echo "40. a pasteboard the injector cannot carry is named, not silently emptied"
# MEASURED ON A REAL MAC and reported by a seat: with an image on the
# pasteboard the text read returns nothing, so the snapshot is empty, and
# restoring that empty snapshot CLEARS the pasteboard. The image was already
# lost when the line was copied, which no text-only path can prevent, but
# emptying it afterwards is an extra harm and a silent one. The fixture below
# is a pasteboard that reads as empty text while the system reports it holds
# something, which is exactly that state.
RC="$T/fake-rich"
mkdir -p "$RC"
cat > "$RC/pbpaste" <<PB
#!/bin/sh
if [ -f "$RC/clip" ]; then cat "$RC/clip"; fi
PB
cat > "$RC/pbcopy" <<PB
#!/bin/sh
cat > "$RC/clip"
PB
# the system says there IS something on the pasteboard, and it is not text
cat > "$RC/osascript" <<PB
#!/bin/sh
case "\$*" in
  *"clipboard info"*) echo "«class PNGf», 84210"; exit 0 ;;
  *-e*) : ;;                     # the -e form pipes nothing, see case 39
  *) cat >/dev/null 2>&1 ;;
esac
echo "fake composer"
PB
chmod +x "$RC/pbpaste" "$RC/pbcopy" "$RC/osascript"
rm -f "$RC/clip"            # empty text read, which is what an image looks like
OLDPATH=$PATH
PATH="$RC:$PATH"; export PATH
FGLOCK="$T/fglock2" FGWAIT=5 ACK=1 TIMEOUT=2 SETTLE=1 POLL=1 \
  sh "$INJSH" FakeApp "$T/rcstamp" 'the instruction' > "$T/rc.log" 2>&1 && rc=0 || rc=$?
check "says the pasteboard held something it cannot carry" \
      "not plain text" "$T/rc.log"
if [ -s "$RC/clip" ]; then
  ok "and leaves the injected line there rather than emptying the pasteboard"
else
  bad "it emptied the pasteboard, which is the extra harm this case exists for"
fi
PATH=$OLDPATH; export PATH

echo "41. the outbox is rewritten without changing how many entries it has"
# A COUNT IS NOT AN APPEND-ONLY CHECK, and the watcher used to claim it was:
# "A REAL REWRITE STILL SHRINKS THIS COUNT". Measured false by the Codex seat.
# Remove one entry and add another and the count does not move, so a rewrite of
# everything already reported took the "no new outbox entries" path and the
# operator was told nothing had happened. The two halves below are the ones
# that discriminate: a same-count rewrite must alarm, and ordinary appending
# must still not, because a false alarm on an integrity alarm teaches the
# reader to skip the one line that must never be skipped.
cd "$T"; git init -q --bare origin41.git
git clone -q origin41.git s41 2>/dev/null
cd "$T/s41"; git config user.email s@example.invalid; git config user.name s
mkdir -p collab
printf -- '- one\n- two\n- three\n' > collab/OUTBOX_a.md
git add -A; git commit -qm seed >/dev/null 2>&1
git push -q origin HEAD:refs/heads/sub/a 2>/dev/null
cd "$T"; git clone -q origin41.git m41 2>/dev/null
cd "$T/m41"; git config user.email m@example.invalid; git config user.name m
( cd "$T/m41" && P=2 sh "$OUTSH" a sub/a collab > "$T/ob41.log" 2>&1 & echo $! > "$T/ob41.pid" )
t0=$(date +%s); while ! grep -q ARMED "$T/ob41.log" 2>/dev/null; do
  sleep 1; [ $(( $(date +%s) - t0 )) -gt 25 ] && break; done
check "arms on the three entries it can see" "ARMED on sub/a at head .*, 3 entries" "$T/ob41.log"

# ORDINARY APPENDING FIRST, so the alarm below cannot be an alarm that is
# simply always on.
cd "$T/s41"; printf -- '- one\n- two\n- three\n- four\n' > collab/OUTBOX_a.md
git add -A; git commit -qm append >/dev/null 2>&1
git push -q origin HEAD:refs/heads/sub/a 2>/dev/null
t0=$(date +%s); while ! grep -q -- '- four' "$T/ob41.log" 2>/dev/null; do
  sleep 1; [ $(( $(date +%s) - t0 )) -gt 25 ] && break; done
check "delivers an appended entry" "^- four" "$T/ob41.log"
if grep -q "OUTBOX REWRITTEN" "$T/ob41.log" 2>/dev/null; then
  bad "called an ordinary append a rewrite, which is the false alarm"
else ok "and does not call an ordinary append a rewrite"; fi

# NOW THE REWRITE. Entries one and three are replaced and the count holds at
# four, which is the exact shape a count cannot see.
cd "$T/s41"; printf -- '- ONE REPLACED\n- two\n- THREE REPLACED\n- four\n' > collab/OUTBOX_a.md
git add -A; git commit -qm rewrite >/dev/null 2>&1
git push -q origin HEAD:refs/heads/sub/a 2>/dev/null
t0=$(date +%s); while ! grep -q "OUTBOX REWRITTEN" "$T/ob41.log" 2>/dev/null; do
  sleep 1; [ $(( $(date +%s) - t0 )) -gt 25 ] && break; done
check "alarms when reported entries are replaced under an unchanged count" \
      "OUTBOX REWRITTEN" "$T/ob41.log"
if grep -q "sub-session pushed .* (no new outbox entries)" "$T/ob41.log" 2>/dev/null &&
   ! grep -q "OUTBOX REWRITTEN" "$T/ob41.log" 2>/dev/null; then
  bad "reported the rewrite as a push carrying nothing, which is what it used to do"
else ok "and does not report it as a push carrying nothing"; fi
check "and shows the file as it stands, since the record of it is now wrong" \
      "ONE REPLACED" "$T/ob41.log"

# REMOVAL PLUS ADDITION, the other same-count shape. The log already holds
# one alarm, so this counts them rather than searching for the words again.
was=$(grep -c "OUTBOX REWRITTEN" "$T/ob41.log" 2>/dev/null || echo 0)
cd "$T/s41"; printf -- '- ONE REPLACED\n- two\n- THREE REPLACED\n- five instead\n' > collab/OUTBOX_a.md
git add -A; git commit -qm swap >/dev/null 2>&1
git push -q origin HEAD:refs/heads/sub/a 2>/dev/null
t0=$(date +%s); while [ "$(grep -c 'OUTBOX REWRITTEN' "$T/ob41.log" 2>/dev/null || echo 0)" -le "$was" ]; do
  sleep 1; [ $(( $(date +%s) - t0 )) -gt 25 ] && break; done
now=$(grep -c "OUTBOX REWRITTEN" "$T/ob41.log" 2>/dev/null || echo 0)
if [ "$now" -gt "$was" ]; then
  ok "an entry removed and another added raises the alarm too, not only a replacement in place"
else bad "a removal plus an addition passed unseen, which is the same-count hole"; fi
stop "$T/m41/.git/outbox_watch_a.pid"

echo "42. a pid number is not an identity, and a supervisor must not kill a stranger"
# `kill -0` proves that SOME process owns that number today, and pid numbers
# are reused. Measured by the Codex seat: an unrelated sleep whose pid happened
# to sit in a state file was announced as an orphaned watcher and killed. A
# supervisor that kills a stranger is worse than one that does nothing.
cd "$T"; git init -q --bare origin42.git
git clone -q origin42.git m42 2>/dev/null
cd "$T/m42"; git config user.email m@example.invalid; git config user.name m
mkdir -p collab; printf -- '- one\n' > collab/INBOX_z.md
git add -A; git commit -qm seed >/dev/null 2>&1
git push -q origin HEAD:refs/heads/main 2>/dev/null
G42="$T/m42/.git"
# a live process that has nothing whatever to do with this seat
sleep 120 & stranger=$!
echo $stranger > "$G42/inbox_watch_z.pid"
( cd "$T/m42" && sh "$SUPSH" inbox z main collab > "$T/sup42.log" 2>&1 & echo $! > "$T/sup42.pid" )
t0=$(date +%s); while ! grep -q "REFUSING to adopt" "$T/sup42.log" 2>/dev/null; do
  sleep 1; [ $(( $(date +%s) - t0 )) -gt 20 ] && break; done
check "refuses to adopt when the recorded pid is not one of its watchers" \
      "REFUSING to adopt z" "$T/sup42.log"
if kill -0 $stranger 2>/dev/null; then
  ok "and the unrelated process it was pointed at is still alive"
else
  bad "it killed a process that had nothing to do with this seat"
fi
if [ -f "$G42/inbox_watch_z.pid" ]; then
  ok "and it left the record alone rather than clearing evidence it did not understand"
else bad "it removed the pid file it had just refused to act on"; fi
check "and says what that process actually is" "It is running:" "$T/sup42.log"
kill $stranger 2>/dev/null || true
stop "$T/sup42.pid"
rm -f "$G42/inbox_watch_z.pid"

# THE SAME NUMBER MUST NOT LOCK A SEAT OUT OF ARMING EITHER.
sleep 120 & stranger2=$!
echo $stranger2 > "$G42/inbox_watch_z.pid"
( cd "$T/m42" && P=2 sh "$INSH" z main collab > "$T/arm42.log" 2>&1 & echo $! > "$T/arm42.pid" )
t0=$(date +%s); while ! grep -q "ARMED" "$T/arm42.log" 2>/dev/null; do
  sleep 1; [ $(( $(date +%s) - t0 )) -gt 20 ] && break; done
check "arms anyway when the recorded pid belongs to something else" "ARMED" "$T/arm42.log"
check "and says why it treated the record as stale" "is alive but is not a" "$T/arm42.log"
if kill -0 $stranger2 2>/dev/null; then
  ok "and that process is untouched, since arming never signals anybody"
else bad "arming killed an unrelated process"; fi
kill $stranger2 2>/dev/null || true
stop "$T/arm42.pid"

echo "43. reclaiming a dead injector's lock cannot take a live one with it"
# A read followed by rm is not compare-and-delete. Two reclaimers both see the
# dead token, the first removes it, a live injector installs its own, and the
# second removes THAT. Reclaimers are serialised behind an atomic create and
# the winner re-reads after taking it.
RL="$T/fglock43"
rm -f "$RL" "$RL.reclaim"
# the reclaim lock is held by a LIVE process, so no reclaim may proceed
ln -s "999998.inj-999998-1" "$RL"
sleep 60 & holder43=$!
ln -s "reclaim.$holder43" "$RL.reclaim"
OLDPATH=$PATH; PATH="$LK:$PATH"; export PATH
FGLOCK="$RL" FGWAIT=3 ACK=1 TIMEOUT=2 SETTLE=1 POLL=1 \
  sh "$INJSH" FakeApp "$T/rl43" 'hello' > "$T/rl43.log" 2>&1 && rc=0 || rc=$?
if [ -L "$RL" ]; then
  ok "leaves a dead holder's lock alone while another injector is reclaiming"
else
  bad "two reclaimers could both have removed it, which is the race this case exists for"
fi
if [ "$rc" = 1 ]; then ok "and returns 1 while it could not take the lock, since nothing was typed"
else bad "returned $rc while it could not take the lock, where 1 is what the contract calls this"; fi
kill $holder43 2>/dev/null || true

# A RECLAIM LOCK WHOSE OWNER IS GONE MUST NOT BLOCK RECLAIM FOR EVER.
rm -f "$RL.reclaim"; ln -s "reclaim.999997" "$RL.reclaim"
: > "$LK/ran"
FGLOCK="$RL" FGWAIT=10 ACK=1 TIMEOUT=2 SETTLE=1 POLL=1 \
  sh "$INJSH" FakeApp "$T/rl43b" 'hello' > "$T/rl43b.log" 2>&1 && rc=0 || rc=$?
check "breaks the dead holder's lock once the stale reclaim is cleared" \
      "broke a foreground lock left by pid 999998" "$T/rl43b.log"
if [ -s "$LK/ran" ]; then ok "and goes on to drive the application"
else bad "reclaimed nothing and never reached the backend"; fi
if [ -e "$RL.reclaim" ] || [ -L "$RL.reclaim" ]; then
  bad "the reclaim lock outlived the injector that took it"
else ok "and leaves no reclaim lock behind"; fi
PATH=$OLDPATH; export PATH

echo "44. a notifier that is installed and fails says so, and still exits zero"
# Swallowing the failure is right, since a view of the work must never stop the
# work. Swallowing the DIAGNOSTIC too makes the view silently false: the
# operator believes they are being told about alarms and they are not. Measured
# by the Codex seat with a present notify-send returning 1, which produced zero
# bytes on both streams.
FN="$T/fake-notifier"; mkdir -p "$FN"
printf '#!/bin/sh\nexit 1\n' > "$FN/notify-send"; chmod +x "$FN/notify-send"
out=$(PATH="$FN:$PATH" NOTIFY_BACKEND=notify-send NOTIFY_STATE=alarm \
      NOTIFY_TEXT='a seat has gone quiet' sh "$NOTSH" Peer Self 2>&1) && rc=0 || rc=$?
if [ "$rc" = 0 ]; then ok "exits zero even when the backend it found fails"
else bad "returned $rc, so a broken notifier could stop the bus"; fi
case $out in
  *"is installed and it failed"*) ok "and says the backend failed rather than staying silent" ;;
  *) bad "said nothing at all, so the operator believes a notification was shown" ;;
esac
case $out in
  *"NOT shown"*) ok "and says plainly that no notification exists" ;;
  *) bad "the diagnostic does not say the notification was never shown" ;;
esac
case $out in
  *"The work carried on"*) ok "and that the work was not affected" ;;
  *) bad "does not say the work carried on, which is the reader's first question" ;;
esac
# AND A WORKING BACKEND MUST STAY QUIET, or the diagnostic is just noise.
printf '#!/bin/sh\nexit 0\n' > "$FN/notify-send"
out2=$(PATH="$FN:$PATH" NOTIFY_BACKEND=notify-send NOTIFY_STATE=started \
       NOTIFY_TEXT='ordinary' sh "$NOTSH" Peer Self 2>&1) || true
if [ -z "$out2" ]; then ok "and says nothing when the backend works"
else bad "spoke on a successful notification: $out2"; fi

echo "45. a turn that ends is not a turn that did the work"
# THE CODEX SEAT, asked whether it would run a seat unattended overnight, said
# no and named this: the protocol proves a turn was queued and ENDED and cannot
# prove the named instruction was CARRIED OUT, so a seat that starts, fails
# quietly and stops returns the same zero as one that did the work. With
# ACK_BRANCH set the change is not consumed until the seat's own branch says
# so, which turns silence from an ambiguous success signal into durable
# unfinished state. Subcase (c) is the one that protects every lane already
# running: with the dial unset, nothing about this changes.
cd "$T"; git init -q --bare origin45.git
git clone -q origin45.git m45 2>/dev/null
cd "$T/m45"; git config user.email m@example.invalid; git config user.name m
mkdir -p collab
printf -- '# Inbox\n\n## Open instructions\n\n- ZZ-1: do the thing.\n\n## Closed\n' > collab/INBOX_z.md
printf -- '- nothing yet\n' > collab/OUTBOX_z.md
git add -A; git commit -qm seed >/dev/null 2>&1
git push -q origin HEAD:refs/heads/main 2>/dev/null
git push -q origin HEAD:refs/heads/sub/z 2>/dev/null
G45="$T/m45/.git"

# (a) A SEAT THAT ACKNOWLEDGES reaches handled, and says what satisfied it.
cat > "$T/turn45a.sh" <<'TS'
#!/bin/sh
exit 0
TS
chmod +x "$T/turn45a.sh"
( cd "$T/m45" && P=2 ACK_BRANCH=sub/z ACK_WAIT=1 NAG=1 ON_CHANGE="sh $T/turn45a.sh" \
    sh "$INSH" z main collab > "$T/ack45a.log" 2>&1 & echo $! > "$T/ack45a.pid" )
t0=$(date +%s); while ! grep -q "acknowledgement gate is ON" "$T/ack45a.log" 2>/dev/null; do
  sleep 1; [ $(( $(date +%s) - t0 )) -gt 25 ] && break; done
check "says the gate is on and what it will wait for" \
      "acknowledgement gate is ON" "$T/ack45a.log"
# REV-F47: the seat that defeated this gate for three days put every marker in
# its outbox, where the gate never looks, because nothing at arm time said
# where it reads. The arming line now names the commit subject.
check "and names the commit subject as the one place it reads" \
      "in a commit subject on" "$T/ack45a.log"
# the inbox changes, the turn runs, and the change must NOT be handled yet
cd "$T/m45"; printf -- '# Inbox\n\n## Open instructions\n\n- ZZ-1: do the thing.\n- ZZ-2: and this one.\n\n## Closed\n' > collab/INBOX_z.md
git add -A; git commit -qm inst >/dev/null 2>&1; git push -q origin HEAD:refs/heads/main 2>/dev/null
t0=$(date +%s); while ! grep -q "NOT recorded handled yet" "$T/ack45a.log" 2>/dev/null; do
  sleep 1; [ $(( $(date +%s) - t0 )) -gt 30 ] && break; done
check "a turn that ends does not consume the change" \
      "NOT recorded handled yet" "$T/ack45a.log"
# now the seat acknowledges on its own branch
cd "$T/m45"; git checkout -q -B sub/z origin/sub/z 2>/dev/null
printf -- '- did it [done: ZZ-1] [done: ZZ-2]\n' > collab/OUTBOX_z.md
git add -A; git commit -qm 'seat acks [done: ZZ-1] [done: ZZ-2]' >/dev/null 2>&1
git push -q origin HEAD:refs/heads/sub/z 2>/dev/null
git checkout -q main 2>/dev/null || git checkout -q -B main origin/main 2>/dev/null
t0=$(date +%s); while ! grep -q "ACKNOWLEDGED:" "$T/ack45a.log" 2>/dev/null; do
  sleep 1; [ $(( $(date +%s) - t0 )) -gt 30 ] && break; done
check "and reaches handled once the seat's branch carries the markers" \
      "ACKNOWLEDGED:" "$T/ack45a.log"
stop "$T/ack45a.pid"

# (b) A SEAT THAT ENDS ITS TURN AND NEVER ACKNOWLEDGES must alarm, and the
# turn must NOT be run again, because it ran.
rm -f "$G45/inbox_watch_y" "$G45/inbox_watch_y.ackbase"
cd "$T/m45"; git checkout -q main 2>/dev/null
printf -- '# Inbox\n\n## Open instructions\n\n- YY-1: do it.\n\n## Closed\n' > collab/INBOX_y.md
printf -- '- quiet\n' > collab/OUTBOX_y.md
git add -A; git commit -qm seedy >/dev/null 2>&1; git push -q origin HEAD:refs/heads/main 2>/dev/null
git push -q origin HEAD:refs/heads/sub/y 2>/dev/null
: > "$T/turns45b"
cat > "$T/turn45b.sh" <<TS
#!/bin/sh
echo ran >> "$T/turns45b"
exit 0
TS
chmod +x "$T/turn45b.sh"
( cd "$T/m45" && P=2 ACK_BRANCH=sub/y ACK_WAIT=2 NAG=2 ON_CHANGE="sh $T/turn45b.sh" \
    sh "$INSH" y main collab > "$T/ack45b.log" 2>&1 & echo $! > "$T/ack45b.pid" )
t0=$(date +%s); while ! grep -q ARMED "$T/ack45b.log" 2>/dev/null; do
  sleep 1; [ $(( $(date +%s) - t0 )) -gt 25 ] && break; done
cd "$T/m45"; printf -- '# Inbox\n\n## Open instructions\n\n- YY-1: do it.\n- YY-2: and this.\n\n## Closed\n' > collab/INBOX_y.md
git add -A; git commit -qm insty >/dev/null 2>&1; git push -q origin HEAD:refs/heads/main 2>/dev/null
t0=$(date +%s); while ! grep -q "STILL UNACKNOWLEDGED" "$T/ack45b.log" 2>/dev/null; do
  sleep 1; [ $(( $(date +%s) - t0 )) -gt 40 ] && break; done
check "alarms when a turn ends and the seat never acknowledges" \
      "STILL UNACKNOWLEDGED" "$T/ack45b.log"
check "and names the instruction that is unanswered" "YY-2" "$T/ack45b.log"
check "and says the turn is not being re-run, because it ran" \
      "NOT being re-run" "$T/ack45b.log"
# THE PROPERTY IS NOT "ONE TURN EVER", which is what this asked for first and
# which was the check failing on correct work. Two turns ran here and both were
# right: the cold start delivers the inbox it found, and the pushed change is a
# second, distinct inbox. What must NOT happen is a THIRD turn while the change
# sits unacknowledged, because that would be re-running a turn that ended.
was=$(wc -l < "$T/turns45b" | tr -d ' ')
sleep 8
now=$(wc -l < "$T/turns45b" | tr -d ' ')
if [ "${now:-0}" = "${was:-0}" ]; then
  ok "and no further turn starts while the change is unacknowledged, over four more polls"
else
  bad "the turn count went from $was to $now while unacknowledged, so an ended turn is being retried"
fi
if [ "${was:-0}" -ge 1 ]; then ok "and a turn had really been started, so the count is not vacuous"
else bad "no turn ever ran, so this case measured nothing"; fi
stop "$T/ack45b.pid"

# (c) WITH THE DIAL UNSET NOTHING CHANGES, which is what makes this safe to
# ship while four lanes are live on this bus.
rm -f "$G45/inbox_watch_x" "$G45/inbox_watch_x.ackbase"
cd "$T/m45"; git checkout -q main 2>/dev/null
printf -- '# Inbox\n\n## Open instructions\n\n- XX-1: do it.\n\n## Closed\n' > collab/INBOX_x.md
git add -A; git commit -qm seedx >/dev/null 2>&1; git push -q origin HEAD:refs/heads/main 2>/dev/null
( cd "$T/m45" && P=2 ON_CHANGE="sh $T/turn45a.sh" \
    sh "$INSH" x main collab > "$T/ack45c.log" 2>&1 & echo $! > "$T/ack45c.pid" )
t0=$(date +%s); while ! grep -q ARMED "$T/ack45c.log" 2>/dev/null; do
  sleep 1; [ $(( $(date +%s) - t0 )) -gt 25 ] && break; done
check "says plainly that the gate is off when no branch is named" \
      "acknowledgement gate is OFF" "$T/ack45c.log"
check "and that no notifier is wired, the other dial an operator cannot see from silence" \
      "NO NOTIFIER IS WIRED" "$T/ack45c.log"
cd "$T/m45"; printf -- '# Inbox\n\n## Open instructions\n\n- XX-1: do it.\n- XX-2: more.\n\n## Closed\n' > collab/INBOX_x.md
git add -A; git commit -qm instx >/dev/null 2>&1; git push -q origin HEAD:refs/heads/main 2>/dev/null
t0=$(date +%s); while ! grep -q "the turn finished" "$T/ack45c.log" 2>/dev/null; do
  sleep 1; [ $(( $(date +%s) - t0 )) -gt 30 ] && break; done
check "and a finished turn still consumes the change with the gate off" \
      "the turn finished" "$T/ack45c.log"
absent "with no mention of waiting for an acknowledgement" \
       "NOT recorded handled yet" "$T/ack45c.log"
h=$(awk 'NR==1{print $3}' "$G45/inbox_watch_x" 2>/dev/null)
if [ "${h:-handled}" = handled ]; then ok "and the state file records it handled, exactly as before"
else bad "the state says '$h' where the gate is off"; fi
stop "$T/ack45c.pid"

echo "46. a watcher that stayed up is not a watcher that keeps crashing"
# THE LADDER USED TO CLIMB ON A LIFETIME COUNTER. Three exits separated by days
# of healthy running backed off exactly as far as three crashes in a row, so the
# supervisor was slowest at the moment it is meant to be quickest. STABLE was
# added this morning with no behavioural case at all, which the Codex seat
# named: only its default was visible, through the settings-table parser. A
# dial nobody exercises is a dial nobody has tested.
cd "$T"; git init -q --bare origin46.git
git clone -q origin46.git m46 2>/dev/null
cd "$T/m46"; git config user.email m@example.invalid; git config user.name m
mkdir -p collab; printf -- '- one\n' > collab/INBOX_s.md
git add -A; git commit -qm seed >/dev/null 2>&1
git push -q origin HEAD:refs/heads/main 2>/dev/null
# a fake watcher that stays up longer than STABLE, then exits
FW="$T/fakewatch"; mkdir -p "$FW"
cat > "$FW/watch-inbox.sh" <<WS
#!/bin/sh
echo "fake watcher up as \$\$"
sleep 3
echo "fake watcher exiting"
exit 7
WS
chmod +x "$FW/watch-inbox.sh"
cp "$HERE/supervise.sh" "$FW/supervise.sh"
( cd "$T/m46" && STABLE=2 sh "$FW/supervise.sh" inbox s main collab > "$T/sup46.log" 2>&1 &
  echo $! > "$T/sup46.pid" )
t0=$(date +%s); while [ "$(grep -c 'stability window' "$T/sup46.log" 2>/dev/null)" -lt 1 ]; do
  sleep 1; [ $(( $(date +%s) - t0 )) -gt 40 ] && break; done
check "says the ladder starts again after a watcher stayed up past STABLE" \
      "stability window" "$T/sup46.log"
check "and names how long it had been up, so the judgement is visible" \
      "had been up [0-9]*s before this exit" "$T/sup46.log"
# the restart after a stable run must be a QUICK one, not a climbed one.
# READ AFTER THE STABILITY LINE, NEVER OVER THE WHOLE LOG. Every run climbs
# through `restart 1` on its way up, so a whole-log grep found that first
# restart and reported it as the reset: with the reset deleted from the
# supervisor, all three assertions here still passed.
first_stable_restart() {
  awk '/stability window/{seen=1;next}
       seen && /restart [0-9]* in [0-9]*s/{print;exit}' "$T/sup46.log"
}
t0=$(date +%s)
while [ -z "$(first_stable_restart)" ]; do
  sleep 1; [ $(( $(date +%s) - t0 )) -gt 40 ] && break
done
if first_stable_restart | grep -q "restart 1 in 10s"; then
  ok "and the restart after it is the quick one rather than a climbed one"
else
  bad "the ladder did not reset: after the stability line the next restart was $(first_stable_restart | grep -o 'restart [0-9]* in [0-9]*s')"
fi
stop "$T/sup46.pid"

# AND IT MUST NOT RESET ON A WATCHER THAT DIES AT ONCE, or the backoff is gone.
cat > "$FW/watch-inbox.sh" <<WS
#!/bin/sh
exit 7
WS
chmod +x "$FW/watch-inbox.sh"
( cd "$T/m46" && STABLE=600 sh "$FW/supervise.sh" inbox s main collab > "$T/sup46b.log" 2>&1 &
  echo $! > "$T/sup46b.pid" )
t0=$(date +%s); while ! grep -q "restart 2 in" "$T/sup46b.log" 2>/dev/null; do
  sleep 1; [ $(( $(date +%s) - t0 )) -gt 40 ] && break; done
absent "a watcher that dies at once never claims a stability window" \
       "stability window" "$T/sup46b.log"
check "and its restarts keep climbing" "restart 2 in" "$T/sup46b.log"
stop "$T/sup46b.pid"

echo "47. a corrupt record must not convict an innocent history"
# THE FALSE ALARM THIS ANSWERS WAS MEASURED 27 AUGUST: a state record whose
# count exceeded the body its digest covered made the watcher report a rewrite
# on a branch whose every fetch had been a fast-forward. Three doors into the
# same verdict are graded here. A LEGACY record, three fields and no digest,
# with a count inflated past the body at its own head, seeds `short` there and
# says the recording never covered its count. A record whose digest is REAL
# but covers fewer entries than the count beside it fails to reproduce at its
# own head and convicts nobody. And a stored literal `short` is caught by the
# marker itself. The TRUE alarms' half of the discrimination lives in cases 5,
# 38 and 41, which this suite runs on the same code: a real shrink, a real
# truncation and a real rewrite must all still alarm, so a fix that swallowed
# them would fail there, which is exactly what the first draft of this guard
# did. On the pre-fix watcher every door here raises the false REWRITTEN.
cd "$T"; git init -q --bare origin47.git
git clone -q origin47.git s47 2>/dev/null
cd "$T/s47"; git config user.email s@example.invalid; git config user.name s
mkdir -p collab
printf -- '- one\n- two\n- three\n' > collab/OUTBOX_a.md
git add -A; git commit -qm seed >/dev/null 2>&1
git push -q origin HEAD:refs/heads/sub/a 2>/dev/null
cd "$T"; git clone -q origin47.git m47 2>/dev/null
cd "$T/m47"; git config user.email m@example.invalid; git config user.name m
( cd "$T/m47" && P=2 sh "$OUTSH" a sub/a collab > "$T/ob47.log" 2>&1 & echo $! > "$T/ob47.pid" )
t0=$(date +%s); while ! grep -q ARMED "$T/ob47.log" 2>/dev/null; do
  sleep 1; [ $(( $(date +%s) - t0 )) -gt 25 ] && break; done
stop "$T/m47/.git/outbox_watch_a.pid"
# a cold start holds no record, so the record verdicts have nothing to say:
# the shipped code accused an empty head here, in the credibility-bearing voice
absent "a genuine cold start verifies nothing and accuses nobody" \
       "CANNOT VERIFY" "$T/ob47.log"
# DOOR ONE, THE LEGACY RECORD. The cold start above saved three fields and no
# digest, which is exactly what a pre-marker deployment left on disk. Inflate
# its count past the three entries its head carries: the seed at that head can
# only answer `short`, and short is a cannot-verify, never an accusation.
S47="$T/m47/.git/outbox_watch_a"
h1=$(awk 'NR==1{print $1}' "$S47")
printf '%s 5 b\n' "$h1" > "$S47"
# the seat appends three entries while the watcher is down: append-only,
# every push a fast-forward, nothing for an honest alarm to say
cd "$T/s47"
printf -- '- one\n- two\n- three\n- four\n- five\n- six\n' > collab/OUTBOX_a.md
git add -A; git commit -qm append >/dev/null 2>&1
git push -q origin HEAD:refs/heads/sub/a 2>/dev/null
( cd "$T/m47" && P=2 sh "$OUTSH" a sub/a collab > "$T/ob47b.log" 2>&1 & echo $! > "$T/ob47b.pid" )
t0=$(date +%s); while ! grep -q "CANNOT VERIFY THE OUTBOX HISTORY" "$T/ob47b.log" 2>/dev/null; do
  sleep 1; [ $(( $(date +%s) - t0 )) -gt 30 ] && break; done
absent "does not report a rewrite on an untouched history" \
       "OUTBOX REWRITTEN" "$T/ob47b.log"
absent "and does not report a shrink there either" \
       "OUTBOX SHRANK" "$T/ob47b.log"
check "says the legacy recording never covered its own count" \
      "never covered its own count" "$T/ob47b.log"
check "and shows the file it re-seeded from, entries included" \
      "^- six" "$T/ob47b.log"
# the reseed must leave a working watcher behind
cd "$T/s47"; printf -- '- seven arrives after the reseed\n' >> collab/OUTBOX_a.md
git add -A; git commit -qm seven >/dev/null 2>&1
git push -q origin HEAD:refs/heads/sub/a 2>/dev/null
t0=$(date +%s); while ! grep -q "seven arrives" "$T/ob47b.log" 2>/dev/null; do
  sleep 1; [ $(( $(date +%s) - t0 )) -gt 25 ] && break; done
check "delivers the next entry normally after the reseed" \
      "OUTBOX new entries:" "$T/ob47b.log"
stop "$T/m47/.git/outbox_watch_a.pid"
# DOOR TWO, THE POISONED COUNT BESIDE A REAL DIGEST, which is the measured
# record's exact shape. The delivery of seven wrote a genuine four-field
# record: keep its head and its digest and inflate only the count, so the
# digest is real and covers fewer entries than the count claims. The watcher
# must re-derive the record at its own head, find it short of nine there, and
# convict nobody.
h3=$(awk 'NR==1{print $1}' "$S47"); d3=$(awk 'NR==1{print $4}' "$S47")
printf '%s 9 b %s\n' "$h3" "$d3" > "$S47"
cd "$T/s47"
printf -- '- eight\n- nine\n- ten\n' >> collab/OUTBOX_a.md
git add -A; git commit -qm more >/dev/null 2>&1
git push -q origin HEAD:refs/heads/sub/a 2>/dev/null
( cd "$T/m47" && P=2 sh "$OUTSH" a sub/a collab > "$T/ob47c.log" 2>&1 & echo $! > "$T/ob47c.pid" )
t0=$(date +%s); while ! grep -q "CANNOT VERIFY THE OUTBOX HISTORY" "$T/ob47c.log" 2>/dev/null; do
  sleep 1; [ $(( $(date +%s) - t0 )) -gt 30 ] && break; done
absent "a real digest with an inflated count raises no rewrite alarm" \
       "OUTBOX REWRITTEN" "$T/ob47c.log"
check "it fails at its own head and the record convicts nobody" \
      "the record is corrupt and convicts nobody" "$T/ob47c.log"
check "and the reseed shows the file as it stands" \
      "^- ten" "$T/ob47c.log"
stop "$T/m47/.git/outbox_watch_a.pid"
# DOOR THREE, A RECORDED `short` BY THE FRONT DOOR: the fixed recorder writes
# it whenever a count it is given exceeds the body, so the guard has to catch
# the marker itself.
h4=$(awk 'NR==1{print $1}' "$S47"); n4=$(awk 'NR==1{print $2}' "$S47")
printf '%s %s b short\n' "$h4" "$n4" > "$S47"
cd "$T/s47"; printf -- '- eleven\n' >> collab/OUTBOX_a.md
git add -A; git commit -qm eleven >/dev/null 2>&1
git push -q origin HEAD:refs/heads/sub/a 2>/dev/null
( cd "$T/m47" && P=2 sh "$OUTSH" a sub/a collab > "$T/ob47d.log" 2>&1 & echo $! > "$T/ob47d.pid" )
t0=$(date +%s); while ! grep -q "never covered its own count" "$T/ob47d.log" 2>/dev/null; do
  sleep 1; [ $(( $(date +%s) - t0 )) -gt 30 ] && break; done
check "treats a recorded short marker as cannot-verify, not as an alarm" \
      "never covered its own count" "$T/ob47d.log"
absent "and raises no rewrite alarm on it" "OUTBOX REWRITTEN" "$T/ob47d.log"
absent "and no shrink alarm either" "OUTBOX SHRANK" "$T/ob47d.log"
stop "$T/m47/.git/outbox_watch_a.pid"

echo "48. a watcher armed on existing history guards it from the arming"
# REV-F46, found by the review seat on the shipped tree: the cold start seeded
# the count and not the digest, and every verdict sits behind a recorded
# digest, so until the first new entry the append-only check was unarmed. A
# same-count force-push rewrite and a shrink both reported as "no new outbox
# entries", in the exact window where a master arms on a working seat's
# history and waits. The cold seed now digests the body it counted, so the
# watch begins at the arming and not at the first delivery.
cd "$T"; git init -q --bare origin48.git
git clone -q origin48.git s48 2>/dev/null
cd "$T/s48"; git config user.email s@example.invalid; git config user.name s
mkdir -p collab
printf -- '- first\n- second\n- third\n' > collab/OUTBOX_a.md
git add -A; git commit -qm seed >/dev/null 2>&1
git push -q origin HEAD:refs/heads/sub/a 2>/dev/null
cd "$T"; git clone -q origin48.git m48 2>/dev/null
cd "$T/m48"; git config user.email m@example.invalid; git config user.name m
( cd "$T/m48" && P=2 sh "$OUTSH" a sub/a collab > "$T/ob48.log" 2>&1 & echo $! > "$T/ob48.pid" )
t0=$(date +%s); while ! grep -q ARMED "$T/ob48.log" 2>/dev/null; do
  sleep 1; [ $(( $(date +%s) - t0 )) -gt 25 ] && break; done
# the seat force-pushes a SAME-COUNT rewrite of delivered history: three
# entries before, three after, one of them changed
cd "$T/s48"
printf -- '- first\n- forged\n- third\n' > collab/OUTBOX_a.md
git add -A; git commit -q --amend -m rewritten >/dev/null 2>&1
git push -qf origin HEAD:refs/heads/sub/a 2>/dev/null
t0=$(date +%s); while ! grep -q "OUTBOX REWRITTEN" "$T/ob48.log" 2>/dev/null; do
  sleep 1; [ $(( $(date +%s) - t0 )) -gt 30 ] && break; done
check "alarms on a rewrite that arrives before any delivery" \
      "OUTBOX REWRITTEN" "$T/ob48.log"
# then destroys two of the three entries outright
printf -- '- first\n' > collab/OUTBOX_a.md
git add -A; git commit -q --amend -m shrunk >/dev/null 2>&1
git push -qf origin HEAD:refs/heads/sub/a 2>/dev/null
t0=$(date +%s); while ! grep -q "OUTBOX SHRANK" "$T/ob48.log" 2>/dev/null; do
  sleep 1; [ $(( $(date +%s) - t0 )) -gt 30 ] && break; done
check "and a shrink in the same window still alarms" \
      "OUTBOX SHRANK" "$T/ob48.log"
absent "and never calls destroyed history no new entries" \
       "no new outbox entries" "$T/ob48.log"
stop "$T/m48/.git/outbox_watch_a.pid"

echo
echo "49. the release round's repairs, each driven rather than read"
# WRITTEN TWICE. The first version asserted source strings and log phrases, and
# an independent seat mutated four of its five assertions without turning any
# of them red: accepting both 0 and 1 for the baseline, permuting the identity
# classifier, returning the wrong code on an unreadable ps, and appending a
# later trap that overrides the repaired one. Static presence is not evidence
# that the running behaviour is there, which is the finding this suite made
# about ITSELF twice in one round. Everything below executes the thing it names.

# (a) AN UNREADABLE BULLET IS COUNTED, AND ITS SENTINEL CANNOT BE ACKNOWLEDGED.
# Printed as UNPARSABLE-2 the sentinel matched the identifier grammar itself,
# so a seat writing `[done: UNPARSABLE-2]` discharged it and the gate went
# quiet with the malformed bullets still in Open.
mkdir -p "$T/c49" "$T/c49bin"
printf -- '## Open instructions\n\n- REAL-1: parses\n- 2-1: a numbered seat\n- a bullet with no id\n\n## Closed\n' > "$T/c49/inbox.md"
# THE FAKE ANSWERS ONE CALL AND PASSES THE REST TO THE REAL GIT. The inbox
# under test is a file rather than a blob in any repository, so `show` has to
# be faked. Making the fake answer EVERYTHING with failure is what broke the
# second half of this case: `acked_ids` fetches a real branch through the same
# PATH, got a refusal, returned FETCHFAILED, and the assertion below then
# reported a discharge that had never been attempted.
REALGIT=$(command -v git)
cat > "$T/c49bin/git" <<GITF
#!/bin/sh
[ "\$1" = show ] && exec cat "$T/c49/inbox.md"
exec $REALGIT "\$@"
GITF
chmod +x "$T/c49bin/git"
got=$( PATH="$T/c49bin:$PATH"; INTEG=main; BUS=collab; NAME=x
       eval "$(awk '/^IDGRAM=/{print}' "$HERE/watch-inbox.sh")"
       eval "$(awk '/^open_ids\(\) ?\{/{p=1} p{print} p&&/^\}$/{exit}' "$HERE/watch-inbox.sh")"
       open_ids | tr '\n' ' ' )
# THE EXACT SET, because accepting any sentinel passed a build that counted
# one malformed bullet where there are two.
want50="REAL-1 UNPARSABLE(2)"
gotsorted=$(printf '%s\n' $got | sort | tr '\n' ' ')
wantsorted=$(printf '%s\n' $want50 | sort | tr '\n' ' ')
if [ "$gotsorted" = "$wantsorted" ]; then
  ok "an unreadable bullet under Open is counted and reported, not read as nothing owed"
else
  bad "open_ids returned [$gotsorted] where one readable id and two unreadable bullets require [$wantsorted]"
fi
# AND IT SURVIVES AN ACKNOWLEDGEMENT AIMED AT IT, driven through the gate's
# own reader rather than compared against the grammar by eye. A static check
# here passed a normalisation that turned the sentinel back into a legal id.
sentinel=$(printf '%s\n' $got | grep UNPARSABLE || true)
# THROUGH THE REAL `acked_ids`, ON A REAL BRANCH, because stubbing it tests a
# state the system cannot reach: that function extracts acknowledgements
# THROUGH the same grammar, so the protection being checked here is exactly
# the one a stub assumes away. The commit below really does say
# `[done: UNPARSABLE(2)]`, which is the strongest thing a seat can write.
cd "$T"; git init -q --bare origin49s.git
git clone -q origin49s.git s49s 2>/dev/null
cd "$T/s49s"; git config user.email s@example.invalid; git config user.name s
echo x > w.txt; git add -A
git commit -qm "work [done: $sentinel] [done: REAL-9]" >/dev/null 2>&1
git push -q origin HEAD:refs/heads/sub/s 2>/dev/null
surv=$( cd "$T/s49s"; PATH="$T/c49bin:$PATH"; INTEG=main; BUS=collab; NAME=x
        ACK_BRANCH=sub/s; S="$T/c49state"
        eval "$(awk '/^IDGRAM=/{print}' "$HERE/watch-inbox.sh")"
        eval "$(awk '/^open_ids\(\) ?\{/{p=1} p{print} p&&/^\}$/{exit}' "$HERE/watch-inbox.sh")"
        eval "$(awk '/^acked_ids\(\) ?\{/{p=1} p{print} p&&/^\}$/{exit}' "$HERE/watch-inbox.sh")"
        eval "$(awk '/^missing_acks\(\) ?\{/{p=1} p{print} p&&/^\}$/{exit}' "$HERE/watch-inbox.sh")"
        missing_acks )
case $surv in
  *UNPARSABLE*) ok "and a commit subject that really says [done: $sentinel] does not discharge it" ;;
  *) bad "a real acknowledgement naming [$sentinel] discharged it, leaving [$surv], so malformed bullets can be signed off by a seat" ;;
esac
# AND THE GRAMMAR ADMITS THE NAMES THE PROTOCOL PROMISES. Section 1 allows a
# seat name starting with a letter, which includes seat2.
# A MANIFEST OF NAMES, so a parser special-cased for one of them fails here.
idg=$(awk -F"'" '/^IDGRAM=/{print $2}' "$HERE/watch-inbox.sh")
manifest_bad=""
for good in REAL-1 seat2-7 rev-36 a_b-2 cdx-45x; do
  printf '%s\n' "$good" | grep -qE "^$idg\$" || manifest_bad="$manifest_bad accept:$good"
done
for evil in 2-1 2026-08-31 -7 x- "UNPARSABLE(2)"; do
  printf '%s\n' "$evil" | grep -qE "^$idg\$" && manifest_bad="$manifest_bad reject:$evil"
done
if [ -z "$manifest_bad" ]; then
  ok "and the grammar accepts every name the protocol allows and refuses every one it does not, ten rows"
else
  bad "the grammar disagrees with the documented contract on:$manifest_bad"
fi

# (b) THE BASELINE OPTS IN ON 1 ALONE, DRIVEN THROUGH THE GATE ITSELF. The
# source string was asserted here once and a build accepting both 0 and 1
# passed it.
cd "$T"; git init -q --bare origin49.git
git clone -q origin49.git s49 2>/dev/null
cd "$T/s49"; git config user.email s@example.invalid; git config user.name s
mkdir -p collab
printf -- '## Open instructions\n\n- ZERO-1: never acknowledged\n\n## Closed\n' > collab/INBOX_z.md
git add -A; git commit -qm seed >/dev/null 2>&1
git push -q origin HEAD:refs/heads/main 2>/dev/null
git push -q origin HEAD:refs/heads/sub/z 2>/dev/null
cd "$T"; git clone -q origin49.git m49 2>/dev/null
cd "$T/m49"; git config user.email m@example.invalid; git config user.name m
for v in unset empty zero one; do
  rm -f .git/inbox_watch_z .git/inbox_watch_z.ackbase .git/inbox_watch_z.pid
  case $v in
    unset) ( cd "$T/m49" && P=2 ACK_BRANCH=sub/z sh "$INSH" z main collab > "$T/ab_$v.log" 2>&1 & echo $! > "$T/ab.pid" ) ;;
    empty) ( cd "$T/m49" && P=2 ACK_BRANCH=sub/z ACK_BASELINE= sh "$INSH" z main collab > "$T/ab_$v.log" 2>&1 & echo $! > "$T/ab.pid" ) ;;
    zero)  ( cd "$T/m49" && P=2 ACK_BRANCH=sub/z ACK_BASELINE=0 sh "$INSH" z main collab > "$T/ab_$v.log" 2>&1 & echo $! > "$T/ab.pid" ) ;;
    one)   ( cd "$T/m49" && P=2 ACK_BRANCH=sub/z ACK_BASELINE=1 sh "$INSH" z main collab > "$T/ab_$v.log" 2>&1 & echo $! > "$T/ab.pid" ) ;;
  esac
  t0=$(date +%s); while ! grep -q "acknowledgement gate is ON" "$T/ab_$v.log" 2>/dev/null; do
    sleep 1; [ $(( $(date +%s) - t0 )) -gt 20 ] && break; done
  stop "$T/ab.pid"
done
excl(){ grep -q "ALREADY UNANSWERED WHEN THIS ARMED" "$T/ab_$1.log" 2>/dev/null; }
if ! excl unset && ! excl empty && ! excl zero && excl one; then
  ok "the baseline excludes outstanding work on 1 alone, driven for unset, empty, 0 and 1"
else
  bad "the baseline excluded on unset=$(excl unset && echo y || echo n) empty=$(excl empty && echo y || echo n) zero=$(excl zero && echo y || echo n) one=$(excl one && echo y || echo n), and only one should exclude"
fi

# (c) EVERY IDENTITY ROW OF EVERY SHIPPED PREDICATE, asserted individually. An
# aggregate count of two passed a classifier permuted to accept the wrong two.
mkdir -p "$T/c49ps"
cat > "$T/c49ps/ps" <<'PSF'
#!/bin/sh
[ -n "$FAKEPS" ] || exit 1
printf '%s\n' "$FAKEPS"
PSF
chmod +x "$T/c49ps/ps"
# EXTRACTED WITH awk AND THE STATUS CAPTURED, because neither was portable.
# A dynamic address in `sed -n "/^$2() {/,/^}/p"` is `invalid command code` on
# the BSD sed that ships with macOS, and the expected NONZERO return then
# aborts the command substitution under set -e before the status can be
# echoed. Both were measured on the release platform, where they stopped the
# suite before cases 50 and 51 ran at all.
idrow(){ # <script> <function> <script-basename> <fakeps> ; echoes the status
  ( PATH="$T/c49ps:$PATH"; SCRIPT=$3; NAME=cdx; FAKEPS=$4; export FAKEPS
    fnbody=$(awk -v fn="$2" '$0 ~ "^" fn "\\(\\) ?\\{$" {p=1} p {print} p && /^}$/ {exit}' "$HERE/$1")
    eval "$fnbody"
    rc=0
    "$2" 1 || rc=$?
    printf '%s\n' "$rc" )
}
rows=0; wrong=""
for spec in "supervise.sh owns_watcher watch-inbox.sh" \
            "watch-outbox.sh looks_like_us watch-outbox.sh" \
            "watch-inbox.sh looks_like_us watch-inbox.sh"; do
  set -- $spec; f=$1; fn=$2; base=$3
  exact=$(idrow "$f" "$fn" "$base" "sh /p/bin/$base cdx main cloud")
  nbr=$(idrow "$f" "$fn" "$base" "sh /p/bin/$base cdx2 main collab")
  unread=$(idrow "$f" "$fn" "$base" "")
  rows=$((rows+3))
  [ "$exact" = 0 ] || wrong="$wrong $f:exact=$exact"
  [ "$nbr" = 1 ]   || wrong="$wrong $f:neighbour=$nbr"
  [ "$unread" = 2 ]|| wrong="$wrong $f:unreadable=$unread"
done
if [ -z "$wrong" ]; then
  ok "all three shipped predicates answer 0, 1 and 2 for an exact, a neighbouring and an unreadable identity, $rows rows"
else
  bad "identity rows disagree:$wrong"
fi

# (d) CANCELLING THE MASTER REHEARSAL EXITS, RUN RATHER THAN GREPPED. A static
# check for the trap lines passed a script carrying a LATER trap overriding it.
# IT NEEDS A WORKING TREE, AND THE FIRST VERSION HAD NONE. `master-check.sh`
# resolves its root with `git rev-parse --show-toplevel` and takes its remote
# from THAT tree's origin, ignoring any REMOTE the caller exports. Run from a
# bare mktemp directory it printed the working-tree refusal and exited before
# the signal ever arrived, so deleting all three traps left this assertion
# green. Measured by the review seat.
#
# AND THAT REFUSAL WAS THE ONLY THING KEEPING THE SUITE OFF A REAL REMOTE,
# which is protection by accident. The clone below exists so the rehearsal
# takes its origin from a throwaway bare repository. Never give this case a
# tree whose origin is a remote anybody cares about: it pushes rehearsal refs
# to whatever origin it finds.
cd "$T"; git init -q --bare origin49b.git
git clone -q origin49b.git wc49 2>/dev/null
cd "$T/wc49"; git config user.email m@example.invalid; git config user.name m
echo seed > seed.txt; git add -A; git commit -qm seed >/dev/null 2>&1
git push -q origin HEAD:refs/heads/main 2>/dev/null
( cd "$T/wc49" && sh "$HERE/master-check.sh" mc49 > "$T/mc49.log" 2>&1 & echo $! > "$T/mc49.pid" )
# AND IT MUST HAVE STARTED BEFORE ITS ENDING MEANS ANYTHING. Without this the
# case passes again on any script that refuses to run at all.
t0=$(date +%s); while ! grep -q "REHEARSAL" "$T/mc49.log" 2>/dev/null; do
  sleep 1; [ $(( $(date +%s) - t0 )) -gt 15 ] && break; done
# AND A MISSING PID FILE IS NOT A REASON TO KILL THE WHOLE SUITE. Under set -e
# a bare `cat` of a file the background subshell has not written yet takes the
# run down with it, and every case after this one then never runs.
mcp=$(cat "$T/mc49.pid" 2>/dev/null || echo 0)
if [ "$mcp" != 0 ] && grep -q "REHEARSAL" "$T/mc49.log" 2>/dev/null && kill -0 "$mcp" 2>/dev/null; then
  ok "the master rehearsal starts and is running, so how it ends can be tested"
else
  bad "the rehearsal never started or was already gone, so nothing below tests a cancellation: $(head -2 "$T/mc49.log" 2>/dev/null | tr '\n' ' ')"
fi
[ "$mcp" = 0 ] || kill -TERM "$mcp" 2>/dev/null || true
i=0; while [ "$mcp" != 0 ] && kill -0 "$mcp" 2>/dev/null && [ "$i" -lt 8 ]; do sleep 1; i=$((i+1)); done
if [ "$mcp" != 0 ] && kill -0 "$mcp" 2>/dev/null; then
  kill -9 "$mcp" 2>/dev/null
  bad "the master rehearsal was still running ${i}s after TERM, so a cancelled rehearsal keeps pushing"
else
  ok "cancelling the master rehearsal exits rather than cleaning up and carrying on"
fi

# (e) AN UNREACHABLE REMOTE SAYS WHY, AND CLEANS UP NOTHING. A quiet clone
# discarded git's own message, so an authorisation problem, a full disk and a
# repository too large to fetch in the time allowed all read as "cannot reach
# the remote at all", and the cleanup then told the operator to delete two
# branches by hand that had never been created. Measured against a 469 MiB
# repository by the Cursor seat: the first quiet clone died, a visible clone of
# the same URL finished in 97.5 seconds, and the rehearsal it was gating then
# passed. The remote below cannot be cloned by anyone.
cd "$T"; mkdir -p wc49x; cd "$T/wc49x"; git init -q
git config user.email m@example.invalid; git config user.name m
git remote add origin "$T/there-is-no-repository-here.git"
( cd "$T/wc49x" && sh "$HERE/master-check.sh" mc49x > "$T/mc49x.log" 2>&1 ) || true
check "retries the clone once before calling a remote unreachable" \
      "retrying once" "$T/mc49x.log"
check "and hands back what git actually said instead of its own guess" \
      "git said:" "$T/mc49x.log"
absent "with no advice to delete branches by hand that were never pushed" \
       "remove them by hand" "$T/mc49x.log"

echo "50. an unreachable remote at arm time is a debt, not a permanent hole"
# The count repair runs once, at arm, and the poll loop only acts when the head
# MOVES, so a fetch that failed at arm left a wrong count nothing revisited.
# WRITTEN TWICE: the first pair of assertions read two phrases out of a log,
# and an independent seat suppressed the state correction, the persistence and
# the missing-entry print in turn without turning either of them red.
cd "$T"; git init -q --bare origin50.git
git clone -q origin50.git s50 2>/dev/null
cd "$T/s50"; git config user.email s@example.invalid; git config user.name s
mkdir -p collab
printf -- '- first\n- second\n- third\n' > collab/OUTBOX_a.md
git add -A; git commit -qm seed >/dev/null 2>&1
git push -q origin HEAD:refs/heads/sub/a 2>/dev/null
cd "$T"; git clone -q origin50.git m50 2>/dev/null
cd "$T/m50"; git config user.email m@example.invalid; git config user.name m
git fetch -q origin '+sub/a:refs/remotes/origin/sub/a' 2>/dev/null
h50=$(git rev-parse origin/sub/a 2>/dev/null || echo)
d50=$(git show "origin/sub/a:collab/OUTBOX_a.md" | head -1 | cksum | tr -d ' \n')
printf '%s 1 b %s\n' "$h50" "$d50" > .git/outbox_watch_a
mv "$T/origin50.git" "$T/origin50.hidden"
( cd "$T/m50" && P=2 sh "$OUTSH" a sub/a collab > "$T/ob50.log" 2>&1 & echo $! > "$T/ob50.pid" )
t0=$(date +%s); while ! grep -q ARMED "$T/ob50.log" 2>/dev/null; do
  sleep 1; [ $(( $(date +%s) - t0 )) -gt 20 ] && break; done
mv "$T/origin50.hidden" "$T/origin50.git"
t0=$(date +%s); while ! grep -q "STATE DISAGREES" "$T/ob50.log" 2>/dev/null; do
  sleep 1; [ $(( $(date +%s) - t0 )) -gt 25 ] && break; done
# AND THEN WAIT FOR THE FILE, NOT FOR THE SENTENCE ABOUT IT. The watcher prints
# the disagreement, then recomputes the digest with a git call, then saves, so
# stopping on the log line races the save. Under load the TERM landed first and
# this case reported a repair that had not persisted when a standalone run of
# the same scenario showed the state already correct the moment the line
# appeared. This suite's own protocol says to validate against the artifact
# rather than against a log line, and here the suite was breaking that rule
# about itself.
t0=$(date +%s); while [ "$(awk '{print $2}' "$T/m50/.git/outbox_watch_a" 2>/dev/null)" != 3 ]; do
  sleep 1; [ $(( $(date +%s) - t0 )) -gt 20 ] && break; done
stop "$T/ob50.pid"
# THE PERSISTED STATE IS THE ASSERTION, not the sentence about it. Suppressing
# save_state left the log identical and the file wrong.
# THE DIGEST IS COMPARED TO ONE COMPUTED HERE, not merely required to have
# changed: persisting the literal string `bogus` satisfied "non-empty and
# different" and passed.
want50=$( cd "$T/m50"; eval "$(awk '/^fingerprint_in\(\) \{/{p=1} p{print} p&&/^\}$/{exit}' "$HERE/watch-outbox.sh")"
          git show "origin/sub/a:collab/OUTBOX_a.md" | head -3 | fingerprint_in )
st50=$(cat "$T/m50/.git/outbox_watch_a" 2>/dev/null)
set -- $st50
if [ "${1:-}" = "$h50" ] && [ "${2:-}" = 3 ] && [ "${4:-}" = "$want50" ]; then
  ok "the count is reconciled in the state file itself, at the same head, with the digest three entries actually give"
else
  bad "the state reads [$st50] where it should carry head $h50, count 3 and digest $want50"
fi
# AND EACH RECORD IT HAD NOT COUNTED IS SHOWN EXACTLY ONCE. Suppressing the
# print left both assertions of the first version green.
# AND THE ONE IT HAD ALREADY COUNTED IS ABSENT. Printing the WHOLE outbox
# satisfied a pair of counts on the two new entries and passed, which is the
# opposite of the behaviour named: it delivers what was already delivered.
blk=$(awk '/OUTBOX entries this watcher had not counted/{p=1;next} p&&/^-/{print} p&&!/^-/{exit}' "$T/ob50.log" 2>/dev/null)
sec=$(printf '%s\n' "$blk" | grep -c -- '- second' || true)
thi=$(printf '%s\n' "$blk" | grep -c -- '- third' || true)
fst=$(printf '%s\n' "$blk" | grep -c -- '- first' || true)
if [ "$sec" = 1 ] && [ "$thi" = 1 ] && [ "$fst" = 0 ]; then
  ok "and its delivery block holds each uncounted entry once and nothing it had already counted"
else
  bad "the delivery block held first=$fst second=$sec third=$thi, where the entry already counted belongs nowhere in it"
fi
# AND A HEAD THAT MOVED DURING THE OUTAGE STILL RAISES ITS ALARM. The first
# version of the repair updated the count and the digest before the changed
# head path could compare the old prefix, so a rewrite during the outage was
# absorbed silently. Measured by the Codex seat.
cd "$T"; git init -q --bare origin50b.git
git clone -q origin50b.git s50b 2>/dev/null
cd "$T/s50b"; git config user.email s@example.invalid; git config user.name s
mkdir -p collab; printf -- '- first\n- second\n- third\n' > collab/OUTBOX_a.md
git add -A; git commit -qm seed >/dev/null 2>&1
git push -q origin HEAD:refs/heads/sub/a 2>/dev/null
cd "$T"; git clone -q origin50b.git m50b 2>/dev/null
cd "$T/m50b"; git config user.email m@example.invalid; git config user.name m
git fetch -q origin '+sub/a:refs/remotes/origin/sub/a' 2>/dev/null
hb=$(git rev-parse origin/sub/a 2>/dev/null || echo)
# SEEDED WITH THE WATCHER'S OWN FUNCTION, never a hand-rolled cksum. The
# watcher digests through fingerprint_in, which prefers sha256sum, so a cksum
# seed never reproduces: the changed-head path then took its "cannot verify"
# branch and the assertion below ACCEPTED that message, passing on a sentence
# whose own words say the rewrite was not caught. Measured by the review seat.
db=$( cd "$T/m50b"; eval "$(awk '/^fingerprint_in\(\) \{/{p=1} p{print} p&&/^\}$/{exit}' "$HERE/watch-outbox.sh")"
      git show "origin/sub/a:collab/OUTBOX_a.md" | head -3 | fingerprint_in )
printf '%s 3 b %s\n' "$hb" "$db" > .git/outbox_watch_a
mv "$T/origin50b.git" "$T/origin50b.hidden"
( cd "$T/m50b" && P=2 sh "$OUTSH" a sub/a collab > "$T/ob50b.log" 2>&1 & echo $! > "$T/ob50b.pid" )
t0=$(date +%s); while ! grep -q ARMED "$T/ob50b.log" 2>/dev/null; do
  sleep 1; [ $(( $(date +%s) - t0 )) -gt 20 ] && break; done
mv "$T/origin50b.hidden" "$T/origin50b.git"
# rewrite the first entry and append a fourth while the watcher was blind
cd "$T/s50b"; printf -- '- FIRST REWRITTEN\n- second\n- third\n- fourth\n' > collab/OUTBOX_a.md
git add -A; git commit -q --amend -m rewritten >/dev/null 2>&1
git push -qf origin HEAD:refs/heads/sub/a 2>/dev/null
cd "$T/m50b"
# AND THE PASS CONDITION EXCLUDES THE FAILURE MESSAGE. Accepting "cannot
# verify" here is what let a broken fixture look green for a whole round: an
# assertion that takes the script's own report of defeat as a success cannot
# fail. Only the alarms count.
t0=$(date +%s); while ! grep -qE "OUTBOX REWRITTEN|OUTBOX SHRANK|CANNOT VERIFY" "$T/ob50b.log" 2>/dev/null; do
  sleep 1; [ $(( $(date +%s) - t0 )) -gt 30 ] && break; done
if grep -qE "OUTBOX REWRITTEN|OUTBOX SHRANK" "$T/ob50b.log" 2>/dev/null; then
  ok "and a rewrite that lands during the outage is still raised rather than absorbed into a re-count"
elif grep -q "CANNOT VERIFY" "$T/ob50b.log" 2>/dev/null; then
  bad "the watcher could not verify its own seeded digest, so this fixture tests nothing: seed and watcher disagree"
else
  bad "a rewrite during the startup outage was absorbed silently: $(grep -o 'STATE DISAGREES\|no new outbox entries' "$T/ob50b.log" | head -2 | tr '\n' ' ')"
fi
stop "$T/ob50b.pid"

echo
echo "51. a seat waiting on its turn does not hold the foreground against the others"
# Measured on a live Mac: one injector held the machine-wide lock from 18:24
# waiting on a turn that never acknowledged, and a third seat's watcher spent
# the next three hours taking 75 at FGWAIT with nothing wrong at that seat.
# Reclaim cannot help, since it frees a lock whose owner is GONE and this one
# is alive. The lock is for bringing a window forward, so it is released once
# enter has been pressed.
FL51="$T/fglock51"; rm -f "$FL51" "$FL51.reclaim" "$LK/heldby"
OLDPATH=$PATH; PATH="$LK:$PATH"; export PATH
# A holds the foreground, types, and then waits out its ACK on a stamp nobody
# will ever write.
FGLOCK="$FL51" FGWAIT=20 ACK=25 TIMEOUT=25 SETTLE=1 POLL=1 \
  sh "$INJSH" FakeApp "$T/st51a" 'first' > "$T/inj51a.log" 2>&1 &
a51=$!
t0=$(date +%s); while ! grep -q "waiting up to" "$T/inj51a.log" 2>/dev/null; do
  sleep 1; [ $(( $(date +%s) - t0 )) -gt 20 ] && break; done
# B must get the foreground straight away rather than waiting out FGWAIT
# A IS REQUIRED TO HAVE HELD IT, AND TO HAVE LET IT GO. B being quick proves
# nothing on its own: deleting every fg_take, and releasing the moment after
# acquiring one, both left this case green because neither changes how fast B
# runs. The fake backend records the lock's owner while it is active, so the
# case can require that A owned it during the keyboard work and that the lock
# is gone while A is still alive waiting on its stamp.
held=$(cat "$LK/heldby" 2>/dev/null || echo none)
if [ "$held" != none ] && [ -n "$held" ]; then
  ok "the first injector owned the foreground while its keyboard work ran"
else
  bad "no injector owned the foreground during the paste, so this case cannot say anything about releasing it"
fi
if kill -0 "$a51" 2>/dev/null && [ ! -e "$FL51" ] && [ ! -L "$FL51" ]; then
  ok "and the lock is gone while that injector is still alive waiting on its stamp"
else
  bad "with the first injector $(kill -0 "$a51" 2>/dev/null && echo alive || echo gone), the lock is $( { [ -e "$FL51" ] || [ -L "$FL51" ]; } && echo still held || echo absent), so the release cannot be attributed to the paste finishing"
fi
b0=$(date +%s)
FGLOCK="$FL51" FGWAIT=20 ACK=1 TIMEOUT=1 SETTLE=1 POLL=1 \
  sh "$INJSH" FakeApp "$T/st51b" 'second' > "$T/inj51b.log" 2>&1 || true
b1=$(date +%s)
if grep -q "still holds it" "$T/inj51b.log" 2>/dev/null; then
  bad "a second seat waited out the foreground while the first was only watching a file, which starves every other seat for a whole turn"
elif [ $((b1 - b0)) -lt 10 ]; then
  ok "and a second seat takes the foreground while the first is waiting on its stamp"
else
  bad "the second injector took $((b1 - b0))s to reach the foreground, so it was queued behind a turn rather than behind a paste"
fi
kill $a51 2>/dev/null || true; wait $a51 2>/dev/null || true
PATH=$OLDPATH; export PATH

echo "52. the Linux keyboard branch will not type into the wrong window"
# THE TWO KEYBOARD BACKENDS ARE ONE CONTRACT AND THE LINUX ONE USED TO BREAK
# IT. macOS errors when activate did not bring the named application forward.
# This branch swallowed the same failure and typed an instruction, and pressed
# Return, into whatever did have focus. Found by the Cursor seat reading the
# two paths side by side, which no test could have found, because until now
# nothing exercised this branch at all.
#
# REACHING IT NEEDS A PATH WITH NO osascript ON IT, since the injector prefers
# osascript wherever it exists and would otherwise drive a real application,
# which this suite has caused once already. So the case builds a PATH of its
# own out of the few tools the injector actually calls, and refuses to run at
# all if osascript still resolves.
XD="$T/fake-xdotool"; mkdir -p "$XD"
OLDPATH52=$PATH
for b in basename cat cut date git grep head kill ln ls mktemp printf ps \
         readlink rm sed sh sleep tail tr uname; do
  r=$(command -v "$b" 2>/dev/null) || continue
  [ -n "$r" ] && ln -sf "$r" "$XD/$b" 2>/dev/null || true
done
# THE FAKE ANSWERS THE THREE QUESTIONS THE BRANCH ASKS and records the two
# actions it must not take when it refuses.
cat > "$XD/xdotool" <<XDT
#!/bin/sh
case \$1 in
  search)          echo 4242 ;;
  getactivewindow) [ -n "\$XD_FRONT" ] && echo "\$XD_FRONT" ;;
  windowactivate)  : ;;
  type)            shift 5; echo "TYPED \$*" >> "$XD/acted" ;;
  key)             echo "KEY \$3" >> "$XD/acted" ;;
esac
exit 0
XDT
chmod +x "$XD/xdotool"
PATH="$XD"; export PATH
if [ -n "$(command -v osascript 2>/dev/null)" ]; then
  PATH=$OLDPATH52; export PATH
  bad "osascript still resolves, so this case was not run: it would have driven a real application"
elif [ "$(command -v xdotool 2>/dev/null)" != "$XD/xdotool" ]; then
  PATH=$OLDPATH52; export PATH
  bad "the fake xdotool is not what resolves, so this case was not run"
else
  ok "the injector's Linux branch is reachable, with no osascript on the path to prefer"
  FL52="$T/case52.lock"

  # (a) THE FRONT WINDOW IS THE ONE THAT WAS ASKED FOR, so it types and sends.
  rm -f "$XD/acted" "$T/st52a"; : > "$T/st52a"
  ( sleep 3
    n=$(grep -o 'inj-[0-9]*-[0-9]*' "$XD/acted" 2>/dev/null | tail -1)
    echo "$n" > "$T/st52a" ) &
  w52=$!
  XD_FRONT=4242 FGLOCK="$FL52" FGWAIT=5 SETTLE=1 POLL=1 ACK=8 TIMEOUT=20 \
    sh "$INJSH" TheApp "$T/st52a" "read the inbox" > "$T/inj52a.log" 2>&1 && rc=0 || rc=$?
  wait $w52 2>/dev/null || true
  check "types the instruction when the window it activated is the one in front" \
        "TYPED read the inbox" "$XD/acted"
  check "and presses Return, so the line is actually sent" "KEY Return" "$XD/acted"

  # (b) SOMETHING ELSE IS IN FRONT. Nothing may be typed and nothing sent.
  rm -f "$XD/acted"; : > "$T/st52b"
  XD_FRONT=9999 FGLOCK="$FL52" FGWAIT=5 SETTLE=1 POLL=1 ACK=3 TIMEOUT=6 \
    sh "$INJSH" TheApp "$T/st52b" "do not send this" > "$T/inj52b.log" 2>&1 && rc=0 || rc=$?
  if [ "$rc" = 1 ]; then
    ok "returns 1 when another window is in front, so the watcher retries rather than quarantining"
  else bad "returned $rc with another window in front, and 1 is what says nothing was typed"; fi
  check "says which window it refused to type into" "front window is 9999" "$T/inj52b.log"
  if [ -f "$XD/acted" ]; then
    bad "it acted on the keyboard anyway: $(cat "$XD/acted" | tr '\n' ' ')"
  else ok "and nothing at all was typed or sent into that window"; fi

  # (c) NOTHING CAN SAY WHAT IS IN FRONT. Refusing is the answer, because a
  # window nothing can name is exactly the one an instruction must not reach.
  rm -f "$XD/acted"; : > "$T/st52c"
  XD_FRONT= FGLOCK="$FL52" FGWAIT=5 SETTLE=1 POLL=1 ACK=3 TIMEOUT=6 \
    sh "$INJSH" TheApp "$T/st52c" "do not send this either" > "$T/inj52c.log" 2>&1 && rc=0 || rc=$?
  if [ "$rc" = 1 ]; then ok "refuses when the front window cannot be read at all"
  else bad "returned $rc when the front window was unreadable, so it typed into an unknown window"; fi
  check "and says the answer was unreadable instead of naming a window" \
        "front window is unreadable" "$T/inj52c.log"
  if [ -f "$XD/acted" ]; then
    bad "it acted on the keyboard with the front window unknown: $(cat "$XD/acted" | tr '\n' ' ')"
  else ok "with nothing typed there either"; fi

  # (d) THE TYPE CALL FAILS PART WAY THROUGH. Nothing here can know how much
  # of the instruction reached the composer, so the free-retry code would let
  # the watcher append a second instruction to a fragment. The fixture records
  # the line and THEN fails, which is what the injector sees in either case,
  # since a failed `type` reports only its status and never how far it got.
  # The Codex seat reached the same finding with a fake that truncated first.
  cat > "$XD/xdotool" <<XDT2
#!/bin/sh
case \$1 in
  search)          echo 4242 ;;
  getactivewindow) echo 4242 ;;
  windowactivate)  : ;;
  type)            shift 5; echo "TYPED \$1" >> "$XD/acted"; exit 1 ;;
  key)             echo "KEY \$3" >> "$XD/acted" ;;
esac
exit 0
XDT2
  # NO chmod HERE, and the missing one killed a whole run at status 127. This
  # case narrows PATH to the few tools the injector itself calls, and chmod is
  # not among them, so calling it after that narrowing finds nothing. It is not
  # needed either: the file already exists and is executable from the arming
  # above, and `cat >` truncates content while leaving the mode alone. Adding
  # chmod to the fake PATH would work and would widen the surface this case
  # exists to keep narrow.
  rm -f "$XD/acted"; : > "$T/st52d"
  XD_FRONT=4242 FGLOCK="$FL52" FGWAIT=5 SETTLE=1 POLL=1 ACK=3 TIMEOUT=6 \
    sh "$INJSH" TheApp "$T/st52d" "half of this lands" > "$T/inj52d.log" 2>&1 && rc=0 || rc=$?
  if [ "$rc" = 75 ]; then
    ok "a type that fails part way returns 75, since a fragment may be sitting in the composer"
  else bad "returned $rc after a partial type, and 1 would tell the watcher to retry onto that fragment"; fi
  check "and says the landing is unknown instead of claiming nothing was typed" \
        "UNKNOWN" "$T/inj52d.log"
  # AND THIS ONE HAS TO BE ABLE TO FAIL. It used to assert the absence of
  # "Nothing was typed", which the broken path never printed either, so
  # reverting the fix left it green: it guarded nothing. The broken path's own
  # sentence is what discriminates, and it is gone from the repaired one.
  absent "and no longer calls a fragment a partial landing without saying the outcome is unknown" \
         "may have landed in part" "$T/inj52d.log"

  # (e) THE FOREGROUND LOCK IS NOT LEFT BEHIND BY A REFUSAL, which is the trap
  # a refusal added late to a path usually springs: the lock is taken before
  # the window is checked, and every one of these exits through it.
  if [ -e "$FL52" ] || [ -L "$FL52" ]; then
    bad "a refused injection left the foreground lock behind, so the next seat waits out FGWAIT for nothing"
  else ok "and a refusal releases the foreground lock on its way out"; fi
fi
PATH=$OLDPATH52; export PATH

echo "53. two watchers started at the same instant, on one name, in one clone"
# THE GUARD USED TO BE CHECK THEN WRITE, ten lines apart with nothing atomic
# between them, so two watchers starting together both passed the check and
# both then wrote. Measured by the review seat: fifteen simultaneous
# double-starts produced one pair polling together, about one in forty, and a
# copy with a two second sleep between the old check and the old write produced
# two armed watchers every time. That is the shape of a live incident, two
# watch-inbox.sh against one seat with a supervisor believing it had one.
#
# CASE 13 IS WHY THE SUITE WAS GREEN ON IT: that case starts its second watcher
# AFTER the first has armed, which the old guard caught correctly every time.
# Nothing here started two at once until now.
cd "$T"; git init -q --bare origin53.git
git clone -q origin53.git s53 2>/dev/null
cd "$T/s53"; git config user.email s@example.invalid; git config user.name s
mkdir -p collab; printf -- '- one\n' > collab/OUTBOX_r53.md
git add -A; git commit -qm seed >/dev/null 2>&1
git push -q origin HEAD:refs/heads/sub/r53 2>/dev/null
cd "$T"; git clone -q origin53.git m53 2>/dev/null
cd "$T/m53"; git config user.email m@example.invalid; git config user.name m
# AND EVERY TRIAL USED TO BEGIN WITH NO RECORD AT ALL, which is why this case
# could not refuse the defect the codex seat found next: the atomic create
# makes CREATING a record atomic and says nothing about the path taken when the
# create FAILS, so two starters that both fail against the same STALE record
# could each decide it was stale and the second could delete the first's live
# claim. A race case that only ever starts from an empty seat tests one third
# of the guard. Both scripts are driven here, from an absent record and from a
# stale one, and the loser is found from whichever log holds it.
lose53(){ if grep -q 'stands down' "$T/w53b.log" 2>/dev/null; then echo b; \
          elif grep -q 'stands down' "$T/w53a.log" 2>/dev/null; then echo a; fi; }
pairs=0; stood=0; named=0; kept=0; trials=0; surv53=0
for w53 in outbox inbox; do
  case $w53 in outbox) sc=$OUTSH; br=sub/r53; st=outbox_watch_r53 ;;
                inbox) sc=$INSH;  br=main;    st=inbox_watch_r53 ;; esac
  for seed53 in absent stale; do
    i=0
    while [ "$i" -lt 4 ]; do
      i=$((i + 1)); trials=$((trials + 1))
      rm -f "$T/m53/.git/$st" "$T/m53/.git/$st.pid"; rm -rf "$T/m53/.git/$st.claiming"
      [ "$seed53" = stale ] && echo 999999 > "$T/m53/.git/$st.pid"
      : > "$T/w53a.log"; : > "$T/w53b.log"
      # `cmd1 && cmd2` in a subshell is NOT a single command, so no shell
      # exec-optimises it away and `$!` is the WRAPPER, not the watcher. The
      # bounded kill below then killed the wrapper and left the watcher alive
      # under PID 1, one orphan per trial, still polling the throwaway remote
      # while the case counted itself green. Measured by the Codex seat:
      # wrapper 10468 gone, watcher 10470 alive at PPID 1. `exec` makes the
      # subshell BECOME the watcher, which is the trap this package's own
      # appendix warns about and the suite walked into.
      ( cd "$T/m53" || exit 1; P=60; export P
        exec sh "$sc" r53 "$br" collab > "$T/w53a.log" 2>&1 ) & pa=$!
      ( cd "$T/m53" || exit 1; P=60; export P
        exec sh "$sc" r53 "$br" collab > "$T/w53b.log" 2>&1 ) & pb=$!
      sleep 4
      alive=0
      kill -0 "$pa" 2>/dev/null && alive=$((alive + 1))
      kill -0 "$pb" 2>/dev/null && alive=$((alive + 1))
      [ "$alive" -gt 1 ] && pairs=$((pairs + 1))
      l53=$(lose53)
      [ -n "$l53" ] && stood=$((stood + 1))
      [ -n "$l53" ] && grep -q 'already running as pid' "$T/w53$l53.log" 2>/dev/null && named=$((named + 1))
      # AND THE SURVIVING RECORD NAMES THE WATCHER THAT IS STILL ALIVE, which is
      # what the stale seed is really asking: a second starter that removed the
      # first one's claim leaves a record naming nobody, or naming a corpse.
      rec53=$(cat "$T/m53/.git/$st.pid" 2>/dev/null)
      case $rec53 in ''|*[!0-9]*) : ;;
        *) kill -0 "$rec53" 2>/dev/null && kept=$((kept + 1)) ;; esac
      # AND A WATCHER CANNOT ANSWER A TERM UNTIL ITS `sleep $P` RETURNS, so a
      # bare wait here would sit out most of a minute per trial for a signal
      # already delivered. Bound it and escalate, the way stop() does.
      kill "$pa" "$pb" 2>/dev/null || true
      k53=0
      while [ "$k53" -lt 3 ] && { kill -0 "$pa" 2>/dev/null || kill -0 "$pb" 2>/dev/null; }; do
        sleep 1; k53=$((k53 + 1))
      done
      kill -9 "$pa" "$pb" 2>/dev/null || true
      wait "$pa" 2>/dev/null || true; wait "$pb" 2>/dev/null || true
      kill -0 "$pa" 2>/dev/null && surv53=$((surv53 + 1))
      kill -0 "$pb" 2>/dev/null && surv53=$((surv53 + 1))
    done
  done
done
if [ "$pairs" = 0 ]; then
  ok "over $trials simultaneous double-starts, never two watchers on one name"
else
  bad "$pairs of $trials simultaneous double-starts left two watchers polling one name"
fi
if [ "$stood" = "$trials" ]; then
  ok "and the loser says it is standing down every time, rather than dying silently"
else
  bad "the loser announced a stand-down in only $stood of $trials, so a supervisor cannot tell this from a crash"
fi
if [ "$named" = "$trials" ]; then
  ok "and every stand-down names the pid that owns the seat, in whichever log it landed"
else
  bad "only $named of $trials stand-downs named the owning pid"
fi
if [ "$surv53" = 0 ]; then
  ok "and every watcher this case started is gone when it ends, none left orphaned at PID 1"
else
  bad "$surv53 watchers outlived this case and are still polling the throwaway remote"
fi
if [ "$kept" = "$trials" ]; then
  ok "and the surviving record names a watcher that is still alive, from a stale record as well as from none"
else
  bad "in $(( trials - kept )) of $trials trials the record named nobody alive, so a starter deleted the claim of the watcher that won"
fi
# EITHER LOG, BECAUSE THE WINNER IS THE ONE STARTED FIRST. This read `w53a.log`
# alone, which is the process started first and therefore the one that WINS the
# claim, so the file it read holds the winner's arm line and never the loser's
# stand-down. Measured by the review seat: eight double-starts, the stand-down
# in `b` eight times out of eight and in `a` none. An assertion that names one
# side of a race has to be right about which side it named.
if grep -qh "already running as pid" "$T/w53a.log" "$T/w53b.log" 2>/dev/null; then
  ok "and the stand-down names the pid that owns the seat"
else
  bad "neither log carries the pid the stand-down should have named"
fi

echo "54. a delivery command that never returns is given up on"
# THE ONE WAIT IN THE INJECTOR THAT NOTHING BOUNDED. `INJECT_CMD` runs to
# completion before either ACK or TIMEOUT begins its loop, so a delivery
# command that hangs takes the seat off the air for as long as it runs, while
# the watcher holds that seat's turn lock. Measured by the review seat: a
# command sleeping twenty seconds under TIMEOUT=4 and ACK=2 took twenty two.
mkdir -p "$T/d54"
printf '#!/bin/sh\nsleep 30\n' > "$T/d54/hang"
printf '#!/bin/sh\nprintf "%%s\\n" "$1" >> "%s/d54/typed"\n' "$T" > "$T/d54/ok"
chmod +x "$T/d54/hang" "$T/d54/ok"
: > "$T/d54/stamp"
t54=$(date +%s)
INJECT_CMD="$T/d54/hang" DELIVER=3 TIMEOUT=30 ACK=20 SETTLE=1 POLL=1 \
  sh "$INJSH" FakeApp "$T/d54/stamp" 'hello' > "$T/d54.log" 2>&1 && rc=0 || rc=$?
e54=$(( $(date +%s) - t54 ))
if [ "$e54" -lt 15 ]; then
  ok "gives up on a hanging delivery in about DELIVER seconds, ${e54}s here"
else
  bad "waited ${e54}s on a delivery bounded at 3s, so DELIVER does not bound it"
fi
# 75, NOT 1, AND THE FIXTURE THAT PROVED IT IS BELOW. This asserted 1, "since
# nothing was typed", which is true of a command that hangs BEFORE delivering
# and of no other. The injector started the command and abandoned it, so it
# cannot know, and 1 tells the watcher to retry into a seat whose turn may
# already be running. A case written from the same belief as the repair, which
# is the most expensive kind. Found by the review seat.
if [ "$rc" = 75 ]; then ok "and returns 75, since an abandoned delivery cannot say what it delivered"
else bad "returned $rc where 75 leaves the seat alone rather than injecting into it twice"; fi
check "and says which command it gave up on" "gave up on INJECT_CMD" "$T/d54.log"
check "and says plainly that it does not know whether the line landed" \
      "WHETHER THE LINE REACHED THE SEAT IS UNKNOWN" "$T/d54.log"

# (b) THE FIXTURE THAT MATTERS: a delivery that HANDS OVER THE LINE and then
# hangs. The seat has the whole instruction and the nonce, and the injector
# still has to say it does not know.
rm -f "$T/d54/typed"; : > "$T/d54/stamp"
printf '#!/bin/sh\nprintf "%%s\\n" "$1" >> "%s/d54/typed"\nsleep 30\n' "$T" > "$T/d54/dth"
chmod +x "$T/d54/dth"
INJECT_CMD="$T/d54/dth" DELIVER=3 TIMEOUT=30 ACK=20 SETTLE=1 POLL=1 \
  sh "$INJSH" FakeApp "$T/d54/stamp" 'read the inbox' > "$T/d54c.log" 2>&1 && rc=0 || rc=$?
if [ "$rc" = 75 ]; then ok "a delivery that lands the line and then hangs also returns 75"
else bad "returned $rc after a delivery that had already reached the seat, and 1 there starts a second turn"; fi
if grep -q 'read the inbox' "$T/d54/typed" 2>/dev/null; then
  ok "and the seat really did have the instruction, so the case is not vacuous"
else
  bad "the fixture never delivered, so this case is testing the same hang as the one above"
fi
# AND THE ABANDONED DELIVERY IS SIGNALLED, wrapper and children together, since
# killing the wrapper alone left the delivery running and reparented to init.
sleep 2
left=$(ps -o pid=,args= -e 2>/dev/null | awk '$0 ~ /d54\/dth/ && $0 !~ /awk/ {c++} END{print c+0}')
if [ "${left:-0}" = 0 ]; then ok "and nothing of that delivery is left running afterwards"
else bad "$left process(es) of the abandoned delivery survived, which is what reparents to init and delivers later"; fi

# (c) AND A DELIVERY THAT DAEMONISES IS THE BOUNDARY, MEASURED RATHER THAN
# ASSUMED. The check above reads argv, so a descendant whose argv is merely
# `sleep` is invisible to it, which the Codex seat demonstrated with a double
# fork. This fixture records its own descendant's pid to a file and the case
# asks the kernel about THAT pid. The injector reaches one level, so the
# descendant is expected to LIVE: that is the documented limit and the reason
# the protocol makes a daemonising adapter own its own cleanup. If someone
# widens the sweep to process groups this assertion goes red, which is the
# correct prompt to update the contract with it.
rm -f "$T/d54/typed" "$T/d54/dpid"; : > "$T/d54/stamp"
printf '#!/bin/sh\nprintf "%%s\\n" "$1" >> "%s/d54/typed"\n( ( sleep 45 & echo $! > "%s/d54/dpid" ) & )\nsleep 30\n' "$T" "$T" > "$T/d54/dmn"
chmod +x "$T/d54/dmn"
INJECT_CMD="$T/d54/dmn" DELIVER=3 TIMEOUT=25 ACK=15 SETTLE=1 POLL=1 \
  sh "$INJSH" FakeApp "$T/d54/stamp" 'read the inbox' > "$T/d54d.log" 2>&1 && rc=0 || rc=$?
if [ "$rc" = 75 ]; then ok "a delivery that daemonises still returns 75, so no second turn starts beside it"
else bad "returned $rc from a daemonising delivery, and anything but 75 invites a retry"; fi
sleep 2
dp=$(cat "$T/d54/dpid" 2>/dev/null)
case $dp in
  ''|*[!0-9]*) bad "the daemonising fixture recorded no pid, so this case measured nothing" ;;
  *) if kill -0 "$dp" 2>/dev/null; then
       ok "and its daemonised descendant $dp outlives the injector, which is the limit the code states"
       kill -9 "$dp" 2>/dev/null || true
     else
       bad "the daemonised descendant is gone, so the injector now reaches further than the protocol says and the contract needs updating"
     fi ;;
esac
check "and the injector says the outcome is unknown rather than claiming a clean stop" \
      "WHETHER THE LINE REACHED THE SEAT IS UNKNOWN" "$T/d54d.log"

# (d) AND THE CONTRACT IS SATISFIABLE, which a boundary case has to show or it
# is just an excuse. A COMPLIANT adapter daemonises and traps TERM to kill what
# it started, so the same shape that leaked above cleans up here with no help
# from the injector. Its wait is a loop of short sleeps because a trap cannot
# run until the foreground command returns, which is the same fact case 53 pays
# for. If this control ever goes red the contract is unmeetable and the
# protocol has to say so instead of asking adapters for it.
# ITS CLEANUP TAKES A DELIBERATE TWO SECONDS, and that is the whole difference
# between a control and a coin toss. With an instant handler this case is a
# race between the adapter finishing and the injector's KILL arriving, and the
# two machines that ran it disagreed on the same code: green here, red on the
# review seat, one assertion apart on a 326-case suite. A handler that needs
# real time loses that race every time on the old code and wins it every time
# on the repaired code, which is what an assertion is for.
rm -f "$T/d54/typed" "$T/d54/cpid"; : > "$T/d54/stamp"
cat > "$T/d54/good" <<GOODA
#!/bin/sh
printf '%s\n' "\$1" >> "$T/d54/typed"
( sleep 45 & echo \$! > "$T/d54/cpid" ) &
trap 'sleep 2; k=\$(cat "$T/d54/cpid" 2>/dev/null); [ -n "\$k" ] && kill -9 "\$k" 2>/dev/null; exit 0' TERM
i=0; while [ \$i -lt 60 ]; do sleep 1; i=\$((i + 1)); done
GOODA
chmod +x "$T/d54/good"
INJECT_CMD="$T/d54/good" DELIVER=3 TIMEOUT=25 ACK=15 SETTLE=1 POLL=1 \
  sh "$INJSH" FakeApp "$T/d54/stamp" 'read the inbox' > "$T/d54e.log" 2>&1 && rc=0 || rc=$?
sleep 2
cp2=$(cat "$T/d54/cpid" 2>/dev/null)
case $cp2 in
  ''|*[!0-9]*) bad "the compliant adapter recorded no daemon pid, so this control measured nothing" ;;
  *) if kill -0 "$cp2" 2>/dev/null; then
       bad "the compliant adapter's own TERM handling did not remove its daemon $cp2, so the contract the protocol asks for cannot be met"
       kill -9 "$cp2" 2>/dev/null || true
     else
       ok "an adapter that traps TERM removes its own daemon, so the contract the protocol states is meetable"
     fi ;;
esac
# AND A DELIVERY THAT RETURNS IS UNTOUCHED BY THE BOUND, which is the half a
# timeout usually breaks.
rm -f "$T/d54/typed"; : > "$T/d54/stamp"
( sleep 2
  n=$(grep -o 'inj-[0-9]*-[0-9]*' "$T/d54/typed" 2>/dev/null | tail -1)
  [ -n "$n" ] && echo "$n" > "$T/d54/stamp" ) &
w54=$!
INJECT_CMD="$T/d54/ok" DELIVER=30 TIMEOUT=25 ACK=10 SETTLE=1 POLL=1 \
  sh "$INJSH" FakeApp "$T/d54/stamp" 'read the inbox' > "$T/d54b.log" 2>&1 && rc=0 || rc=$?
wait $w54 2>/dev/null || true
if [ "$rc" = 0 ]; then ok "and an ordinary delivery still finishes normally under the same bound"
else bad "returned $rc on a delivery that worked, so the bound broke the good path"; fi
check "with the instruction actually handed to the command" "read the inbox" "$T/d54/typed"

echo "55. the supervisor stands down on 3 and climbs the ladder on anything else"
# CASE 34 USED TO COVER THIS BY ACCIDENT, with a fake that exited 3 before 3
# meant anything. When 3 was given a meaning that fake stopped exercising the
# ladder and nothing exercised the stand-down, so the suite lost one behaviour
# and mis-reported another in the same stroke. Both are named here.
S55="$T/sup55"; mkdir -p "$S55"
cp "$SUPSH" "$S55/supervise.sh"
cat > "$S55/watch-outbox.sh" <<'FW'
#!/bin/sh
echo "fake watcher for $1 exiting $EXITWITH"
exit ${EXITWITH:-4}
FW
chmod +x "$S55/watch-outbox.sh"
cd "$T/master"
( EXITWITH=3 P=2 STABLE=1 sh "$S55/supervise.sh" outbox s55 sub/a collab > "$T/sup55a.log" 2>&1 ) & p55=$!
i=0; while kill -0 $p55 2>/dev/null && [ "$i" -lt 15 ]; do sleep 1; i=$((i+1)); done
if kill -0 $p55 2>/dev/null; then
  kill $p55 2>/dev/null
  bad "the supervisor kept going after a watcher stood down, so the orphan-restart loop is still reachable"
else
  ok "the supervisor exits when its watcher stands down, rather than restarting into a seat somebody owns"
fi
check "and says why it is exiting" "STOOD DOWN" "$T/sup55a.log"
absent "with no restart line, since there is nothing to keep alive" \
       "restart 1 in" "$T/sup55a.log"
( EXITWITH=4 P=2 STABLE=1 sh "$S55/supervise.sh" outbox s55b sub/a collab > "$T/sup55b.log" 2>&1 ) & q55=$!
sleep 12
if kill -0 $q55 2>/dev/null; then ok "and any other non-zero exit still climbs the restart ladder"
else bad "the supervisor gave up on an ordinary failure, which is the ladder this case exists for"; fi
check "with the ladder's own line, so the two paths are told apart in the log" \
      "restart 1 in" "$T/sup55b.log"
absent "and no stand-down claimed about an exit that was not one" \
       "STOOD DOWN" "$T/sup55b.log"
kill $q55 2>/dev/null; wait $q55 2>/dev/null || true
# AND 78 IS THE THIRD PATH: a refusal no restart can clear. Before it existed
# the git-version refusal exited 1, so a machine with git older than 2.13 got
# that message every 300s for as long as it was up.
( EXITWITH=78 P=2 STABLE=1 sh "$S55/supervise.sh" outbox s55c sub/a collab > "$T/sup55c.log" 2>&1 ) & r55=$!
i=0; while kill -0 $r55 2>/dev/null && [ "$i" -lt 15 ]; do sleep 1; i=$((i+1)); done
if kill -0 $r55 2>/dev/null; then
  kill $r55 2>/dev/null
  bad "the supervisor kept restarting a watcher that said this machine cannot run it"
else
  ok "the supervisor stops on 78, since no restart can make a machine meet a requirement"
fi
check "and says the machine is the reason, not the watcher" \
      "CANNOT RUN ON THIS MACHINE" "$T/sup55c.log"
# AND IT LEAVES BY THE CODE IT WAS TOLD. The supervisor refuses the same
# condition from its own git guard, and returned 78 there while returning 1
# here, so a launcher reading the status saw two answers to one question.
# `( ... ) ; rc=$?` DOES NOT SURVIVE `set -e`, which this file sets at line 19.
# The subshell's non-zero status ends the script before the assignment runs, so
# this assertion killed a whole run at status 78, the very code it was added to
# check. Every other block here backgrounds the supervisor, which never trips
# set -e; a foreground one has to put the status in a condition context.
rc55=0
( EXITWITH=78 P=2 STABLE=1 sh "$S55/supervise.sh" outbox s55d sub/a collab > "$T/sup55d.log" 2>&1 ) || rc55=$?
if [ "$rc55" = 78 ]; then
  ok "and exits 78 itself, the same code it refuses its own unmet requirement with"
else
  bad "exited $rc55 after a watcher returned 78, so one condition leaves this script by two codes"
fi
absent "with no restart line, because there is nothing to retry" \
       "restart 1 in" "$T/sup55c.log"
absent "and no stand-down claimed, which is a different exit with a different cause" \
       "STOOD DOWN" "$T/sup55c.log"

echo "56. the hostile git config the isolation block claims to neutralise"
# THE BLOCK AT THE TOP OF THIS FILE IS THE ONE PIECE OF THE SUITE NOTHING EVER
# TESTED, and it was rewritten three times in one night as each new route into
# git's configuration was found: HOME, then /etc, then XDG, then the explicit
# GIT_CONFIG family, then GIT_CONFIG_PARAMETERS. Every one of those was found
# by a reviewer attacking the suite from outside, and each fix landed with no
# assertion, so the next route was found the same slow way. This case reads THE
# SHIPPED LINES out of this file and runs them under each attack, so dropping a
# variable from the sweep fails here rather than on somebody's machine.
SELF="$HERE/${0##*/}"
ISO="$T/iso56.sh"
sed -n '/^HOME=\$T; export HOME$/,/^i=0; while \[ "\$i" -lt 32 \]/p' "$SELF" > "$ISO"
iso_lines=$(awk 'END{print NR+0}' "$ISO") || true
# AND THE EXTRACTION IS BOUNDED AT BOTH ENDS. A range whose closing anchor has
# moved runs to the end of the file, and sourcing the whole suite from inside
# the suite produces four confident failures that say nothing about the block.
# Measured while writing this case: dropping the loop that closes the block
# made the range 3,573 lines and every later assertion meaningless.
if [ "$iso_lines" -lt 5 ] || [ "$iso_lines" -gt 40 ]; then
  bad "the isolation block extracted as $iso_lines lines, which is not the size of a block, so its anchors have moved and this case is testing nothing"
else
  ok "reads the isolation block out of this file, $iso_lines lines of it, rather than testing a copy of it"
fi
mkdir -p "$T/iso56"; cd "$T/iso56"; git init -q .
# Each attack is one route into git's configuration, and all four force a
# signature through a program that always fails. That is the shape of the real
# failure: a commit this suite makes for its own fixtures dies, and the run
# ends mid-case with no totals line and nothing saying why.
mkdir -p "$T/a56xdg/git"
sig='[commit]
	gpgsign = true
[gpg]
	program = /bin/false
'
printf '%s' "$sig" > "$T/a56xdg/git/config"
printf '%s' "$sig" > "$T/a56global"
cat > "$T/a56.XDG_CONFIG_HOME" <<A
XDG_CONFIG_HOME=$T/a56xdg; export XDG_CONFIG_HOME
A
cat > "$T/a56.GIT_CONFIG_GLOBAL" <<A
GIT_CONFIG_GLOBAL=$T/a56global; export GIT_CONFIG_GLOBAL
A
cat > "$T/a56.GIT_CONFIG_PARAMETERS" <<'A'
GIT_CONFIG_PARAMETERS="'commit.gpgsign'='true' 'gpg.program'='/bin/false'"
export GIT_CONFIG_PARAMETERS
A
cat > "$T/a56.GIT_CONFIG_COUNT" <<'A'
GIT_CONFIG_COUNT=2
GIT_CONFIG_KEY_0=commit.gpgsign; GIT_CONFIG_VALUE_0=true
GIT_CONFIG_KEY_1=gpg.program;    GIT_CONFIG_VALUE_1=/bin/false
export GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0 GIT_CONFIG_KEY_1 GIT_CONFIG_VALUE_1
A
for attack in XDG_CONFIG_HOME GIT_CONFIG_GLOBAL GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT; do
  a="$T/a56.$attack"
  # FIRST PROVE THE ATTACK BITES. A control that cannot break the thing it
  # guards proves nothing, and this suite has shipped one of those before.
  # EVERY ASSIGNMENT HERE ENDS IN `|| true`, AND THAT IS NOT DEFENSIVE NOISE.
  # `git config --get` exits 1 when the key is absent, which is the answer this
  # case WANTS, and under the `set -e` at the top of this file an assignment
  # from a command substitution carries that status: the run ends at the
  # assignment and the assertion below never executes. It happened, on the
  # first run after this case was written, two assertions in.
  bites=$(sh -c ". '$a'; git config --get commit.gpgsign" 2>/dev/null) || true
  if [ "$bites" = true ]; then
    ok "$attack reaches git's configuration from outside, so it is a real attack and not a spelling of one"
  else
    bad "$attack did not reach git at all, so nothing this case says about it next means anything"
  fi
  got=$(sh -c ". '$a'; T='$T'; . '$ISO'; git config --get commit.gpgsign" 2>/dev/null) || true
  if [ -z "$got" ]; then
    ok "and the shipped block closes it, so a run under $attack is the same run as any other"
  else
    bad "the isolation block left commit.gpgsign=$got reachable through $attack, so this suite still answers to the machine it runs on"
  fi
done
cd "$T"

echo "57. a pid that exits while it is being identified is stale, not a refusal"
# 78 IS A REFUSAL NO RESTART CLEARS, so the condition that earns it has to be
# read twice. `kill -0` says alive, `ps` says nothing, and those are two
# different instants: a process that exits between them is unidentifiable for
# the ordinary reason and its record is simply stale. The first version read
# once and called that a machine that cannot identify its own processes, which
# turned a routine race into a supervisor stopped until a person came. Found by
# the Codex seat, fixed in both watchers, and neither fix had an assertion until
# this case. Both answers are driven, because a pid that STAYS alive and stays
# unreadable must still refuse, and a repair that loses that has lost the
# behaviour rather than fixed it.
FB57="$T/c57bin"; mkdir -p "$FB57"
cd "$T"; git init -q --bare origin57.git; git clone -q origin57.git c57 2>/dev/null
identify "$T/c57"
cd "$T/c57"; mkdir -p collab; printf -- '- one\n' > collab/OUTBOX_r57.md
git add -A >/dev/null 2>&1; git commit -qm 'seed r57' >/dev/null 2>&1
git push -q origin HEAD:sub/a 2>/dev/null || true
for which in outbox inbox; do
  sc="$HERE/watch-$which.sh"; S="$T/c57/.git/${which}_watch_r57"
  # THE VICTIM IS ORPHANED ON PURPOSE, to pid 1, so that killing it removes it
  # from the table instead of leaving a zombie this shell has not reaped. A
  # zombie answers `kill -0` and the race would never be built.
  sh -c "sleep 300 & echo \$! > $T/c57victim"
  victim=$(cat "$T/c57victim") || true
  # The fake ps kills the pid it was asked about and returns nothing, which is
  # the interleaving itself. It records whether the pid really went, so a
  # platform that leaks zombies says so instead of failing the watcher for it.
  cat > "$FB57/ps" <<PS
#!/bin/sh
kill $victim 2>/dev/null
i=0
while kill -0 $victim 2>/dev/null && [ "\$i" -lt 8 ]; do sleep 1; i=\$((i + 1)); done
if kill -0 $victim 2>/dev/null; then echo lingered > $T/c57mark; else echo gone > $T/c57mark; fi
exit 0
PS
  chmod +x "$FB57/ps"; rm -f "$T/c57mark"
  echo "$victim" > "$S.pid"
  rc=0
  ( cd "$T/c57" || exit 1; PATH="$FB57:$PATH"; export PATH; P=2; export P
    exec sh "$sc" r57 sub/a collab > "$T/c57.$which.a.log" 2>&1 ) & wp=$!
  i=0; while kill -0 $wp 2>/dev/null && [ "$i" -lt 25 ]; do sleep 1; i=$((i + 1)); done
  built=$(cat "$T/c57mark" 2>/dev/null) || true
  if [ "$built" != gone ]; then
    ok "this platform did not let the $which race be built, the pid was still in the table after the identity read, so there is nothing here to judge"
    kill $wp 2>/dev/null || true; wait $wp 2>/dev/null || true
  elif kill -0 $wp 2>/dev/null; then
    ok "the $which watcher armed over a record whose pid died while it was being identified, rather than refusing for ever"
    kill $wp 2>/dev/null || true; wait $wp 2>/dev/null || true
  else
    rc=0; wait $wp 2>/dev/null || rc=$?
    if [ "$rc" = 78 ]; then
      bad "the $which watcher returned 78 for a pid that had already gone, so an ordinary stale record stops the supervisor until a person comes"
    else
      bad "the $which watcher exited $rc instead of arming over a record whose owner had gone"
    fi
  fi
  check "and says what actually happened, that the owner went while it was being identified"         "went while this was identifying it" "$T/c57.$which.a.log"
  absent "rather than the sentence written for a live foreign process, which would send a person looking for one that is not there"          "alive but is not a watch" "$T/c57.$which.a.log"
  kill "$victim" 2>/dev/null || true
  # THE OTHER HALF. A pid that stays alive and stays unreadable is the case
  # that really does need a person, and it must still refuse.
  sh -c "sleep 300 & echo \$! > $T/c57victim"
  alive=$(cat "$T/c57victim") || true
  printf '#!/bin/sh\nexit 0\n' > "$FB57/ps"; chmod +x "$FB57/ps"
  echo "$alive" > "$S.pid"
  # AND THIS ONE IS BOUNDED TOO. A watcher that has lost the refusal ARMS here
  # and polls for ever, so a foreground run would hang the whole suite instead
  # of reporting the defect. Measured while writing this case, against a
  # deliberately broken copy: the run had to be killed by hand at two minutes.
  rc=0
  ( cd "$T/c57" || exit 1; PATH="$FB57:$PATH"; export PATH; P=2; export P
    exec sh "$sc" r57 sub/a collab > "$T/c57.$which.b.log" 2>&1 ) & bp=$!
  i=0; while kill -0 $bp 2>/dev/null && [ "$i" -lt 20 ]; do sleep 1; i=$((i + 1)); done
  if kill -0 $bp 2>/dev/null; then
    bad "the $which watcher armed beside a live owner it could not identify, which is two watchers on one seat, each eating entries the other never shows anyone"
    kill $bp 2>/dev/null || true; wait $bp 2>/dev/null || true
  else
    rc=0; wait $bp 2>/dev/null || rc=$?
    if [ "$rc" = 78 ]; then
      ok "and the $which watcher still refuses on 78 when that pid stays alive and stays unreadable, which is the case a person has to clear"
    else
      bad "the $which watcher exited $rc for a live owner it could not identify, so the refusal this repair had to keep is gone"
    fi
  fi
  check "naming the record it will not write over" "REFUSES to arm" "$T/c57.$which.b.log"
  kill "$alive" 2>/dev/null || true; rm -f "$S.pid"
done
rm -f "$FB57/ps"
cd "$T"

reached_totals=1
echo
echo "$pass passed, $fail failed"
[ "$fail" = 0 ] || exit 1
