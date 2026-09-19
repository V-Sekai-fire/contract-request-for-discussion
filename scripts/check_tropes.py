#!/usr/bin/env python3
"""Trope density did not rise.

    python scripts/check_tropes.py                # report
    python scripts/check_tropes.py --base <ref>   # gate
    python scripts/check_tropes.py --self-test
"""
import argparse
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

TELLS = {
    "em_dash_join": re.compile(r"(?<=\S) [-—][-—]? "),
    "counting_announcement": re.compile(
        r"\b(in|for|on)\s+(two|three|four|five|six)\s+(ways|reasons|counts|things|senses)\b",
        re.I,
    ),
    "reasoning_leak": re.compile(
        r"\b(the reason .+? is that|the whole point .+? is that|what makes .+? is)\b",
        re.I,
    ),
    "pompous_copula": re.compile(r"\b(is|are)\s+what\s+(makes|proves|shows|says)\b", re.I),
    "exact_window": re.compile(r"\bthe exact (window|moment|shape|line|point|reason|failure)\b", re.I),
    "welded_clauses": re.compile(
        r"(?<!when )(?<!where )(?<!unless )(?<!only when )"
        r"\b(?:A|An|The)\s+[a-z][a-z-]*\s+(?:is|are)\s+"
        r"(?!.*\b(?:that|which|when|where|if|whether|because)\b)"
        r"[^.;,\n]{3,60}\s+and\s+"
        r"(?:a|an|the|every|each|no|its|this)\s+(?:[a-z][a-z-]*\s+){1,2}"
        r"(?:is|are|says|does|has|have|carries|reads|means|makes|gets)\b",
        re.I,
    ),
}

FILE_PATTERNS = (
    re.compile(r"^rfd/[0-9]{4}-[^/]+\.exs$"),
    re.compile(r"^rfd/[^/]+/(README|DETAILS)\.md$"),
    re.compile(r"^logbook/.+\.md$"),
)


def in_scope(path: str) -> bool:
    p = path.replace("\\", "/")
    return any(pat.match(p) for pat in FILE_PATTERNS)


def count_tropes(text: str) -> tuple[int, dict[str, int]]:
    text_no_code = re.sub(r"```.*?```", "", text, flags=re.DOTALL)
    per = {name: len(rx.findall(text_no_code)) for name, rx in TELLS.items()}
    return sum(per.values()), per


def non_blank_lines(text: str) -> int:
    return sum(1 for line in text.splitlines() if line.strip())


def density(text: str) -> float:
    n = non_blank_lines(text)
    hits, _ = count_tropes(text)
    return (100.0 * hits / n) if n else 0.0


def git_show(ref: str, path: str) -> str | None:
    out = subprocess.run(
        ["git", "show", f"{ref}:{path}"],
        capture_output=True,
        text=True,
        encoding="utf-8",
        cwd=ROOT,
    )
    return out.stdout if out.returncode == 0 else None


def rendered(path: str) -> bool:
    m = re.match(r"^rfd/([0-9]{4}-[^/]+)/(README|DETAILS)\.md$", path.replace("\\", "/"))
    return bool(m) and os.path.isfile(os.path.join(ROOT, "rfd", m.group(1) + ".exs"))


def prior_text(base: str, path: str) -> str:
    text = git_show(base, path)
    if text is not None:
        return text
    m = re.match(r"^rfd/([0-9]{4}-[^/]+)\.exs$", path.replace("\\", "/"))
    if not m:
        return ""
    return "".join(git_show(base, f"rfd/{m.group(1)}/{n}") or ""
                   for n in ("README.md", "DETAILS.md"))


def changed_files(base: str) -> list[str]:
    out = subprocess.run(
        ["git", "diff", "--name-only", f"{base}...HEAD"],
        capture_output=True,
        text=True,
        cwd=ROOT,
        check=True,
    )
    return [p for p in out.stdout.splitlines() if in_scope(p) and not rendered(p)]


