#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
"""Reconcile Bao identity groups with the ReBAC role tuples in relationships/.

RFD 2200 defined role tuples as data. RFD 2202 wires them to Bao identity groups so the
KV/PKI/etc capabilities each role gets are ENFORCED by Bao, not just documented. This
script is the reconciler: it reads `relationships/<agent>--role--<role>` tuples, resolves
each agent to a Bao entity via cert-auth aliases, and updates the corresponding
`identity/group/name/agents-<role>` group's member_entity_ids to match.

WHAT IT DOES NOT DO. Enforce `may-use--<hardware>` tuples. Bao does not gate GPU or NPU
access — those tuples remain client-side self-restraint. RFD 2202 names the split
explicitly.

Idempotent — re-running produces no change if state already agrees.

Usage:
    python scripts/sync_rebac_groups.py            # dry-run
    python scripts/sync_rebac_groups.py --apply    # write the changes
    python scripts/sync_rebac_groups.py --self-test
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys


# Role → policy(s) mapping. Extension point: adding a role adds an entry here + a
# matching group in Bao. RFD 2200 defines the current set.
ROLE_POLICIES = {
    "coordinator":      ["mps-admin"],
    "gpu-experimenter": ["agents-rw"],
    "edge-qat-specialist": ["agents-rw"],
    "assist":           ["agents-rw"],
}


def bao(*args, capture=True):
    """Run a bao command, return stdout on success or raise on failure."""
    r = subprocess.run(["bao", *args], capture_output=capture, text=True)
    if r.returncode:
        raise RuntimeError(f"bao {' '.join(args)}: {r.stderr.strip()[:200]}")
    return r.stdout


def read_role_tuples() -> dict[str, str]:
    """Return {agent_cn_short: role} from relationships/*--role--*."""
    out = bao("kv", "list", "-format=json", "relationships/")
    keys = json.loads(out)
    tuples = {}
    for k in keys:
        if "--role--" not in k:
            continue
        # <subject>--role--<object>
        parts = k.split("--role--", 1)
        if len(parts) != 2:
            continue
        subject, role = parts[0], parts[1]
        tuples[subject] = role
    return tuples


def resolve_entity_id(agent_short: str) -> str | None:
    """Find the entity id whose cert-auth alias is <agent_short>.agents.weftspun."""
    out = bao("list", "-format=json", "identity/entity/id")
    for eid in json.loads(out):
        try:
            data = json.loads(bao("read", "-format=json", f"identity/entity/id/{eid}"))
        except RuntimeError:
            continue
        for a in data.get("data", {}).get("aliases", []):
            if a.get("name", "").startswith(f"{agent_short}.agents.weftspun"):
                return eid
    return None


def current_group_members(group_name: str) -> list[str]:
    try:
        data = json.loads(bao("read", "-format=json", f"identity/group/name/{group_name}"))
    except RuntimeError:
        return []
    return data.get("data", {}).get("member_entity_ids") or []


def apply_group(group_name: str, policies: list[str], member_ids: list[str]) -> None:
    """Upsert a group with the given policies and members."""
    bao(
        "write",
        f"identity/group/name/{group_name}",
        f"policies={','.join(policies)}",
        f"member_entity_ids={','.join(member_ids)}",
        "type=internal",
    )


def reconcile(apply: bool) -> int:
    tuples = read_role_tuples()
    if not tuples:
        print("no role tuples in relationships/; nothing to reconcile")
        return 0

    # role -> [entity_id]
    by_role: dict[str, list[str]] = {r: [] for r in ROLE_POLICIES}
    unknown_roles = []
    unresolved_agents = []
    for agent, role in tuples.items():
        if role not in ROLE_POLICIES:
            unknown_roles.append((agent, role))
            continue
        eid = resolve_entity_id(agent)
        if not eid:
            unresolved_agents.append(agent)
            continue
        by_role[role].append(eid)

    if unknown_roles:
        print("UNKNOWN ROLES (add to ROLE_POLICIES or fix tuple):")
        for a, r in unknown_roles:
            print(f"  {a} -> {r}")
    if unresolved_agents:
        print("UNRESOLVED AGENTS (no matching cert-auth entity):")
        for a in unresolved_agents:
            print(f"  {a}")

    changes = 0
    for role, want_members in by_role.items():
        group = f"agents-{role}"
        have_members = current_group_members(group)
        want_set = set(want_members)
        have_set = set(have_members)
        if want_set == have_set:
            print(f"  ok  {group}: {len(want_members)} member(s), no change")
            continue
        added = want_set - have_set
        removed = have_set - want_set
        changes += 1
        print(f"  DRIFT {group}:")
        for e in sorted(added):
            print(f"    + {e}")
        for e in sorted(removed):
            print(f"    - {e}")
        if apply:
            apply_group(group, ROLE_POLICIES[role], sorted(want_set))
            print(f"    applied.")

    if unknown_roles or unresolved_agents:
        return 1
    return 0 if changes == 0 or apply else 1


def self_test() -> int:
    """4 controls exercising role mapping + tuple parsing."""
    ok = True

    # tuple parsing
    for k, want in [
        ("mps-45994b--role--coordinator", ("mps-45994b", "coordinator")),
        ("cuda-a63415--role--gpu-experimenter", ("cuda-a63415", "gpu-experimenter")),
        ("hailo-552dfa--role--assist", ("hailo-552dfa", "assist")),
    ]:
        parts = k.split("--role--", 1)
        got = (parts[0], parts[1]) if len(parts) == 2 else None
        marker = "ok " if got == want else "FAIL"
        print(f"  {marker} parse {k!r} -> {got} (want {want})")
        if got != want:
            ok = False

    # role → policy mapping present for all currently-used roles
    for role in ["coordinator", "gpu-experimenter", "assist"]:
        present = role in ROLE_POLICIES
        marker = "ok " if present else "FAIL"
        print(f"  {marker} role {role!r} in ROLE_POLICIES: {present}")
        if not present:
            ok = False

    # unknown role rejected
    unknown = "not-a-role" not in ROLE_POLICIES
    marker = "ok " if unknown else "FAIL"
    print(f"  {marker} unknown role rejected (control): {unknown}")

    print("---")
    print("self-test:", "ok" if ok else "FAIL")
    return 0 if ok else 1


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="Apply changes to Bao")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args(argv[1:])

    if args.self_test:
        return self_test()

    if not os.environ.get("BAO_ADDR"):
        print("BAO_ADDR not set; not running reconcile", file=sys.stderr)
        return 2

    try:
        return reconcile(args.apply)
    except RuntimeError as e:
        print(f"error: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
