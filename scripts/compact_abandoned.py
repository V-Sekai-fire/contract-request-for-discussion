# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Compact the DETAILS.md of an abandoned RFD, leaving the README whole.

The anti-entropy check reads every pair and reports drift. This does the
opposite on purpose: an abandoned document's working-out is a dead end, and a
dead end costs context on every read. The stub keeps the title and the commit
the full text is in, so the road stays marked and still walkable. The README is
never touched. A README may keep its DETAILS with `<!-- retain-details -->`.

    python compact_abandoned.py            # report, change nothing
    python compact_abandoned.py --apply
    python compact_abandoned.py --self-test
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
RFD = "rfd"
DIR_RE = re.compile(r"^1[0-9]{3}-[a-z0-9-]+$")
STATE_RE = re.compile(r"^\*\*State:\*\*\s*abandoned\s*$", re.M)
TITLE_RE = re.compile(r"^#\s+(RFD [0-9]{4} details: .+?)\s*$", re.M)
RETAIN = "<!-- retain-details -->"
STUB_MARK = "**Compacted.**"


def git(*args):
    r = subprocess.run(["git", "-C", ROOT, *args], capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else None


def candidates(root):
    out = []
    for d in sorted(os.listdir(os.path.join(root, RFD))):
        if not DIR_RE.match(d):
            continue
        readme = os.path.join(root, RFD, d, "README.md")
        details = os.path.join(root, RFD, d, "DETAILS.md")
        if not (os.path.isfile(readme) and os.path.isfile(details)):
            continue
        rtext = open(readme, encoding="utf8").read()
        if not STATE_RE.search(rtext):
            continue
        dtext = open(details, encoding="utf8").read()
        if STUB_MARK in dtext:
            continue
        out.append((d, details, dtext, RETAIN in rtext))
    return out


def stub(title, rel, sha, words):
    return (
        "# %s\n\n"
        "%s This RFD is abandoned, so its working-out was removed to keep the\n"
        "live corpus small. %d words are in git history and nothing was lost.\n\n"
        "    git show %s:%s\n\n"
        "The README beside this file is whole. It carries the state, the\n"
        "decision and the retraction, which is what a reader needs to know a\n"
        "road is closed and why.\n" % (title, STUB_MARK, words, sha, rel)
    )


def run(root, apply_it):
    sha = git("rev-parse", "HEAD") or "HEAD"
    rows, saved = [], 0
    for d, path, text, retained in candidates(root):
        words = len(text.split())
        m = TITLE_RE.search(text)
        if not m:
            print("FAIL  %s/DETAILS.md has no title line to keep" % d)
            return 1
        if retained:
            rows.append(("keep", d, words))
            continue
        rows.append(("compact", d, words))
        saved += words
        if apply_it:
            rel = "%s/%s/DETAILS.md" % (RFD, d)
            with open(path, "w", encoding="utf8", newline="\n") as fh:
                fh.write(stub(m.group(1), rel, sha, words))
    for what, d, words in rows:
        print("  %-8s %-48s %5d words" % (what, d, words))
    print("  %s %d words across %d file(s)"
          % ("removed" if apply_it else "would remove", saved,
             sum(1 for w, _, _ in rows if w == "compact")))
    return 0


def self_test():
    import tempfile
    tmp = tempfile.mkdtemp()
    d = os.path.join(tmp, RFD, "1001-a-slug")
    os.makedirs(d)
    open(os.path.join(d, "README.md"), "w", encoding="utf8").write(
        "# RFD 1001: A\n\n**State:** abandoned\n\nSee `DETAILS.md`.\n")
    open(os.path.join(d, "DETAILS.md"), "w", encoding="utf8").write(
        "# RFD 1001 details: the rest\n\n" + "word " * 200)
    if [c[0] for c in candidates(tmp)] != ["1001-a-slug"]:
        sys.exit("FAIL  an abandoned RFD with a DETAILS was not offered")

    open(os.path.join(d, "README.md"), "w", encoding="utf8").write(
        "# RFD 1001: A\n\n**State:** abandoned\n\n%s\nSee `DETAILS.md`.\n" % RETAIN)
    if not candidates(tmp)[0][3]:
        sys.exit("FAIL  a README asking to retain its DETAILS was not honoured")

    open(os.path.join(d, "README.md"), "w", encoding="utf8").write(
        "# RFD 1001: A\n\n**State:** published\n\nSee `DETAILS.md`.\n")
    if candidates(tmp):
        sys.exit("FAIL  a published RFD was offered for compaction")

    open(os.path.join(d, "README.md"), "w", encoding="utf8").write(
        "# RFD 1001: A\n\n**State:** abandoned\n\nSee `DETAILS.md`.\n")
    open(os.path.join(d, "DETAILS.md"), "w", encoding="utf8").write(
        "# RFD 1001 details: the rest\n\n%s already done\n" % STUB_MARK)
    if candidates(tmp):
        sys.exit("FAIL  an already-compacted DETAILS was offered a second time")

    print("self-test: abandoned offered, retain honoured, published skipped, "
          "compacted-twice refused")
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()
    if a.self_test:
        return self_test()
    return run(ROOT, a.apply)


if __name__ == "__main__":
    sys.exit(main())
