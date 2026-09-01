#!/bin/sh
# Copyright 2026 Zheng Luo (Davies Luo). Licensed under the Apache License
# 2.0, whose text is the LICENSE file in this package. Keep this notice
# when you copy the script.
#
# notify.sh <peer> <self>      cross-session link, a seat or the master
# notify.sh <self>             one session's own events, no peer involved
#
# Raises one desktop notification, in the team's single format, for one
# watcher state change. Written to be pointed at by the watchers' NOTIFY hook
# and by nothing else:
#
#   NOTIFY="sh .../bin/notify.sh 'Claude Opus 5' 'Cursor Composer'" \
#     sh .../bin/watch-inbox.sh local main cloud
#
# The watcher runs NOTIFY with two variables set, NOTIFY_STATE being one of
# armed, started, finished, failed, slowing, recovered or alarm, and
# NOTIFY_TEXT being one line about it. A third, NOTIFY_FLOW, is set only when
# a message actually crossed, and it says which way. Everything else comes
# from here, which is the point: ONE format for the whole team, so a person
# glancing at a notification never has to work out whose convention they are
# reading.
#
#   Claude Opus 5 → Cursor Composer        a task arriving at the seat
#   started
#   an inbox change arrived, starting a turn
#
#   Cursor Composer → Claude Opus 5        the same seat reporting back
#   finished
#   the turn ended, its report is the seat's to push
#
#   Cursor Composer                        this session's own event
#   alarm
#   the branch main is gone from the remote
#
# THE ARROW IS FOR TRAFFIC BETWEEN SESSIONS AND NOTHING ELSE. A team mixing
# Claude, Cursor, Codex and others raises notifications that otherwise all
# look alike, and when a message crosses, the direction is the first thing
# worth knowing: an instruction going out to a seat and a finding coming back
# from one mean different things to the person watching. But a watcher arming,
# a turn failing, a link falling silent are ONE session's own business, and
# writing an arrow on them says a message moved when none did.
#
# THE DIRECTION IS THE CALLER'S TO DECLARE, because only the caller knows it.
# This script used to infer it from the state, treating started and finished
# alike as PEER to SELF, and that was wrong on the commonest event of all: a
# seat's inbox watcher fires started when a task ARRIVES and finished when the
# work goes BACK, so both rendered master to seat and a completed task looked
# exactly like a new one. Davies caught it on sight. A state name cannot carry
# a direction, since the same name means an inbound message on one watcher and
# an outbound one on another. So the caller sets NOTIFY_FLOW to `in` for a
# message arriving from the peer, `out` for one going to the peer, and leaves
# it unset when nothing crossed.
#
# AN UNDECLARED FLOW GETS NO ARROW. A wrong arrow is worse than no arrow: it
# asserts a direction that is not true, while a missing one only withholds
# something the text usually says anyway. So a caller that forgets degrades
# to the plain title rather than to a lie.
#
# ARGUMENT ORDER IS ALWAYS PEER THEN SELF, which reads the same on both sides
# of the bus. A seat's INBOX watcher is the master talking to the seat, so the
# seat passes the master then itself. A master's OUTBOX watcher is the seat
# talking back, so the master passes the seat then itself. Give one label only
# where nothing crosses, a single session's own timer or scheduled task, and
# every line is that session's own.
#
# A LABEL IS THE PLATFORM AND THE MODEL, never the platform alone. One tool
# runs many models and two seats on the same tool are different colleagues:
# `Cursor Grok` and `Cursor Composer` are not interchangeable, and a
# notification saying only `Cursor` leaves the reader guessing which seat
# spoke. Take both halves from the same place the ledger's source header
# takes them, so a notification and a ledger entry name the same session, and
# CHANGE THE LABEL WHEN THE SEAT CHANGES MODEL, because a stale label is worse
# than none: it names a colleague who is not the one working.
#
# AND KEEP IT SHORT, three or four words, because it is a title and not a
# record. `Codex GPT-5`, never `Codex GPT-5 (reasoning effort unavailable)`.
# Qualifiers, version strings and notes about what a platform declines to
# expose belong in the ledger's source header, which is written to be
# read once and carefully. A title is read at a glance, on a phone, beside
# five others, and a parenthetical there eats the room the arrow and the
# peer need.
#
# THIS SCRIPT EXISTS BECAUSE THE HOOK ALONE WAS NOT ENOUGH. The hook shipped
# and the recipe did not, so every operator retyped an osascript one-liner
# with four levels of quoting into a screen command, and the seats that never
# got round to it stayed invisible. A link that works perfectly and looks dead
# costs the same as a broken one: measured, a master pushed an instruction,
# the seat acknowledged it three minutes later, and the person watching asked
# whether it had been sent at all.
#
# IT CAN NEVER BREAK THE BUS. Every DELIVERY path exits zero, whatever the
# notifier does or fails to do, and a machine with no notifier says so once
# and carries on, because a view of the work must not be able to stop the
# work. The one non-zero exit is the usage guard below, reached only by a
# call that names no session at all, and every shipped caller wraps this hook
# in `|| true` so even that cannot reach the bus. An earlier version of this
# line claimed every path exits zero, which was simply untrue.
set -u

