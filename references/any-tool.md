## 8. Running this on any tool

The protocol asks three things of a tool: a shell with git and push
access to a shared remote, a session that comes back to the same clone,
and a way for a person to paste text into it. Everything else is
acceleration.

WHAT EACH TOOL ACTUALLY GIVES YOU IS IN PART ONE OF
[`APPENDIX.md`](APPENDIX.md), and it is the one file to open before
bringing up a seat on a tool you have not used before.

It carries where the skill file goes on each tool and which of them can
schedule a reminder or wake another session. It carries how to run a
seat on a tool with neither, the two lines a person pastes when nothing
else can move the loop, how to make a still chat window move, and what a
batch scheduler changes for a compute seat. It also carries the platform
failures a live deployment paid to learn: which shells reap detached
children, what replaces tmux on stock macOS, how headless authentication
differs from the graphical session, and what a sleeping laptop does to
every timer on it.

A HEADLESS COMMAND LINE TOOL NEEDS NEITHER A SCHEDULER NOR A POKE, and
this is the cheapest unattended seat there is. Where a tool answers a
prompt as a process, THE PROCESS IS THE TURN, so a detached watcher whose
change command is that tool closes the loop with no window, no
accessibility grant and nobody present. Measured on 1 September, twice in
succession, thirty seconds from the master's push to the seat's push, with
the watcher surviving both. Two things decide whether it works. Arm the
watcher from a shell the tool does NOT own, exactly as for a window seat,
since a watcher started from inside a headless turn dies with that turn.
And give the turn the authority to act: a permission MODE alone was
measured running, reporting and writing nothing, so the change command
carries the tool's explicit allowance for the writes and the git calls the
seat's work needs. `APPENDIX.md` carries the measured recipe.

THE FLOOR THIS LOWERS IS THE WINDOW, NOT THE LOGIN. A detached WATCHER
inherits the session that armed it, and a SCHEDULER does not. Measured the
same day on macOS: the same tool, the same absolute path and a corrected
PATH answered `logged in` from a terminal and `not logged in` under the
system cron daemon, which does not inherit the desktop login the tool's
account uses, so every fired turn failed at authentication and produced
nothing. Before putting a seat behind a scheduler rather than a watcher,
run the tool's own authentication check from that scheduler and read the
answer, since a turn that cannot authenticate still exits and still looks
like a turn that ran.

THE CONFIGURATION TO ASSUME WHEN IN DOUBT is the poorest one: no
scheduler, no cross-session delivery, a person relaying one line. Nothing
in this protocol is lost there, because every instruction, report,
finding and ruling is a committed file that any session reads on its next
turn. What is lost is only speed.

