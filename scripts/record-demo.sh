#!/bin/sh
# Copyright 2026 Zheng Luo (Davies Luo). Licensed under the Apache License
# 2.0, whose text is the LICENSE file in this package. Keep this notice
# when you copy the script.
#
# Record the README demo: a master pushes an instruction, a second clone
# standing in for a seat receives it, replies in its outbox, and a
# notification line prints. Uses this package's own watchers and notifier.
#
# The toy repository lives under a throwaway directory and is never one of
# the author's project repos. No tokens, account names or public hostnames
# are printed.
#
#   sh scripts/record-demo.sh          # setup, play, write docs/demo.gif
#   sh scripts/record-demo.sh --play   # just the visible loop (for vhs)
#   sh scripts/record-demo.sh --setup  # create the toy repo only
#
# Needs: sh, git, and for --record: asciinema and agg on PATH.

set -e
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
WORK=${SUBSESSION_DEMO_DIR:-/tmp/subsession-demo}
BIN=$ROOT/bin
BARE=$WORK/hello-notes.git
MASTER=$WORK/master
SEAT=$WORK/seat
MODE=record
for a in "$@"; do
  case $a in
    --play) MODE=play ;;
    --setup) MODE=setup ;;
    --record) MODE=record ;;
    *) echo "usage: sh scripts/record-demo.sh [--play|--setup|--record]" >&2; exit 2 ;;
  esac
done

# Isolate git from the operator's identity and signing config.
# record() must not do this: asciinema is a user-site Python script and
# agg/vhs live on the real HOME PATH.
isolate_git() {
  HOME=$WORK/home
  export HOME
  mkdir -p "$HOME"
  GIT_CONFIG_NOSYSTEM=1
  export GIT_CONFIG_NOSYSTEM
  XDG_CONFIG_HOME=$WORK/xdg
  export XDG_CONFIG_HOME
  mkdir -p "$XDG_CONFIG_HOME"
  unset GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM GIT_CONFIG_COUNT GIT_CONFIG GIT_CONFIG_PARAMETERS 2>/dev/null || true
  GIT_PAGER=cat
  export GIT_PAGER
  GIT_TERMINAL_PROMPT=0
  export GIT_TERMINAL_PROMPT
}

git_init_ident() {
  git config user.name "Demo Operator"
  git config user.email "demo@example.invalid"
}

setup() {
  isolate_git
  rm -rf "$WORK"
  mkdir -p "$WORK" "$HOME"
  git config --global init.defaultBranch main
  mkdir -p "$MASTER"
  git init -q -b main "$MASTER"
  (
    cd "$MASTER"
    git_init_ident
    mkdir -p collab
    printf '%s\n' "hello, team" > notes.txt
    git add notes.txt
    git commit -q -m "start the toy notes repo"
  )
  git clone -q --bare "$MASTER" "$BARE"
  git -C "$MASTER" remote add origin "$BARE"
  git -C "$MASTER" push -q -u origin main
  git clone -q "$BARE" "$SEAT"
  (
    cd "$SEAT"
    git_init_ident
    git checkout -q -b work/review
    mkdir -p collab
    : > collab/OUTBOX_review.md
    git add collab/OUTBOX_review.md
    git commit -q -m "open the review seat outbox"
    git push -q -u origin work/review
  )
  # Seat turn: when the inbox changes, do the tiny edit and report.
  # Baked-in path so ON_CHANGE is a single command with no extra quoting.
  cat > "$WORK/seat-turn.sh" <<EOS
#!/bin/sh
set -e
cd "$SEAT"
git fetch -q origin +main:refs/remotes/origin/main
printf '%s\\n' "# hello, team" > notes.txt
now=\$(date -u +"%Y-%m-%d %H:%M:%S")
printf '%s\\n' "- \${now} UTC REVIEW-1 started. Adding a heading to notes.txt." \\
              "- \${now} UTC REVIEW-1 done. Heading added." \\
  >> collab/OUTBOX_review.md
git add notes.txt collab/OUTBOX_review.md
git commit -q -m "add heading [done: REVIEW-1]"
git push -q origin work/review
EOS
  chmod +x "$WORK/seat-turn.sh"
  # The watchers send NOTIFY stdout to /dev/null, so the shipped notifier
  # writes its three-line format to a file we can show.
  cat > "$WORK/notify-tee.sh" <<EOS
#!/bin/sh
NOTIFY_ECHO=1
export NOTIFY_ECHO
sh "$BIN/notify.sh" "\$@" >> "$WORK/notify.log"
EOS
  chmod +x "$WORK/notify-tee.sh"
  : > "$WORK/notify.log"
}