if [ "$#" -ge 2 ]; then PEER=$1; SELF=$2; else PEER=; SELF=${1:?usage: notify.sh <peer> <self>, or notify.sh <self>}; fi
STATE=${NOTIFY_STATE:-note}
TEXT=${NOTIFY_TEXT:-}
FLOW=${NOTIFY_FLOW:-}

# The caller declares the direction and this only renders it. `in` is a
# message arriving from the peer, `out` is one going to the peer, and anything
# else, including nothing, means no message crossed and there is no arrow.
if [ -n "$PEER" ] && [ "$FLOW" = in ]; then
  TITLE="$PEER → $SELF"
elif [ -n "$PEER" ] && [ "$FLOW" = out ]; then
  TITLE="$SELF → $PEER"
else
  TITLE="$SELF"
fi

# A LABEL NAMES A PLATFORM AND A MODEL, and one word cannot be both. `Opus`
# leaves the reader guessing which of several tools is speaking, and Davies
# read exactly that on a live notification. Said on stderr and once, at arming,
# because a notifier must never be able to stop the work it reports on.
if [ "$STATE" = armed ]; then
  for label in "$SELF" "$PEER"; do
    case $label in
      '' | *' '*) ;;
      *) echo "notify.sh: the label \"$label\" is one word, so it names a platform or a model but not both. Two seats on one tool, or one tool running two models, are different colleagues and a reader cannot tell them apart from a single word. Use the platform and the model, as in 'Claude Opus 5' or 'Cursor Composer'." >&2 ;;
    esac
  done
fi

# WHICH NOTIFIER THIS MACHINE HAS, decided before anything is delivered, so a
# machine with none can be reported without also raising a notification.
#
# NOTIFY_BACKEND NAMES THE BRANCH, which is how the three of them get tested
# anywhere. Detection prefers osascript, so on a Mac the other two branches are
# unreachable and their formatting, the Linux urgency mapping and the Windows
# quote doubling, had no coverage at all. Faking the route was tried for the
# injector and failed twice on undocumented details; a named override was the
# repair that worked, so it is the repair here too. Unset, this detects exactly
# as it always did.
# CHOSEN SILENCE IS NOT A BROKEN MACHINE, and the difference decides whether
# the warning below fires. `none` is one of the four documented values and it
# means raise nothing, so telling that operator to install a notifier is both
# false and unactionable, once per state change for as long as the seat runs.
# An unknown name already prints its own precise complaint and must not collect
# the generic one on top. SPOKEN tracks whether this script has already said
# its piece about the backend.
SPOKEN=
case ${NOTIFY_BACKEND:-} in
  osascript|notify-send|powershell) HAVE=$NOTIFY_BACKEND ;;
  none) HAVE=; SPOKEN=chosen ;;
  '')
    if command -v osascript >/dev/null 2>&1; then HAVE=osascript
    elif command -v notify-send >/dev/null 2>&1; then HAVE=notify-send
    elif command -v powershell.exe >/dev/null 2>&1; then HAVE=powershell
    else HAVE=
    fi ;;
  *) echo "notify.sh: NOTIFY_BACKEND=\"$NOTIFY_BACKEND\" names no backend this script has. Use osascript, notify-send, powershell, none, or leave it unset to detect." >&2
     HAVE=; SPOKEN=refused ;;
esac

