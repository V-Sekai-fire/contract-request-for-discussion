#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Compile rectgtn/fleet.jsonld into rectgtn/fleet.sqlite for the Bao plugin.

The plugin (service-taskweft-bao, database-plugin type per RFD 2205) reads
the fleet domain as a SQLite blob at `secret/taskweft/db/fleet` — served
by the sibling sqlite-fdb secrets engine — plus skip-state rows the plugin
writes, plus assignment rows Bao's lease lifecycle manages. The JSONLD is
what humans edit; this script mirrors it into the runtime container.

Schema (ETNF, per CLAUDE.md carve-out for local SQLite work):

    domain (id INTEGER PRIMARY KEY, jsonld BLOB NOT NULL);
    skip   (task_key TEXT, method_idx INTEGER, cn TEXT, at INTEGER,
            PRIMARY KEY (task_key, method_idx));
    assign (lease_id TEXT PRIMARY KEY, cn TEXT NOT NULL,
            action TEXT NOT NULL, expires_at INTEGER NOT NULL);

The `domain` table always holds exactly one row (id=1); replacement is
atomic. The `skip` and `assign` tables ship empty — populated at runtime
by the plugin.

    python build_fleet_sqlite.py <fleet.jsonld> <fleet.sqlite>
    python build_fleet_sqlite.py --self-test
