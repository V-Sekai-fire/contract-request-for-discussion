# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2247. `mix rfd.render` renders rfd/2247-property-testing-in-every-language/README.md
# and DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2247 do
  use RFD.DSL

  rfd 2247,
      "Property testing in every language, with falsification" do
    state :discussion

    feature "every test suite in the workspace states invariants a generator searches, and ships the negative control that must fail"

    scope "every language in the workspace: Elixir (StreamData), Python (Hypothesis), C++ (RapidCheck), Rust (proptest), Go (testing/quick, rapid), GDScript/C# (FsCheck where hosted)"

    decision ~S"""
    A test asserts an invariant over generated input, not an outcome for one
    hand-chosen input. Every language the workspace builds in uses its
    property-testing library. On top of that, every property ships its
    falsification: the input that SHOULD violate it, with the test failing if
    the violation goes undetected.

    See `DETAILS.md` for the property shapes, the harness bug that motivated
    this, determinism, and what the rule does not ask for.
    """

    problem ~S"""
    Example-based tests pass by construction. The author picks inputs they
    already believe work, so the suite encodes the author's assumptions rather
    than testing them, and it goes green over a harness that measures nothing.

    A property without a negative control is barely better: it establishes that
    the assertion is reachable, not that it discriminates.
    """

    details_title "Properties worth stating, and how falsification pairs with them"

    details_preamble ~S"""
    The useful properties are the ones that hold for every input rather than the
    ones convenient to write down. Below are the recurring shapes, each with the
    negative control that gives it teeth, drawn from work already in the
    workspace.
    """

    details "Property shapes", ~S"""
    - **Monotonicity.** Raising a parameter moves the result one way. Raising
      spring-bone `pull` must not increase deflection; keeping every 4th bone must
      not score better than keeping every 2nd. Falsification: assert the
      comparison is strict where the model says it must be, so an implementation
      that ignores the parameter entirely fails instead of tying.
    - **Conservation.** A transformation preserves a quantity it must not
      change. Merging parameter-identical springbone chains changes the
      component count and nothing else -- transform count before equals after.
      Falsification: a merge that drops a transform must fail the test.
    - **Round-trip identity.** Export then import returns the input. The engine's
      USD adapter carried blend shapes out and silently dropped every one on the
      way back in, because no test round-tripped a mesh that had any.
      Falsification: perturb one shape's deltas and assert the round trip
      detects the difference, so an importer returning the ORIGINAL mesh
      unchanged cannot pass.
    - **Invariance.** An irrelevant change does not alter the result.
      Arclength-resampling a curve is invariant to how finely it was
      discretised. Falsification: a genuinely different curve must NOT compare
      equal, or the metric has flattened everything to zero and approves any
      reduction.
    - **Ordering and idempotence.** Applying a reduction twice equals applying
      it once; grouping is independent of input order.

    Pin regressions as explicit examples on top of the generator (Hypothesis
    `@example`, proptest's `.regressions` file). The generator finds the class;
    the pinned case proves the specific bug stays dead.
    """

    details "The harness bug that motivated this", ~S"""
    The springbone chain-reduction harness reported a tidy set of numbers: 61
    spring-bone components reduced to 19, collision checks 1233 to 512. Twelve
    example-based tests passed.

    Two negative controls -- a frozen chain that must NOT register motion, and a
    stiff chain that must deflect less than a soft one -- failed with the same
    number, 0.2017 m, for every parameter setting. The harness was measuring the
    carrier translating the chains rigidly, never their articulation: `qpos`
    written each step teleports the carrier and imparts no velocity, so nothing
    swung.

    The component result survived, being pure combinatorics on parameter
    identity with no simulation involved. The collision result did not, and it
    was biased toward over-pruning, because a chain that never swings never
    approaches a collider it would really have hit.

    The falsification cases caught it and the twelve examples did not. A
    generator would have caught it faster and smaller: "deflection is monotone
    in pull" is one property over generated parameters, and it shrinks to a
    minimal counterexample instead of needing a human to guess which two
    settings to compare. That is the argument for both halves of this rule.

    The workspace already believes half of it. RFD 2234's gates each read
    "every gate ships with its negative control". That discipline was written
    down for data gates and practised nowhere else; this RFD generalises it to
    code and adds the generator.
    """

    details "Determinism", ~S"""
    Anything touching a simulator, a GPU or a sampler fixes its seed, and the
    seed is part of the recorded failure. A property test that cannot reproduce
    its own counterexample is a flake generator. MuJoCo, CoACD and EditScore
    runs all fall under this.
    """

    details "What this does not ask for", ~S"""
    Not every test becomes a property test. Wiring checks -- does this menu item
    exist, does this file parse -- stay as examples; there is no invariant to
    generalise. The rule binds where there is a claim about behaviour over a
    domain of inputs, which is where the interesting bugs are.
    """

    related ~S"""
    RFD 2234 (dress-on pipeline; the "every gate ships with its negative
    control" discipline this generalises, and the springbone follow-on whose
    harness bug motivated it), RFD 2232 (Markdown as build artifact),
    `2-contract/manuals-weftspun/apparatus/springbone_mujoco.py` and its test
    suite, `3-interactor/motion-bricks-cpp/mujoco/` (add_cloth_chains.py,
    bench_silhouette.py, coacd_calibrate.py).
    """

    drafted_by :ai
  end
end
