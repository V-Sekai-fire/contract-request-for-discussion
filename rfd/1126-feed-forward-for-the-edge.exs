# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 1126. `mix rfd.render` renders rfd/1126-feed-forward-for-the-edge/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD1126 do
  use RFD.DSL

  rfd 1126, "Unroll the descent, do not replace it" do
    state :discussion

    feature "edge deployment of the wholebody chain"

    scope "`3-interactor/rf-detr-cpp`, `4-entities/anny-pose-retarget-work`"

    attest_in :none

    decision ~S"""
    Unroll the descent into a fixed number of steps, keeping the forward we own.

    **Clamp every step, with pairwise kusudamas concatenated.** No kusudama carries
    two or more cones: three equidistant cones sum to zero. A clamp is `Clip`, so
    the unrolled graph still cannot emit an unreachable pose.

    **Warm-start from the previous frame**, so the step count stays small.

    **Compile the backbone with `num_windows=1`.** Measured: it parses and
    `num_windows=2` does not. It costs 1.35x wall-clock and needs retraining.

    **Give the face camera the resolution and starve the body cameras.** One device
    holds four streams at 120 fps only if they differ.

    **Report the residual as a percentage of stature**, as `soma_referee` does.

    See `DETAILS.md` for the rig budget, the unrolled cost, and what is unmeasured.
    """

    problem ~S"""
    RFD 1122's chain has six stages: three feed-forward graphs, and three descent
    loops that an inference accelerator cannot compile.

    The obstacle is control flow rather than precision. `lbfgs_polish.py` uses a
    strong-Wolfe line search, a loop whose trip count depends on values, and `Loop`
    and `If` are what an edge compiler refuses. Its `float64` follows from that same
    file's `tolerance_grad=1e-10`, an offline target rather than an inference one.

    An earlier draft answered by replacing the fit with a learned student, which
    gives up the property the parametric model exists for: `soma_referee.py` states
    that a parametric model cannot represent an impossible skeleton, and nothing in
    a regressor's architecture forbids one.
    """

    details_title "Unroll the descent, do not replace it"

    details_preamble ~S"""
    Every section names its gate in an HTML comment under its heading, per RFD 1125.
    """

    details "Why unrolling and not a student", ~S"""
    <!-- gate: tropes -->

    The first draft of this RFD reached for a learned regressor, and the reasoning
    looked sound: the head is being retrained anyway for 104 points, so make the
    replacement one an accelerator can run. What that misses is which property was
    being spent.

    `soma_referee.py` is explicit about it. A parametric model cannot represent an
    impossible skeleton, and a discriminative estimator can: a heatmap peak lands
    where it lands, and nothing in the architecture forbids an elbow bending
    backwards or a limb changing length between frames. The referee was built around
    that asymmetry. Replacing the fit with a regressor puts the estimator back where
    the parametric model was, and calls it progress.

    Unrolling keeps it. A fixed number of descent steps through the ANNY forward is
    still descent through a forward we own, with the iteration count frozen instead
    of decided at run time. The pose it emits is reachable because the
    parameterisation says so, not because training made it likely.

    The clamp is what makes that claim survive compilation. `swing-twist-kusudama`
    already has joint limits stated in Lean 4 and checked against Godot's own
    output, and clamping swing and twist at every unrolled step is a `Clip`, which
    compiles. So the guarantee holds in a feed-forward graph, which is the thing a
    regressor cannot offer at any accuracy.

    **How the clamp is built is decided, and it is not the obvious reading.** No
    kusudama carries two or more cones. A joint limit that a multi-cone kusudama
    was being asked to express is built as a concatenation of pairwise ones. The
    measurement behind that is in `humanoid-rom/FINDINGS.md`: three equidistant
    cones, 120 degrees apart, sum to `4.003e-16`, so the pole derived by summing
    cone centres and normalising is degenerate, and one unit in the last place
    moves it by 45 degrees.

    That helps the graph rather than costing it. A pairwise kusudama is small and
    fixed, a concatenation of them is a fixed-length chain, and the whole
    constraint stays feed-forward with no data-dependent count. Deriving a pole
    would have needed a normalise whose input can be zero, and an INT8 pipeline has
    no good answer for that division.
    """

    details "What actually blocked the accelerator", ~S"""
    <!-- gate: ste100 -->

    Three obstacles, in order of severity. Precision is the third.

    | obstacle | why it blocks | remedy |
    | ------------------------------- | ---------------------------------------- | -------------------- |
    | `line_search_fn="strong_wolfe"` | data-dependent loop; `Loop` and `If` fail | unroll to fixed steps |
    | `max_iter=300`, `history_size=50` | 50 stored gradient pairs, deep unroll    | warm-start           |
    | `float64`                        | INT8 activations are the widest available | measure the residual |

    The `float64` in `lbfgs_polish.py` follows from `tolerance_grad=1e-10` and
    `tolerance_change=1e-12` in the same call. Float32 carries about 1e-7 relative
    precision, so those tolerances are unmeasurable in it. They are offline
    convergence targets for producing retarget data. At 120 fps the solver starts
    from the previous frame and applies a correction.

    Compensated arithmetic, which represents one high-precision value as a sum of
    two low-precision ones, is available if the residual proves insufficient. Reach
    for it after measuring rather than before. It costs 2x to 4x the operations, and
    it means carrying residual channels through a quantizer that will try to rescale
    them.
    """

    details "The unrolled solver is free", ~S"""
    <!-- gate: ste100 -->

    Fitting to keypoints needs the kinematic chain, not the mesh. Composing a 3x2
    rotation for each of 104 bones and projecting into four views is about 8,500
    multiply-accumulates. One descent step is roughly three times that, for the
    forward and its gradient.

    | stage                              | cost per frame |
    | ---------------------------------- | -------------- |
    | 25 unrolled descent steps          | 0.64 MMAC      |
    | 4-view backbone, 3 at 288 + 1 at 432 | 102.1 GMAC   |
    | solver as a share of the rig       | 0.0006%        |

    Posing all 13,718 vertices, which the silhouette and depth fits need, is 0.7
    MMAC per evaluation. Even 25 steps carrying the full mesh is 0.05 GMAC.

    The solver was never a compute problem. It was a control-flow problem wearing a
    precision problem's clothes.
    """

    details "The rig on one device", ~S"""
    <!-- gate: ste100 -->

    Three body cameras and one face camera, one architecture on all four, on a
    single 40 TOPS INT4 accelerator. Backbone measured at `num_windows=1`, decoder
    included.

    Utilisation needed for four cameras at one resolution:

    | resolution | GMAC  | at 120 fps | at 90 fps | at 60 fps |
    | ---------- | ----- | ---------- | --------- | --------- |
    | 288        | 17.8  | 43%        | 32%       | 21%       |
    | 336        | 25.8  | 62%        | 46%       | 31%       |
    | 384        | 35.9  | 86%        | 65%       | 43%       |
    | 432        | 48.7  | over 100%  | 88%       | 58%       |
    | 576        | 107.9 | over 100%  | over 100% | over 100% |

    Four cameras at 432 and 120 fps is not available on one device. It needs 117% of
    the part at perfect utilisation, before any overhead.

    **So the cameras must differ.** Precision is wanted on the face and not on the
    body, because a face camera frames a 200 mm face and a body camera frames a
    1.7 m person.

    | rig                          | fps | utilisation | body stride         | face stride     |
    | ---------------------------- | --- | ----------- | ------------------- | --------------- |
    | 3 at 288 plus 1 at 432       | 120 | 61%         | 71 mm, a soda can   | 5.6 mm, a pencil |
    | 3 at 288 plus 1 at 384       | 120 | 54%         | 71 mm, a soda can   | 6.2 mm, a pencil |
    | 3 at 336 plus 1 at 432       | 120 | 76%         | 61 mm, a soda can   | 5.6 mm, a pencil |
    | 3 at 336 plus 1 at 432       | 90  | 57%         | 61 mm, a soda can   | 5.6 mm, a pencil |

    Three views at 71 mm triangulating is a different measurement from one view
    guessing, which is why the body cameras can be starved. The z-test that computes
    `visibility` in RFD 1122's schema is the same idea applied to labels.
    """

    details "What is unmeasured, and matters", ~S"""
    <!-- gate: ste100 -->

    **Utilisation.** Every percentage above divides by 40 TOPS as though the part reaches peak. The part does not reach peak. If the true figure is 50%, the 61% rig becomes 122%
    and nothing in that table fits. The Dataflow Compiler has a profiler and it has
    not been run. Treat the table as a ranking, not a budget.

    **Two resolutions is two compiled graphs.** Switching context per frame on one
    device has a cost that is not counted here, and it may erase the saving. A
    uniform rig at 288 and 43% may beat the asymmetric rig at 61%.

    **Ingest.** Four synchronised 120 fps streams is 480 frames per second to move
    and time-align before any of this arithmetic applies.

    **Calibration.** The rig needs extrinsics. No code in the workspace solves them.

    **Temporal coherence.** Per-frame fits at 120 fps will jitter. Warm-starting
    helps the step count and does not by itself make the output smooth.

    **The residual itself.** How close an unrolled fit with K steps gets, as a
    percentage of stature, at the precision the part offers, is the number this
    decision rests on and nobody has taken it.
    """

    drafted_by :ai
  end
end
