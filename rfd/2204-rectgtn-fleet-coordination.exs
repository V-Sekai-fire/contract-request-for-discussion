# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2204. `mix rfd.render` renders rfd/2204-rectgtn-fleet-coordination/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2204 do
  use RFD.DSL

  rfd 2204, "RECTGTN fleet coordination" do
    compact_head true

    state :discussion

    feature "peers pick their next work item by running the same RECTGTN
query against one shared fleet domain, rather than by reading prose
relayed from the coordinator"

    scope "every session that participates in the coordinate-agents
ceremony (RFD 2201); the Taskweft engine already in tree; a new
fleet-domain document"

    decision ~S"""
    Feed the Taskweft engine a **fleet domain**, a single JSON-LD
    document conforming to
    `3-interactor/taskweft/priv/schemas/rectgtn_domain.schema.json`, that
    names the live peers as entities, their owned resources as capability
    edges, the verbs peers execute as actions, and known decompositions as
    methods. Every peer answers "what should I do next?" with the same
    (continues in `DETAILS.md`)

    `DETAILS.md` carries the full text of this RFD.
    """

    problem ~S"""
    Peer sessions coordinate through three ad-hoc channels: Bao rows, free-
    form `SendMessage` prose, and operator-typed un-park signals. There
    is no shared representation of *why* a peer is doing what it is doing,
    so a peer that reranks does it by hand, a peer that finishes an item
    (continues in `DETAILS.md`)
    """

    related ~S"""
    - RFD 2200 (ReBAC agent roles), supplies the relation vocabulary the
      fleet domain reuses.
    - RFD 2201 (coordinate-agents ceremony), step 3 gets the one-line
    (continues in `DETAILS.md`)
    """

    details_title "RECTGTN fleet coordination"

    details "Fleet-domain shape", ~S"""
    Checked in at `2-contract/manuals-weftspun/rectgtn/fleet.jsonld`,
    conforming to
    `3-interactor/taskweft/priv/schemas/rectgtn_domain.schema.json`. The
    document is one full RECTGTN domain (`actions`, `methods`,
    `capabilities`, `variables`, `todo_list`, same shape as
    `priv/plans/problems/work_queue.jsonld` in the Taskweft repo).

    ### Entities

    One per live peer CN, `hero.<mps-suffix>.agents.weftspun`,
    `anchor.<mps-suffix>.agents.weftspun`, and so on. The CN is the full
    form under `agents/<cn>.agents.weftspun` per RFD 2195. Session-local
    aliases (HERO / ANCHOR / SIDEKICK / HERD) are not entities in the
    domain, the CN is the address.

    ### Capability edges

    Populated by `sync_fleet_domain.py`, which reads `agents/*` Bao rows
    and writes edges of these shapes under `capabilities.graph.edges`:

        {"subject":"hero.<cn>","rel":"runs-on","object":"windows-desktop"}
        {"subject":"hero.<cn>","rel":"owns","object":"gpu-3090"}
        {"subject":"hero.<cn>","rel":"may-use--gpu","object":"gpu-3090"}
        {"subject":"hero.<cn>","rel":"may-use--hf-repo","object":"chibifire/*"}
        {"subject":"hero.<cn>","rel":"may-use--uplink","object":"windows-desktop"}

    Contention is expressed by `may-use--gpu`, a peer without an edge
    cannot bind an action that guards on it. Un-park is a caveat on the
    edge, not a message.

    ### Actions

    Fleet verbs peers actually execute, each with an ISO-8601 `duration`
    and a `rebac/check` guard:

        open-pr, run-ci, extract-safetensors, train-qat,
        render-shard, publish-hf-dataset, merge-pr

    Example (in Elixir DSL form; the JSON-LD form is the compiled output):

        train_qat: %{
          params: [:actor, :model_id, :precision],
          check: [
            %{eval: %{type: "rebac/check",
                      subject: "{actor}", rel: "may-use--gpu", object: "{model_id}_gpu"}}
          ],
          body: [
            %{pointer_set: "/agents/{actor}/claims/gpu", value: "{model_id}_gpu"},
            %{pointer_set: "/goal/{model_id}/status", value: "qat_running"}
          ],
          duration: "PT4H"
        }

    ### Methods

    Known decompositions. First landing methods:

        ship-a-Q4-quant:
          alternatives:
           , name: extract_then_train
              subtasks:
               , [extract-safetensors, {actor}, {model_id}]
               , [train-qat, {actor}, {model_id}, "int4"]
               , [validate, {actor}, {model_id}]
               , [publish-hf-dataset, {actor}, {model_id}]
           , name: use_aero_ex_configs
              subtasks:
               , [update-config-pins, {actor}, {model_id}]
               , [extract-safetensors, {actor}, {model_id}]
               , [train-qat, {actor}, {model_id}, "int4"]
               , [validate, {actor}, {model_id}]
               , [publish-hf-dataset, {actor}, {model_id}]

        land-a-clean-pr:
          alternatives:
           , name: open_then_merge
              subtasks:
               , [open-pr, {actor}, {repo}, {branch}]
               , [run-ci, {actor}, {repo}, {branch}]
               , [merge-pr, {actor}, {repo}, {branch}]

    Alternatives are ordered: the planner tries the first, falls to the
    second when a `TwMethodSkip` write on the fleet's skip rows says the
    first is blocked. That is the same `nearest_retryable_ancestor`
    backjump `tw_soltree.hpp` already implements.

    ### Variables

    State pointers the actions read and write:

        /agents/<cn>/claims/<resource> -> <resource_id> | null
        /goal/<id>/status              -> pending | extracted | qat_running |
                                           validated | published | failed
        /skip/<task_key>#<method_idx>  -> true | absent

    `<task_key>` is the C++ planner's `tw_call_key`, action-or-method name
    plus stringified args, so a skip row keys on the specific instance,
    not the verb.

    ### Todo list

    Today's operator-set goals as `TwGoal` bindings. Example:

        "todo_list": [
          {"goal": [{"pointer": "/goal/motionbricks/status", "eq": "published"}]}
        ]

    Standing `TwMultiGoal` entries cover steady-state work (open PRs must
    reach `merged` before quarter close, and so on).
    """

    details "Coordinator adapter", ~S"""
    New module `3-interactor/taskweft/lib/taskweft/coordinator.ex`, ~150
    lines. Public API:

    - `snapshot/0`, read `agents/*` Bao rows and the RFD board's current
      goal statuses, materialise `fleet.jsonld` in memory.
    - `pick/1`, `Taskweft.plan(snapshot, actor: cn)`, return the first
      `TwCall` whose bindings resolve `actor` to `cn`. Returns `nil` when
      no task in the plan is assignable to that peer.
    - `publish/2`, write the returned Task as an ordinary row at
      `agents/<cn>/assignment` with a `SqlarCas.Caveat` carrying
      `{"type":"expires_at","at": start + duration}`.
    - `fail/2`, write a truthy row at `/skip/<task_key>#<method_idx>` so
      the next `Taskweft.replan` treats it as `TwMethodSkip` and
      backjumps.

    Reuses `Taskweft.JSONLD.Loader.validate/2` and `Taskweft.MCP.Server`
    without modification. The caveat primitive is imported verbatim from
    `7-service/service-sqlar-cas/lib/sqlar_cas/caveat.ex`, no fork.
    """

    details "Tiebreak order", ~S"""
    Encoded in the domain's `methods.alternatives` list order, the
    planner picks the first alternative that satisfies its guards and
    has no matching `/skip/` row. Operator priority (e.g. `land-clean-pr`
    before `render-shard`) is a domain edit, not a coordinator argument.
    The domain is checked into git; the tiebreak is diffable.
    """

    details "Pilot before rollout", ~S"""
    One end-to-end trace on the seeded fleet before flipping the
    ceremony:

    1. Encode "ship MotionBricks Q4" as a `TwGoal` with HERO's
       `may-use--gpu` edge present.
    2. `Coordinator.pick(hero_cn)`, assert `extract-safetensors`, not
       `train-qat`. The extractor is the unmet predecessor.
    3. Manually mark extraction done; re-`pick`, assert `train-qat`.
    4. Encode HERO's real config-hash blocker as a
       `/skip/train-qat#0` write; assert the backjump picks the
       `use_aero_ex_configs` alternative rather than looping on the
       original method.

    If any step fails, the fleet domain is wrong and the RFD moves back to
    `discussion`. If all pass, the RFD moves to `published` and the
    ceremony's step 3 flips in one commit.
    """

    details "Compute-lease broker", ~S"""
    RFD 2202 named "compute-lease broker" as future work. This RFD is
    that broker in miniature: a peer's `may-use--gpu` edge is a lease,
    and the assignment row's `expires_at` caveat is its TTL. When the
    caveat expires, `Coordinator.pick` no longer sees the row and the
    next `plan` reassigns the GPU. No new Sentinel, no new engine, the
    caveat primitive plus the planner's own capability check are enough.
    """

    details "Migration", ~S"""
    - **RFD 2201 step 3**: swap the free-form message for
      `Coordinator.snapshot |> pick |> publish`. The `SendMessage` still
      fires (operator-visible), but its body is generated from the
      assignment row rather than composed by hand.
    - **Un-park signals**: an un-park is a write to `agents/<cn>/claims/*`
      clearing a stale claim, plus (optionally) a `TwGoal` added to the
      todo_list. The operator's terminal-typed direct signal remains the
      ground-truth authoriser.
    - **Persona reflex**: `SqlarCas.Persona.reflex/2`'s docstring
      promises "multi-step decomposition is a follow-up in `Taskweft.SQL`."
      This RFD replaces that promise: the persona uses `Taskweft.plan`
      over a per-persona sub-domain, and `Taskweft.SQL` is not built.
    """

    details "Verification", ~S"""
    - **Determinism**: two peers, same snapshot revision → disjoint tasks
      whose union is a prefix of `Taskweft.plan(snapshot)`. Test:
      `3-interactor/taskweft/test/coordinator_determinism_test.exs`.
    - **Capability reactivity**: one-line edge change moves the winning
      task to another peer on the next `pick`. Test asserts the diff.
    - **TTL correctness**: an assignment past `expires_at` is not
      returned; the oracle is `SqlarCas.Caveat.satisfied?/2` (already
      unit-tested).
    - **Backjumping**: a skip-row write produces an alternative method,
      not the same method again. Reuses the sol-tree tests already in
      Taskweft's suite; adds one integration test at the fleet layer.
    - **Negative control**: a planted broken domain (missing capability
      edge) → `pick` returns `nil` for every peer, and the coordinator
      surfaces "no assignable Task" rather than silently returning the
      first `TwCall`. Rule 2 of CLAUDE.md's verification list.
    - **Browser reviewability**: the WASM SQLite demo in
      `7-service/service-sqlar-cas/docs/` gets the fleet-domain tables
      in its fixture and renders the plan sol-tree client-side, so a
      reader can inspect the planner's output without an Elixir toolchain.
    """

    details "From the README, moved here on 2026-09-07", ~S"""
    **Coordinator adapter as an Elixir module:** retracted 2026-09-05,
    see [RFD 2205](../2205-taskweft-in-bao/README.md), superseded by
    an in-Bao database-plugin (Go binary, cgo-linked C++ planner) that
    callers reach via `bao read taskweft/creds/<goal_id>`. This RFD's
    "fleet-domain document" scope stays live; the "adapter" scope
    moves to 2205.
    """

    details "Decision", ~S"""
    Feed the Taskweft engine a **fleet domain**, a single JSON-LD
    document conforming to
    `3-interactor/taskweft/priv/schemas/rectgtn_domain.schema.json`, that
    names the live peers as entities, their owned resources as capability
    edges, the verbs peers execute as actions, and known decompositions as
    methods. Every peer answers "what should I do next?" with the same
    call: `Taskweft.plan(fleet, actor: self_cn)`. Contention becomes
    capability tuples; ordering becomes ISO-8601 durations; peer authority
    becomes the ReBAC relations Taskweft already speaks
    (`HAS_CAPABILITY`, `OWNS`, `IS_MEMBER_OF`, `DELEGATED_TO`,
    `SUPERVISOR_OF`, `PARTNER_OF`, `CAN_ENTER`, `CAN_INSTANCE`). No new
    planner, no new SQL layer, no port of RECTGTN into Bao; the engine is
    the ground-truth solver and the fleet is a domain that feeds it.

    The seven-step coordinate-agents ceremony (RFD 2201) stays. One line
    of step 3 ("notify peers") becomes `Coordinator.snapshot |>
    Coordinator.pick(self) |> Coordinator.publish(self)`. Determinism
    against the shared snapshot removes the need to relay next-item picks
    in prose. Assignment rows carry a `SqlarCas.Caveat` with
    `{"type":"expires_at","at":start+duration}`, the compute-lease broker
    RFD 2202 named as future work, filled by reusing the caveat primitive
    that already exists in service-sqlar-cas.
    """

    details "Problem", ~S"""
    Peer sessions coordinate through three ad-hoc channels: Bao rows, free-
    form `SendMessage` prose, and operator-typed un-park signals. There
    is no shared representation of *why* a peer is doing what it is doing,
    so a peer that reranks does it by hand, a peer that finishes an item
    picks the next one from a board it interprets alone, and the operator
    carries the priority ordering in their head each turn. The
    `may-use--<device>` tuples RFD 2202 introduced are documentation only —
    nothing gates work on them. When two peers want the same GPU or the
    same HF repo, prose adjudicates.
    """

    details "Non-goals", ~S"""
    Not a scheduler; not a hook; not a replacement for the operator's
    right to reprioritise mid-turn. The fleet domain is a snapshot the
    operator edits like any other document, the planner is deterministic
    against whatever the snapshot says. Not a claim that RECTGTN scales to
    100+ peers today; the pilot is single-Goal, single-decomposition, and
    the engine's search bounds already surface a "no assignable Task"
    answer rather than looping.
    """

    details "Related", ~S"""
    - RFD 2200 (ReBAC agent roles), supplies the relation vocabulary the
      fleet domain reuses.
    - RFD 2201 (coordinate-agents ceremony), step 3 gets the one-line
      hook; the other six steps are unchanged.
    - RFD 2202 (ReBAC Bao enforcement), this RFD fills the compute-lease
      broker gap RFD 2202 named as future work.
    - RFD 2195 (weftspun-bao), the Bao row shape the coordinator reads
      from and writes back to.
    - Taskweft engine RFDs 0005 (unify capabilities with ReBAC) and 0008
      (MCP public API), the surfaces the fleet uses without modification.
    """

    drafted_by :ai
  end
end
