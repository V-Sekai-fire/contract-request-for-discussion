# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2205. `mix rfd.render` renders rfd/2205-taskweft-in-bao/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2205 do
  use RFD.DSL

  rfd 2205, "Taskweft in Bao: database plugin, cgo-linked" do
    compact_head true

    state :discussion

    feature "the RECTGTN planner lives inside weftspun-bao as a
database-plugin-type Bao plugin (Go binary, cgo-linked C++ from
`taskweft_nif/standalone/`); the same C++ compiles via emcc to a
`taskweft.wasm` blob callable from the browser"

    scope "the plugin binary itself; the weftspun-bao deploy that
loads it; the git-tracked fleet.jsonld → fleet.sqlite mirror pipeline;
the browser-side WASM parity target"

    decision ~S"""
    Ship one C++ planner (`taskweft_nif/standalone/*.hpp`, unchanged),
    one thin `extern "C"` shim mirroring its 23-function NIF surface,
    and two hosts that call the shim:

    `DETAILS.md` carries the full text of this RFD.
    """

    problem ~S"""
    RFD 2204 named the fleet-coordination shape; the plan-mode session
    of 2026-09-05 iterated three approaches before landing here. Two
    earlier shapes are retracted, deliberately, retraction pointers
    below.
    """

    related ~S"""
    - RFD 2204 (RECTGTN fleet coordination), the domain document
      shape the plugin queries. This RFD supersedes its "coordinator
      adapter" section with a one-line pointer, per CLAUDE.md doctrine.
    - RFD 2140 (OpenBao on FoundationDB), the storage backend the
      plugin's SQLite fixture sits on top of.
    - RFD 2142 (Bao PKI zerotrust), the cert-auth path peers use.
    (continues in `DETAILS.md`)
    """

    details_title "Taskweft in Bao: database plugin, cgo-linked"

    details "Plugin binary: `bao-plugin-taskweft`", ~S"""
    New Go project at `7-service/service-taskweft-bao/`. Layout mirrors
    the shipped `7-service/service-bao-sqlite-fdb/` reference plugin:

        service-taskweft-bao/
          main.go               # plugin.ServeMultiplex entrypoint
          backend/
            backend.go          # Factory → framework.Backend
            paths.go            # taskweft/{config,roles,creds,skip}/…
            rebac_check.go      # Bao capability lookup via req identity
          planner/
            shim.h              # extern "C", one entry per FINE_NIF
            shim.cpp            # includes standalone/*.hpp, drops fine glue
            planner.go          # cgo bindings, ~600 LOC
          Makefile              # builds libtaskweft.a from standalone/
          README.md

    Sizing from the standalone-header audit (2026-09-05): **~400 LOC
    shim C++ + ~600 LOC Go bindings + build glue**, ~3–5 days to a
    green pilot. Adds `clang` to the Bao container build (already
    present for FDB's C client) and a static `libtaskweft.a` linked
    into the plugin binary.
    """

    details "Plugin type declaration", ~S"""
    Registered as a **database** plugin (`bao plugin register database
    taskweft`), not a secrets engine. The database type gives us Bao's
    native lease lifecycle, Initialize / New / Update / Delete
    callbacks with no bookkeeping of our own. Mapping RECTGTN onto the
    database-plugin vocabulary:

    | Bao database | RECTGTN |
    |---|---|
    | Database | Fleet domain (one per mount) |
    | Role | Goal id (`motionbricks`, `escort-refugee-ship`) |
    | Credentials read | Pick a Task for the caller |
    | New user response | `{"task":[<action>, <actor>, …]}` + lease |
    | Delete-on-revoke | Undo assignment state (release GPU claim, …) |
    | Update | Renew a running task's lease (heartbeat) |

    If the database-plugin interface's `NewUserResponse{Username string}`
    field proves too narrow for the task-JSON payload, the fallback is
    a **secrets engine plugin with `framework.Secret`**, same lease
    semantics, JSON-shaped responses natively supported. Either way
    the planner code path is identical; only the SDK-facing shims
    differ. The pilot will tell us which fits.
    """

    details "Paths", ~S"""
    Four Bao-native paths, database-plugin convention:

        taskweft/config/<name>      # Configure, points at fleet.sqlite
        taskweft/roles/<goal_id>    # Role, declare an issuable Goal
        taskweft/creds/<goal_id>    # NewUser, the pick call
        taskweft/skip/<task_key>    # UpdateUser / sibling, skip-write

    ### `taskweft/creds/<goal_id>` (the pick)

    1. Read the fleet domain SQLite database via the sibling sqlite-fdb
       secrets engine at `secret/taskweft/db/fleet`.
    2. Select current skip-state rows from the `skip` table.
    3. Marshal both to JSON; call `tw_plan(domain_json, skip_json)` on
       the cgo-linked planner.
    4. Filter the returned steps by `actor == <caller cn>`.
    5. Return the first match as a `NewUserResponse` (or
       `logical.Response{Secret: ...}` in the fallback shape) with
       `lease_duration = duration_of(action)`.

    Bao stamps the response `lease_id` on the server clock; every peer's
    `expires_at` derives from one wall-clock reading, operator's
    global-time argument, satisfied by construction.

    ### `taskweft/skip/<task_key>`

    Inserts `(task_key, method_idx, cn, at)` into the skip table. The
    next `creds` read substitutes it into the domain's `todo_list`
    before planning, so the planner backjumps to
    `nearest_retryable_ancestor` (see `tw_soltree.hpp`) without a
    planner-side extension.

    ### Lease Revoke (`DeleteUser`)

    Undoes any state the pick wrote, releases GPU claims, decrements
    progress-track marks, clears `/gpu_claim/gpu-3090`. A peer that
    crashes without renewing its lease has its assignment reclaimed by
    Bao automatically. No bespoke reaper.
    """

    details "ReBAC gating", ~S"""
    The plugin runs `may-use--<device>` checks BEFORE calling the
    planner, using Bao's own `system.Client.Sys().Capabilities` against
    the request's authenticated identity. A caller whose group lacks
    the capability gets `403` from Bao and the cgo hop never runs.
    "Documentary → enforced" in one plugin, the compute-lease broker
    RFD 2202 named as future work.
    """

    details "Storage: SQLite, not KV", ~S"""
    The git-tracked file
    `2-contract/manuals-weftspun/rectgtn/fleet.jsonld` remains the
    human-editable source of truth for the domain document. A small
    builder script `scripts/build_fleet_sqlite.py` compiles it into
    `2-contract/manuals-weftspun/rectgtn/fleet.sqlite` (also checked
    into git, a small binary fixture, same pattern as
    `service-sqlar-cas/docs/fixtures/persona.sqlite`).

    CI on manuals-weftspun runs `bao kv put secret/taskweft/db/fleet
    @rectgtn/fleet.sqlite` on any commit that changes the sqlite blob.
    The diffable JSON-LD is what humans review. `sync_fleet_domain.py`
    (already shipped) still reconciles capability edges from Bao's own
    `relationships/*--<verb>--*` tuples into the JSON-LD before the
    sqlite mirror step.

    Schema, three tables, ETNF-shaped for local SQLite work (per
    CLAUDE.md's carve-out: HF datasets denormalize, local SQLite stays
    ETNF):

        CREATE TABLE domain (
          id INTEGER PRIMARY KEY,
          jsonld BLOB NOT NULL
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
    """

    details "WASM parity target", ~S"""
    The same `standalone/*.hpp` compiles via emcc to WebAssembly with
    zero source changes. Parallel build at
    `3-interactor/taskweft/wasm/`:

        build.sh              # emcc invocation
        taskweft-shim.cpp     # same shim as the cgo plugin
        → taskweft.wasm       # output
        → taskweft.js         # small JS loader

    The browser demo already shipping in
    `7-service/service-sqlar-cas/docs/` (`sql-wasm.js` + Range-fetch
    `persona.sqlite`) loads `taskweft.wasm` alongside and calls
    `plan(domainJson, skipJson)` on it. See RFD 2204's Starforged demo
    section for the game-loop shape.

    Parity is a hard verification target, same domain + same skip
    state → byte-for-byte identical plan JSON in both hosts. Recorded
    as a fixture under `test/parity/` that both harnesses read.
    """

    details "Deploy gap: three edits, none built today", ~S"""
    1. `7-service/service-openbao/Dockerfile.fdb`, `COPY
       bao-plugin-taskweft /bao/plugins/`.
    2. `7-service/service-openbao/config-fdb.hcl`, add
       `plugin_directory = "/bao/plugins"`.
    3. `7-service/service-openbao/entrypoint-fdb.sh`, one-shot init:

            CHECKSUM=$(sha256sum /bao/plugins/bao-plugin-taskweft | cut -d' ' -f1)
            bao plugin register -sha256=$CHECKSUM database taskweft
            bao secrets enable -path=taskweft taskweft

    Same shape `service-bao-sqlite-fdb`'s README documents. The
    existing weftspun-bao deploy loads zero plugins today (both HCLs
    have no `plugin_directory`, entrypoint has no `bao plugin
    register` step); this RFD closes that gap.
    """

    details "Pilot: three phases", ~S"""
    **Phase 1, local Bao plugin**. Build the plugin binary (cgo-linked,
    static `libtaskweft.a`); register against a `bao dev` server; mount
    as `taskweft/`; fleet.sqlite loaded from disk via the sibling
    sqlite-fdb secrets engine. Assert:

    1. `bao read taskweft/creds/motionbricks` (auth: HERO's cert)
       returns `{"task":["extract-safetensors","hero.<cn>","motionbricks"],
       "lease_id":..., "lease_duration": 2700}` (PT45M).
    2. `bao write taskweft/skip/train-qat method_idx=0`; then
       `bao read taskweft/creds/motionbricks` returns
       `["update-config-pins", ...]` from `use_aero_ex_configs`, the
       backjump.
    3. Two `bao read` calls one second apart, one from HERO one from
       ANCHOR, both against a Goal both are eligible for, see
       `lease_id`s stamped by the same server clock and disjoint task
       assignments (planner determinism).
    4. Lease expiry: `bao lease revoke <lease_id>` triggers
       `DeleteUser`; assert the SQLite `assign` row is gone and any
       state var the pick wrote is undone.

    **Phase 2, WASM parity**. Emcc-build `taskweft.wasm` from the same
    standalone headers. Extend the browser demo to fetch fleet.sqlite
    via `Range: bytes=0-` and call `taskweft.wasm`'s
    `plan(domainJson, skipJson)`. Assert byte-identical output vs
    phase-1 step 1 for the same input. Playwright at
    `scratchpad/pages_check.mjs` verifies.

    **Phase 3, production deploy**. Land the three deploy-gap edits;
    push weftspun-bao; smoke-test phase-1 assertions against the
    deployed instance with real peer certs.
    """

    details "Verification", ~S"""
    - **Global-time correctness**: two peers, same read, `lease_id`
      stamped by one wall-clock. Recorded in a measurement section
      appended to this RFD after phase 1 lands.
    - **ReBAC enforcement**: a peer without `may-use--gpu` on
      `gpu-3090` gets `403` from `bao read taskweft/creds/motionbricks`
      and the planner never runs. Test asserts the cgo hop never
      executed (log absence).
    - **Backjumping**: a `skip` write moves the winning task to the
      next method's first action; a second skip (same task, `method_idx
      + 1`) moves it further. Reuses `tw_soltree.hpp`'s
      `nearest_retryable_ancestor` verbatim.
    - **Cgo boundary safety**: valgrind / asan on the plugin binary
      linked against `libtaskweft.a`; assert no leaks across 1000 plan
      calls. Negative control (rule 2): intentionally-malformed domain
      JSON produces a Bao error, not a segfault.
    - **WASM / plugin parity**: same domain + same skip state → same
      plan JSON in both hosts, byte-for-byte. Recorded as a fixture
      under `test/parity/` that both harnesses read.
    - **Blast-radius awareness** (RFD 2147): a plugin crash restarts
      the subprocess without taking Bao down (Bao's plugin process
      model); a planner-domain load failure returns `500` from `creds`
      reads, and the peer falls back to the pre-plugin ad-hoc
      coordination. Documented here as "graceful degrade".
    - **Browser-reviewable**: reviewers open GitHub Pages, load
      `fleet.sqlite`, and see the planner's sol-tree rendered
      client-side. No Bao, no toolchain.
    - **Negative control** (rule 2): a planted broken domain (missing
      capability edge) returns "no assignable Task" for every peer with
      a specific error code, rather than silently returning the first
      step of a stale plan.
    """

    details "Future work", ~S"""
    - **Pure-Go port of the planner**, sized at ~7000 LOC / 8–12
      weeks in the standalone-header audit. The plugin's Go API stays
      stable across the swap; callers see no change. Trigger: when the
      plugin's cgo hop shows up as a hot path in tracing, or when the
      Bao container's clang dependency becomes a supply-chain concern.
    - **Starforged domain** (RFD 2204 test-vector corpus), a second
      domain loaded into the same plugin, exercising deeper method
      alternatives and stochastic move outcomes. Drives the VRM demo's
      decision-point control surface.
    """

    details "From the README, moved here on 2026-09-07", ""

    details "Decision", ~S"""
    Ship one C++ planner (`taskweft_nif/standalone/*.hpp`, unchanged),
    one thin `extern "C"` shim mirroring its 23-function NIF surface,
    and two hosts that call the shim:

    1. **Bao plugin**, Go binary at `7-service/service-taskweft-bao/`,
       registered against weftspun-bao as `bao plugin register database
       taskweft`. Every peer resolves "what is my next task?" as
       `bao read taskweft/creds/<goal_id>`. Bao stamps the response
       `lease_id` on the server clock, every peer sees the same
       `expires_at`, so global time for durations is satisfied by
       construction. `may-use--<device>` ReBAC tuples become ENFORCED
       at read-time via Bao's own capability check (fills the compute-
       lease broker gap RFD 2202 named as future work).
    2. **CDN + WASM**, emcc-built `taskweft.wasm` loaded from GitHub
       Pages, reading a static `fleet.sqlite` via HTTP `Range: bytes=0-`
       the same way `service-sqlar-cas/docs/`'s persona demo already
       loads `persona.sqlite`. No server, no toolchain, reviewers see
       the planner's output client-side against the same fixture the
       Bao plugin runs.

    The same `.sqlite` fixture ships under `docs/fixtures/` on GitHub
    Pages and is the file the Bao plugin reads from
    `secret/taskweft/db/fleet` after CI's mirror step. **One file, two
    hosts, one planner.**
    """

    details "Problem", ~S"""
    RFD 2204 named the fleet-coordination shape; the plan-mode session
    of 2026-09-05 iterated three approaches before landing here. Two
    earlier shapes are retracted, deliberately, retraction pointers
    below.

    Peer sessions today coordinate through Bao rows + free-form
    `SendMessage` + operator-typed un-park signals. There is no shared
    representation of *why* a peer is doing what it is doing, no
    programmatic assignment surface, no compute-lease enforcement, and
    no clock the whole fleet can agree on for lease `expires_at`. This
    RFD is the answer.
    """

    details "Retractions", ~S"""
    - **coordinator.ex Elixir adapter as primary:** retracted
      2026-09-05, superseded by the Go plugin in this RFD. The Elixir
      standalone adapter had no answer for global time or ReBAC
      enforcement.
    - **thin-HTTPS bridge to taskweft-mcp.fly.dev:** retracted
      2026-09-05, superseded by cgo-linked C++. The bridge shape added
      an external service dependency the plugin doesn't need; embedding
      the planner satisfies operator's constraint that the plugin
      requires only REST commands and no other service.
    - **`router.ex` mTLS auth extension:** retracted with the bridge —
      nothing calls MCP any more.
    """

    details "Non-goals", ~S"""
    Not a pure-Go port of the planner (RFD 2006 sized it at ~7000 LOC
    and 8–12 weeks; cgo is 3–5 days). Not a rewrite of the RECTGTN
    schema. Not a scheduler; not a hook. The plugin does not extend
    Bao's storage surface, plan and skip state live in a SQLite blob
    served by the sibling sqlite-fdb secrets engine, not in KV rows
    under a separate mount.
    """

    details "Related", ~S"""
    - RFD 2204 (RECTGTN fleet coordination), the domain document
      shape the plugin queries. This RFD supersedes its "coordinator
      adapter" section with a one-line pointer, per CLAUDE.md doctrine.
    - RFD 2140 (OpenBao on FoundationDB), the storage backend the
      plugin's SQLite fixture sits on top of.
    - RFD 2142 (Bao PKI zerotrust), the cert-auth path peers use.
    - RFD 2146 (Bao is the secret store), the policy discipline any
      new mount inherits.
    - RFD 2147 (Bao is critical infrastructure), the blast-radius bar
      a new plugin must meet.
    - RFD 2195 (weftspun-bao Tailscale sidecar), the deploy shape
      this plugin ships alongside.
    - RFD 2202 (ReBAC Bao enforcement), this RFD fills the
      compute-lease broker gap RFD 2202 named as future work.
    - Sibling plugin scaffold: `7-service/service-bao-sqlite-fdb/` —
      the layout the new plugin copies verbatim.
    """

    drafted_by :ai
  end
end
