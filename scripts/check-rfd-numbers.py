#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Check that every RFD number follows the org-qualified decimal rule.

RFD 1000 gives the rule. This script enforces it. Run --self-test to see each
check reject a known-bad input, because a check that passes on broken input
certifies the defect instead of catching it.

This gate owns numbering: directory names, the organization digit, serial
uniqueness, and heading agreement. It used to also check ALIASES.md coverage,
and that table is deleted rather than extended, so the check went with it. RFD
1000 records what the deletion costs. It used to also scan
for unmigrated decimal citations, and no longer does. That scan read the raw
bytes, so a citation an RFD wrapped over two lines never matched it: it found
3 of the 37 in the tree. `check-rfd-structure.py` reads the same citations off
a CommonMark AST and finds all of them, so the scan moved there rather than
being kept in two places at two strengths. RFD 1124 records the move.
"""
import os
import re
import sys

ORG = "1"
DIR_RE = re.compile(r"^([0-9]{4})-[a-z0-9-]+$")
HEAD_RE = re.compile(r"^# RFD ([0-9]{4}):")


def rfd_dirs(root):
    return sorted(
        d for d in os.listdir(os.path.join(root, "rfd"))
        if os.path.isdir(os.path.join(root, "rfd", d)) and not d.startswith(".")
        and re.match(r"^1[0-9a-zA-Z]{3}-", d)
    )


def check(root):
    problems = []
    dirs = rfd_dirs(root)
    if not dirs:
        problems.append("no RFD directories found, which is never correct here")

    seen = {}
    for d in dirs:
        m = DIR_RE.match(d)
        if not m:
            problems.append(f"{d}: name is not four decimal digits and a slug")
            continue
        num = m.group(1)
        if num[0] != ORG:
            problems.append(f"{d}: organization digit is {num[0]}, not {ORG}")
        if num in seen:
            problems.append(f"{d}: serial {num} is already used by {seen[num]}")
        seen[num] = d

        readme = os.path.join(root, "rfd", d, "README.md")
        if not os.path.exists(readme):
            problems.append(f"{d}: has no README.md")
            continue
        with open(readme, encoding="utf-8", errors="ignore") as fh:
            first = fh.readline().rstrip("\n")
        h = HEAD_RE.match(first)
        if not h:
            problems.append(f"{d}: first line is not '# RFD <num>: title', it is {first!r}")
        elif h.group(1) != num:
            problems.append(f"{d}: heading says {h.group(1)}, directory says {num}")

    return problems


def self_test():
    import shutil
    import tempfile

    def build(tmp, **kw):
        for name, head in kw.get("extra_dirs", []):
            os.makedirs(os.path.join(tmp, "rfd", name))
            with open(os.path.join(tmp, "rfd", name, "README.md"), "w", encoding="utf-8") as fh:
                fh.write(head)
        d = os.path.join(tmp, "rfd", kw.get("dirname", "1001-a-slug"))
        os.makedirs(d)
        with open(os.path.join(d, "README.md"), "w", encoding="utf-8") as fh:
            fh.write(kw.get("heading", "# RFD 1001: A slug\n"))

    cases = [
        ("a clean tree passes", {}, False),
        ("wrong organization digit", {"dirname": "2001-a-slug"}, True),
        ("no organization digit", {"dirname": "0001-a-slug"}, True),
        # The two below are the withdrawn hex rule. A serial with a letter is
        # the form this repository carried for 131 RFDs, so the gate has to
        # reject it by name rather than by the slug pattern happening to miss.
        ("a hex directory name", {"dirname": "100a-a-slug"}, True),
        ("a hex heading",
         {"dirname": "1010-a-slug", "heading": "# RFD 100a: A slug\n"}, True),
        ("heading disagrees with directory", {"heading": "# RFD 1002: A slug\n"}, True),
        ("a second RFD needs no lookup table",
         {"extra_dirs": [("1002-a-slug", "# RFD 1002: A slug\n")]}, False),
    ]
    ok = True
    for name, kw, should_fail in cases:
        tmp = tempfile.mkdtemp()
        try:
            build(tmp, **kw)
            failed = bool(check(tmp))
            mark = "ok " if failed == should_fail else "BAD"
            if failed != should_fail:
                ok = False
            verb = "rejected" if failed else "accepted"
            print(f"  {mark} {name}: {verb}")
        finally:
            shutil.rmtree(tmp)
    return 0 if ok else 1


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        print("self-test: each known-bad input must be rejected")
        sys.exit(self_test())
    found = check(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    for line in found:
        print(line)
    print(f"{len(found)} problems")
    sys.exit(1 if found else 0)
