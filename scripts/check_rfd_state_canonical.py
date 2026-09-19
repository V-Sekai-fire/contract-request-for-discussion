#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Every RFD README's State field is one of the canonical values RFD 1000 lists.

RFD 1000 enumerates seven states: prediscussion, ideation, discussion,
published, committed, abandoned, moved. Four RFDs on 2026-09-03 carried
a parenthetical annotation after the value ("discussion (implemented
2026-09-01...)"), which is neither canonical nor parseable by strict
tooling. This gate refuses that shape.

The state list is read out of RFD 1000 rather than restated, so this
gate and the document cannot drift.

Run --self-test to see the check reject a known-bad shape and pass on
a clean one.
"""
from __future__ import annotations

import os
import re
import sys
import tempfile


RFD_DIR = re.compile(r"^[12]\d{3}-[a-z0-9-]+$")
STATE_LINE = re.compile(r"^\*\*State:\*\*\s*(.+?)\s*$", re.M)
STATE_LIST_RE = re.compile(r"has a state:\s*([a-z,\s]+?)\.", re.S)


def canonical_states(root: str) -> set[str]:
    p = os.path.join(root, "rfd", "1000-conventions", "README.md")
    if not os.path.isfile(p):
        # Fallback to the frozen list; still record where it came from.
        return {"prediscussion", "ideation", "discussion", "published",
                "committed", "abandoned", "moved"}
    text = open(p, encoding="utf-8").read()
    text = re.sub(r"\s+", " ", text)
    m = STATE_LIST_RE.search(text)
    if not m:
        return {"prediscussion", "ideation", "discussion", "published",
                "committed", "abandoned", "moved"}
    words = [re.sub(r"^or\s+", "", w.strip()) for w in m.group(1).split(",")]
    return {w for w in words if w}


def scan(root: str) -> list[tuple[str, str]]:
    states = canonical_states(root)
    rfd_root = os.path.join(root, "rfd")
    bad: list[tuple[str, str]] = []
    if not os.path.isdir(rfd_root):
        return bad
    for name in sorted(os.listdir(rfd_root)):
        if not RFD_DIR.match(name):
            continue
        p = os.path.join(rfd_root, name, "README.md")
        if not os.path.isfile(p):
            continue
        text = open(p, encoding="utf-8").read()
        m = STATE_LINE.search(text)
        if not m:
            continue  # a separate gate covers absence
        value = m.group(1).strip()
        # Reject a single word followed by a parenthetical annotation.
        first = value.split()[0]
        if value != first or first not in states:
            bad.append((name, value))
    return bad


def run(root: str) -> int:
    bad = scan(root)
    if bad:
        print(f"FAIL {len(bad)} RFD(s) with non-canonical State:")
        for name, value in bad:
            print(f"       rfd/{name}/README.md: {value!r}")
        print("     the canonical values are in rfd/1000-conventions/README.md;")
        print("     move any annotation into the Decision body.")
        return 1
    print(f"ok   every RFD State is a canonical value")
    return 0


def _self_test() -> int:
    with tempfile.TemporaryDirectory() as t:
        os.makedirs(os.path.join(t, "rfd", "1000-conventions"))
        open(os.path.join(t, "rfd", "1000-conventions", "README.md"), "w").write(
            "# RFD 1000\n\nEach RFD has a state: prediscussion, ideation, "
            "discussion, published, committed, abandoned, or moved.\n"
        )
        # positive control: clean State field
        os.makedirs(os.path.join(t, "rfd", "1001-ok"))
        open(os.path.join(t, "rfd", "1001-ok", "README.md"), "w").write(
            "# RFD 1001\n\n**State:** discussion\n"
        )
        bad = scan(t)
        assert bad == [], f"positive control failed: {bad}"
        # negative control: parenthetical annotation
        os.makedirs(os.path.join(t, "rfd", "1002-bad"))
        open(os.path.join(t, "rfd", "1002-bad", "README.md"), "w").write(
            "# RFD 1002\n\n**State:** discussion (implemented 2026-09-01)\n"
        )
        bad = scan(t)
        assert len(bad) == 1 and bad[0][0] == "1002-bad", f"negative control failed: {bad}"
        # negative control 2: unknown state
        os.makedirs(os.path.join(t, "rfd", "1003-unknown"))
        open(os.path.join(t, "rfd", "1003-unknown", "README.md"), "w").write(
            "# RFD 1003\n\n**State:** invented\n"
        )
        bad = scan(t)
        names = sorted(b[0] for b in bad)
        assert names == ["1002-bad", "1003-unknown"], f"negative 2 failed: {bad}"
    print("self-test ok")
    return 0


def main() -> int:
    if len(sys.argv) == 2 and sys.argv[1] == "--self-test":
        return _self_test()
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    return run(root)


if __name__ == "__main__":
    sys.exit(main())