# ARMING IS NOT AN EVENT ABOUT THE WORK AND DOES NOT REACH THE DESKTOP. It says
# a watcher started, which is the most frequent notification a team raises and
# the least informative: supervisors restart watchers, screens are relaunched,
# containers are rebuilt, and a person with several seats and two watchers each
# gets a burst of them every time, none of which is about the task. Davies
# asked whether it was needed and it is not, at least not there.
#
# WHAT IT WAS FOR STILL MATTERS, and is kept another way. A link that works
# perfectly and looks dead costs the same as a broken one, so arming used to be
# the proof that the desktop path worked at all. That proof now belongs in the
# setup, ONCE per machine, where a person is watching a terminal and can act on
# it: raise one real notification by hand before arming anything. The recipe is
# in the skill beside the arming line. Arming still says its piece on the
# terminal, and still reports a machine with no notifier at all.
# A MACHINE THAT CANNOT SHOW ANYTHING SAYS SO ON EVERY STATE, and not only on
# the one state the protocol tells you not to rely on. This warning used to sit
# inside the `armed` branch below, so the by-hand proof section 2 prescribes,
# which runs with NOTIFY_STATE=started, printed nothing on the screen AND
# nothing on the terminal, leaving the operator unable to tell a missing
# notifier from a working one with nothing to say. The state it also swallowed
# was `alarm`, the one that means a seat has gone silent past its DUE and a
# person is needed. On a machine WITH a notifier this line is never reached, so
# the noise falls only where a seat is genuinely running blind, and there one
# line per notification is the honest report rather than spam.
if [ -z "$HAVE" ] && [ -z "$SPOKEN" ] && [ -z "${NOTIFY_ECHO:-}" ]; then
  echo "notify.sh found no desktop notifier on this machine, so $TITLE will run silently. Install notify-send, or point NOTIFY at something this machine can show." >&2
fi
if [ "$STATE" = armed ]; then exit 0; fi

# ONE SHAPE FOR EVERY NOTIFICATION, so a wall of them reads at a glance:
# newlines and runs of spaces collapse, and a long line is cut rather than
# left to wrap a notification to three times the height of its neighbours.
TEXT=$(printf '%s' "$TEXT" | tr '\n\r\t' '   ' | sed 's/  */ /g; s/^ //; s/ $//')
# THE CUT IS IN BYTES AND IT NEVER SPLITS A CHARACTER, and getting that wrong
# produced two different bugs from one line. `${#TEXT}` and `printf '%.107s'`
# count CHARACTERS in some shells and BYTES in others, so the same text was
# truncated in dash and left whole in the Bash that stock macOS ships. Worse,
# the byte cut landed inside a four-byte code point and emitted a sequence
# `iconv` rejects. Codex measured both with sixty emoji: 240 valid bytes and no
# truncation under Bash 3.2, 110 bytes with an invalid tail under dash, from
# identical input. Every truncation fixture in the suite was ASCII, so nothing
# saw it. LC_ALL=C makes awk count bytes on every platform, and the walk back
# off continuation bytes, then off a lead byte whose sequence was cut, leaves
# only whole characters.
TEXT=$(printf '%s' "$TEXT" | LC_ALL=C awk '
  BEGIN { for (i = 0; i < 256; i++) ord[sprintf("%c", i)] = i }
  { if (length($0) <= 110) { print; exit }
    s = substr($0, 1, 107)
    while (length(s) > 0) {
      b = ord[substr(s, length(s), 1)]
      if (b >= 128 && b < 192) { s = substr(s, 1, length(s) - 1); continue }
      if (b >= 192) s = substr(s, 1, length(s) - 1)
      break
    }
    print s "..." }')

# A FORMAT NOBODY CAN INSPECT IS A FORMAT NOBODY CAN TEST. Set NOTIFY_ECHO
# and the three parts go to stdout instead of to the desktop, which is how
# the self-test asserts the arrow rule on a machine with no notifier at all,
# and how an operator checks what a seat will actually show before arming it.
if [ -n "${NOTIFY_ECHO:-}" ]; then
  printf '%s\n%s\n%s\n' "$TITLE" "$STATE" "$TEXT"
  exit 0
fi

# ONE RANK, DECIDED HERE, RENDERED THREE WAYS. Every backend used to pick its
# own loudness and the three disagreed: `slowing` was audible on macOS and
# ordinary on Linux, `recovered` had a sound on macOS and no special case
# anywhere else, and every Windows balloon came out Info including `failed`
# and `alarm`. A person watching two machines could not learn one rule from
# them. The media cannot be made equal, since a sound is not an icon, but the
# ORDER can be. URGENT means a person is needed. NOTICE means the link changed
# state by itself. Everything else is the ordinary heartbeat and stays quiet.
case $STATE in
  failed|alarm)      RANK=urgent ;;
  slowing|recovered) RANK=notice ;;
  *)                 RANK=ordinary ;;