def gate(base: str) -> int:
    changed = changed_files(base)
    if not changed:
        print("0 changed prose file(s) in scope.")
        return 0

    fails = 0
    for path in changed:
        full = os.path.join(ROOT, path)
        if not os.path.isfile(full):
            continue
        after = open(full, encoding="utf-8").read()
        before = prior_text(base, path)
        d_now = density(after)
        d_was = density(before)
        if d_now > d_was + 0.001:
            hits, per = count_tropes(after)
            top = ", ".join(f"{k}={v}" for k, v in per.items() if v)
            print(f"  FAIL {path}  {d_now:.2f}% was {d_was:.2f}%  ({hits} hits: {top})")
            fails += 1
        else:
            print(f"  ok   {path}  {d_now:.2f}% was {d_was:.2f}%")
    print(f"{fails} of {len(changed)} scoped file(s) rose above their prior density.")
    return 1 if fails else 0


def report() -> int:
    scanned = 0
    for dirpath, _, filenames in os.walk(os.path.join(ROOT, "rfd")):
        for name in filenames:
            if name in ("README.md", "DETAILS.md") or in_scope(
                    os.path.relpath(os.path.join(dirpath, name), ROOT)):
                rel = os.path.relpath(os.path.join(dirpath, name), ROOT)
                d = density(open(os.path.join(dirpath, name), encoding="utf-8").read())
                if d > 0:
                    print(f"  {d:5.2f}%  {rel}")
                scanned += 1
    for name in sorted(os.listdir(os.path.join(ROOT, "logbook"))):
        if name.endswith(".md"):
            rel = os.path.join("logbook", name)
            d = density(open(os.path.join(ROOT, rel), encoding="utf-8").read())
            if d > 0:
                print(f"  {d:5.2f}%  {rel}")
            scanned += 1
    print(f"{scanned} scoped file(s) scanned.")
    return 0


def self_test() -> int:
    controls = [
        ("em-dash between clauses", "The gate ran — every control fired.", "em_dash_join", 1),
        ("hyphen range unchanged", "The window is day 11-14.", "em_dash_join", 0),
        (
            "markdown bullet is not a join",
            "See the deployment notes:\n\n- first item\n- second item\n- third item\n",
            "em_dash_join",
            0,
        ),
        ("counting announcement", "It shapes the checks in three ways.", "counting_announcement", 1),
        ("prose that mentions three ways", "Three ways lead there.", "counting_announcement", 0),
        ("reasoning leak", "The reason it holds is that quorum tolerates one down.", "reasoning_leak", 1),
        ("pompous copula", "The second check is what proves the restart.", "pompous_copula", 1),
        ("plain because", "The second check proves the restart because a stale write would fail.", "pompous_copula", 0),
        ("exact window", "That is the exact window in which a shard can stall.", "exact_window", 1),
        (
            "two clauses welded by a bare and",
            "A release is one flat namespace and every build tree says fdbserver.",
            "welded_clauses",
            1,
        ),
        (
            "the same point subordinated",
            "A release is one flat namespace for every build tree.",
            "welded_clauses",
            0,
        ),
        (
            "a comma before and is ordinary English",
            "The account is five characters, and the corpus is 3.2 GB.",
            "welded_clauses",
            0,
        ),
        (
            "a compound predicate is not two clauses",
            "A permission is not a preference and cannot be granted sideways.",
            "welded_clauses",
            0,
        ),
        (
            "and inside a subordinate clause",
            "A build is the confirmation that auth and the endpoint are reachable.",
            "welded_clauses",
            0,
        ),
    ]
    fails = 0
    for label, text, tell, expected in controls:
        _, per = count_tropes(text)
        got = per[tell]
        if got != expected:
            print(f"  FAIL {label}: {tell} expected {expected}, got {got}")
            fails += 1
    if fails:
        print(f"{fails} of {len(controls)} controls failed")
        return 1
    print(f"ok   {len(controls)} of {len(controls)} controls fired in both directions")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", help="git ref to compare against (fail on density rise)")
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()
    if a.self_test:
        return self_test()
    if a.base:
        return gate(a.base)
    return report()


if __name__ == "__main__":
    sys.exit(main())
