#!/bin/sh
# Copyright 2026 Zheng Luo (Davies Luo). Licensed under the Apache License
# 2.0, whose text is the LICENSE file in this package. Keep this notice
# when you copy the script.
#
# Prove that every non-empty line of the original v1.0 SKILL.md still
# appears, exactly, in today's SKILL.md or a file under references/.
# The original is commit 71483995d93c6e09321c62f3a0280eae8dc4ee05
# (the squashed first release on main, short 7148399) unless ORIG_SKILL
# points at a file, or a commit-ish is given as $1.
#
#   sh scripts/check-skill-coverage.sh
#   sh scripts/check-skill-coverage.sh 7148399
#   ORIG_SKILL=/path/to/old/SKILL.md sh scripts/check-skill-coverage.sh
#
# A shallow clone (GitHub Actions' default fetch-depth: 1) does not
# contain that commit. The script fetches it from origin when missing.
#
# This script is not one of the seven protocol scripts. It lives under
# scripts/ so the self-test's "all seven" parse loop is not enlarged.

set -e
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1

# Full SHA so `git fetch origin <sha>` works on a shallow clone.
ORIG_COMMIT=${1:-71483995d93c6e09321c62f3a0280eae8dc4ee05}
DEST=$ROOT/.coverage-dest.txt
MISSING=$ROOT/.coverage-missing.txt
rm -f "$DEST" "$MISSING"

# Destination corpus: the slim protocol plus every reference file.
# Pointers are not the protocol and are not searched.
{
  [ -f SKILL.md ] && cat SKILL.md
  if [ -d references ]; then
    # Sort for a stable report; contents are what matter.
    for f in references/*.md; do
      [ -f "$f" ] && cat "$f"
    done
  fi
} > "$DEST"

if [ -n "${ORIG_SKILL:-}" ] && [ -f "$ORIG_SKILL" ]; then
  ORIG=$ORIG_SKILL
else
  ORIG=$ROOT/.coverage-orig.txt
  if ! git cat-file -e "$ORIG_COMMIT^{commit}" 2>/dev/null; then
    # actions/checkout defaults to depth 1; pull the v1.0 commit only.
    git fetch --no-tags --depth=1 origin "$ORIG_COMMIT"
  fi
  git show "$ORIG_COMMIT:SKILL.md" > "$ORIG"
fi

# Exact line match, trailing spaces kept (the original has none that
# matter). Empty lines are ignored, as the suite only has to prove
# rules and instructions survived.
python3 - "$ORIG" "$DEST" "$MISSING" <<'PY'
import sys
from pathlib import Path

orig_path, dest_path, missing_path = sys.argv[1], sys.argv[2], sys.argv[3]
dest_lines = Path(dest_path).read_text(encoding="utf-8").splitlines()
dest_set = set(dest_lines)
missing = []
total = 0
for i, line in enumerate(Path(orig_path).read_text(encoding="utf-8").splitlines(), 1):
    if line.strip() == "":
        continue
    total += 1
    if line not in dest_set:
        missing.append(f"{i}:{line}")
Path(missing_path).write_text("\n".join(missing) + ("\n" if missing else ""), encoding="utf-8")
print(f"original non-empty lines: {total}")
print(f"present in SKILL.md or references/: {total - len(missing)}")
print(f"missing: {len(missing)}")
if missing:
    print("MISSING LINES:")
    for row in missing:
        print(row)
    sys.exit(1)
print("coverage: every non-empty original line is present")
PY
rc=$?
rm -f "$DEST"
[ -n "${ORIG_SKILL:-}" ] || rm -f "$ROOT/.coverage-orig.txt"
rm -f "$MISSING"
exit $rc
