# Logbook: five-turn plan-mode redirect on coordinator design

Session of 2026-09-05. The plan-mode file at
`~/.claude/plans/quirky-dazzling-ripple.md` opened with one
approach for the peer-coordination surface and walked through
four redirects before landing on the shape RFD 2205 codified.
Recorded here because the retractions are institutional memory
CLAUDE.md's "retractions stay next to what they retract" rule
tells us to preserve.

## The five turns

| turn | shape proposed | what killed it |
|---|---|---|
| 1 | `coordinator.ex` Elixir adapter, standalone, reads Bao and calls `Taskweft.plan` out-of-process | no answer for global time across peer clocks; no ReBAC enforcement path |
| 2 | in-Bao Taskweft engine (Bao plugin fronting Taskweft) | operator picked the type — database plugin, not secrets — for the native lease lifecycle |
| 3 | thin HTTPS bridge to `taskweft-mcp.fly.dev` | operator: "low dependency and only requires REST commands and can be lifted to work in a github cdn with range queries and sqlite" |
| 4 | cgo-linked C++ embedded in the plugin | shipped as RFD 2205 |
| 5 | (same) — database plugin type declaration confirmed | shipped |

## What survived

- The Taskweft engine's `standalone/*.hpp` C++ — untouched.
- The 23-function NIF surface as the shim's interface contract.
- `fleet.jsonld` (already shipped) as the domain document.
- `sync_fleet_domain.py` (already shipped) as the edge
  reconciler.
- The verb triple `pick / skip / assign` from the retired
  Elixir adapter, now as plugin path names.

## What got retracted (with pointers)

- **`coordinator.ex` Elixir adapter as primary:** retracted
  2026-09-05, see RFD 2205. Pointer left on RFD 2204's README.
- **thin HTTPS bridge to `taskweft-mcp.fly.dev`:** retracted
  2026-09-05, superseded by cgo-linked C++ in RFD 2205.
- **`router.ex` mTLS auth extension:** retracted with the
  bridge — nothing calls MCP any more.
- **`SqlarCas.Caveat` wrapping on assignment rows:** retracted
  2026-09-05, superseded by Bao's own `logical.Response.Secret`
  lease TTL. The caveat primitive stays scoped to sqlar-cas.
- **`Taskweft.SQL` module:** retracted before it existed — the
  `service-sqlar-cas` persona reflex docstring named it as a
  follow-up; the planner is already the ground-truth solver, so no new module is needed.

Every retraction leaves a one-line pointer at its former section,
per CLAUDE.md's "How Retracted RFD Topics Are Deleted" doctrine.
The bodies moved to logbook + RFD 2205's Retractions section
rather than staying in place — RFDs record decisions, and a
retracted decision that keeps sitting in the RFD reads as current
to a fresh reader.

## Why record the walk rather than just the destination

Rule from CLAUDE.md's "How the Logbook Is Written": *"a reader
who knows which roads are dead ends is better off than one who
only knows the current answer."* The Elixir-adapter shape is
the obvious first sketch for anyone approaching this again; a
future session that re-derives it and does not know the two
structural reasons it fails (global time, ReBAC enforcement)
walks the same road again.

## Related

- RFD 2204 (RECTGTN fleet coordination) — the fleet-domain
  scope that survived.
- RFD 2205 (Taskweft in Bao) — the plugin scope that landed.
- RFD 2202 (ReBAC Bao enforcement) — the gap this design closed.
