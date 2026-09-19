#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Anti-entropy check: the Taskweft shim source at
7-service/service-taskweft-bao/planner/shim.cpp and
3-interactor/taskweft/wasm/taskweft-shim.cpp MUST be byte-identical.
Two copies exist because cgo requires the file in the Go package dir
and emcc reads it from the wasm dir — neither host can symlink to the
other without breaking its own build. This checker keeps them in sync.

    python check_shim_parity.py
    python check_shim_parity.py --self-test
"""
from __future__ import annotations

import argparse
import hashlib
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
COPIES = [
    ROOT / "3-interactor/taskweft/wasm/taskweft-shim.cpp",
    ROOT / "7-service/service-taskweft-bao/planner/shim.cpp",
]


def sha(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()


def check() -> int:
    hashes = {}
    for p in COPIES:
        if not p.exists():
            print(f"FAIL: {p} missing", file=sys.stderr)
            return 1
        hashes[p] = sha(p)
    unique = set(hashes.values())
    if len(unique) == 1:
        print(f"ok · {len(COPIES)} copies in sync ({next(iter(unique))[:12]})")
        return 0
    print("FAIL: shim.cpp copies diverged:", file=sys.stderr)
    for p, h in hashes.items():
        print(f"  {h[:12]}  {p}", file=sys.stderr)
    return 1


def self_test() -> int:
    """Positive control + one planted defect."""
    import tempfile
    fails: list[str] = []

    with tempfile.TemporaryDirectory() as td:
        tdp = Path(td)
        a = tdp / "a.cpp"; a.write_text("same")
        b = tdp / "b.cpp"; b.write_text("same")

        # Positive control.
        if sha(a) != sha(b):
            fails.append("identical files should hash equal")

        # Negative control: mutate one byte, MUST diverge.
        b.write_text("diff")
        if sha(a) == sha(b):
            fails.append("divergent files must hash differently")

    if fails:
        for f in fails: print(f"FAIL: {f}", file=sys.stderr)
        return 1
    print("self-test ok (2 controls: identical → equal hash, mutated → unequal)")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    return self_test() if args.self_test else check()


if __name__ == "__main__":
    sys.exit(main())
