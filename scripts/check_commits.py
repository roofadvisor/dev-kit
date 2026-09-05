#!/usr/bin/env python3
"""
C-06 — conventional commits, enforced.

Validates every commit subject in the PR range against the conventional format:

  type(scope)!: subject      type ∈ feat fix docs chore refactor perf test build ci style revert release

Range comes from $BASE_REF (CI passes origin/<base branch>) as BASE..HEAD.
Auto-generated `Merge ...` and `Revert "..."` subjects are skipped.
Subjects over 100 characters fail (commitlint's default header ceiling).

Fail-loud (G-03): an empty or unresolvable range is an error, never a pass —
a gate that cannot see the commits it judges must block, not allow.
Exit 1 on any violation. Exit 0 clean.
"""
import os
import re
import subprocess
import sys

TYPES = "feat|fix|docs|chore|refactor|perf|test|build|ci|style|revert|release"
PATTERN = re.compile(rf"^({TYPES})(\([a-z0-9._/-]+\))?!?: \S.*")
SKIP = re.compile(r'^(Merge |Revert ")')
MAX_LEN = 100


def main():
    base = os.environ.get("BASE_REF", "").strip()
    if not base:
        print("check_commits: ERROR: BASE_REF unset — cannot determine the commit range to judge (C-06).")
        print("Set BASE_REF=origin/<base-branch> and re-run.")
        return 1
    try:
        out = subprocess.run(
            ["git", "log", "--format=%s", f"{base}..HEAD"],
            capture_output=True, text=True, check=True,
        ).stdout
    except subprocess.CalledProcessError as e:
        print(f"check_commits: ERROR: git log {base}..HEAD failed: {e.stderr.strip()} (C-06)")
        return 1

    subjects = [s for s in out.splitlines() if s.strip()]
    if not subjects:
        print(f"check_commits: ERROR: no commits in {base}..HEAD — nothing to judge is a "
              "range problem, not a pass (C-06). Check BASE_REF and fetch depth.")
        return 1

    bad = []
    for s in subjects:
        if SKIP.match(s):
            continue
        if not PATTERN.match(s):
            bad.append((s, "not conventional — expected `type(scope)?: subject`"))
        elif len(s) > MAX_LEN:
            bad.append((s, f"subject is {len(s)} chars (max {MAX_LEN})"))

    if bad:
        print(f"C-06 VIOLATIONS ({len(bad)} of {len(subjects)} commits):")
        for s, why in bad:
            print(f"  {s!r}\n      {why}")
        print(f"\nAllowed types: {TYPES.replace('|', ' ')}")
        return 1

    print(f"check_commits: OK — {len(subjects)} commit(s) conventional (C-06).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
