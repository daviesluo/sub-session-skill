#!/bin/sh
# Copyright 2026 Zheng Luo (Davies Luo). Licensed under the Apache License
# 2.0, whose text is the LICENSE file in this package. Keep this notice
# when you copy the script.
#
# inject.sh <app-name> <stamp-file> [line...]
#
# Types one line into a chat application's input box and presses enter, then
# WAITS until that turn finishes. Point a watcher's ON_CHANGE at it and the
# seat's own window does the work, in front of the person paying for it:
#
#   ON_CHANGE="sh .../bin/inject.sh Cursor /tmp/local_stamp 'INBOX CHANGED: read collab/INBOX_local.md from origin/main and execute every unacked Open instruction.'"
#
# THE STAMP SITS OUTSIDE EVERY WORKING TREE, one path per seat, which is why
# the example names a temporary file and not `.git/<name>_stamp`. In a linked
# worktree `.git` is a FILE pointing at the real git directory, so a relative
# `.git` path cannot hold a stamp at all; the guard below refuses that case
# loudly, and a path no lane owns never reaches it.
#
# INJECTION IS THE PREFERRED PATH ON EVERY PLATFORM. A headless turn writes
# into a command-line transcript and the window the user watches does not
# move, so a working seat and a dead one look identical. Injection creates a
# real, visible turn instead. Fall back to a headless entry point only where
# injection cannot work: no desktop, no accessibility grant, a seat on a
# server. Never configure BOTH for one seat. The headless turn and the
# injected turn are two different agents, they hold none of each other's
# locks, and a live deployment ran two of them over the same outbox.
#
# HOW THE KEYBOARD PATH FOCUSES, and this is general, not per application.
# Activate the named application, then drive the frontmost process whose
# bundle identifier matches that application. Never `tell process <app-name>`:
# Electron and other wrappers register a process name that is not the
# application name (a Codex.app window is ChatGPT to System Events). After
# activate, if the front process is some other bundle, nothing was brought
# forward and this script types nothing. Then focus a text input: use the
# focused AX field if it is already a text area or field, otherwise click
# the lower centre of the front window, which is where chat composers sit
# on every desktop client measured. WHEN THE FOCUSED ELEMENT'S ROLE CANNOT
# BE READ, Select All is skipped and the paste still goes ahead: Select All
# is what could wipe a transcript, and pasting into an unknown field is at
# worst a no-op. An earlier version aborted instead, and Electron windows
# whose role reads as nothing made Cursor injections fail until a retry
# happened to land. Paste through the Edit menu (Paste / 粘贴) so a CJK
# input method cannot swallow the paste as letters, and fall back to key
# code 9 only if the menu is missing. Restore the clipboard only after the
# application has had time to handle the paste, not when System Events has
# posted it.
#
# WHY IT WAITS. Injection is asynchronous: the keystroke returns the moment
# enter is pressed, while the turn it started runs on inside the application.
# A watcher holds its per-seat lock only for as long as ON_CHANGE runs, so an
# injector that returned immediately would drop the lock with its own turn
# still going, and the next change would start a second turn beside the first.
# So this script blocks until the seat says it has finished.
#
# THE SEAT REPORTS COMPLETION BY ECHOING A NONCE, not by touching a file.
# This script mints a fresh nonce per injection, tells the seat to write it,
# and waits for THAT nonce to appear. A bare timestamp file cannot do the job:
# any other turn advancing it makes this one look finished, and a seat that
# rewrites the same second leaves both the bytes and a minute-resolution
# modification time unchanged, so a genuinely fast turn is missed. Both were
# found in review before either could bite.
#
# EXIT STATUS IS THE CONTRACT with the watcher.
#   0   the turn ran and finished. THAT IS NOT PROOF THE INSTRUCTION WAS
#       CARRIED OUT. A seat that echoes the nonce and does nothing else
#       returns 0 here and the watcher records the change as handled.
#       Requiring the seat's outbox to carry [done: ID] is the phase after
#       this one and it is not shipped.
#   75  THE TURN MAY STILL BE RUNNING. The watcher must KEEP ITS LOCK and must
#       not start another turn, because a retry here would meet a live turn.
#       This is the timeout path and it is the dangerous one: the earlier
#       version returned a plain failure, the watcher released the lock on
#       every failure, and a retry could then run beside the turn that had not
#       finished. Found in review, never shipped in that state.
#   1   nothing was typed, so nothing is running. Retry freely.
set -u

APP=${1:?usage: inject.sh <app-name> <stamp-file> [line...]}
STAMP=${2:?usage: inject.sh <app-name> <stamp-file> [line...]}
shift 2

