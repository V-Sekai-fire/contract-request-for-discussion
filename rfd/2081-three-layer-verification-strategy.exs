# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2081. `mix rfd.render` renders rfd/2081-three-layer-verification-strategy/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2081 do
  use RFD.DSL

  rfd 2081, "Three layer verification strategy" do
    state :prediscussion

    decision ~S"""
    See `DETAILS.md` for the full argument.
    """

    problem ~S"""
    | Layer | Tool | Scope | What it proves | | --------------- |
    --------------------- | -------------- |
    ------------------------------------------------------------ | | C
    invariants | CBMC | Implementation | SPSC ring FIFO, bounds,
    head-tail, NURand range | | Specification | Lean 4 | Design | SPSC
    linearizability, push/pop preserve bounds | | TPC-C semantics |
    plausible-witness-dag | Runtime | NewOrder atomicity, Delivery
    correctness, Stock non-negative |
    """

    related ~S"""
    See `DETAILS.md` for the full argument.
    """

    details_title "Three layer verification strategy"

    details "Layers", ~S"""
    | Layer           | Tool                  | Scope          | What it proves                                               |
    | --------------- | --------------------- | -------------- | ------------------------------------------------------------ |
    | C invariants    | CBMC                  | Implementation | SPSC ring FIFO, bounds, head-tail, NURand range              |
    | Specification   | Lean 4                | Design         | SPSC linearizability, push/pop preserve bounds               |
    | TPC-C semantics | plausible-witness-dag | Runtime        | NewOrder atomicity, Delivery correctness, Stock non-negative |
    """

    details "Why three layers", ~S"""
    CBMC proves the C code is correct for bounded inputs but cannot reason
    about TPC-C semantics. Lean 4 proves the specification is sound but does
    not verify the C implementation. plausible-witness-dag searches for
    runtime invariant violations via HTTP but cannot prove absence of bugs.

    Together they cover the gap: CBMC catches implementation bugs, Lean 4
    catches specification bugs, plausible-witness-dag catches integration
    bugs.
    """

    details "CBMC harnesses", ~S"""
    - `test/cbmc/spsc_harness.c`, FIFO ordering, overflow, underflow, head-tail invariant
    - `test/cbmc/nurand_harness.c`, NURand result in [x, y]
    - `test/cbmc/random_harness.c`, get_random_number in [0, max]
    """

    details "Lean 4 modules", ~S"""
    - `TpccVerification/Spsc.lean`, SPSC ring buffer specification with proofs: `init_safe`,
    `push_safe`, `pop_safe`
    - `TpccVerification/Basic.lean`, TPC-C invariant predicates for plausible-witness-dag
    """

    details "plausible-witness-dag integration", ~S"""
    Depends on `fire/plausible-witness-dag` as a Lake dependency. The
    `resolve` function takes a candidate predicate and a deterministic
    readback, escalating through L0/L1/L2 until it finds a witness or
    proves none exists.

    Escalation ladder: L0 (10 txns, W=1), L1 (100 txns, W=5), L2 (1000 txns, W=20).
    """

    drafted_by :ai
  end
end
