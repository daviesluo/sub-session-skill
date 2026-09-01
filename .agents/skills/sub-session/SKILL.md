---
name: sub-session
description: >-
  Master and sub-session collaboration protocol for running two or more
  sessions on one repository as a coordinated team. Load this when the
  user says a session is the master or a sub-session of a multi-session
  setup: it defines the roles, the git-file communication bus, the
  instruction and report protocols, liveness (self check-ins,
  watchers, wake-up pokes), validation gates, escalation discipline
  and the budget economy rules that keep a team cheap to run, so
  sessions cooperate without stepping on each other or burning the
  user's usage allowance. Works for
  research, software development or any long-running task, with any
  number of sub-sessions, and on any tool with a shell and git, Claude
  Code, Cursor, Codex or another, including teams that mix them.
---

# Read `SKILL.md`, not this file

Copyright 2026 Zheng Luo (Davies Luo), Apache License 2.0, whose text
is the LICENSE file in this package. Keep this line when you copy the
file.

This file is a POINTER, not the protocol. The protocol is ONE file,
`SKILL.md` at the root of this package, so that Claude Code, Cursor,
Codex and anything reading `AGENTS.md` all load the same text and no
copy can go stale against another.

READ THE PROTOCOL NOW, in full, before acting on anything this skill
covers. It is `SKILL.md` at the ROOT OF THIS PACKAGE, which is
`../../../SKILL.md` relative to THIS FILE and plain `SKILL.md` from the
package root. Those are different starting points and a session usually
stands at the second, so if one does not resolve try the other, and if
neither does, find it with `git grep -L 'This file is a POINTER' -- '*SKILL.md'`,
which lists the protocols by excluding every file that says, as this
one does, that it is a pointer.
Do not act on this file alone.

Everything beside the protocol is part of the same package: the
`README.md`, the `APPENDIX.md`, a worked `EXAMPLE.md`, and under `bin/`
the two watchers, the injector, the notifier, the supervisor, the
master rehearsal, and the self-test that syntax checks all seven and
exercises all seven.
