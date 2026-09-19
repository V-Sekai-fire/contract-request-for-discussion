#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Invariants on the chibifire/starforged HF dataset (parquet shards).

Every counter carries a control (CLAUDE.md rule 2). --self-test plants
three broken rows in an in-memory table and asserts the checker fails
on each.

    python check_starforged_hf.py <path/to/dataset-dir-with-data-subdir>
    python check_starforged_hf.py --self-test
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import pyarrow.parquet as pq


EXPECTED_BY_KIND = {
    "move": 56, "asset": 90, "oracle": 250, "encounter": 23, "truth": 14,
}
EXPECTED_TOTAL = 433
EXPECTED_LICENSE = "CC-BY-4.0"
REQUIRED_COLUMNS = {"kind", "id", "name", "category", "source_title",
                    "source_page", "source_authors", "license", "content_json"}


def load_rows(shards_dir: Path) -> list[dict]:
    files = sorted(shards_dir.glob("data/train-*.parquet"))
    if not files:
        files = sorted(shards_dir.glob("*.parquet"))
    if not files:
        raise FileNotFoundError(f"no parquet shards under {shards_dir}")
    rows: list[dict] = []
    for f in files:
        t = pq.read_table(f)
        for r in t.to_pylist():
            rows.append(r)
    return rows


def check_rows(rows: list[dict], fails: list[str]) -> None:
    # Schema completeness.
    if rows:
        got_cols = set(rows[0].keys())
        missing = REQUIRED_COLUMNS - got_cols
        if missing:
            fails.append(f"missing columns: {missing}")

    # Total.
    if len(rows) != EXPECTED_TOTAL:
        fails.append(f"total rows: {len(rows)} != {EXPECTED_TOTAL}")

    # By-kind counts.
    from collections import Counter
    by_kind = Counter(r.get("kind") for r in rows)
    for k, want in EXPECTED_BY_KIND.items():
        got = by_kind.get(k, 0)
        if got != want:
            fails.append(f"kind={k}: {got} != {want}")
    unknown_kinds = set(by_kind) - set(EXPECTED_BY_KIND)
    if unknown_kinds:
        fails.append(f"unknown kinds present: {unknown_kinds}")

    # Every license == expected.
    bad_lic = [r for r in rows if r.get("license") != EXPECTED_LICENSE]
    if bad_lic:
        fails.append(f"{len(bad_lic)} rows have license != {EXPECTED_LICENSE}; "
                     f"first: id={bad_lic[0].get('id')!r} license={bad_lic[0].get('license')!r}")

    # Every content_json parses.
    unparsed = []
    for r in rows:
        cj = r.get("content_json")
        if cj is None:
            unparsed.append((r.get("id"), "null"))
            continue
        try:
            json.loads(cj)
        except Exception as e:
            unparsed.append((r.get("id"), str(e)[:40]))
    if unparsed:
        fails.append(f"{len(unparsed)} rows have unparseable content_json; "
                     f"first: {unparsed[0]}")


def check(shards_dir: Path) -> int:
    fails: list[str] = []
    rows = load_rows(shards_dir)
    check_rows(rows, fails)
    if fails:
        for f in fails:
            print(f"FAIL: {f}", file=sys.stderr)
        return 1
    from collections import Counter
    by_kind = Counter(r["kind"] for r in rows)
    print(f"ok · {len(rows)} rows, "
          + ", ".join(f"{k}={by_kind[k]}" for k in sorted(EXPECTED_BY_KIND))
          + f", all license={EXPECTED_LICENSE}, all content_json parses")
    return 0


def self_test() -> int:
    """Plant three defects in an in-memory row set; assert each is caught."""
    def base_rows():
        return ([
            {"kind": "move", "id": f"m/{i}", "name": "n", "category": "c",
             "source_title": "R", "source_page": 1, "source_authors": "A",
             "license": EXPECTED_LICENSE, "content_json": "{}"}
            for i in range(EXPECTED_BY_KIND["move"])
        ] + [
            {"kind": "asset", "id": f"a/{i}", "name": "n", "category": "c",
             "source_title": "R", "source_page": 1, "source_authors": "A",
             "license": EXPECTED_LICENSE, "content_json": "{}"}
            for i in range(EXPECTED_BY_KIND["asset"])
        ] + [
            {"kind": "oracle", "id": f"o/{i}", "name": "n", "category": "c",
             "source_title": "R", "source_page": 1, "source_authors": "A",
             "license": EXPECTED_LICENSE, "content_json": "{}"}
            for i in range(EXPECTED_BY_KIND["oracle"])
        ] + [
            {"kind": "encounter", "id": f"e/{i}", "name": "n", "category": "c",
             "source_title": "R", "source_page": 1, "source_authors": "A",
             "license": EXPECTED_LICENSE, "content_json": "{}"}
            for i in range(EXPECTED_BY_KIND["encounter"])
        ] + [
            {"kind": "truth", "id": f"t/{i}", "name": "n", "category": "c",
             "source_title": "R", "source_page": 1, "source_authors": "A",
             "license": EXPECTED_LICENSE, "content_json": "{}"}
            for i in range(EXPECTED_BY_KIND["truth"])
        ])

    failures: list[str] = []

    # Positive: pristine rows → clean.
    fails: list[str] = []
    check_rows(base_rows(), fails)
    if fails:
        failures.append(f"pristine rows should be clean; got {fails}")

    # Defect 1: one row with wrong license.
    rows = base_rows()
    rows[0]["license"] = "CC-BY-NC-4.0"
    fails = []
    check_rows(rows, fails)
    if not any("license" in f for f in fails):
        failures.append("wrong-license defect not caught")

    # Defect 2: unparseable content_json.
    rows = base_rows()
    rows[10]["content_json"] = "{not valid json"
    fails = []
    check_rows(rows, fails)
    if not any("content_json" in f for f in fails):
        failures.append("bad-JSON defect not caught")

    # Defect 3: missing kind (unknown kind → count mismatch AND unknown set).
    rows = base_rows()
    rows[20]["kind"] = "wanderer"
    fails = []
    check_rows(rows, fails)
    if not any("kind=move" in f or "unknown kinds" in f for f in fails):
        failures.append("unknown-kind defect not caught")

    if failures:
        for f in failures:
            print(f"FAIL: {f}", file=sys.stderr)
        return 1
    print("self-test ok (pristine clean + 3 planted defects each caught)")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("shards_dir", nargs="?",
                    help="dir containing data/train-*.parquet (or *.parquet directly)")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        return self_test()
    if not args.shards_dir:
        ap.error("shards_dir required (or --self-test)")
    return check(Path(args.shards_dir))


if __name__ == "__main__":
    sys.exit(main())
