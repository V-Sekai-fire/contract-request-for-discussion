#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Gate: commit subjects on our own repos are sentence-case prose, no Conventional Commits prefix.

WHY. RFD 2026 picked sentence-case prose over Conventional Commits for our own repos. A
`feat:` / `fix:` / `chore(scope):` prefix reads as noise before the meaning, and no tool
here consumes it. Forks stay on their upstream's convention — a Conventional-Commits
upstream (say, an engine we mirror) gets its own style, because the diff is going upstream
one day and needs to fit there.

WHAT IS CHECKED. Every commit reachable from HEAD but not from --base:

1. The subject line does not begin with a Conventional-Commits prefix
   (`^[a-z]+(\\([^)]+\\))?!?:` — e.g. `feat:`, `fix(parser):`, `chore!:`).
2. The subject's first character is an uppercase letter (or a digit / bracket that a
   sentence can plausibly open with; `RFD 2026: …` and `[RFD 2026] …` both pass).
3. The subject does not end with a trailing period.

SCOPE. The gate runs only when `git config remote.origin.url` matches `github.com/weftspun/`
(or the equivalent SSH form). Forks — anything with a different origin — are skipped with
a `skipped: origin not weftspun` line, per RFD 2026's "use the fork's standard pattern".

DETECTION FLOOR. A subject that opens with a valid Conventional-Commits type BUT happens
to also read as a sentence (imagine an author writing `Feat: some feature.`) is caught by
the trailing-period check or the case check anyway. The pattern targets machine-typed
prefixes; there is no reasonable prose subject that is `type:` prefixed by accident.

Usage:
    python scripts/check_commit_style.py                    # HEAD..HEAD~10 (last 10)
    python scripts/check_commit_style.py --base origin/main # gate a branch
    python scripts/check_commit_style.py --self-test        # 6 controls

Exit codes: 0 all pass, 1 at least one fails, 2 bad usage.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys


CONVENTIONAL_RE = re.compile(r"^[a-z][a-z0-9-]*(\([^)]+\))?!?:")
SENTENCE_START_RE = re.compile(r"^([A-Z]|\d|\[|`)")
TRAILING_PERIOD_RE = re.compile(r"\.$")


def is_own_repo(cwd: str = ".") -> bool:
    """True when any git remote points at a weftspun-owned repo.

    Remotes here are named after the manifest (`weftspun`, `huggingface-datasets`, etc.),
    not `origin`, so `remote.origin.url` returns nothing on a repo-managed checkout.
    Enumerate every remote's URL and match on any hit.
    """
    try:
        out = subprocess.check_output(
            ["git", "-C", cwd, "config", "--get-regexp", r"^remote\..*\.url$"],
            text=True,
        )
    except subprocess.CalledProcessError:
        return False
    for line in out.splitlines():
        # `remote.<name>.url  <url>`
        parts = line.split(None, 1)
        if len(parts) == 2 and re.search(r"github\.com[/:]weftspun/", parts[1]):
            return True
    return False


def check_subject(subject: str) -> list[str]:
    problems = []
    if CONVENTIONAL_RE.match(subject):
        problems.append("Conventional-Commits prefix (RFD 2026 says sentence-case prose)")
    if not SENTENCE_START_RE.match(subject):
        problems.append("first char not uppercase / digit / bracket")
    if TRAILING_PERIOD_RE.search(subject):
        problems.append("trailing period")
    return problems


def commits_in_range(base: str, head: str = "HEAD") -> list[tuple[str, str]]:
    out = subprocess.check_output(
        ["git", "log", "--format=%H%x1f%s", f"{base}..{head}"],
        text=True,
    )
    rows = []
    for line in out.splitlines():
        if "\x1f" not in line:
            continue
        sha, subj = line.split("\x1f", 1)
        rows.append((sha, subj))
    return rows


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default=None,
                    help="Commit range base (default: HEAD~10)")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args(argv[1:])

    if args.self_test:
        return self_test()

    if not is_own_repo():
        print("skipped: origin not weftspun (fork convention applies, RFD 2026)")
        return 0

    base = args.base or "HEAD~10"
    try:
        commits = commits_in_range(base)
    except subprocess.CalledProcessError as e:
        print(f"error: git log failed: {e}")
        return 2

    if not commits:
        print(f"ok  0 commits in {base}..HEAD")
        return 0

    failures = 0
    for sha, subj in commits:
        problems = check_subject(subj)
        if problems:
            failures += 1
            print(f"FAIL {sha[:12]}  {subj}")
            for p in problems:
                print(f"       - {p}")
        else:
            print(f"ok   {sha[:12]}  {subj[:60]}")
    print(f"---")
    print(f"{len(commits)} commit(s), {failures} failure(s)")
    return 1 if failures else 0


def self_test() -> int:
    """6 controls: 3 that pass, 3 that fail. Every direction fires."""
    cases = [
        # (subject, expected_problems_count, label)
        ("Add the macOS and Windows release workflows", 0, "plain sentence"),
        ("RFD 2026: Commit messages sentence case", 0, "RFD prefix, sentence body"),
        ("[urgent] Fix the leaking file descriptor", 0, "bracket-tag open"),
        ("feat: add the release workflow", 2, "conventional-commits + not-capital"),
        ("fix(parser): handle nested arrays", 2, "conventional-commits w/ scope + not-capital"),
        ("Add the workflow.", 1, "trailing period"),
    ]
    all_pass = True
    for subj, expect, label in cases:
        problems = check_subject(subj)
        ok = len(problems) == expect
        marker = "ok   " if ok else "FAIL "
        print(f"  {marker} [{label}] expect={expect} got={len(problems)}: {subj}")
        if not ok:
            for p in problems:
                print(f"       problem: {p}")
            all_pass = False

    # A weftspun URL is detected as own
    for url, expect_own in [
        ("https://github.com/weftspun/request-for-discussion", True),
        ("git@github.com:weftspun/request-for-discussion.git", True),
        ("https://github.com/godotengine/godot", False),
        ("git@github.com:huggingface/transformers.git", False),
    ]:
        # Simulate: parse URL directly via the same regex
        got_own = bool(re.search(r"github\.com[/:]weftspun/", url))
        ok = got_own == expect_own
        marker = "ok   " if ok else "FAIL "
        print(f"  {marker} url-classify {url!r} → own={got_own} (expected {expect_own})")
        if not ok:
            all_pass = False

    print("---")
    print("self-test:", "ok" if all_pass else "FAIL")
    return 0 if all_pass else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
