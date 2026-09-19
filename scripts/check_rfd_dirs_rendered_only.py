#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Nothing tracked lives under rfd/NNNN-slug/.

RFD 2232 renders README.md and DETAILS.md there from rfd/NNNN-slug.exs, so the
directory is build output and `rm -rf rfd/*/` should cost a render and nothing
else. On 2026-09-07 it cost 65 tracked files, because apparatus had been landing
beside the renders for months. RFD 1000 puts apparatus in apparatus/NNNN-slug/.

Run --self-test to see the check reject a planted tree and pass on a clean one.
"""
from __future__ import annotations

import os
import re
import subprocess
import sys

RENDERED = ("README.md", "DETAILS.md")
TRACKED_IN_RFD_DIR = re.compile(r"^rfd/[12]\d{3}-[a-z0-9-]+/(.+)$")


def scan(paths: list[str]) -> list[str]:
    bad = []
    for path in paths:
        match = TRACKED_IN_RFD_DIR.match(path.replace(os.sep, "/"))
        if match and match.group(1) not in RENDERED:
            bad.append(path)
    return sorted(bad)


def tracked(root: str) -> list[str]:
    out = subprocess.run(
        ["git", "-C", root, "ls-files", "--", "rfd"],
        capture_output=True, text=True, check=True,
    )
    return [line for line in out.stdout.splitlines() if line]


def run(root: str) -> int:
    paths = tracked(root)
    bad = scan(paths)
    if bad:
        print(f"FAIL {len(bad)} tracked file(s) under rfd/NNNN-slug/:")
        for path in bad:
            print(f"       {path}")
        print("       apparatus belongs in apparatus/NNNN-slug/ (RFD 1000)")
        return 1
    print(f"ok   {len(paths)} tracked path(s) under rfd/, none inside a render dir")
    return 0


def _self_test() -> int:
    clean = [
        "rfd/1000-conventions.exs",
        "rfd/2145-certificate-lifetimes.exs",
        "rfd/1143-keypoints-to-anny/README.md",
        "rfd/1143-keypoints-to-anny/DETAILS.md",
    ]
    assert scan(clean) == [], scan(clean)

    for planted in (
        "rfd/1143-keypoints-to-anny/fourloops-etnf.usda",
        "rfd/1128-four-bit-tolerance/SKILL.md",
        "rfd/2145-certificate-lifetimes/references/10-rfc5280.cff",
        "rfd/1047-voxhammer-text-mesh-editing/domain.ex",
    ):
        found = scan(clean + [planted])
        assert found == [planted], f"negative control failed: {planted} -> {found}"

    # A render dir is not the only thing under rfd/; the .exs sources sit there too.
    assert scan(["rfd/1036-packaging-convention.exs"]) == []
    assert scan(["rfd/not-an-rfd/thing.txt"]) == []
    print("self-test ok (3 positive controls, 4 negative controls)")
    return 0


def main() -> int:
    if len(sys.argv) == 2 and sys.argv[1] == "--self-test":
        return _self_test()
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    return run(root)


if __name__ == "__main__":
    sys.exit(main())
