#!/usr/bin/env python3
"""
Reads .claude/.session-log and answers, with counts rather than recollection:
  - How many sessions started outside the repo root (relative-path risk signal;
    CLAUDE.md still auto-loads from subdirectories — corrected 2026-08-11)
  - Whether the rules count has been stable
  - How often verify actually ran

This exists because "observe for a week and then decide" is not something an
agent can do. Every session starts blank. The observation has to be written down.
"""
import os
import re
import subprocess
import sys
from collections import Counter


sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _common import repo_root  # noqa: E402


def main():
    root = repo_root()
    path = os.path.join(root, ".claude", ".session-log")
    if not os.path.exists(path):
        print("No session log yet.")
        print("Wire hooks/session-context.sh, then re-run after a few sessions.")
        fire_report(os.path.join(root, ".claude", ".enforcement-log"))
        return 0

    starts, verifies, dirs, rulecounts = [], 0, Counter(), Counter()
    for line in open(path):
        parts = line.rstrip("\n").split("\t")
        if len(parts) >= 2 and parts[1] == "verify":
            verifies += 1
        elif len(parts) >= 5:
            starts.append(parts)
            dirs[parts[2] or "(root)"] += 1
            rulecounts[parts[4]] += 1

    n = len(starts)
    if n == 0:
        print("Session log exists but records no session starts.")
        fire_report(os.path.join(root, ".claude", ".enforcement-log"))
        return 0

    sub = sum(1 for s in starts if s[1] == "subdir")
    nomd = sum(1 for s in starts if s[3] == "no-claudemd")

    print(f"SESSIONS RECORDED   {n}")
    print(f"  from repo root    {n - sub}")
    print(f"  from a subdir     {sub}  ({sub * 100 // n}%)")
    print(f"VERIFY RUNS         {verifies}   ({verifies / n:.1f} per session)")
    print()

    if sub:
        print(f"NOTE: {sub} of {n} sessions started outside the repo root.")
        print("CLAUDE.md still loads there (upward walk), and every session in")
        print("this log had the SessionStart hook (it wrote the log). Treat this")
        print("as a relative-path risk signal, not a rules-loading failure.")
        print("Top start directories:")
        for d, c in dirs.most_common(5):
            print(f"  {c:>4}  {d}")
        print()

    if nomd:
        print(f"FINDING: {nomd} sessions ran with no CLAUDE.md at the repo root.")
        print()

    if len(rulecounts) > 1:
        print("FINDING: rules count changed across sessions —", dict(rulecounts))
        print("Rules were added or removed mid-stream; comparisons across the")
        print("window are not like-for-like.")
        print()

    if verifies < n * 0.5:
        print("FINDING: verify ran in fewer than half of sessions.")
        print("Any 'done' claim from a session without a verify run was a guess.")
        print()

    fire_report(os.path.join(root, ".claude", ".enforcement-log"))

    print("DECIDE NOW, NOT LATER")
    if n >= 5:
        print("  Every session in this log ran the SessionStart hook (it wrote the")
        print("  log). On current CLIs (auto-load verified on 2.1.220) rules were in")
        print("  context; on older CLIs the hook injects an INDEX, not contents —")
        print("  confirm with /context evidence before treating a rule as loaded.")
        print("  With loading established: a rule that still did not fire is")
        print("  genuinely mis-classified — promote it to a hook or a test.")
        if sub:
            print(f"  ({sub} subdir starts are a relative-path risk only, not a")
            print("  rules-loading failure.)")
    else:
        print(f"  Only {n} sessions recorded. Thin, but do not wait passively —")
        print("  run /project-audit now and use the static evidence instead.")
    return 0


def fire_report(path=".claude/.enforcement-log"):
    """A10 — rules by fire count, from the deny log the hooks write.

    Constantly-firing rule → usually a design problem the guard papers over.
    Never-firing rule → prune candidate (after enough sessions to mean it).
    UNREGISTERED → the guard enforces something the registry holds no row for.
    """
    import os
    from collections import Counter
    if not os.path.exists(path):
        print("ENFORCEMENT FIRES    no log yet — zero denies recorded (or hooks predate 1.17.0)")
        print()
        return
    counts, arms, malformed, first, last = Counter(), Counter(), 0, None, None
    for line in open(path, encoding="utf-8", errors="replace"):
        parts = line.rstrip("\n").split("\t")
        if len(parts) != 3 or not parts[0]:
            malformed += 1
            continue
        counts[parts[1]] += 1
        # A secret-class rule withholds the command, so a real block and a false
        # positive read identically at the rule level — 147 of 165 denies here
        # were C-01, across six arms. The arm label is the only way to tell them
        # apart afterwards, and it is a fixed string, never command text.
        arm = re.search(r"secret-class deny: ([a-z-]+)\]", parts[2])
        if arm:
            arms[f"{parts[1]}/{arm.group(1)}"] += 1
        first = first or parts[0]
        last = parts[0]
    print(f"ENFORCEMENT FIRES    {sum(counts.values())} denies, {first} .. {last}")
    for rule, n in counts.most_common():
        note = "  <- registry holds no row for this deny (honesty gap)" if rule == "UNREGISTERED" else ""
        print(f"  {rule:<14} {n}{note}")
    if arms:
        print("  which arm fired (the command is withheld for these rules; the arm is not)")
        for arm, n in arms.most_common():
            print(f"    {arm:<26} {n}")
    if malformed:
        print(f"  (malformed lines skipped: {malformed} — the log is telemetry, not a ledger, but say so)")
    print()


if __name__ == "__main__":
    sys.exit(main())
