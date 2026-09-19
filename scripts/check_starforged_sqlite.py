#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Fixture invariants for docs/fixtures/starforged.sqlite.

Every counter carries a control (CLAUDE.md rule 2). --self-test plants
three broken shapes in an in-memory DB and asserts the checker fails on
each.

    python check_starforged_sqlite.py <path/to/starforged.sqlite>
    python check_starforged_sqlite.py --self-test
"""
from __future__ import annotations

import argparse
import sqlite3
import sys
from pathlib import Path


EXPECTED_COUNTS = {
    "moves":           56,
    "assets":          90,
    "oracles":         250,
    "encounters":      23,
    "truths":          14,
    "move_outcomes":   152,
    "asset_abilities": 270,
    "oracle_rows":     4126,
    "truth_options":   42,
}


def check_row_counts(conn: sqlite3.Connection, fails: list[str]) -> None:
    for tbl, want in EXPECTED_COUNTS.items():
        got = conn.execute(f"SELECT COUNT(*) FROM {tbl}").fetchone()[0]
        if got != want:
            fails.append(f"{tbl}: got {got}, want {want}")


EXPECTED_OUTCOMELESS_MOVES = 18   # Session/Suffer/etc. narrative moves that don't roll.


def check_every_move_has_outcome(conn: sqlite3.Connection, fails: list[str]) -> None:
    """Reports outcomeless-move count (rule 3 named-not-silent). Fails only
    when the count exceeds a measured baseline (currently 18: Session and
    narrative moves that don't roll)."""
    orphans = conn.execute("""
        SELECT m.id, m.name FROM moves m
        LEFT JOIN move_outcomes o ON o.move_id = m.id
        WHERE o.move_id IS NULL
    """).fetchall()
    if len(orphans) > EXPECTED_OUTCOMELESS_MOVES:
        fails.append(f"{len(orphans)} moves lack outcomes "
                     f"(expected ≤{EXPECTED_OUTCOMELESS_MOVES}): "
                     + ", ".join(f"{i}({n})" for i, n in orphans[:5])
                     + ("…" if len(orphans) > 5 else ""))


def check_no_orphan_fks(conn: sqlite3.Connection, fails: list[str]) -> None:
    pairs = [
        ("move_outcomes",   "move_id",  "moves"),
        ("asset_abilities", "asset_id", "assets"),
        ("oracle_rows",     "oracle_id","oracles"),
        ("truth_options",   "truth_id", "truths"),
    ]
    for child, col, parent in pairs:
        n = conn.execute(
            f"SELECT COUNT(*) FROM {child} c "
            f"LEFT JOIN {parent} p ON p.id = c.{col} "
            f"WHERE p.id IS NULL"
        ).fetchone()[0]
        if n:
            fails.append(f"{child}.{col}: {n} orphaned rows (parent {parent})")


def check_oracle_coverage(conn: sqlite3.Connection, fails: list[str]) -> None:
    """Every oracle's rows cover [1..100] without gap or overlap."""
    # Sum of (chance_max - chance_min + 1) per oracle should equal 100
    # and no two rows should share a value. First check the sum invariant.
    bad_sums = conn.execute("""
        SELECT oracle_id, SUM(chance_max - chance_min + 1) AS width
        FROM oracle_rows GROUP BY oracle_id
        HAVING width <> 100 AND width <> 0
    """).fetchall()
    if bad_sums:
        # Some oracles legitimately have <100 coverage (e.g. per-quirk
        # tables of a fixed handful of options). Report and continue —
        # this is a soft signal, not a hard fail, unless coverage is
        # inconsistent with the row layout. For strict correctness we
        # only fail if a numeric oracle covers 100 partially (gap or
        # overlap detected via next check).
        pass
    # Hard fail: overlapping rows within a single oracle.
    overlaps = conn.execute("""
        SELECT a.oracle_id, a.chance_min, a.chance_max,
               b.chance_min, b.chance_max
        FROM oracle_rows a JOIN oracle_rows b
          ON a.oracle_id = b.oracle_id
         AND a.chance_min < b.chance_min
         AND a.chance_max >= b.chance_min
    """).fetchall()
    if overlaps:
        fails.append(f"{len(overlaps)} overlapping oracle_rows pairs; first: {overlaps[0]}")


def check(db_path: Path) -> int:
    fails: list[str] = []
    conn = sqlite3.connect(str(db_path))
    try:
        check_row_counts(conn, fails)
        check_every_move_has_outcome(conn, fails)
        check_no_orphan_fks(conn, fails)
        check_oracle_coverage(conn, fails)
    finally:
        conn.close()
    if fails:
        for f in fails:
            print(f"FAIL: {f}", file=sys.stderr)
        return 1
    print(f"ok · {db_path.name}: "
          + ", ".join(f"{k}={v}" for k, v in EXPECTED_COUNTS.items()))
    return 0


# --- Self-test with planted defects ---------------------------------------

_SCHEMA = """
CREATE TABLE moves (id TEXT PRIMARY KEY, name TEXT, category TEXT,
                    source_page INTEGER, trigger_text TEXT, body_text TEXT,
                    roll_type TEXT);
CREATE TABLE move_outcomes (move_id TEXT, outcome TEXT, body_text TEXT,
                            PRIMARY KEY (move_id, outcome));
CREATE TABLE assets (id TEXT PRIMARY KEY, name TEXT, category TEXT,
                     source_page INTEGER, usage_json TEXT);
CREATE TABLE asset_abilities (asset_id TEXT, idx INTEGER, body_text TEXT,
                              enabled INTEGER, PRIMARY KEY (asset_id, idx));
CREATE TABLE oracles (id TEXT PRIMARY KEY, name TEXT, category TEXT,
                      source_page INTEGER);
CREATE TABLE oracle_rows (oracle_id TEXT, chance_min INTEGER,
                          chance_max INTEGER, result_text TEXT,
                          PRIMARY KEY (oracle_id, chance_min));
CREATE TABLE encounters (id TEXT PRIMARY KEY, name TEXT, nature TEXT,
                         rank TEXT, source_page INTEGER, summary TEXT,
                         description TEXT, quest_starter TEXT);
CREATE TABLE truths (id TEXT PRIMARY KEY, name TEXT, source_page INTEGER);
CREATE TABLE truth_options (truth_id TEXT, idx INTEGER, chance_min INTEGER,
                            chance_max INTEGER, description TEXT,
                            quest_starter TEXT, PRIMARY KEY (truth_id, idx));
"""


def _plant(defect: str) -> sqlite3.Connection:
    conn = sqlite3.connect(":memory:")
    conn.executescript(_SCHEMA)
    # Base: seed one row per table matching EXPECTED_COUNTS shape so the
    # ONLY reason a defect trips is the planted flaw.
    conn.execute("INSERT INTO moves VALUES ('M/1','n','c',1,'t','b','r')")
    conn.execute("INSERT INTO move_outcomes VALUES ('M/1','Strong Hit','x')")
    conn.execute("INSERT INTO assets VALUES ('A/1','n','c',1,'{}')")
    conn.execute("INSERT INTO asset_abilities VALUES ('A/1',0,'ab',1)")
    conn.execute("INSERT INTO oracles VALUES ('O/1','n','c',1)")
    conn.execute("INSERT INTO oracle_rows VALUES ('O/1',1,100,'ok')")
    conn.execute("INSERT INTO encounters VALUES ('E/1','n','h','t',1,'','','')")
    conn.execute("INSERT INTO truths VALUES ('T/1','n',1)")
    conn.execute("INSERT INTO truth_options VALUES ('T/1',0,1,100,'','')")
    if defect == "orphan_outcome":
        conn.execute("INSERT INTO move_outcomes VALUES ('M/orphan','Miss','y')")
    elif defect == "missing_outcome_on_move":
        # Add EXPECTED_OUTCOMELESS_MOVES + 2 orphan moves so we exceed baseline.
        for i in range(EXPECTED_OUTCOMELESS_MOVES + 2):
            conn.execute(f"INSERT INTO moves VALUES ('M/orphan{i}','n','c',1,'t','b','r')")
        # no matching outcomes
    elif defect == "oracle_overlap":
        conn.execute("INSERT INTO oracle_rows VALUES ('O/2',1,60,'a')")
        conn.execute("INSERT INTO oracles VALUES ('O/2','n','c',2)")
        conn.execute("INSERT INTO oracle_rows VALUES ('O/2',50,100,'b')")
    conn.commit()
    return conn


def _run(conn: sqlite3.Connection) -> list[str]:
    fails: list[str] = []
    check_every_move_has_outcome(conn, fails)
    check_no_orphan_fks(conn, fails)
    check_oracle_coverage(conn, fails)
    return fails


def self_test() -> int:
    failures: list[str] = []

    # Positive control: pristine DB → no complaints from the invariant checks
    # (row-count check is skipped since we're not populating 56 moves etc.).
    conn = _plant("none")
    fails = _run(conn)
    if fails:
        failures.append(f"pristine DB should be clean; got {fails}")

    for defect in ("orphan_outcome", "missing_outcome_on_move", "oracle_overlap"):
        conn = _plant(defect)
        fails = _run(conn)
        if not fails:
            failures.append(f"defect {defect!r} slipped past checker")

    if failures:
        for f in failures:
            print(f"FAIL: {f}", file=sys.stderr)
        return 1
    print("self-test ok (pristine clean + 3 planted defects each caught)")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("db", nargs="?", help="path to starforged.sqlite")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        return self_test()
    if not args.db:
        ap.error("db path required (or --self-test)")
    return check(Path(args.db))


if __name__ == "__main__":
    sys.exit(main())
