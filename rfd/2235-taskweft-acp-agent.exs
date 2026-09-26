# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2235. `mix rfd.render` renders rfd/2235-taskweft-acp-agent/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2235 do
  use RFD.DSL

  rfd 2235, "An ACP agent that plans with taskweft and executes through the editor" do
    state :discussion

    flight_level :l2

    feature "a no-model Agent Client Protocol agent: a deterministic grammar, taskweft plans, ACP tool calls under the client's permission, the session as an event log in the fdb-sqlite store"

    scope "`1-transport/transport-taskweft-acp`, the Fly app `weftspun-taskweft-acp`, the executor sides that dial into it"

    decision ~S"""
    The agent holds no language model. A prompt is a slash command or a phrase
    matched against the domain's method names; taskweft plans it; every step is
    one ACP tool call through the client's files and terminals behind a
    permission prompt; a failed step replans from the verified prefix or says
    that no other decomposition reaches the goal. Claude Code drives the same
    agent through an MCP bridge that is an ACP client, so the session keeps its
    context. Every request and update is an event in one `weft_fdb` database
    per session, the hosted door being the fabric-store writer and OpenBao's
    sqlite-fdb engine the fallback. The Fly door is gated by OpenBao tokens,
    never GitHub, and runs no step itself: executor sides dial in and answer the
    client-side requests of their sessions under a bao-held policy with a local
    override. `DETAILS.md` carries the rest.
    """

    problem ~S"""
    MCP tools answer one call and forget it, so an agent driven through them
    loses the turn's context; taskweft had a planner and no executor; the editor
    already owns the files, the terminals and the permission dialog. Hosting the
    bridge raised the question of where steps run, and a machine on Fly is not
    the desk with the checkout, the GPU box, or the editor a human is watching.
    """

    references ~S"""
    - RFD 2232, the RFD DSL this document is written in
    - RFD 2154, RFD 2157 and RFD 2159, the plan-to-Godot-Sandbox path the export follows
    - RFD 2140, RFD 2146 and RFD 2205, OpenBao and the sqlite-fdb engine the fallback extends
    """

    related ~S"""
    RFD 2234 (the dress-on plan this repository's planning pattern was first tried on), RFD 2111 (the side the repository sits on), RFD 2134 (the cluster's TLS).
    """

    details_title "An ACP agent that plans with taskweft and executes through the editor"

    details "The shape in the decompilable-model vocabulary", ~S"""
    A natively decompilable model separates perception from execution, routes
    with hard gates instead of continuous attention, keeps its state discrete,
    and executes over a syntax tree it can export as code. This repository is
    that shape with the neural half left empty. The grammar is the perception
    layer; its output is a DSL term. If a learned front door is ever added, its
    hidden state is quantized through residual FSQ, the workspace's standard
    codebook, so the model's path stays a finite, inspectable state sequence.
    The HTN method alternatives with their `check` guards are the branches, and
    the planner's explain tree is the route taken. The world state is the
    domain's typed variables and every transition is a `pointer_set` in an
    action body; the session store is the trace. The plan is a DSL term executed
    as a state machine, and `/export` decompiles it: a SafeGDScript program for
    Godot Sandbox whose guest holds the plan and the state machine and cannot
    run a command or open a file, while the host scene shipped beside it
    performs each step the guest asks for and reports the exit code back.
    """

    details "Why no model, and the open item", ~S"""
    The operator asked for a taskweft-only agent with the agentic feel of an
    editor session, and then asked whether the smallest Gemma 4 model should be
    trained on the taskweft DSL. Keep it code: a model would sit at the front
    door only, translating typed text into a domain or goal, which is exactly
    the part that stops being reproducible once a model does it. The slash
    grammar plus the planner's own diagnostics cover what someone types in an
    editor and fail with a line and column instead of a guess. The training case
    also does not stand yet: three DSL domains exist, so a corpus would be
    constructed, and the validator that would label it (compile, plan, goal
    reached) is the validator the deterministic agent needs anyway. If the
    grammar proves too narrow, Gemma 4 E2B is the allowlisted size, the corpus
    generator exists by then, the latent goes through residual FSQ, and the
    grammar is the baseline it has to beat.
    """

    details "The session store", ~S"""
    The store is the session, not a summary beside it. Every JSON-RPC message
    that belongs to a session is appended before it is acted on: the
    `session/new` params, each prompt, every `session/update` the agent emits,
    every request to the client and its answer, each permission decision, and
    the stop reason. The in-memory session is what replaying that log yields;
    `session/load` and `session/resume` are replays, `session/list` is a
    registry query. One `weft_fdb` database per session and a registry
    database, fabric-store's own parallel-commit protocol across the two, one
    fenced writer per database: the hosted process that owns the session.
    Taking a session over raises the fence and a stale writer's next write is
    refused visibly. The primary adapter drives a helper built from
    fabric-store's `sqlrun.c` over a Port with a line protocol (plain SQLite
    files on a desk and in CI, `weft_fdb` databases on the cluster); the
    fallback adapter reaches the same tables through OpenBao's sqlite-fdb
    engine once it carries a catalog write path, and the switch is written
    through the fallback first so the log says why. The operator chose the
    primary for latency: one FoundationDB commit per step from the machine in
    the cluster's region, no HTTP hop.
    """

    details "Executor sides", ~S"""
    ACP's client owns files and terminals. Hosted, the bridge would be that
    client and steps would run on Fly; executors sit behind NAT, so Fly cannot
    dial them. Executors dial in instead and answer the client-side requests of
    their sessions: a headless desk or build box runs files and terminals in the
    BEAM and answers permissions from the `taskweft_acp_policy` field of its
    `agents/<cn>` secret in OpenBao, overridden key by key by
    `.taskweft-acp/policy.exs`; the answer is produced where the cost lands and
    the hosted side records it. A session binds to a connected executor by name
    at `acp_new_session`; a prompt on a session whose executor is gone fails
    with the name. The Fly machine is itself an executor called `fly` for the
    CI-runner case, chosen explicitly, never by default. The bearer on `/mcp`
    and on `/executor` is an OpenBao token validated by `auth/token/lookup-self`
    and admitted by policy; a bao outage is 503, never an open door.
    """

    details "What was measured", ~S"""
    Forty-one tests drive the agent over ex_mcp's memory transport with a
    scripted editor: the grammar, the domain loader and its literal `@exec`
    walk, the planner (build then test; the five-step commit; replan taking the
    other decomposition on the failed action; no recovery when none exists),
    the end-to-end run with a permission per step, rejection and refusal, the
    replan budget, load and list from the store, the export, the store adapter
    through the real helper, the fallback adapter through a fake mount (the
    switch is written through the fallback before the retried write, a plain
    SQL error does not switch, and a degraded boot names its reason on every
    call), and the bridge running real commands. Dialyzer runs on the whole
    application as a gate.

    `mix taskweft_acp.bench` drives a ten-step plan through the agent with an
    editor that answers instantly, five runs of ten steps, on this desk on
    2026-09-07:

    | store mode, on this desk | p50 ms/step | p95 ms/step |
    | ------------------------ | ----------- | ----------- |
    | floor (memory store)     | 0.31        | 0.41        |
    | plain (helper + SQLite)  | 1.64        | 1.95        |
    | fabric (weft_fdb)        | not run     | not run     |

    The cluster is 6PN-only, so the fabric row is measured from the Fly
    machine (`shared-cpu-1x`, 512 MB, sjc) once its credentials exist, the
    same five runs through `bin/taskweft_acp_deploy rpc`:

    | store mode, on the Fly machine | p50 ms/step | p95 ms/step |
    | ------------------------------ | ----------- | ----------- |
    | floor (memory store)           | 0.31        | 0.46        |
    | plain (helper + SQLite)        | 26.43       | 29.38       |
    | fabric (weft_fdb)              | 27.20       | 32.21       |

    On the machine the cluster costs what the machine's own disk costs: a
    step is several appended events, each one commit, and the machine's
    root disk syncs about as slowly as the cluster answers. The desk's
    plain row is the same helper on a local NVMe. The bench leaves its
    `bench_<stamp>_*` databases in the cluster; `fdbcli` clears them.

    Reaching the cluster exposed two packaging defects the plain mode never
    could: the migrations directory and the built-in domain path were
    resolved at compile time into the build tree, so the first boot that
    connected crashed and Fly stopped the machine after ten restarts. Both
    are runtime lookups now, and a defect while opening the store faults the
    release (operator: "it must fault"); only an unreachable cluster degrades.

    The client certificate is `fdb-taskweft-acp.chibifire.com`, issued by
    bao's PKI role `fdb-server` for 90 days (RFD 2145) and placed as the four
    secrets of RFD 2134 by `scripts/issue_cluster_credentials.sh`, which is
    written as a state machine over observed states (PITFALLS 12). On the
    desk the taskweft NIF and the helper build with llvm-mingw (operator
    directive: not Visual Studio), and the stdio bridge answers `initialize`
    two seconds after launch. The fabric build needs `FDB_API_VERSION=730`
    defined, as the bao plugin's cgo flags do; the first Fly build failed
    without it.
    """

    drafted_by :ai
  end
end
