# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2149. `mix rfd.render` renders rfd/2149-grafcet-static-analysis-in-lean4/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2149 do
  use RFD.DSL

  rfd 2149, "GRAFCET static analysis in Lean 4, from Elixir" do
    state :prediscussion

    feature "port `Project-AGRAFE/GRAFCET-static-analysis` (Java, MIT)
to Lean 4 with a plain C ABI, called from Elixir via a C NIF"

    scope "taskweft-grafcet-static (new repo), taskweft (NIF module)"

    decision ~S"""
    Port the two structural analyses to Lean 4. The port is a first-class
    repository, `taskweft-grafcet-static`, placed in the workspace
    manifest at `3-interactor/taskweft-grafcet-static`. Lean's `@[export]`
    produces a C ABI declared in `c_src/grafcet_static.h`; a small NIF in
    taskweft loads the shared library and exposes `analyse/1` to Elixir.
    Abstract interpretation is staged; the SFC types carry the fields,
    the analysis is a follow-on that needs either a Lean-native interval
    domain or a Z3 bridge.

        char *grafcet_static_analyse(const char *sfc_json);
        void  grafcet_static_free(char *buf);

    A stub in `c_src/grafcet_static_stub.c` returns `{"error":"stub"}` so
    the NIF links today; swapping the stub for the Lean-produced library
    closes this RFD. `DETAILS.md` carries semantics, staging, verification.
    """

    problem ~S"""
    RFD 2148 puts compact IEC 60848 GRAFCET at the front of taskweft, but
    provides no verifier. AGRAFE ship a static analyser (step reachability,
    pairwise concurrency, abstract interpretation of variable domains) as
    an Eclipse plugin in Java, with hard build dependencies on Apron and
    Z3. Not something a taskweft loader can call.
    """

    references ~S"""
    1. `3-interactor/taskweft-grafcet-static/`; the port
    2. Upstream: https://github.com/Project-AGRAFE/GRAFCET-static-analysis
    3. RFD 2148: compact GRAFCET as taskweft's authoring surface
    """

    details_title "GRAFCET static analysis in Lean 4, from Elixir"

    details "Two analyses now, one later", ~S"""
    AGRAFE's tool ships three: structural (step reachability), structural
    (pairwise concurrency), and abstract interpretation of variable
    domains. This RFD closes the first two and stages the third.

    **Reachability.** The set of step ids that appear in some marking
    reachable from the initial marking by simultaneous-firing IEC 60848
    semantics. Implemented as a fuel-bounded BFS through the firing graph
    in `SFC.reachableSteps`. Fuel is a parameter; a real deployment
    supplies `2 ^ |steps|` as the state-space upper bound.

    **Pairwise concurrency.** The set of `(a, b)` step-id pairs (ordered
    by name to avoid duplicates) that co-occur in some reachable marking.
    `SFC.concurrentPairs`. This is what surfaces an OR-divergence with
    non-exclusive receptivities: the two branches show up as a concurrent
    pair, which is a chart bug the author should see.

    **Abstract interpretation.** Variable domain analysis over internal
    variables. Staged; the SFC types carry the fields (`Step.storedTarget`,
    receptivity `V.<var>` atoms), the analysis itself is empty. Landing
    this needs either a Lean port of an Apron-style domain library
    (interval, octagon, polyhedron) or a Z3 bridge; neither is a taskweft
    gate today, so the RFD closes on structural analysis and leaves the
    abstract-interpretation stage on the roadmap.
    """

    details "Firing semantics", ~S"""
    `Receptivity` has three constructors: `trueR`, `stepActive`, `andR`.
    That covers the compact GRAFCET DSL's supported receptivity fragment
    (AND of step-activity atoms). `V.<var>` atoms are conservatively
    `true` in the current firing predicate; a sound over-approximation
    for reachability (a step reachable under unrestricted variables is
    reachable under any restriction). Abstract interpretation replaces
    this with a real domain check.

    `SFC.fire` is simultaneous-firing IEC 60848: every enabled transition
    fires at once, sources come out of the marking, targets go in. The
    result is `eraseDups`ed because the union may put a step in twice
    (one transition adds it, another already had it there).
    """

    details "Why Lean", ~S"""
    Two reasons over "just port to Elixir".

    **Proof.** The port opens the door to proving `reachableSteps` sound
    and complete against the semantics: `s ∈ SFC.reachableSteps sfc` iff
    there is a firing sequence from the initial marking that puts `s` in
    some marking. Those theorems land in `Theorems.lean`; they are the
    value-add over the Java tool, which asserts them rather than proving
    them.

    **C ABI, no runtime.** Lean 4 compiles to C, links as a static or
    shared library, and imposes no runtime BEAM or JVM. That is the
    minimum interface a NIF can pull; the fully-linked NIF is one
    `.so`/`.dylib` and has no Apron and no Z3 in its transitive closure.
    """

    details "The C ABI", ~S"""
    `c_src/grafcet_static.h`:

        char *grafcet_static_analyse(const char *sfc_json);
        void  grafcet_static_free(char *buf);

    Ownership: caller frees. The reply is a null-terminated UTF-8 JSON
    string. Success shape:

        {"reachable": ["init", "find", "pickup_from_table",
                       "unstack", "mark_done"],
         "concurrent_pairs": [["pickup_from_table", "unstack"]]}

    Error shape:

        {"error": "reason"}

    The stub returns `{"error":"stub","reason":"...","see":"rfd 2144"}`
    until the Lean-produced shared library replaces it.
    """

    details "Elixir NIF", ~S"""
    Modelled on `3-interactor/taskweft-nmm-personas/c_src/weft_bus_nif.cpp`
    and `7-service/spot-broker/c_src/store_bus_nif.cpp`. Loads
    `libgrafcet_static.dylib`, calls `grafcet_static_analyse`, hands the
    JSON string back as an Elixir binary. Runs on a dirty CPU scheduler
    because the BFS is CPU-bound and unbounded in the fuel argument.

    Exposed at `Taskweft.Grafcet.Static.analyse/1` in the taskweft
    project; called from the loader when a `.grafcet.jsonld` document
    lands, so a chart with an unreachable step or an unintended
    concurrent pair refuses to load.
    """

    details "Repo manifest", ~S"""
    `taskweft-grafcet-static` is a first-class checkout, listed in
    `.repo/manifests/default.xml` at `3-interactor/taskweft-grafcet-static`
    alongside `taskweft` and `taskweft-nmm-personas`. Remote is
    `weftspun`. The three sit on the interactor side of the hexagon per
    CLAUDE.md's "one live goal manifest" rule.
    """

    details "Verification", ~S"""
    1. `lake build` in `3-interactor/taskweft-grafcet-static` builds the
      Lean library and the smoke-test executable.
    2. `./.lake/build/bin/grafcet_static` runs the blocks_get_or fixture
      (RFD 2148's OR-divergence worked example) and prints:

          reachable: [init, find, pickup_from_table, unstack, mark_done]
          concurrent pairs: [(pickup_from_table, unstack)]

      The concurrent pair correctly flags that the two OR branches share
      the same receptivity; an author-visible symptom of a chart where
      the AGRAFE tool would say "not mutually exclusive".
    1. When the Lean-produced shared library lands, the Elixir NIF's
      `analyse/1` returns the same JSON, wired into taskweft's loader
      gate.
    """

    details "Staging table", ~S"""
    | construct | state |
    |---|---|
    | Reachability | landed in Lean, real C body wired via Lean `@[export]` |
    | Pairwise concurrency | landed in Lean, real C body wired |
    | Elixir NIF | `Taskweft.Grafcet.Static.analyse/1` wired, 2/2 tests green |
    | Abstract interpretation | typed in the SFC, analysis empty; needs a Lean interval/octagon domain or a Z3 bridge |
    | Soundness theorems | `Theorems.lean` empty; next stage |
    | Loader gate | not wired; needs a `Taskweft.JSONLD.Loader` hook after the compact GRAFCET parse |
    """

    details "Unaffected by RFD 2150's FBD-target pivot", ~S"""
    RFD 2150 changed the *emitter's target* from PLCopen SFC to PLCopen
    FBD (state machine encoded as SR flip-flops). This analyser reads the
    *compact GRAFCET input* to the emitter, not its output, so nothing
    here changes. Reachability and pairwise concurrency are graph queries
    on the SFC step/transition structure carried in the input JSON-LD;
    that structure is unchanged by whatever the emitter ships downstream.

    A separate analyser reading the FBD output (to catch defects
    introduced during the FBD encoding; a mis-wired reset input, a
    missing first-scan latch) is a follow-on. This one stays authoritative
    for the input side.
    """

    drafted_by :ai
  end
end