esac
# AND THE SOUND COMES FROM THE RANK, NOT FROM THE STATE, which is the half of
# this repair that was missed the first time. `notify-send` and the balloon
# both read RANK; the macOS branch spent a SOUND keyed to the STATE, so
# `slowing` played the urgent sound and `recovered`, its rank-mate, played a
# different one. The rank had three levels on Linux and Windows and two on
# macOS with the boundary in the wrong place, under a comment claiming one
# rank rendered three ways. Found by the review seat, which quoted the
# comment back.
case $RANK in
  urgent)  SOUND=Basso ;;
  notice)  SOUND=Glass ;;
  *)       SOUND= ;;
esac

# A BACKEND THAT IS PRESENT AND FAILS LEAVES NO NOTIFICATION AND SAID NOTHING.
# Swallowing the failure is right, since a view of the work must never be able
# to stop the work, but swallowing the DIAGNOSTIC too makes the view silently
# false: the operator believes they are being told about alarms and they are
# not. Measured by the Codex seat with a present notify-send returning 1, which
# produced zero bytes on both streams. One line on stderr, and still exit zero.
backend_failed() {
  echo "notify.sh: $1 is installed and it failed, so \"$TITLE · $STATE\" was NOT shown. The work carried on. Run it by hand to see why, or set NOTIFY_BACKEND=none if this machine is meant to be silent." >&2
  return 0
}

case $HAVE in
  # macOS. A notification needs no permission, unlike the injector beside it,
  # so this works on a stock machine with nothing granted.
  # AND NO BACKEND READS THIS SCRIPT'S STDIN. Each call below takes its
  # input from /dev/null. A notifier is a VIEW of the work and must never
  # be able to stop it, which this file already says of a machine with no
  # notifier at all, and a backend that reads stdin stops it just as
  # completely. Measured on a live Mac: a shim earlier on PATH read stdin,
  # notify.sh was called from inside a screen session whose stdin is a
  # terminal that never ends, and the ARMING of two watchers hung there
  # until a person noticed. Reproduced here at exit 124 before the
  # redirection and 0 after it.
  osascript)
    # Substitute by the SHELL rather than by osascript's own parser, escaping
    # the two characters that would end an AppleScript string early. A finding
    # ID containing a quote would otherwise turn a notification into a syntax
    # error, and a broken notifier must not be able to break the bus.
    esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
    script="display notification \"$(esc "$TEXT")\""
    script="$script with title \"$(esc "$TITLE")\""
    script="$script subtitle \"$(esc "$STATE")\""
    [ -n "$SOUND" ] && script="$script sound name \"$SOUND\""
    osascript -e "$script" >/dev/null 2>&1 </dev/null || backend_failed osascript
    ;;
  # Linux desktops. No subtitle field, so the state folds into the title and
  # the reader still sees the same three parts in the same order.
  notify-send)
    case $RANK in
      urgent)  urgency=critical ;;
      notice)  urgency=normal ;;
      *)       urgency=low ;;
    esac
    notify-send -u "$urgency" "$TITLE · $STATE" "$TEXT" >/dev/null 2>&1 </dev/null ||
      backend_failed notify-send
    ;;
  # Windows, through PowerShell's balloon, which needs nothing installed.
  powershell)
    wesc() { printf '%s' "$1" | sed "s/'/''/g"; }
    case $RANK in urgent) BALLOON=Error ;; notice) BALLOON=Warning ;; *) BALLOON=Info ;; esac
    powershell.exe -NoProfile -Command "
      [reflection.assembly]::LoadWithPartialName('System.Windows.Forms') | Out-Null
      \$n = New-Object System.Windows.Forms.NotifyIcon
      \$n.Icon = [System.Drawing.SystemIcons]::Information
      \$n.Visible = \$true
      \$n.ShowBalloonTip(5000, '$(wesc "$TITLE · $STATE")', '$(wesc "$TEXT")', '$BALLOON')
    " >/dev/null 2>&1 </dev/null || backend_failed powershell
    ;;
esac
exit 0