play() {
  isolate_git
  # Always rebuild the toy repo so a leftover inbox cannot fire first.
  setup
  # Fresh watcher state each play.
  rm -f "$MASTER/.git/"*_watch_* "$SEAT/.git/"*_watch_* \
        "$MASTER/.git/turn_"* "$SEAT/.git/turn_"* 2>/dev/null || true

  printf '\n'
  printf '%s\n' "============================================================"
  printf '%s\n' "  sub-session demo  —  throwaway repo: hello-notes"
  printf '%s\n' "  MASTER = this shell"
  printf '%s\n' "  SEAT   = a second clone, standing in for another tool"
  printf '%s\n' "============================================================"
  printf '\n'
  sleep 2

  printf '%s\n' "-- SEAT: arm inbox watcher (P=5, NOTIFY_ECHO, ON_CHANGE) --"
  (
    cd "$SEAT"
    P=5 \
    NOTIFY_ECHO=1 \
    NOTIFY="sh $WORK/notify-tee.sh \"Master shell\" \"Seat clone\"" \
    ON_CHANGE="sh $WORK/seat-turn.sh" \
    sh "$BIN/watch-inbox.sh" review main collab
  ) > "$WORK/seat.log" 2>&1 &
  echo $! > "$WORK/seat.pid"
  sleep 1

  printf '%s\n' "-- MASTER: arm outbox watcher (P=5, NOTIFY_ECHO) --"
  (
    cd "$MASTER"
    P=5 \
    NOTIFY_ECHO=1 \
    NOTIFY="sh $WORK/notify-tee.sh \"Seat clone\" \"Master shell\"" \
    sh "$BIN/watch-outbox.sh" review work/review collab
  ) > "$WORK/master.log" 2>&1 &
  echo $! > "$WORK/master.pid"
  sleep 2

  printf '%s\n' "-- watchers as they armed --"
  sed 's/^/   seat | /' "$WORK/seat.log"
  sed 's/^/ master | /' "$WORK/master.log"
  printf '\n'
  sleep 1

  printf '%s\n' "-- MASTER: write REVIEW-1 and push --"
  (
    cd "$MASTER"
    git fetch -q origin
    git checkout -q main
    mkdir -p collab
    printf '%s\n' "## Open instructions" "" \
      "- REVIEW-1: add a heading to notes.txt. Gate: the file starts with #." \
      > collab/INBOX_review.md
    git add collab/INBOX_review.md
    git commit -q -m "assign REVIEW-1"
    git push -q origin main
    printf '%s\n' "   pushed INBOX_review.md on main"
  )
  sleep 1

  printf '%s\n' "-- waiting for the seat (one poll, P=5) --"
  t0=$(date +%s)
  while [ $(( $(date +%s) - t0 )) -lt 20 ]; do
    if grep -q "REVIEW-1 done" "$SEAT/collab/OUTBOX_review.md" 2>/dev/null; then
      break
    fi
    sleep 1
  done
  sleep 2

  printf '\n'
  printf '%s\n' "-- SEAT watcher (inbox change + turn) --"
  sed 's/^/   seat | /' "$WORK/seat.log"
  printf '\n'
  printf '%s\n' "-- SEAT outbox --"
  sed 's/^/   /' "$SEAT/collab/OUTBOX_review.md"
  printf '\n'

  # Give the master watcher one more poll to see the outbox.
  t0=$(date +%s)
  while [ $(( $(date +%s) - t0 )) -lt 12 ]; do
    if grep -q "REVIEW-1 done" "$WORK/master.log" 2>/dev/null; then
      break
    fi
    sleep 1
  done
  sleep 1

  printf '%s\n' "-- MASTER watcher (new outbox entries) --"
  sed 's/^/ master | /' "$WORK/master.log"
  printf '\n'
  printf '%s\n' "-- notification lines (NOTIFY_ECHO via notify.sh) --"
  if [ -s "$WORK/notify.log" ]; then
    sed 's/^/   /' "$WORK/notify.log"
  else
    printf '%s\n' "   (none captured)"
  fi
  printf '%s\n' "============================================================"
  printf '%s\n' "  done. The seat received the instruction, replied, and a"
  printf '%s\n' "  notification printed. Toy repo discarded after the GIF."
  printf '%s\n' "============================================================"
  printf '\n'
  sleep 3

  kill "$(cat "$WORK/seat.pid")" 2>/dev/null || true
  kill "$(cat "$WORK/master.pid")" 2>/dev/null || true
  # Best effort: the watchers may have child shells.
  if [ -f "$SEAT/.git/inbox_watch_review.pid" ]; then
    kill "$(cat "$SEAT/.git/inbox_watch_review.pid")" 2>/dev/null || true
  fi
  if [ -f "$MASTER/.git/outbox_watch_review.pid" ]; then
    kill "$(cat "$MASTER/.git/outbox_watch_review.pid")" 2>/dev/null || true
  fi
}

record() {
  command -v asciinema >/dev/null || { echo "asciinema is not on PATH" >&2; exit 1; }
  command -v agg >/dev/null || { echo "agg is not on PATH" >&2; exit 1; }
  mkdir -p "$ROOT/docs"
  # Write the cast into docs/ so --play's rm -rf of $WORK cannot delete it.
  CAST=$ROOT/docs/demo.cast
  rm -f "$CAST"
  # Idle-time-limit collapses long waits; keep a little pause so the
  # poll is visible without stretching the GIF past a minute.
  asciinema rec \
    --overwrite \
    --idle-time-limit 2.5 \
    --cols 100 \
    --rows 36 \
    --title "sub-session demo (toy hello-notes repo)" \
    --command "sh \"$ROOT/scripts/record-demo.sh\" --play" \
    "$CAST"
  [ -f "$CAST" ] || { echo "asciinema did not write $CAST" >&2; exit 1; }
  agg \
    --cols 100 \
    --rows 36 \
    --font-size 15 \
    --font-family "JetBrains Mono" \
    --font-dir /usr/share/fonts/truetype/macos \
    --renderer fontdue \
    --theme monokai \
    --speed 0.42 \
    --last-frame-duration 8 \
    "$CAST" "$ROOT/docs/demo.gif"
  echo "wrote $ROOT/docs/demo.gif and $ROOT/docs/demo.cast"
}

case $MODE in
  setup) setup ;;
  play) play ;;
  record) record ;;
esac
