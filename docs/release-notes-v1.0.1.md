# sub-session v1.0.1

Draft notes for a GitHub Release. This file is the draft only: the
tag and the Release have not been created.

**1.0.1** is a packaging and documentation revision of the **1.0**
protocol (September 2026). The rules are the same. The package is
easier to try, easier to list, and cheaper to load.

## What's new

- **Install in one line.** `npx skills add daviesluo/sub-session-skill`
  finds the `sub-session` skill and copies the package, including
  `bin/` with executable bits, into the scanned skills directory.
  `-a claude-code`, `-a cursor` and `-a codex` pick the agent.
- **README that starts with the try-it path.** Three-sentence pitch,
  a 30-second demo, install, a 60-second quickstart, when to use /
  when not to use, and a comparison table against Claude Squad and
  OpenRig using only cells those READMEs support.
- **Demo GIF** at `docs/demo.gif`, recorded from this package's own
  watchers and notifier on a throwaway `hello-notes` repo. The second
  clone is labelled as a seat stand-in, not as another vendor.
- **Lean `SKILL.md`.** The protocol body is under 500 lines. The rest
  of the v1.0 text lives unchanged in `references/*.md`, one level
  from `SKILL.md`. `scripts/check-skill-coverage.sh` proves every
  non-empty original line is still present. Rewritten lines are listed
  in `docs/skill-line-rewrites.md`.
- **Claude Code marketplace.** `.claude-plugin/marketplace.json` and
  `.claude-plugin/plugin.json` name the plugin `sub-session` and point
  its skill at this package (`"."`).
- **Live self-test.** GitHub Actions runs `sh bin/selftest.sh` on
  Ubuntu and macOS. The README badge tracks that workflow instead of
  a hard-coded case count.

## What did not change

- The seven POSIX scripts, their defaults, and the self-test cases.
- The one-writer bus, the master-only merge rule, and the starter
  prompts (the prompts are now in `references/setup.md`).
- License: Apache-2.0.
- Measured facts still quoted: 59 s Codex round trip; loading checked
  on Claude Code, Codex, Cursor, opencode and grok; a live team across
  Claude Code, Cursor, Codex and Antigravity.

## Install

```sh
npx skills add daviesluo/sub-session-skill
```

Then tell your main session: "You are the master. Set up a sub-session
team."

## Protocol version

The protocol file still says **Version 1.0, September 2026**. 1.0.1 is
the package revision that relocated that file's body and added the
install, marketplace and CI surfaces above.
