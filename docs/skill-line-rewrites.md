# SKILL.md lines rewritten in the v1.0.1 split

The original protocol is commit `7148399`. Every non-empty line of that
`SKILL.md` is kept verbatim in `SKILL.md` or a file under `references/`.
`scripts/check-skill-coverage.sh` proves that.

This file lists the original lines whose *wording* changed in the slim
`SKILL.md`, and why. Relocated lines (moved into `references/` without
edits) are not listed.

## Rewritten wording

| Original (7148399) | New wording in slim `SKILL.md` | Reason |
|---|---|---|
| `This file is the complete contract. Both sides read it first, then the` / `user (or the master) tells each session its role and its name. Nothing` / `else needs to be agreed in advance.` | `This file and the files it links under \`references/\` are the complete contract.` plus the same role-assignment sentence and a line telling a session to open a linked file when the work reaches that section. | After the split, a session that treated `SKILL.md` alone as the whole contract would skip liveness, verification, economy and the starter prompts. The original three lines remain verbatim in `references/preamble.md`. |

## Headings that became link stubs

These headings keep their original text. In slim `SKILL.md` they are
immediately followed by a one-level link instead of the original body.
The original body is unchanged in the named file.

| Heading (unchanged text) | Now a stub linking to | Reason |
|---|---|---|
| `## 3. Liveness: check-ins, watchers and wake-up pokes` | `references/liveness.md` | Body was 673 lines. The settings table lives in that file, which is what `bin/selftest.sh` case 31 reads. |
| `## 4. Work design rules` | `references/work-design.md` | Body was 153 lines; not needed on every load. |
| `## 5. Verification discipline` | `references/verification.md` | Body was 214 lines; load when gating. |
| `## 6. Multi-sub-session setups` | `references/multi-seat.md` | Body was 35 lines. Kept out of slim `SKILL.md` so the body stays under 500 lines. |
| `## 8. Running this on any tool` | `references/any-tool.md` | Body already pointed at `APPENDIX.md`; the section itself is now the same pointer. |
| `## 9. Economy: the smallest budget that keeps the guarantees` | `references/economy.md` | Body was 163 lines; load when setting cadences. |
| `## 10. Why this shape (design notes)` | `references/design-notes.md` | Short, but already a pointer at `APPENDIX.md`. |

Section 2's heading is unchanged and the exclusive-writer rule stays in
`SKILL.md`. The subsections from `### Instruction protocol: the inbox`
through the end of section 2 are relocated, not rewritten, to
`references/bus.md`. A new sentence after the exclusive-writer rule
points there.

Section 7's heading and the user-setup / guided-start steps stay in
`SKILL.md`. The three pasteable prompt blocks (master, sub-session,
wake-up poke) are relocated, not rewritten, to `references/setup.md`.
A new sentence after the placeholder paragraph points there.

## Pointer files (not part of the protocol)

`.claude/skills/sub-session/SKILL.md` and
`.agents/skills/sub-session/SKILL.md` still name `../../../SKILL.md`.
Their body now also names `references/`, so a session that follows a
pointer does not stop at the slim file. Front matter is unchanged
(`bin/selftest.sh` case 21).
