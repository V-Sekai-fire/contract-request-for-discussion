#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Gate: a line added to an .ex or .exs file stays within .formatter.exs's line_length.

Run: check_line_length.py [--base HEAD] [--fix] [--self-test]
"""
import argparse
import os
import re
import subprocess
import sys
import tempfile
import textwrap

EXT = (".ex", ".exs")
# A one-line string whose \\n escapes can become literal newlines without changing its value.
STRING_WITH_NEWLINES = re.compile(r'^(\s*[a-z_]+ )"((?:[^"\\]|\\.)*\\n(?:[^"\\]|\\.)*)"$')


def git(repo, *args):
    out = subprocess.run(["git", "-C", repo] + list(args), capture_output=True, text=True)
    return out.stdout


def limit_of(repo):
    path = os.path.join(repo, ".formatter.exs")
    if not os.path.exists(path):
        return None
    m = re.search(r"line_length:\s*(\d+)", open(path, encoding="utf-8").read())
    return int(m.group(1)) if m else None


def added_lines(repo, base):
    diff = git(repo, "diff", "-U0", "--no-color", *(["--cached"] if base == "HEAD" else [base]))
    added, path, line = {}, None, 0
    for row in diff.split("\n"):
        if row.startswith("+++ "):
            path = row[6:] if row.startswith("+++ b/") else None
        elif row.startswith("@@") and path:
            line = int(re.match(r"@@ -\S+ \+(\d+)", row).group(1))
        elif row.startswith("+") and path and path.endswith(EXT):
            added.setdefault(path, set()).add(line)
            line += 1
    return added


def heredoc_indent(lines):
    """Map line index -> closing-quote indent, for lines inside a triple-quoted string."""
    inside, start, spans = False, 0, {}
    for i, text in enumerate(lines):
        quotes = text.count('"""')
        if not inside and quotes == 1 and text.rstrip().endswith('"""'):
            inside, start = True, i + 1
        elif inside and text.strip().startswith('"""'):
            indent = len(text) - len(text.lstrip())
            for j in range(start, i):
                spans[j] = indent
            inside = False
    return spans


def fixable(text, indent):
    stripped = text.strip()
    own = len(text) - len(text.lstrip())
    return stripped and not stripped.startswith("|") and own == indent


def fix(repo, path, lines_to_fix, limit):
    full = os.path.join(repo, path)
    lines = open(full, encoding="utf-8").read().split("\n")
    spans = heredoc_indent(lines)
    out = []
    for i, text in enumerate(lines):
        escaped = STRING_WITH_NEWLINES.match(text)
        if (i + 1) in lines_to_fix and len(text) > limit and escaped and i not in spans:
            out.extend((escaped.group(1) + '"' + escaped.group(2) + '"').split("\\n"))
        elif (i + 1) in lines_to_fix and len(text) > limit and i in spans and fixable(text, spans[i]):
            pad = " " * spans[i]
            out.extend(textwrap.wrap(text.strip(), width=limit, initial_indent=pad,
                                     subsequent_indent=pad, break_long_words=False,
                                     break_on_hyphens=False))
        else:
            out.append(text)
    open(full, "w", encoding="utf-8").write("\n".join(out))


def check(repo, base, do_fix=False, verbose=True):
    limit = limit_of(repo)
    if limit is None:
        if verbose:
                print("FAIL: .formatter.exs states no line_length, so there is no limit to check")
        return 1
    added = added_lines(repo, base)
    if do_fix:
        for path, nums in added.items():
            if os.path.exists(os.path.join(repo, path)):
                fix(repo, path, nums, limit)
        added = added_lines(repo, base)
    bad = []
    for path, nums in sorted(added.items()):
        full = os.path.join(repo, path)
        if not os.path.exists(full):
            continue
        lines = open(full, encoding="utf-8").read().split("\n")
        for n in sorted(nums):
            if n <= len(lines) and len(lines[n - 1]) > limit:
                bad.append("%s:%d is %d columns, over %d" % (path, n, len(lines[n - 1]), limit))
    if verbose:
        for b in bad:
            print("  " + b)
        files = len(added)
        print("%s %d changed Elixir file(s), %d added line(s) over %d" %
              ("FAIL" if bad else "ok  ", files, len(bad), limit))
    return 1 if bad else 0


def self_test():
    long_prose = "    " + " ".join(["word"] * 30)
    long_code = "  def f, do: " + "x + " * 30 + "x"
    cases = [
        ("a short added line passes", [("a.exs", "short = 1")], None, 0, False),
        ("a long added line fails", [("a.exs", long_code)], None, 1, False),
        ("a long line already on the base is not asked for", [], ("a.exs", long_code), 0, False),
        ("no line_length in .formatter.exs fails", [("a.exs", "short = 1")], None, 1, "nolimit"),
        ("--fix rewraps long heredoc prose and then passes",
         [("a.exs", '  x ~S"""\n' + long_prose + '\n    """')], None, 0, "fix"),
        ("--fix leaves a long code line failing", [("a.exs", long_code)], None, 1, "fix"),
        ("--fix turns \\n escapes in a long string into line breaks and then passes",
         [("a.exs", '    feature "' + "\\n".join(["short words here"] * 5) + '"')], None, 0, "fix"),
    ]
    bad = 0
    for label, staged, committed, want, mode in cases:
        with tempfile.TemporaryDirectory() as repo:
            git(repo, "init", "-q")
            git(repo, "config", "user.email", "t@t")
            git(repo, "config", "user.name", "t")
            formatter = "[inputs: []]" if mode == "nolimit" else "[line_length: 40]"
            open(os.path.join(repo, ".formatter.exs"), "w").write(formatter + "\n")
            if committed:
                open(os.path.join(repo, committed[0]), "w").write(committed[1] + "\n")
            git(repo, "add", "-A")
            git(repo, "commit", "-q", "-m", "base")
            if committed:
                with open(os.path.join(repo, committed[0]), "a") as f:
                    f.write("short = 1\n")
            for name, body in staged:
                open(os.path.join(repo, name), "w").write(body + "\n")
            git(repo, "add", "-A")
            got = check(repo, "HEAD", do_fix=(mode == "fix"), verbose=False)
            if mode == "fix":
                git(repo, "add", "-A")
                got = check(repo, "HEAD", verbose=False)
        ok = got == want
        bad += not ok
        print("  %s %s" % ("ok  " if ok else "FAIL", label))
    print("\n%d control(s) wrong" % bad)
    return 1 if bad else 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default="HEAD")
    ap.add_argument("--fix", action="store_true")
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()
    if a.self_test:
        return self_test()
    repo = git(".", "rev-parse", "--show-toplevel").strip() or "."
    return check(repo, a.base, do_fix=a.fix)


if __name__ == "__main__":
    sys.exit(main())
