#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
"""C++ we write uses no `auto`. Explicit types are the point of a wire-level
codebase: the reader of a NIF or a bus endpoint should see the struct they are
holding, not deduce it. This gate scans the given files or directories for the
keyword outside comments and string literals.

    python scripts/check_no_auto.py <paths...>
    python scripts/check_no_auto.py --self-test

Scope is the paths a repository chooses to gate: code written before the rule
(or vendored) is not swept in unless its repo passes it here.
"""

import re
import sys
from pathlib import Path

EXTENSIONS = {".cpp", ".cc", ".cxx", ".hpp", ".hh", ".h"}

STRIP = re.compile(
    r"//[^\n]*|/\*.*?\*/|\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*'",
    re.DOTALL,
)
AUTO = re.compile(r"\bauto\b")


def blank_preserving_newlines(match: re.Match) -> str:
    return "".join(c if c == "\n" else " " for c in match.group(0))


def violations(text: str):
    stripped = STRIP.sub(blank_preserving_newlines, text)
    for i, line in enumerate(stripped.splitlines(), 1):
        if AUTO.search(line):
            yield i, line.strip()


def scan(paths):
    bad = 0
    for arg in paths:
        root = Path(arg)
        files = [root] if root.is_file() else sorted(root.rglob("*"))
        for f in files:
            if f.suffix not in EXTENSIONS or not f.is_file():
                continue
            for line_no, line in violations(f.read_text(encoding="utf-8", errors="replace")):
                print(f"FAIL {f}:{line_no}: {line}")
                bad += 1
    return bad


def self_test() -> int:
    planted = "int f() {\n    auto x = g();\n    return x;\n}\n"
    clean = (
        "// an automatic variable, and the word auto in prose\n"
        'const char* s = "auto";\n'
        "int autopilot = 0;\n"
    )
    if len(list(violations(planted))) != 1:
        print("FAIL control: a planted `auto` was not seen")
        return 1
    if list(violations(clean)):
        print("FAIL control: comment, string or identifier misread as the keyword")
        return 1
    print("ok   2 of 2 controls fired")
    return 0


if __name__ == "__main__":
    args = sys.argv[1:]
    if args == ["--self-test"]:
        sys.exit(self_test())
    if not args:
        print(__doc__)
        sys.exit(2)
    n = scan(args)
    print(f"{'FAIL' if n else 'ok'}   {n} `auto` use(s)")
    sys.exit(1 if n else 0)
