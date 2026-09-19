#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Reformat rsek/dataforged's dist/starforged JSON as an HF dataset.

Produces one wide-row parquet per Starforged content category (moves, assets,
oracles, encounters, truths) under data/train-XX-of-YY.parquet, ZSTD-compressed,
per the hf-datasets-no-etnf and hf-upload-incremental skills. A single `kind`
column keys each row to its category so the whole set can be loaded as one
`train` split.

Every row keeps the source `$id`, `Name`, `Source.Page`, and a `content_json`
column with the full original JSON so consumers can reach fields not surfaced
in the flat columns.

Licence: dist/starforged/*.json is all CC-BY-4.0 (Shawn Tomkin, Absolute
Tabletop LLC). The `ironsworn/` subtree and raster planet illustrations are
CC-BY-NC-4.0 and NOT in scope for this converter — we read only
dist/starforged/*.json. The build prints the drop count as a rule-3 named-not-
silent gate; for the Starforged subset it will always be 0.

    python build_starforged_hf.py <dataforged-repo>/dist/starforged <out-dir>
    python build_starforged_hf.py --self-test
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import pyarrow as pa
import pyarrow.parquet as pq


LICENSE = "CC-BY-4.0"
LICENSE_SOURCE = "https://creativecommons.org/licenses/by/4.0/"


def _source_of(obj: dict) -> tuple[str, int | None, str]:
    src = obj.get("Source") or {}
    title = src.get("Title", "")
    page = src.get("Page")
    authors = ", ".join(src.get("Authors", []))
    return title, page, authors


def _flatten_moves(moves_json: list) -> list[dict]:
    rows = []
    for cat in moves_json:
        cat_name = cat.get("Name", "")
        for m in cat.get("Moves", []):
            title, page, authors = _source_of(m)
            rows.append({
                "kind": "move",
                "id": m.get("$id", ""),
                "name": m.get("Name", ""),
                "category": cat_name,
                "source_title": title,
                "source_page": page,
                "source_authors": authors,
                "license": LICENSE,
                "content_json": json.dumps(m, ensure_ascii=False),
            })
    return rows


def _flatten_assets(assets_json: list) -> list[dict]:
    rows = []
    for cat in assets_json:
        cat_name = cat.get("Name", "")
        for a in cat.get("Assets", []):
            title, page, authors = _source_of(a)
            rows.append({
                "kind": "asset",
                "id": a.get("$id", ""),
                "name": a.get("Name", ""),
                "category": cat_name,
                "source_title": title,
                "source_page": page,
                "source_authors": authors,
                "license": LICENSE,
                "content_json": json.dumps(a, ensure_ascii=False),
            })
    return rows


def _flatten_oracles(oracles_json: list) -> list[dict]:
    rows = []

    def walk(node: dict, path: str) -> None:
        if not isinstance(node, dict):
            return
        title, page, authors = _source_of(node)
        if "Table" in node:
            rows.append({
                "kind": "oracle",
                "id": node.get("$id", path),
                "name": node.get("Name", ""),
                "category": path,
                "source_title": title,
                "source_page": page,
                "source_authors": authors,
                "license": LICENSE,
                "content_json": json.dumps(node, ensure_ascii=False),
            })
        for k in ("Oracles", "Categories"):
            children = node.get(k) or []
            if isinstance(children, dict):
                children = [children]
            for c in children:
                walk(c, f"{path}/{c.get('Name','?')}" if isinstance(c, dict) else path)

    for cat in oracles_json:
        walk(cat, cat.get("Name", ""))
    return rows


def _flatten_encounters(encs_json: list) -> list[dict]:
    rows = []
    for e in encs_json:
        title, page, authors = _source_of(e)
        rows.append({
            "kind": "encounter",
            "id": e.get("$id", ""),
            "name": e.get("Name", ""),
            "category": e.get("Nature", ""),
            "source_title": title,
            "source_page": page,
            "source_authors": authors,
            "license": LICENSE,
            "content_json": json.dumps(e, ensure_ascii=False),
        })
    return rows


def _flatten_truths(truths_json: list) -> list[dict]:
    rows = []
    for t in truths_json:
        title, page, authors = _source_of(t)
        rows.append({
            "kind": "truth",
            "id": t.get("$id", ""),
            "name": t.get("Name", ""),
            "category": "setting_truth",
            "source_title": title,
            "source_page": page,
            "source_authors": authors,
            "license": LICENSE,
            "content_json": json.dumps(t, ensure_ascii=False),
        })
    return rows


def build(src: Path) -> tuple[list[dict], int]:
    all_rows: list[dict] = []
    all_rows += _flatten_moves(json.loads((src / "moves.json").read_text()))
    all_rows += _flatten_assets(json.loads((src / "assets.json").read_text()))
    all_rows += _flatten_oracles(json.loads((src / "oracles.json").read_text()))
    all_rows += _flatten_encounters(json.loads((src / "encounters.json").read_text()))
    all_rows += _flatten_truths(json.loads((src / "truths.json").read_text()))
    dropped = sum(1 for r in all_rows if r["license"] != LICENSE)
    return all_rows, dropped


def write_shards(rows: list[dict], out_dir: Path, rows_per_shard: int = 250) -> list[Path]:
    schema = pa.schema([
        ("kind",           pa.string()),
        ("id",             pa.string()),
        ("name",           pa.string()),
        ("category",       pa.string()),
        ("source_title",   pa.string()),
        ("source_page",    pa.int32()),
        ("source_authors", pa.string()),
        ("license",        pa.string()),
        ("content_json",   pa.string()),
    ])
    out_dir.mkdir(parents=True, exist_ok=True)
    shards = [rows[i:i + rows_per_shard] for i in range(0, len(rows), rows_per_shard)]
    n = len(shards)
    paths: list[Path] = []
    for idx, shard in enumerate(shards):
        table = pa.Table.from_pylist(shard, schema=schema)
        p = out_dir / f"train-{idx:05d}-of-{n:05d}.parquet"
        pq.write_table(table, p, compression="zstd", compression_level=9)
        paths.append(p)
    return paths


def self_test() -> int:
    fails = []
    fake_moves = [{"Name": "Combat", "Moves": [{"$id": "x/y", "Name": "Fight",
                                                "Source": {"Title": "R", "Page": 12,
                                                           "Authors": ["A"]}}]}]
    rows = _flatten_moves(fake_moves)
    if len(rows) != 1: fails.append(f"moves flatten count {len(rows)}")
    if rows[0]["kind"] != "move": fails.append("kind wrong")
    if rows[0]["source_page"] != 12: fails.append(f"page {rows[0]['source_page']}")
    if rows[0]["license"] != LICENSE: fails.append("license default wrong")

    # Negative control (rule 2): a wrapped oracle with a Table becomes one row;
    # nested categories without Table produce zero rows for the wrapper.
    fake_oracles = [{"Name": "Cats", "Oracles": [
        {"Name": "Roll", "Table": [{"Result": "x"}],
         "Source": {"Title": "R", "Page": 1, "Authors": []}}]}]
    orows = _flatten_oracles(fake_oracles)
    if len(orows) != 1: fails.append(f"oracle rows {len(orows)}")

    # Round-trip through pyarrow schema.
    import tempfile
    with tempfile.TemporaryDirectory() as td:
        paths = write_shards(rows + orows, Path(td), rows_per_shard=1)
        if len(paths) != 2: fails.append(f"shard count {len(paths)}")
        t = pq.read_table(paths[0])
        if t.num_rows != 1: fails.append(f"shard 0 rows {t.num_rows}")

    if fails:
        for f in fails: print(f"FAIL: {f}", file=sys.stderr)
        return 1
    print("self-test ok (5 controls: moves-flatten, kind, page, license, oracle-nesting)")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("src", nargs="?", help="path to dataforged/dist/starforged/")
    ap.add_argument("out", nargs="?", help="output dir (contains data/ + README.md)")
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--rows-per-shard", type=int, default=250)
    args = ap.parse_args()
    if args.self_test:
        return self_test()
    if not args.src or not args.out:
        ap.error("src and out required (or use --self-test)")
    src, out = Path(args.src), Path(args.out)
    rows, dropped = build(src)
    print(f"built {len(rows)} rows; dropped {dropped} non-{LICENSE} rows")
    paths = write_shards(rows, out / "data", rows_per_shard=args.rows_per_shard)
    for p in paths:
        print(f"wrote {p} ({p.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
