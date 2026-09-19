# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Gate: every source file carries the licence this repository actually grants.

WHY THIS EXISTS. LICENSE-APACHE and LICENSE-MIT both sit at the root and
CITATION.cff lists Apache-2.0 and MIT, so the project is offered under either.
A file that says nothing is covered by a claim a reader has to go looking for,
and a file that says `MIT` alone offers less than the project does. Eighteen
said exactly that while fifty said nothing at all.

The identifier is `Apache-2.0 OR MIT`, which is the spelling SPDX defines for a
choice and the one the repository already used where it used anything.

DETECTION FLOOR. None. Every source file under the scanned directories is
enumerated rather than sampled, and a file that cannot be read is a FAIL rather
than a skip, because a skip reads exactly like a pass.

Run:  python scripts/check_spdx.py [--self-test]
"""

import argparse
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
WANT = "SPDX-License-Identifier: Apache-2.0 OR MIT"
DIRS = ("scripts", "lib", "test")
SUFFIXES = (".py", ".ex", ".exs")


def header(text):
    """The identifier a file declares, or None. Only the opening lines count."""
    for line in text.split("\n")[:6]:
        if "SPDX-License-Identifier:" in line:
            return line.split("SPDX-License-Identifier:", 1)[1].strip()
    return None


def gate(root):
    missing, narrow, ok = [], [], 0
    for d in DIRS:
        for path in sorted((root / d).rglob("*")):
            if path.suffix not in SUFFIXES or not path.is_file():
                continue
            rel = path.relative_to(root)
            try:
                found = header(path.read_text(encoding="utf-8"))
            except OSError as exc:
                print(f"  FAIL {rel}: unreadable ({exc})")
                missing.append(rel)
                continue
            if found is None:
                missing.append(rel)
            elif found != "Apache-2.0 OR MIT":
                narrow.append((rel, found))
            else:
                ok += 1
    for rel in missing:
        print(f"  FAIL {rel}: no SPDX identifier")
    for rel, found in narrow:
        print(f"  FAIL {rel}: says {found!r}, the project grants 'Apache-2.0 OR MIT'")
    print(f"{ok} source file(s) carry the licence, {len(missing)} without, {len(narrow)} narrower.")
    return 1 if (missing or narrow) else 0


def self_test():
    controls = [
        ("the dual identifier passes", f"# {WANT}\nx = 1\n", True),
        ("no identifier fails", "x = 1\n", False),
        ("MIT alone fails", "# SPDX-License-Identifier: MIT\nx = 1\n", False),
        ("Apache alone fails", "# SPDX-License-Identifier: Apache-2.0\nx = 1\n", False),
        ("after a shebang passes", f"#!/usr/bin/env python3\n# {WANT}\n", True),
        ("far down the file does not count", "x = 1\n" * 9 + f"# {WANT}\n", False),
    ]
    bad = 0
    for label, text, want_ok in controls:
        got = header(text) == "Apache-2.0 OR MIT"
        if got != want_ok:
            print(f"  FAIL {label}: got {got}, wanted {want_ok}")
            bad += 1
    print(f"ok   {len(controls) - bad} of {len(controls)} controls fired in both directions")
    return 1 if bad else 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    return self_test() if args.self_test else gate(ROOT)


if __name__ == "__main__":
    sys.exit(main())
