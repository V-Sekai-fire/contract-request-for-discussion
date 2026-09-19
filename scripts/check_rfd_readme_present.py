#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Every RFD directory with a DETAILS.md carries a README.md beside it.

the site lists a directory by its README.md, so a directory
with only DETAILS.md renders no page and 404s on the site. The 2026-09-03
QA sweep found 90 such directories that had accumulated silently.

Run --self-test to see the check reject a known-bad tree and pass on a
clean one.
"""
from __future__ import annotations

import os
import re
import sys
import tempfile


RFD_DIR = re.compile(r"^[12]\d{3}-[a-z0-9-]+$")


def scan(root: str) -> list[str]:
    rfd_root = os.path.join(root, "rfd")
    bad: list[str] = []
    if not os.path.isdir(rfd_root):
        return bad
    for name in sorted(os.listdir(rfd_root)):
        if not RFD_DIR.match(name):
            continue
        d = os.path.join(rfd_root, name)
        has_details = os.path.isfile(os.path.join(d, "DETAILS.md"))
        has_readme = os.path.isfile(os.path.join(d, "README.md"))
        if has_details and not has_readme:
            bad.append(name)
    return bad


def run(root: str) -> int:
    bad = scan(root)
    if bad:
        print(f"FAIL {len(bad)} RFD dir(s) have DETAILS.md but no README.md:")
        for d in bad:
            print(f"       rfd/{d}/")
        return 1
    print(f"ok   every RFD dir with DETAILS.md carries a README.md")
    return 0


def _self_test() -> int:
    with tempfile.TemporaryDirectory() as t:
        os.makedirs(os.path.join(t, "rfd", "1000-clean"))
        open(os.path.join(t, "rfd", "1000-clean", "README.md"), "w").write("# x\n")
        open(os.path.join(t, "rfd", "1000-clean", "DETAILS.md"), "w").write("# d\n")
        # negative control: planted defect must fail
        os.makedirs(os.path.join(t, "rfd", "1001-broken"))
        open(os.path.join(t, "rfd", "1001-broken", "DETAILS.md"), "w").write("# d\n")
        bad = scan(t)
        assert bad == ["1001-broken"], f"negative control failed: {bad}"
        os.remove(os.path.join(t, "rfd", "1001-broken", "DETAILS.md"))
        bad = scan(t)
        assert bad == [], f"positive control failed: {bad}"
    print("self-test ok")
    return 0


def main() -> int:
    if len(sys.argv) == 2 and sys.argv[1] == "--self-test":
        return _self_test()
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    return run(root)


if __name__ == "__main__":
    sys.exit(main())
