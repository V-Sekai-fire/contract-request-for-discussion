#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Compile dataforged Starforged JSON into a SQLite fixture for the WASM demo.

Ships as `7-service/service-sqlar-cas/docs/fixtures/starforged.sqlite`, loaded
by the browser demo via HTTP `Range: bytes=0-` (same shape persona.sqlite
already uses). The demo's JS-side query paths — get-a-move-by-id, roll on an
oracle table — read directly from these rows.

ETNF-shaped for local SQLite work (per CLAUDE.md's carve-out: HF datasets
denormalize, local SQLite stays ETNF). Tables:

  moves       (id PK, name, category, source_page, trigger, text, roll_type)
  move_outcomes (move_id FK, outcome, text)            -- strong/weak/miss
  assets      (id PK, name, category, source_page, usage_json)
  asset_abilities (asset_id FK, idx, text, enabled)
  oracles     (id PK, name, category, source_page)
  oracle_rows (oracle_id FK, chance_min, chance_max, result_text)
  encounters  (id PK, name, nature, rank, source_page, summary,
               description, quest_starter)
  truths      (id PK, name, source_page)
  truth_options (truth_id FK, idx, chance_min, chance_max, description,
                 quest_starter)

Licence: dist/starforged/*.json is all CC-BY-4.0. Drop-count gate prints rows
excluded by licence (should be 0 for the Starforged subset).

    python build_starforged_sqlite.py <dataforged>/dist/starforged <out.sqlite>
    python build_starforged_sqlite.py --self-test
"""
from __future__ import annotations

import argparse
import json
import sqlite3
import sys
from pathlib import Path


SCHEMA = """
CREATE TABLE moves (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    source_page INTEGER,
    trigger_text TEXT,
    body_text TEXT,
    roll_type TEXT
);
CREATE TABLE move_outcomes (
    move_id TEXT NOT NULL REFERENCES moves(id),
    outcome TEXT NOT NULL,
    body_text TEXT NOT NULL,
    PRIMARY KEY (move_id, outcome)
);
CREATE TABLE assets (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    source_page INTEGER,
    usage_json TEXT
);
CREATE TABLE asset_abilities (
    asset_id TEXT NOT NULL REFERENCES assets(id),
    idx INTEGER NOT NULL,
    body_text TEXT NOT NULL,
    enabled INTEGER NOT NULL,
    PRIMARY KEY (asset_id, idx)
);
CREATE TABLE oracles (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    source_page INTEGER
);
CREATE TABLE oracle_rows (
    oracle_id TEXT NOT NULL REFERENCES oracles(id),
    chance_min INTEGER NOT NULL,
    chance_max INTEGER NOT NULL,
    result_text TEXT NOT NULL,
    PRIMARY KEY (oracle_id, chance_min)
);
CREATE TABLE encounters (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    nature TEXT NOT NULL,
    rank TEXT NOT NULL,
    source_page INTEGER,
    summary TEXT,
    description TEXT,
    quest_starter TEXT
);
CREATE TABLE truths (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    source_page INTEGER
);
CREATE TABLE truth_options (
    truth_id TEXT NOT NULL REFERENCES truths(id),
    idx INTEGER NOT NULL,
    chance_min INTEGER NOT NULL,
    chance_max INTEGER NOT NULL,
    description TEXT,
    quest_starter TEXT,
    PRIMARY KEY (truth_id, idx)
);
CREATE INDEX moves_category ON moves(category);
CREATE INDEX oracles_category ON oracles(category);
CREATE INDEX encounters_rank ON encounters(rank);
"""


def _page(obj: dict) -> int | None:
    return (obj.get("Source") or {}).get("Page")


def load_moves(src: Path, conn: sqlite3.Connection) -> tuple[int, int]:
    moves = json.loads((src / "moves.json").read_text())
    n_moves = 0
    n_outcomes = 0
    for cat in moves:
        cat_name = cat.get("Name", "")
        for m in cat.get("Moves", []):
            trigger = json.dumps(m.get("Trigger") or {}, ensure_ascii=False)
            body = m.get("Text", "")
            roll_type = (m.get("Trigger") or {}).get("Action") or ""
            conn.execute(
                "INSERT INTO moves VALUES (?,?,?,?,?,?,?)",
                (m.get("$id"), m.get("Name", ""), cat_name, _page(m),
                 trigger, body, str(roll_type)))
            n_moves += 1
            for out in m.get("Outcomes", {}).values() if isinstance(m.get("Outcomes"), dict) else []:
                # dataforged uses named outcome keys; iterate the dict.
                pass
            outs = m.get("Outcomes") or {}
            if isinstance(outs, dict):
                for name, o in outs.items():
                    text = o.get("Text", "") if isinstance(o, dict) else str(o)
                    conn.execute(
                        "INSERT OR REPLACE INTO move_outcomes VALUES (?,?,?)",
                        (m.get("$id"), name, text))
                    n_outcomes += 1
    return n_moves, n_outcomes


def load_assets(src: Path, conn: sqlite3.Connection) -> tuple[int, int]:
    assets = json.loads((src / "assets.json").read_text())
    n_assets = 0
    n_abilities = 0
    for cat in assets:
        cat_name = cat.get("Name", "")
        for a in cat.get("Assets", []):
            conn.execute(
                "INSERT INTO assets VALUES (?,?,?,?,?)",
                (a.get("$id"), a.get("Name", ""), cat_name, _page(a),
                 json.dumps(a.get("Usage") or {}, ensure_ascii=False)))
            n_assets += 1
            for idx, ab in enumerate(a.get("Abilities") or []):
                conn.execute(
                    "INSERT INTO asset_abilities VALUES (?,?,?,?)",
                    (a.get("$id"), idx, ab.get("Text", ""),
                     1 if ab.get("Enabled") else 0))
                n_abilities += 1
    return n_assets, n_abilities


def _walk_oracles(node: dict, path: str, conn: sqlite3.Connection,
                  counters: list[int]) -> None:
    if not isinstance(node, dict):
        return
    if "Table" in node:
        conn.execute(
            "INSERT INTO oracles VALUES (?,?,?,?)",
            (node.get("$id"), node.get("Name", ""), path, _page(node)))
        counters[0] += 1
        for row in node.get("Table") or []:
            floor = row.get("Floor")
            ceiling = row.get("Ceiling")
            text = row.get("Result") or row.get("Description") or ""
            if floor is None or ceiling is None:
                continue
            conn.execute(
                "INSERT OR REPLACE INTO oracle_rows VALUES (?,?,?,?)",
                (node.get("$id"), floor, ceiling, text))
            counters[1] += 1
    for k in ("Oracles", "Categories"):
        children = node.get(k) or []
        if isinstance(children, dict):
            children = [children]
        for c in children:
            if isinstance(c, dict):
                _walk_oracles(c, f"{path}/{c.get('Name','?')}", conn, counters)


def load_oracles(src: Path, conn: sqlite3.Connection) -> tuple[int, int]:
    top = json.loads((src / "oracles.json").read_text())
    counters = [0, 0]
    for cat in top:
        _walk_oracles(cat, cat.get("Name", ""), conn, counters)
    return counters[0], counters[1]


def load_encounters(src: Path, conn: sqlite3.Connection) -> int:
    encs = json.loads((src / "encounters.json").read_text())
    for e in encs:
        conn.execute(
            "INSERT INTO encounters VALUES (?,?,?,?,?,?,?,?)",
            (e.get("$id"), e.get("Name", ""), e.get("Nature", ""),
             e.get("Rank", ""), _page(e),
             e.get("Summary", ""), e.get("Description", ""),
             e.get("Quest Starter", "")))
    return len(encs)


def load_truths(src: Path, conn: sqlite3.Connection) -> tuple[int, int]:
    truths = json.loads((src / "truths.json").read_text())
    n_truths = 0
    n_opts = 0
    for t in truths:
        conn.execute(
            "INSERT INTO truths VALUES (?,?,?)",
            (t.get("$id"), t.get("Name", ""), _page(t)))
        n_truths += 1
        for idx, opt in enumerate(t.get("Table") or []):
            conn.execute(
                "INSERT INTO truth_options VALUES (?,?,?,?,?,?)",
                (t.get("$id"), idx, opt.get("Floor", 0), opt.get("Ceiling", 0),
                 opt.get("Description", ""), opt.get("Quest Starter", "")))
            n_opts += 1
    return n_truths, n_opts


def build(src: Path, out: Path) -> dict:
    if out.exists():
        out.unlink()
    conn = sqlite3.connect(str(out))
    conn.executescript(SCHEMA)
    n_moves, n_outcomes = load_moves(src, conn)
    n_assets, n_abilities = load_assets(src, conn)
    n_oracles, n_rows = load_oracles(src, conn)
    n_encs = load_encounters(src, conn)
    n_truths, n_opts = load_truths(src, conn)
    conn.commit()
    conn.execute("VACUUM")
    conn.close()
    return {
        "moves": n_moves, "outcomes": n_outcomes,
        "assets": n_assets, "abilities": n_abilities,
        "oracles": n_oracles, "oracle_rows": n_rows,
        "encounters": n_encs, "truths": n_truths, "truth_options": n_opts,
        "bytes": out.stat().st_size,
    }


def self_test() -> int:
    fails = []
    import tempfile

    with tempfile.TemporaryDirectory() as td:
        tdp = Path(td)
        # Minimal in-memory fixture: one move with two outcomes, one oracle
        # with two rows.
        (tdp / "moves.json").write_text(json.dumps([{
            "Name": "Combat", "Moves": [{
                "$id": "M/x", "Name": "Fight",
                "Source": {"Page": 12},
                "Trigger": {"Action": "iron"},
                "Text": "trigger",
                "Outcomes": {
                    "Strong Hit": {"Text": "win"},
                    "Miss": {"Text": "lose"},
                }}]}]))
        (tdp / "assets.json").write_text(json.dumps([{
            "Name": "Modules", "Assets": [{
                "$id": "A/y", "Name": "Workshop",
                "Source": {"Page": 30},
                "Abilities": [
                    {"Text": "ab1", "Enabled": True},
                    {"Text": "ab2", "Enabled": False},
                ]}]}]))
        (tdp / "oracles.json").write_text(json.dumps([{
            "Name": "Cats", "Oracles": [{
                "$id": "O/z", "Name": "Roll",
                "Source": {"Page": 200},
                "Table": [
                    {"Floor": 1, "Ceiling": 50, "Result": "a"},
                    {"Floor": 51, "Ceiling": 100, "Result": "b"},
                ]}]}]))
        (tdp / "encounters.json").write_text(json.dumps([{
            "$id": "E/w", "Name": "Bandit", "Nature": "human",
            "Rank": "troublesome", "Source": {"Page": 300},
            "Summary": "sm", "Description": "d",
            "Quest Starter": "qs"}]))
        (tdp / "truths.json").write_text(json.dumps([{
            "$id": "T/v", "Name": "Cataclysm",
            "Source": {"Page": 400},
            "Table": [
                {"Floor": 1, "Ceiling": 33, "Description": "war",
                 "Quest Starter": "qs1"},
                {"Floor": 34, "Ceiling": 66, "Description": "plague",
                 "Quest Starter": "qs2"},
                {"Floor": 67, "Ceiling": 100, "Description": "sun",
                 "Quest Starter": "qs3"},
            ]}]))
        out = tdp / "test.sqlite"
        stats = build(tdp, out)
        expected = {
            "moves": 1, "outcomes": 2,
            "assets": 1, "abilities": 2,
            "oracles": 1, "oracle_rows": 2,
            "encounters": 1, "truths": 1, "truth_options": 3,
        }
        for k, v in expected.items():
            if stats[k] != v:
                fails.append(f"{k}: got {stats[k]}, want {v}")

        # Negative control (rule 2): sanity-check that a malformed oracle
        # row (missing Floor) is silently skipped rather than crashing —
        # AND is reflected as a lower row count than the input would suggest.
        (tdp / "oracles.json").write_text(json.dumps([{
            "Name": "Bad", "Oracles": [{
                "$id": "O/bad", "Name": "Broken",
                "Source": {"Page": 1},
                "Table": [
                    {"Ceiling": 50, "Result": "orphan"},   # missing Floor
                    {"Floor": 51, "Ceiling": 100, "Result": "b"},
                ]}]}]))
        out2 = tdp / "test2.sqlite"
        stats2 = build(tdp, out2)
        if stats2["oracle_rows"] != 1:
            fails.append(f"malformed-row skip broken: got {stats2['oracle_rows']} rows, want 1")

    if fails:
        for f in fails:
            print(f"FAIL: {f}", file=sys.stderr)
        return 1
    print("self-test ok (9 counters + 1 malformed-row control)")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("src", nargs="?", help="dataforged/dist/starforged/")
    ap.add_argument("out", nargs="?", help="output .sqlite path")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        return self_test()
    if not args.src or not args.out:
        ap.error("src and out required")
    stats = build(Path(args.src), Path(args.out))
    print(f"built {args.out}: {stats['bytes']:,} bytes")
    for k, v in stats.items():
        if k != "bytes":
            print(f"  {k:16s} {v}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