"""
from __future__ import annotations

import argparse
import json
import sqlite3
import sys
from pathlib import Path


SCHEMA = """
CREATE TABLE domain (
    id     INTEGER PRIMARY KEY CHECK (id = 1),
    jsonld BLOB    NOT NULL
);
CREATE TABLE skip (
    task_key   TEXT    NOT NULL,
    method_idx INTEGER NOT NULL,
    cn         TEXT    NOT NULL,
    at         INTEGER NOT NULL,
    PRIMARY KEY (task_key, method_idx)
);
CREATE TABLE assign (
    lease_id   TEXT    PRIMARY KEY,
    cn         TEXT    NOT NULL,
    action     TEXT    NOT NULL,
    expires_at INTEGER NOT NULL
);
CREATE INDEX skip_cn     ON skip (cn);
CREATE INDEX assign_cn   ON assign (cn);
CREATE INDEX assign_expires ON assign (expires_at);
"""

REQUIRED_TOP_KEYS = {"@type", "name", "variables", "actions", "methods"}


def _validate_domain(doc: dict) -> list[str]:
    """Cheap shape check without pulling the full RECTGTN schema."""
    fails = []
    missing = REQUIRED_TOP_KEYS - set(doc.keys())
    if missing:
        fails.append(f"missing top-level keys: {sorted(missing)}")
    if doc.get("@type") not in ("domain:Problem", "domain:Definition"):
        fails.append(f"@type must be domain:Problem or domain:Definition, got {doc.get('@type')!r}")
    if not isinstance(doc.get("actions"), dict) or not doc["actions"]:
        fails.append("actions must be a non-empty object")
    if not isinstance(doc.get("methods"), dict) or not doc["methods"]:
        fails.append("methods must be a non-empty object")
    return fails


def build(src: Path, out: Path) -> dict:
    doc = json.loads(src.read_text())
    fails = _validate_domain(doc)
    if fails:
        raise ValueError("fleet.jsonld invalid: " + "; ".join(fails))

    # Canonicalise: sorted keys + no extra whitespace so a rebuild produces
    # a byte-identical blob when the input didn't change.
    canonical = json.dumps(doc, sort_keys=True, separators=(",", ":"),
                           ensure_ascii=False).encode("utf-8")

    if out.exists():
        out.unlink()
    conn = sqlite3.connect(str(out))
    conn.executescript(SCHEMA)
    conn.execute("INSERT INTO domain (id, jsonld) VALUES (1, ?)", (canonical,))
    conn.commit()
    conn.execute("VACUUM")
    conn.close()

    return {
        "actions":       len(doc["actions"]),
        "methods":       len(doc["methods"]),
        "entities":      len((doc.get("capabilities") or {}).get("entities") or {}),
        "edges":         len((doc.get("capabilities") or {}).get("graph", {}).get("edges") or []),
        "variables":     len(doc.get("variables") or []),
        "todo_list":     len(doc.get("todo_list") or []),
        "canonical_bytes": len(canonical),
        "bytes":         out.stat().st_size,
    }


def self_test() -> int:
    """Positive control + 4 planted defects."""
    fails: list[str] = []
    import tempfile

    minimal = {
        "@context": {},
        "@type": "domain:Problem",
        "name": "test",
        "variables": [{"name": "x", "type": "int", "init": {"a": 0}}],
        "actions": {"noop": {"params": [], "body": [
            {"pointer/set": "/x/a", "value": 1}]}},
        "methods": {"m": {"params": [], "alternatives": [
            {"name": "one", "subtasks": [["noop"]]}]}},
        "todo_list": [{"goal": [{"pointer": "/x/a", "eq": 1}]}],
    }

    with tempfile.TemporaryDirectory() as td:
        src = Path(td) / "fleet.jsonld"
        out = Path(td) / "fleet.sqlite"

        # Positive: minimal valid domain writes a single-row domain table.
        src.write_text(json.dumps(minimal))
        stats = build(src, out)
        if stats["actions"] != 1 or stats["methods"] != 1:
            fails.append(f"minimal counts wrong: {stats}")
        conn = sqlite3.connect(str(out))
        n_rows = conn.execute("SELECT COUNT(*) FROM domain").fetchone()[0]
        if n_rows != 1:
            fails.append(f"domain must have 1 row, got {n_rows}")
        got_blob = conn.execute("SELECT jsonld FROM domain WHERE id=1").fetchone()[0]
        got_doc = json.loads(got_blob)
        if got_doc["name"] != "test":
            fails.append("blob round-trip lost content")
        # Empty runtime tables at build time.
        for tbl in ("skip", "assign"):
            n = conn.execute(f"SELECT COUNT(*) FROM {tbl}").fetchone()[0]
            if n != 0:
                fails.append(f"{tbl} must ship empty, got {n}")
        conn.close()

        # Deterministic canonicalisation: build twice with same input →
        # byte-identical blob.
        out2 = Path(td) / "fleet2.sqlite"
        stats2 = build(src, out2)
        if stats["canonical_bytes"] != stats2["canonical_bytes"]:
            fails.append("canonical blob differs across builds on same input")

        # Negative controls (rule 2): each MUST raise ValueError.
        for defect_name, mutator in [
            ("missing_actions",   lambda d: (d.pop("actions"), d)[1]),
            ("wrong_type",        lambda d: {**d, "@type": "foo"}),
            ("empty_methods",     lambda d: {**d, "methods": {}}),
            ("missing_name",      lambda d: (d.pop("name"), d)[1]),
        ]:
            broken = mutator({**minimal,
                              "variables": list(minimal["variables"]),
                              "actions": dict(minimal["actions"]),
                              "methods": dict(minimal["methods"])})
            src.write_text(json.dumps(broken))
            caught = False
            try:
                build(src, Path(td) / f"bad_{defect_name}.sqlite")
            except ValueError:
                caught = True
            if not caught:
                fails.append(f"defect {defect_name!r} was not caught")

    if fails:
        for f in fails:
            print(f"FAIL: {f}", file=sys.stderr)
        return 1
    print("self-test ok (positive build + deterministic canonicalisation "
          "+ 4 planted defects each caught)")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("src", nargs="?", help="path to fleet.jsonld")
    ap.add_argument("out", nargs="?", help="output .sqlite path")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        return self_test()
    if not args.src or not args.out:
        ap.error("src and out required (or --self-test)")
    stats = build(Path(args.src), Path(args.out))
    print(f"built {args.out}: {stats['bytes']:,} bytes "
          f"(canonical domain blob: {stats['canonical_bytes']:,} B)")
    for k in ("actions", "methods", "entities", "edges", "variables", "todo_list"):
        print(f"  {k:12s} {stats[k]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
