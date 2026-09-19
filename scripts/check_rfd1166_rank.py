#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Recompute RFD 1166's rank with `starvote` and fail if the document disagrees.

A hand-rolled runoff is a claim about STAR rather than STAR.
"""
from __future__ import annotations

import re
import sys

DOC = "rfd/1166-scoring-the-accelerator-candidates/DETAILS.md"
MAX = 100


def table(path=DOC):
    lines = open(path, encoding="utf8").read().splitlines()
    start = next(i for i, l in enumerate(lines) if l.strip().startswith("#  model"))
    order, scores = [], {}
    for line in lines[start + 1:]:
        if not line.strip():
            break
        m = re.match(r"\s*(\d+)\s+(.+?)\s+((?:\d+\s+){8})(\d+)\s", line)
        if not m:
            sys.exit("FAIL  unparsed row: %s" % line.strip()[:60])
        name, dims, total = m.group(2).strip(), [int(x) for x in m.group(3).split()], int(m.group(4))
        if sum(dims) != total:
            sys.exit("FAIL  %s sums to %d, table says %d" % (name, sum(dims), total))
        order.append(name)
        scores[name] = dims
    return order, scores


def star_order(scores):
    import starvote
    ballots = [{m: scores[m][i] for m in scores} for i in range(8)]
    out, pool = [], dict(scores)
    while len(pool) > 1:
        b = [{m: v for m, v in bal.items() if m in pool} for bal in ballots]
        w = starvote.election(starvote.STAR_Voting, b, maximum_score=MAX)
        w = w[0] if isinstance(w, list) else w
        out.append(w)
        del pool[w]
    return out + list(pool)


def main():
    order, scores = table()
    got = star_order(scores)
    print("  ok    %d rows, every sum matches its dimensions" % len(order))
    if got != order:
        for i, (a, b) in enumerate(zip(order, got), 1):
            if a != b:
                print("  seat %d: document says %s, starvote says %s" % (i, a, b))
        return 1
    print("  ok    starvote agrees with the recorded order, seat for seat")
    return 0


def self_test():
    order, scores = table()
    swapped = dict(scores)
    a, b = order[0], order[1]
    swapped[a], swapped[b] = scores[b], scores[a]
    if star_order(swapped)[:2] == [a, b]:
        print("  FAIL  swapping the top two changed nothing; the check is decoration")
        return 1
    print("  ok    swapping the top two rows is rejected")
    return 0


if __name__ == "__main__":
    sys.exit(self_test() if "--self-test" in sys.argv else main())