# THE STAMP PATH IS CHECKED BEFORE ANYTHING IS TYPED, and a relative `.git/...`
# is the trap it exists for. In a LINKED WORKTREE `.git` is a FILE pointing at
# the real git directory somewhere else, so `.git/seatchat_stamp` cannot be
# created at all: the paste lands, the seat runs, its acknowledgement goes
# nowhere, and this script waits out the full ACK timeout and reports a
# delivery failure that never happened. Measured on a Codex seat whose clone
# was a linked worktree. Ninety seconds wasted per attempt, for ever, on a
# transport that was working.
case $STAMP in
  .git/*|*/.git/*)
    d=${STAMP%/*}
    if [ ! -d "$d" ]; then
      real=$(git rev-parse --absolute-git-dir 2>/dev/null || true)
      echo "inject.sh cannot use $STAMP because ${d} is not a directory. In a linked worktree .git is a FILE pointing at the real git directory, so a relative .git path cannot hold a stamp and the seat's acknowledgement would go nowhere while this script waited out its whole timeout. Use an absolute path${real:+, for example $real/$(basename "$STAMP")}."
      exit 1
    fi ;;
esac

TIMEOUT=${TIMEOUT:-3600}   # seconds to wait for the turn to finish
DELIVER=${DELIVER:-60}   # seconds a delivery command may take before it is given up on
ACK=${ACK:-90}             # seconds to wait for the seat to say it STARTED
SETTLE=${SETTLE:-5}        # seconds before the first look
POLL=${POLL:-5}            # seconds between looks
case $TIMEOUT in ''|*[!0-9]*) echo "TIMEOUT must be whole seconds, using 3600"; TIMEOUT=3600;; esac
case $ACK in ''|*[!0-9]*) echo "ACK must be whole seconds, using 90"; ACK=90;; esac
case $SETTLE in ''|*[!0-9]*) echo "SETTLE must be whole seconds, using 5"; SETTLE=5;; esac
case $DELIVER in ''|*[!0-9]*) echo "DELIVER must be whole seconds, using 60"; DELIVER=60;; esac
[ "$DELIVER" -lt 1 ] && DELIVER=1
case $POLL in ''|*[!0-9]*) echo "POLL must be whole seconds, using 5"; POLL=5;; esac
[ "$POLL" -lt 1 ] && POLL=1
[ "$SETTLE" -lt 1 ] && SETTLE=1

# The line comes from the arguments, or from stdin when there are none, so a
# watcher can pipe the inbox straight in. NEWLINES BECOME SPACES on purpose:
# a chat input box sends on the first enter, so a multi-line paste would
# submit a fragment and leave the rest sitting in the box.
if [ "$#" -gt 0 ]; then LINE="$*"; else LINE=$(cat); fi
LINE=$(printf '%s' "$LINE" | tr '\n\r\t' '   ')
case $LINE in '') echo "inject.sh was given nothing to type"; exit 1;; esac

# A nonce this injection alone can be finished by. No coreutils beyond what
# every POSIX shell has: the pid, the clock, and the caller's own line.
NONCE=$(printf 'inj-%s-%s' "$$" "$(date +%s)")
# THE INJECTED COMMAND IS SHELL SOURCE and the seat will run it, so the stamp
# path is single-quoted before it goes in. This package supports installation
# paths containing spaces, and it tests for them, so an unquoted redirect here
# would have written the completion token to the wrong file, or to two files,
# on exactly the installations the rest of the package is careful about. An
# embedded single quote is closed and re-opened the POSIX way.
q_stamp=$(printf "%s" "$STAMP" | sed "s/'/'\\\\''/g")
LINE="$LINE FIRST, before anything else, run: echo $NONCE started > '$q_stamp'"
LINE="$LINE Finally, as the LAST act of this turn, run: echo $NONCE > '$q_stamp'"

# TWO MARKERS, MATCHED EXACTLY. `started` contains the nonce, so a substring
# test would read the acknowledgement as a completion and report a turn
# finished the moment it began.
done_yet()  { [ "$(cat "$STAMP" 2>/dev/null)" = "$NONCE" ]; }
begun_yet() { [ "$(cat "$STAMP" 2>/dev/null)" = "$NONCE started" ]; }
if done_yet; then
  echo "inject.sh minted a nonce that is already in $STAMP, which cannot happen unless the stamp is being written by something else"
  exit 1
fi

typed=0
# A NAMED DELIVERY COMMAND, TRIED FIRST, because two of this script's problems
# turn out to be the same problem. It only knows how to drive a keyboard, so a
# platform with a real delivery route of its own cannot be driven at all: one
# seat's application takes a one line message through a plain command that
# reaches the running app directly, which is better than a keystroke in every
# way and had no way in here. And the self-test could only fake the keyboard,
# so on a desktop it drove the REAL application and pasted its own fixtures
# into a live seat, measured and recorded.
#
# INJECT_CMD receives the line as its single argument and must exit non-zero
# only if nothing was delivered. Setting it replaces the keyboard entirely,
# which is what makes the suite test the same path on every machine instead of
# one branch on Linux and another against a real window on macOS.
# ONE KEYBOARD, ONE INJECTOR AT A TIME. The window and the clipboard are
# machine-wide, so two watchers injecting into two different applications at the
# same moment fight over both. Measured 27 August: a Cursor injection failed
# with "activate did not bring Cursor forward (front is ChatGPT)" because a
# second injector had activated a different seat a fraction of a second earlier,
# and the clipboard each had just written was equally at risk. Neither was
# broken on its own. The mutex is taken only by the paths that steal the
# foreground, and never by INJECT_CMD, which needs no window and must not be
# serialised behind one.
#
# THE LOCK IS A SYMLINK, and that is the whole design. ln -s creates the name
# and its payload in ONE atomic step, so the lock never exists without its
# owner recorded beside it. The first version used mkdir and then wrote a pid
# file inside, which is two steps: a second injector arriving in the gap read
# no owner, called the lock corrupt and deleted a lock that was alive. Measured
# 27 August with the publication of the pid deliberately delayed, two injectors
# drove the keyboard together for 1.15 seconds.
#
# The payload is a token unique to this process, so release removes only the
# lock THIS injector took, never one another process created at the same name.
# Release is rm -f on a symlink, which cannot delete a directory tree however
# the path is configured. The first version ran rm -rf on a caller-named path
# and erased an unrelated directory when one was configured by mistake.
FGLOCK=${FGLOCK:-${TMPDIR:-/tmp}/subsession-foreground.lock}
FGWAIT=${FGWAIT:-45}
fg_token=
fg_release(){
  [ "$(readlink "$FGLOCK.reclaim" 2>/dev/null)" = "reclaim.$$" ] &&
    rm -f "$FGLOCK.reclaim" 2>/dev/null
  [ -n "$fg_token" ] || return 0
  [ "$(readlink "$FGLOCK" 2>/dev/null)" = "$fg_token" ] && rm -f "$FGLOCK" 2>/dev/null
  fg_token=
  return 0
}
fg_take(){
  # A NAME THAT IS NOT ONE OF OUR SYMLINKS IS NEVER TOUCHED. Point the dial at
  # a real directory and this refuses rather than removing it.
  if [ -e "$FGLOCK" ] && [ ! -L "$FGLOCK" ]; then
    echo "inject.sh will not use $FGLOCK as its foreground lock, because something that is not one of its own symlinks is already there. Nothing was typed and nothing was removed. Point FGLOCK somewhere else."
    exit 1
  fi
  fg_token="$$.$NONCE"
  fg_i=0
  # THE TRAP GOES UP BEFORE THE LOOP, not after the lock is taken. The loop can
  # hold the reclaim lock for a moment, and an injector killed in that moment
  # used to leave it behind, where it would have blocked every future reclaim.
  trap 'fg_release' EXIT INT TERM
  while [ "$fg_i" -lt "$FGWAIT" ]; do
    if ln -s "$fg_token" "$FGLOCK" 2>/dev/null; then
      return 0
    fi
    # ln failed for one of two reasons and they need different answers. The
    # name is taken, which is contention and clears by itself, or the path
    # cannot be created at all, which never clears. 75 quarantines the watcher
    # for a turn that may be running, and a path that does not exist has no
    # turn behind it, so that case returns 1 and names the path.
    if [ ! -L "$FGLOCK" ] && [ ! -e "$FGLOCK" ]; then
      echo "inject.sh cannot create its foreground lock at $FGLOCK, so it typed nothing. No other injector is involved. The directory above that path has to exist and be writable."
      fg_token=
      exit 1
    fi
    fg_seen=$(readlink "$FGLOCK" 2>/dev/null)
    fg_pid=${fg_seen%%.*}
    case ${fg_pid:-x} in
      ''|*[!0-9]*) : ;;   # an owner we cannot read is waited out, never broken
      *) if ! kill -0 "$fg_pid" 2>/dev/null; then
           # RECLAIMING NEEDS ITS OWN LOCK, because a read followed by rm is
           # not compare-and-delete however carefully the read is written. Two
           # reclaimers both see the dead token, the first removes it, a live
           # injector installs its own, and the second removes THAT. Named by
           # the Codex seat, which is right that portable shell has no atomic
           # compare-and-delete. What it does have is an atomic create, so the
           # reclaimers are serialised behind one and the winner re-reads
           # AFTER taking it. Then the lock cannot have changed underneath,
           # because a new owner can only appear while the name is free and
           # the winner has just seen that it is not.
           # A LEAKED RECLAIM LOCK IS SAFE TO BREAK, which the foreground
           # lock itself is not. Breaking this one can at worst let two
           # reclaimers race for the create below, and only one of them can
           # win an atomic create, so the serialisation survives it.
           fg_rc=$(readlink "$FGLOCK.reclaim" 2>/dev/null)
           case ${fg_rc#reclaim.} in
             ''|*[!0-9]*) : ;;
             *) kill -0 "${fg_rc#reclaim.}" 2>/dev/null ||
                  rm -f "$FGLOCK.reclaim" 2>/dev/null || true ;;
           esac
           if ln -s "reclaim.$$" "$FGLOCK.reclaim" 2>/dev/null; then
             fg_now=$(readlink "$FGLOCK" 2>/dev/null)
             fg_nowpid=${fg_now%%.*}
             case ${fg_nowpid:-x} in
               ''|*[!0-9]*) : ;;
               *) if [ "$fg_now" = "$fg_seen" ] && ! kill -0 "$fg_nowpid" 2>/dev/null; then
                    echo "inject.sh broke a foreground lock left by pid $fg_pid, which is gone"
                    rm -f "$FGLOCK" 2>/dev/null || true
                  fi ;;
             esac
             rm -f "$FGLOCK.reclaim" 2>/dev/null || true
           fi
         fi ;;
    esac
    sleep 1; fg_i=$((fg_i + 1))
  done
  # WAITING OUT THE CLOCK IS NOT A REASON TO TYPE ANYWAY. Another injector is
  # holding the foreground, so pasting now is what produced the measured
  # failure.
  #
  # AND THE CODE IS 1, NOT 75, WHICH IS THE WHOLE POINT OF THE CONTRACT.
  # Nothing has been typed and this function knows it, so "nothing was typed,
  # retry freely" is exactly what happened. Returning 75 here quarantined THIS
  # seat for HOLD minutes because ANOTHER seat held a machine-wide lock, which
  # is the second half of the incident recorded further down this file, where a
  # healthy seat was held for three hours. The repair made then shortened how
  # long a lock is held and left this return alone. The message used to say 75
  # meant the watcher would retry; the watcher says the opposite in its own
  # code, and it is the authority on what it does with the code it receives.
  fg_seen=$(readlink "$FGLOCK" 2>/dev/null)
  case ${fg_seen%%.*} in
    ''|*[!0-9]*) echo "inject.sh waited ${FGWAIT}s and the foreground lock at $FGLOCK names an owner it cannot read, so it typed nothing. Nothing here will clear that by itself. Look at the lock and remove it by hand." ;;
    *) echo "inject.sh waited ${FGWAIT}s for the foreground and another injector still holds it, so it typed nothing and nothing is running here. The watcher is free to try again." ;;
  esac
  exit 1
}

if [ -n "${INJECT_CMD:-}" ]; then
  # THE DELIVERY COMMAND IS BOUNDED, and it was the one wait in this script
  # that nothing stopped. Measured by the review seat: a command sleeping
  # twenty seconds under TIMEOUT=4 and ACK=2 took twenty two seconds, because
  # this call ran to completion before either dial's loop began. While it hangs
  # the watcher holds the seat's turn lock, so an unbounded delivery takes the
  # seat off the air with no dial that stops it, in a script whose whole
  # argument is that waiting is bounded. DELIVER bounds it, sixty seconds by
  # default, which is long for a command whose only job is to hand one line to
  # an application that is already running.
  # AND SIGNALLING IT REACHES THE COMMAND, NOT ONLY A WRAPPER. `sh -c
  # "$INJECT_CMD"` in the background is one shell with the delivery underneath
  # it, and killing that pid alone leaves the delivery running, reparented to
  # init: measured, a command that appends the line and then sleeps was still
  # alive twenty one seconds after this said it had given up. Descendants are
  # collected by PPID while the wrapper is still their parent, since they
  # reparent the moment it dies, and signalled with it. `setsid` was tried and
  # dropped: it forks, so the pid this shell records is not the new group's
  # leader, and macOS does not ship it at all. ONE LEVEL DOWN COVERS THE SHAPE
  # THAT MATTERS and deeper forks still escape, which is the second reason the
  # code below is 75 rather than 1.
  derr=$(mktemp) || exit 1
  sh -c "$INJECT_CMD \"\$1\"" _ "$LINE" > "$derr" 2>&1 &
  dpid=$!
  di=0
  while [ "$di" -lt "$DELIVER" ] && kill -0 "$dpid" 2>/dev/null; do
    sleep 1; di=$((di + 1))
  done
  if kill -0 "$dpid" 2>/dev/null; then
    dkids=$(ps -o pid=,ppid= -e 2>/dev/null | awk -v p="$dpid" '$2 == p { print $1 }')
    # TERM, WAIT, THEN KILL, which is supervise.sh's idiom and was missing here:
    # a delivery that ignores TERM ran on for its full length after this
    # returned.
    kill -TERM "$dpid" $dkids 2>/dev/null
    # AND THE GRACE IS FOR THE DELIVERY, NOT FOR THE WRAPPER OVER IT. This
    # polled `$dpid` alone, and `$dpid` is usually the `sh -c` above the
    # delivery rather than the delivery: measured here, wrapper 15318 over
    # adapter 15320. The wrapper traps nothing, so TERM ends it at once, the
    # loop sees it gone after one second, and KILL lands on an adapter still
    # inside its own handler. An adapter that traps TERM and needs two seconds
    # to put its state back finished that cleanup in 0 of 5 trials on the old
    # loop and 5 of 5 on this one, measured by the review seat and reproduced
    # here. The grace is now spent on every pid this file signalled, which is
    # what the comment above always promised. IT COSTS THE DEAF CASE THE WHOLE
    # GRACE, DELIVER plus five seconds instead of DELIVER plus one, because the
    # loop now waits out the child that is actually refusing. supervise.sh pays
    # fifteen seconds for the same guarantee.
    dk=0
    while [ "$dk" -lt 5 ]; do
      dalive=0
      for dk_p in $dpid $dkids; do
        if kill -0 "$dk_p" 2>/dev/null; then dalive=1; fi
      done
      [ "$dalive" = 1 ] || break
      sleep 1; dk=$((dk + 1))
    done
    kill -KILL "$dpid" $dkids 2>/dev/null
    # AND THE CODE IS 75, BECAUSE THIS EXIT KNOWS LESS THAN ANY OTHER IN THIS
    # FILE. It said 1, "nothing was typed", about a command it had started and
    # abandoned, and 1 tells the watcher to retry freely. Measured: a delivery
    # that hands over the line and THEN hangs had already put the whole
    # instruction and the nonce in front of the seat when this returned 1, so
    # the next poll injected a second time into a seat whose turn was already
    # running, which is the failure the turn lock exists to prevent. The ACK
    # timeout further down already argues this for the WEAKER case, a delivery
    # that returned cleanly and a seat that then said nothing. A delivery
    # killed mid-flight cannot say whether it delivered.
    echo "inject.sh gave up on INJECT_CMD after ${DELIVER}s and signalled it and its children, TERM then KILL. WHETHER THE LINE REACHED THE SEAT IS UNKNOWN: the command was started and then abandoned, so it may have delivered before it hung, and anything it started deeper than one level may still be running. Returning 75, so this seat is left alone rather than injected into twice. The command was: $INJECT_CMD"
    rm -f "$derr"
    exit 75
  fi
  wait "$dpid"; drc=$?
  err=$(cat "$derr" 2>/dev/null); rm -f "$derr"
  if [ "$drc" = 0 ]; then
    typed=1
    [ -n "$err" ] && echo "the delivery command said: $err"
  else
    echo "inject.sh could not deliver through INJECT_CMD: $err"
    exit 1
  fi
elif command -v osascript >/dev/null 2>&1; then
  fg_take
  # macOS. Paste rather than type letter by letter. THE CLIPBOARD MUST ACTUALLY
  # HOLD THE LINE BEFORE ANYTHING IS PASTED. The first version sent pbcopy's
  # failure to /dev/null and pasted anyway, so a clipboard that refused the
  # write made Cmd+V paste WHATEVER THE PERSON HAD COPIED LAST into a chat
  # window and press enter on it. That is worse than doing nothing.
  # THE OPERATOR'S CLIPBOARD IS SNAPSHOT TO A FILE, NOT TO A VARIABLE.
  # `saved=$(pbpaste)` strips every trailing newline, so restoring it hands
  # back something shorter than what was taken: measured at 15 bytes in and 13
  # out on text ending in two newlines. The suite's fixture had no trailing
  # newline and so could never see it. A file preserves the bytes. What it
  # still cannot preserve is a non-text pasteboard, an image or rich text, and
  # that limit is named here rather than left to be discovered.
  savedf=$(mktemp) || exit 1
  pbpaste > "$savedf" 2>/dev/null || : > "$savedf"
  # A NON-TEXT PASTEBOARD IS DESTROYED RATHER THAN MERELY UNPRESERVED, and
  # saying "not preserved" understated it. Measured on a real Mac: with an
  # image on the pasteboard `pbpaste` returns ZERO BYTES, so the snapshot is
  # empty, and restoring it with `pbcopy` afterwards sets an EMPTY plain text
  # clipboard, which clears the image outright. The loss itself happens earlier,
  # when this script's own line is copied, and no text-only path can prevent
  # that. What it can do is refuse to make it worse and refuse to be silent.
  # So a pasteboard holding something this script cannot carry is NAMED, and
  # the empty restore is skipped, which leaves the injected line there instead
  # of nothing at all.
  richclip=0
  if [ ! -s "$savedf" ] && [ -n "$(osascript -e 'clipboard info' 2>/dev/null)" ]; then
    richclip=1
    echo "inject.sh: the clipboard held something that is not plain text, an image or rich text, and this path cannot carry it. It is gone, and that is worth knowing rather than discovering later. Copy it again after this turn." >&2
  fi
  clipf=$(mktemp) || exit 1
  printf '%s' "$LINE" > "$clipf"
  printf '%s' "$LINE" | pbcopy 2>/dev/null || true
  if [ "$(pbpaste 2>/dev/null)" != "$LINE" ] || [ "$(cat "$clipf")" != "$LINE" ]; then
    [ "$richclip" = 1 ] || pbcopy < "$savedf" 2>/dev/null || true
    rm -f "$clipf" "$savedf"
    echo "inject.sh could not put the instruction on the clipboard, so it typed nothing rather than pasting whatever was there before. Another application may be holding the pasteboard."
    exit 1
  fi
  app_as=$(printf '%s' "$APP" | sed 's/\\/\\\\/g; s/"/\\"/g')
  # THE BLIND COMPOSER CLICK IS OFF BY DEFAULT, AND IT WAS A REGRESSION.
  # Until today this path used whatever text input already had focus and it
  # never mis-delivered for the Cursor seat. The click cascade added today
  # guesses the CENTRE of the front window at 88, 80 and 92 percent of its
  # height, which is where a composer sits in a full width chat window and is
  # NOT where one sits in a side docked chat panel. On that layout the click
  # lands in whatever other input happens to be there, the paste goes to a
  # conversation that is not the seat's, and the only sign is the injector
  # timing out ninety seconds later with nothing acknowledged. Measured on the
  # live lane: one delivery lost and fifteen minutes of quarantine behind it.
  # Focus-only is the behaviour that never failed, so it is the default again.
  # INJECT_CLICK=1 restores the cascade for a seat whose composer really is
  # centred and low, and that seat should be named rather than assumed.
  case ${INJECT_CLICK:-} in 1|yes|true) clickok=true ;; *) clickok=false ;; esac
  # THE TRAILING DELAY IS LOAD BEARING. osascript returns once System Events
  # has POSTED the keystrokes, not once the application has HANDLED them.
  # Restoring the clipboard in that gap makes the application paste the
  # restored text, or nothing at all: the window comes forward and the
  # composer stays empty. Drive the frontmost process after activate, not
  # a process named after APP.
  err=$(osascript <<OSA 2>&1
set appName to "$app_as"
set clipPath to "$clipf"
set CLICKOK to ($clickok)
set targetBundle to id of application appName
tell application appName to activate
delay 1.5
tell application "System Events"
  set afterProc to first process whose frontmost is true
  set afterName to name of afterProc
  if bundle identifier of afterProc is not targetBundle then error "activate did not bring " & appName & " forward (front is " & afterName & ")"
  tell afterProc
    if (count of windows) is 0 then error "frontmost process " & afterName & " has no window"
    set w to window 1
    set already to false
    try
      set fe to value of attribute "AXFocusedUIElement"
      set r to role of fe
      if r is "AXTextArea" or r is "AXTextField" or r is "AXComboBox" then set already to true
    end try
    -- ASK THE WINDOW WHERE ITS COMPOSER IS RATHER THAN GUESS A COORDINATE.
    -- The click below aims at the middle of the front window and works only
    -- when the composer is centred and low. On a side docked chat panel it
    -- lands in whatever other input happens to sit there, which is why it is
    -- off by default, and with it off the run used to stop here and deliver
    -- nothing. The accessibility tree already knows where the text areas are.
    --
    -- LAST MATCH FIRST, because a composer sits at the BOTTOM of a chat panel
    -- while the transcript above it may expose text areas of its own. Bounded
    -- by a timeout because the whole-tree walk visits every element and a large
    -- editor window has thousands of elements: if it does not finish, the
    -- click and the refusal below are still there.
    if already is false then
      try
        with timeout of 8 seconds
          set cands to entire contents of w
        end timeout
        repeat with n from (count of cands) to 1 by -1
          try
            set el to item n of cands
            set r to role of el
            if r is "AXTextArea" or r is "AXTextField" or r is "AXComboBox" then
              set focused of el to true
              delay 0.2
              set fe to value of attribute "AXFocusedUIElement"
              set r2 to role of fe
              if r2 is "AXTextArea" or r2 is "AXTextField" or r2 is "AXComboBox" then
                set already to true
                exit repeat
              end if
            end if
          end try
        end repeat
      end try
    end if
    if already is false and CLICKOK is false then
      error "no text input was focused, the accessibility tree offered no text area this window would take focus on, and the composer click is off, so nothing was typed. The click guesses a coordinate in the front window and on a side docked chat panel it lands in whatever other input sits there. Focus the seat's composer once, or set INJECT_CLICK=1 for a seat whose composer is centred and low."
    end if
    if already is false then
      set p to position of w
      set sz to size of w
      set x to ((item 1 of p) + (item 1 of sz) * 0.5) as integer
      set y88 to ((item 2 of p) + (item 2 of sz) * 0.88) as integer
      set y80 to ((item 2 of p) + (item 2 of sz) * 0.80) as integer
      set y92 to ((item 2 of p) + (item 2 of sz) * 0.92) as integer
      click at {x, y88}
      delay 0.45
      try
        set fe to value of attribute "AXFocusedUIElement"
        set r to role of fe
        if r is "AXTextArea" or r is "AXTextField" or r is "AXComboBox" then set already to true
      end try
      if already is false then
        click at {x, y80}
        delay 0.45
        try
          set fe to value of attribute "AXFocusedUIElement"
          set r to role of fe
          if r is "AXTextArea" or r is "AXTextField" or r is "AXComboBox" then set already to true
        end try
      end if
      if already is false then
        click at {x, y92}
        delay 0.45
        try
          set fe to value of attribute "AXFocusedUIElement"
          set r to role of fe
          if r is "AXTextArea" or r is "AXTextField" or r is "AXComboBox" then set already to true
        end try
      end if
    end if
    -- AN UNRECOGNISED FOCUS IS NOT A REASON TO GIVE UP, and treating it as one
    -- was a regression. The three roles below are what the composers measured
    -- so far report, and an application whose composer reports something else
    -- was refused outright: a seat whose injection had never once failed began
    -- failing repeatedly, moving its window and then aborting, and succeeded
    -- only when a click happened to land on a control this list knows.
    --
    -- WHAT THE ABORT WAS PROTECTING IS THE SELECT ALL, not the paste. Select
    -- All in a transcript and then paste replaces what the person is reading;
    -- a paste alone into an unknown field is at worst a no-op. So an unknown
    -- focus now SKIPS the Select All and pastes anyway, and only a window that
    -- could not be brought forward at all is still refused. The nonce wait is
    -- what decides whether it worked, which is what it was always for.
    set replaceFirst to already
    set the clipboard to (do shell script "cat " & quoted form of clipPath)
    delay 0.2
    if replaceFirst then
      try
        click menu item "Select All" of menu "Edit" of menu bar 1
      on error
        try
          click menu item "全选" of menu "编辑" of menu bar 1
        end try
      end try
    end if
    delay 0.12
    try
      click menu item "Paste" of menu "Edit" of menu bar 1
    on error
      try
        click menu item "粘贴" of menu "编辑" of menu bar 1
      on error
        key code 9 using command down
      end try
    end try
    delay 1.2
    set pasted to ""
    try
      set fe to value of attribute "AXFocusedUIElement"
      set pasted to value of fe as text
    end try
    key code 36
    delay 1.0
    return pasted
  end tell
end tell
OSA
) && rc=0 || rc=$?
  rm -f "$clipf"
  [ "$richclip" = 1 ] || pbcopy < "$savedf" 2>/dev/null || true
  rm -f "$savedf"
  # CLASSIFY THE FAILURE, because the two exit codes mean opposite things to
  # the watcher and guessing wrong in one direction starts a second turn.
  # Exit 1 says NOTHING IS RUNNING and the watcher retries at once, so it is
  # only ever returned where no keystroke can have reached the application.
  # THREE FAILURES ARE OF THAT KIND: a missing Accessibility grant, an
  # application that is not running, and a window this script would not type
  # into because it could find nothing to type into. All three raise before
  # the clipboard is even set. EVERY OTHER FAILURE RETURNS 75, because a paste
  # that got halfway is a turn that may be running, and calling that "nothing
  # was typed" is how a retry meets a live turn.
  if [ "$rc" != 0 ]; then
    case "$err" in
      *"not allowed"*|*assistive*|*1002*)
        echo "inject.sh could not type into $APP because the TERMINAL RUNNING THIS WATCHER has no Accessibility grant. The grant goes to the application that SENDS the keystrokes, not to $APP. Measured on a live seat: the operator granted the target application, the window still came forward with an empty composer, and it took a probe to see why, because activating an application needs only Automation while typing into it needs Accessibility, and only the second was missing. Add your terminal under System Settings, Privacy and Security, Accessibility, then QUIT AND REOPEN IT, since the decision is cached per process and a running terminal keeps the refusal. Start a fresh watcher from the new one. Until then this seat has no injected path and must use a headless one."
        exit 1 ;;
      *"isn't running"*|*-600*)
        echo "inject.sh could not reach $APP because it is not running"
        exit 1 ;;
      *"did not bring"*|*"no window"*)
        echo "inject.sh typed nothing into $APP: $err"
        exit 1 ;;
      *"no text input was focused"*)
        # AND THIS ONE WAS COSTING FIFTEEN MINUTES A TIME. The AppleScript
        # raises it before the clipboard is set and before any paste, and its
        # own text ends "so nothing was typed", yet it had no pattern here and
        # fell to the catch-all below: the watcher was told the outcome was
        # unknown, held the seat's turn lock for the whole quarantine and never
        # retried. Measured on a live Cursor seat, where an instruction pushed
        # to the inbox simply never arrived and the lock sat there with nobody
        # holding it. The remedy is in the message the script already wrote.
        echo "inject.sh typed nothing into $APP: $err"
        exit 1 ;;
      *)
        echo "inject.sh failed against $APP in a way it does not recognise, so it CANNOT say whether anything was typed: $err. Returning 75 so the watcher holds its lock rather than starting a second turn."
        exit 75 ;;
    esac
  fi
  # A WARNING ON A SUCCESSFUL RUN IS NOT A FAILURE. An earlier version failed
  # on any output at all, which turned a harmless warning, and a partial
  # delivery that DID type, into "nothing was typed", released the lock and
  # retried. If the keystrokes landed the nonce arrives and this succeeds; if
  # they did not, the wait times out and returns 75, which is the safe answer.
  # AND AN EMPTY READ IS NOT A CONFIRMED DELIVERY, which the next line used to
  # imply. The only evidence this path has that the paste reached the seat's
  # composer is this accessibility read, and an Electron composer routinely
  # returns nothing, so an empty read separates nothing from nothing. Saying
  # `injected into' after it is a value trusted as evidence of something it
  # does not establish, and today it cost a delivery: the paste landed in a
  # composer belonging to another conversation, the log said injected, and the
  # only sign was a timeout ninety seconds later. The compute seat patched its
  # own live copy the same way and asked for the wording here.
  if [ -n "${err:-}" ]; then
    echo "composer after paste echoed the instruction, so it reached a text input: $err"
    landed=confirmed
  else
    # AN UNREADABLE COMPOSER IS NOT AN EMPTY ONE, and printing `<empty>` said
    # the opposite. Measured on Antigravity by the Cursor seat: that window's
    # composer is an AXTextArea described `Message input` whose `value` reads
    # empty AT REST, before anything is pasted, so this line printed `<empty>`
    # on a paste that had landed perfectly and taught the operator to go
    # looking for a delivery failure that was not there.
    echo "could not read the composer back on $APP, which is normal where the application exposes no value for it, so this proves nothing either way. The acknowledgement is the only evidence that the paste landed."
    landed=unconfirmed
  fi
  typed=1
# THE TWO KEYBOARD BACKENDS ARE ONE CONTRACT, and this one used to break it.
# The macOS path errors out when activate did not bring the named application
# forward. This path swallowed the same failure with `|| true` and then typed
# an instruction, and pressed Return, into whatever did have focus: an editor,
# a terminal, a browser, another seat. A wrong window is worse than no
# delivery, because no delivery is retried and a wrong window is submitted.
# Each step now reports its own failure and NOTHING IS TYPED UNTIL ACTIVATE
# HAS SUCCEEDED. The lock the trap already owns is released by the trap.
elif command -v xdotool >/dev/null 2>&1; then
  fg_take
  win=$(xdotool search --name "$APP" 2>/dev/null | tail -1)
  case $win in '') echo "inject.sh found no window matching $APP"; exit 1;; esac
  xdotool windowactivate --sync "$win" 2>/dev/null || true
  # ASK WHAT IS ACTUALLY IN FRONT, the way the macOS path asks for the front
  # bundle, because an exit status answers whether the request was accepted
  # and not whether it worked. An unreadable answer refuses too: typing into
  # a window nothing can name is the harm this is here to prevent.
  front=$(xdotool getactivewindow 2>/dev/null || true)
  if [ "$front" != "$win" ]; then
    echo "inject.sh REFUSED TO TYPE: activate did not bring $APP (window $win) forward, and the front window is ${front:-unreadable}. The keystrokes would have gone there. Nothing was typed."
    exit 1
  fi
  # A FAILED `type` IS THE UNKNOWN CASE, NOT THE EMPTY ONE, and this line used
  # to return 1, which tells the watcher nothing was typed and invites a free
  # retry. The window was already activated and xdotool types character by
  # character, so a failure part way leaves a fragment in the composer, and a
  # retry appends a second instruction to it or submits the fragment. Found by
  # the Codex seat with a fake xdotool that wrote a partial payload and then
  # failed. The macOS path has always drawn this line correctly: 1 is returned
  # only where no keystroke can have reached the application, and everything
  # uncertain is 75.
  if ! xdotool type --clearmodifiers --delay 12 -- "$LINE" 2>/dev/null; then
    echo "inject.sh could not type into $APP after activating it. WHETHER ANY OF THE INSTRUCTION LANDED IS UNKNOWN: xdotool types character by character, so a fragment may be sitting in that composer. Returning 75, so this seat is left alone rather than typed into twice. Look at that window before injecting again."
    exit 75
  fi
  if ! xdotool key --clearmodifiers Return 2>/dev/null; then
    echo "inject.sh typed the instruction into $APP and could not press Return, so it is sitting unsent in the composer."
  fi
  typed=1
fi

if [ "$typed" -eq 0 ]; then
  case $(uname -s 2>/dev/null) in
    Darwin) echo "inject.sh has no way to type on this machine: osascript is missing, which should not happen on macOS. Configure the seat's headless entry point instead." ;;
    CYGWIN*|MINGW*|MSYS*|Windows_NT) echo "inject.sh SHIPS NO WINDOWS KEYBOARD PATH. Injection cannot drive a seat here, so configure the seat's headless entry point, which needs no window. APPENDIX.md names UI Automation and the macro tools as the routes somebody would have to build, and none of them is shipped or measured." ;;
    *) echo "inject.sh has no way to type on this machine, so this seat cannot be driven by injection. Install xdotool, or configure the seat's headless entry point instead." ;;
  esac
  exit 1
fi

case ${landed:-confirmed} in
  unconfirmed)
    echo "typed into $APP as $NONCE, LANDING UNCONFIRMED, waiting up to ${ACK}s for it to start and ${TIMEOUT}s for it to finish. Nothing here proves the keystrokes reached this seat's composer rather than another one, and the acknowledgement is the only thing that will." ;;
  *)
    echo "injected into $APP as $NONCE, waiting up to ${ACK}s for it to start and ${TIMEOUT}s for it to finish" ;;
esac

# THE FOREGROUND IS RELEASED THE MOMENT THE KEYSTROKES ARE SENT, and not when
# this script exits. The lock exists so that two injectors cannot bring windows
# forward at the same moment; once enter has been pressed, this one wants
# nothing from the foreground and only watches a file. Holding it through the
# wait made ONE seat's turn block every other seat on the machine for up to
# TIMEOUT, an hour by default. Measured on a live Mac: an injector had held it
# since 18:24 waiting on a turn that never acknowledged, and a third seat's
# watcher spent the next three hours taking 75 at FGWAIT and quarantining
# itself, with nothing wrong at that seat at all. Reclaim does not help,
# because it frees a lock whose owner is GONE and this owner is alive.
fg_release

# A PASTE THAT NEVER LANDED USED TO COST A FULL TIMEOUT, and the paste goes
# wherever the focus is. Measured on a live seat: the instruction went into the
# MASTER's window instead of the seat's, the seat never saw it, and this script
# waited out its whole hour before the watcher quarantined a lock for another
# hour on top. Ninety-odd minutes of a working seat, for a keystroke that
# landed in the wrong box.
#
# So the seat is now asked to say it has STARTED as its first act, and the
# absence of that within ACK seconds is a strong signal that nothing was
# received. THE ANSWER IS STILL 75 AND NOT 1, because "probably not received"
# is not "certainly not received": a seat that ignores the first-act
# instruction, or writes it late, is running a turn that a retry would meet.
# What changes is WHEN the watcher learns, which is a minute and a half rather
# than an hour, and the quarantine clock starts that much sooner.
waited=0
step=$SETTLE
begun=0
while :; do
  sleep "$step"
  waited=$((waited + step))
  step=$POLL
  if done_yet; then
    echo "the seat echoed $NONCE into $STAMP after ${waited}s, so its turn is finished"
    exit 0
  fi
  if [ "$begun" = 0 ] && begun_yet; then
    begun=1
    echo "the seat acknowledged $NONCE after ${waited}s, so the paste landed and a turn is running"
  fi
  if [ "$begun" = 0 ] && [ "$waited" -ge "$ACK" ]; then
    echo "NOTHING ACKNOWLEDGED IN ${ACK}s: the seat has not written \"$NONCE started\" to $STAMP, so the paste most likely never reached this seat's conversation. Where the keyboard is used, the commonest cause is focus: it types into whichever composer is frontmost in $APP and does not select a thread, so a window showing another conversation swallows the instruction. Where INJECT_CMD is set, the command reported success and the seat still said nothing. Returning 75 rather than 1, because a seat that simply ignored the first-act instruction IS running a turn and a retry would meet it. Check which window has focus, and prefer a driver that targets this seat's conversation by name."
    exit 75
  fi
  if [ "$waited" -ge "$TIMEOUT" ]; then
    # SAY WHICH OF THE TWO SILENCES THIS IS. An acknowledged turn that has not
    # finished is a long turn. An unacknowledged one that ran to TIMEOUT is the
    # mis-landed paste, reached this way whenever ACK is set above TIMEOUT.
    if [ "$begun" = 1 ]; then
      why="the seat DID acknowledge the paste, so this is a turn that is taking longer than ${TIMEOUT}s"
    else
      why="the seat never acknowledged the paste either, so it may never have arrived"
    fi
    echo "TURN MAY STILL BE RUNNING: $NONCE has not reached $STAMP within ${TIMEOUT}s, and $why. Returning 75 so the watcher KEEPS ITS LOCK and starts nothing beside it. Raise TIMEOUT above the longest turn this seat runs."
    exit 75
  fi
done
