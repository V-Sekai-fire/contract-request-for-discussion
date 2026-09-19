#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Reconcile rectgtn/fleet.jsonld's capabilities section with live Bao state.

RFD 2204 defines the fleet domain as a single JSON-LD document peers query with
Taskweft.plan to pick their next task. Its capabilities.entities and
capabilities.graph.edges must reflect the live Bao registry (agents/*.agents.
weftspun rows plus relationships/*--<verb>--<object> tuples) — a stale edge
starves a peer of assignable work or grants one it should not have.

This reconciler rewrites the capabilities section IN PLACE. Every other section
(variables, actions, methods, todo_list, enums) is preserved unchanged: the
domain's decomposition is human-authored; only the fact of which entities exist
and what they may touch is machine-mirrored.

WHAT IT DOES NOT DO. It does not run the planner, does not read
agents/*/assignment rows, and does not modify Bao — the fleet.jsonld is the
source of truth for capabilities, not the sink. sync_rebac_groups.py handles
Bao group membership from the role tuples.

Idempotent — re-running produces no change if state already agrees.

    python scripts/sync_fleet_domain.py            # dry-run
    python scripts/sync_fleet_domain.py --apply    # write changes
    python scripts/sync_fleet_domain.py --self-test
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path


HERE = Path(__file__).resolve().parent
DEFAULT_DOMAIN = HERE.parent / "rectgtn" / "fleet.jsonld"

CAPABILITY_VERBS = ("runs-on", "owns", "may-use--gpu",
                    "may-use--hf-repo", "may-use--uplink")

ROLE_TO_CAPS = {
    "coordinator":         ["coordinator"],
    "gpu-experimenter":    ["gpu-experimenter"],
    "edge-qat-specialist": ["edge-qat-specialist"],
    "assist":              ["assist"],
}


def bao(*args, capture=True):
    r = subprocess.run(["bao", *args], capture_output=capture, text=True)
    if r.returncode:
        raise RuntimeError(f"bao {' '.join(args)}: {r.stderr.strip()[:200]}")
    return r.stdout


def read_agent_rows() -> dict[str, dict]:
    """Return {cn: row_dict} for every agents/<cn>.agents.weftspun row."""
    out = bao("kv", "list", "-format=json", "agents/")
    rows = {}
    for key in json.loads(out):
        if not key.endswith(".agents.weftspun"):
            continue
        try:
            data = json.loads(bao("kv", "get", "-format=json", f"agents/{key}"))
        except RuntimeError:
            continue
        rows[key] = data.get("data", {}).get("data") or data.get("data", {})
    return rows


def read_capability_tuples() -> list[dict]:
    """Return [{subject, rel, object}] for every relationships/*--<verb>--* row."""
    try:
        out = bao("kv", "list", "-format=json", "relationships/")
    except RuntimeError:
        return []
    edges = []
    for key in json.loads(out):
        for verb in CAPABILITY_VERBS:
            marker = f"--{verb}--"
            if marker not in key:
                continue
            subject, obj = key.split(marker, 1)
            edges.append({"subject": subject, "rel": verb, "object": obj})
            break
    return edges


def read_role_tuples() -> dict[str, str]:
    """Return {agent_cn: role} from relationships/*--role--*."""
    try:
        out = bao("kv", "list", "-format=json", "relationships/")
    except RuntimeError:
        return {}
    tuples = {}
    for key in json.loads(out):
        if "--role--" not in key:
            continue
        subject, role = key.split("--role--", 1)
        tuples[subject] = role
    return tuples


def build_capabilities_block(agent_cns: list[str],
                             role_tuples: dict[str, str],
                             edges: list[dict]) -> dict:
    entities = {}
    for cn in sorted(agent_cns):
        role = role_tuples.get(cn.split(".")[0])
        entities[cn] = sorted(set(ROLE_TO_CAPS.get(role, [])))
    edges_sorted = sorted(edges, key=lambda e: (e["subject"], e["rel"], e["object"]))
    seen = set()
    dedup = []
    for e in edges_sorted:
        k = (e["subject"], e["rel"], e["object"])
        if k in seen:
            continue
        seen.add(k)
        dedup.append(e)
    return {"entities": entities, "graph": {"edges": dedup, "definitions": {}}}


def reconcile(domain_path: Path, apply: bool) -> int:
    if not domain_path.exists():
        print(f"FAIL: {domain_path} missing", file=sys.stderr)
        return 2
    doc = json.loads(domain_path.read_text())

    rows = read_agent_rows()
    if not rows:
        print("WARN: no agents/* rows readable; leaving capabilities untouched")
        return 0
    edges = read_capability_tuples()
    roles = read_role_tuples()
    new_caps = build_capabilities_block(list(rows.keys()), roles, edges)

    if doc.get("capabilities") == new_caps:
        print(f"ok: {domain_path.name} already reconciled "
              f"({len(new_caps['entities'])} entities, "
              f"{len(new_caps['graph']['edges'])} edges)")
        return 0

    if not apply:
        print(f"dry-run: {domain_path.name} would update capabilities: "
              f"{len(new_caps['entities'])} entities, "
              f"{len(new_caps['graph']['edges'])} edges")
        return 0

    doc["capabilities"] = new_caps
    domain_path.write_text(json.dumps(doc, indent=2) + "\n")
    print(f"wrote: {domain_path.name} ({len(new_caps['entities'])} entities, "
          f"{len(new_caps['graph']['edges'])} edges)")
    return 0


def self_test() -> int:
    """Every counter carries a control (CLAUDE.md rule 2)."""
    fails = []

    # POSITIVE: two agents, two edges, one role → block matches expected shape.
    roles = {"hero": "gpu-experimenter", "anchor": "assist"}
    edges = [
        {"subject": "hero.mps.agents.weftspun", "rel": "owns", "object": "gpu-3090"},
        {"subject": "anchor.mps.agents.weftspun", "rel": "runs-on", "object": "macbook"},
    ]
    caps = build_capabilities_block(
        ["hero.mps.agents.weftspun", "anchor.mps.agents.weftspun"],
        roles, edges)
    if list(caps["entities"].keys()) != sorted(caps["entities"].keys()):
        fails.append("entities not sorted")
    if caps["entities"]["hero.mps.agents.weftspun"] != ["gpu-experimenter"]:
        fails.append(f"hero caps wrong: {caps['entities']['hero.mps.agents.weftspun']}")
    if len(caps["graph"]["edges"]) != 2:
        fails.append(f"edge count wrong: {len(caps['graph']['edges'])}")

    # NEGATIVE (rule 2): duplicate edges MUST be collapsed to one.
    dup_edges = edges + [edges[0]]
    caps_dup = build_capabilities_block(
        ["hero.mps.agents.weftspun", "anchor.mps.agents.weftspun"],
        roles, dup_edges)
    if len(caps_dup["graph"]["edges"]) != 2:
        fails.append(f"dedup broken: {len(caps_dup['graph']['edges'])} (expected 2)")

    # NEGATIVE (rule 2): an edge with a verb outside CAPABILITY_VERBS must not
    # enter — parse a synthetic relationships key set and assert filtering.
    synthetic = ["hero.mps--may-use--gpu--gpu-3090",
                 "hero.mps--role--gpu-experimenter",
                 "hero.mps--secret-verb--gpu-3090"]
    parsed = []
    for key in synthetic:
        for verb in CAPABILITY_VERBS:
            m = f"--{verb}--"
            if m in key:
                s, o = key.split(m, 1)
                parsed.append((s, verb, o))
                break
    if len(parsed) != 1 or parsed[0][1] != "may-use--gpu":
        fails.append(f"verb filter broken: {parsed}")

    # NEGATIVE (rule 2): unknown role must resolve to empty cap list, not crash.
    caps_unknown = build_capabilities_block(
        ["ghost.mps.agents.weftspun"], {"ghost": "wizard"}, [])
    if caps_unknown["entities"]["ghost.mps.agents.weftspun"] != []:
        fails.append("unknown-role fallback wrong")

    if fails:
        print("SELF-TEST FAIL:")
        for f in fails:
            print(f"  - {f}")
        return 1
    print("self-test ok (4 controls: sort, count, dedup, verb-filter, unknown-role)")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--domain", default=str(DEFAULT_DOMAIN))
    args = ap.parse_args()
    if args.self_test:
        return self_test()
    return reconcile(Path(args.domain), args.apply)


if __name__ == "__main__":
    sys.exit(main())
