# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2249. `mix rfd.render` renders rfd/2249-cloth-by-vertex-block-descent/README.md
# and DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2249 do
  use RFD.DSL

  rfd 2249,
      "Cloth by vertex block descent, on the GPU" do
    state :discussion

    flight_level :l1

    feature "a cloth solver with no global linear solve, no Eigen and no convex approximation of the body"

    scope "garment simulation on avatars, and coverage measured from a static distance"

    decision ~S"""
    Cloth is solved by augmented vertex block descent in Warp kernels. Each
    vertex minimises its own energy against a 3x3 Hessian, which is closed form,
    and the only coupling is that neighbours must not move at once.

    There is no global linear solve to make faster. Contact queries the body mesh
    by generalised winding number, so no convex decomposition is in the loop and
    nothing bridges a garment's concavities. It is the solver
    `slang_solver/AvbdSolver.h` in cloth-dynamics describes and does not contain:
    that `step()` is a stub and those kernels are Metal.
    """

    problem ~S"""
    Whether an avatar's body shows through its clothing was answered from a
    static distance in one pose. That is a stand-in for what cloth does, and the
    question is per frame.

    Neither obvious solver can do the job. A physics engine's cloth element caps
    its contacts at fifty whatever the mesh resolution, reports nothing when the
    cap binds, and collides only convex shapes, which fill a garment's
    concavities. The workspace's differentiable cloth simulator leans on Eigen
    across twelve of nineteen simulation files, and on LBFGSpp.
    """

    details_title "Why the alternatives are out, and what the choices cost"

    details_preamble ~S"""
    Each rejection below is a measurement rather than an argument, because each
    alternative looked workable until it was measured.
    """

    details "The contact cap, measured", ~S"""
    The same cloth over the same sphere, varying only mesh resolution:

    | grid  | elements | final contacts | peak contacts |
    |-------|----------|----------------|---------------|
    | 5x5   | 32       | 6              | 12            |
    | 9x9   | 128      | 8              | 50            |
    | 15x15 | 392      | 35             | 50            |
    | 25x25 | 1,152    | 50             | 50            |
    | 41x41 | 3,200    | 50             | 50            |

    That is `mjMAXCONPAIR`. Nothing reports it: no contact-full warning, no
    contact limit set, a ten gigabyte arena. On a real garment of 10,050 elements
    it is one contact per two hundred elements, so most of the cloth has nothing
    beneath it, and no amount of stiffness, damping or timestep tuning changes
    it. This build accepts no vertex-collision fallback; both spellings are
    refused at the schema.

    The GPU backend does not apply the cap to geometry-against-cloth groups --
    its farthest-point-sampling filter returns early unless the group is
    cloth-against-cloth, and on the device gives 70 contacts at 128 elements
    and 173 at 1,152.
    """

    details "Why not a faster linear solver", ~S"""
    The obvious replacement for a direct factorisation is a matrix-free
    conjugate gradient, and it was already tried in this workspace.
    `PERF_FINDINGS.md` records it at 2.5x slower than Eigen LLT on the Hat demo
    and 17x slower on Dress, because projective dynamics issues about 1,475
    solves per step and each one pays its own device synchronisation.

    Per-kernel throughput was genuinely 4 to 12 times better. It did not survive
    contact with the step structure. Block descent removes the structure rather
    than optimising it.
    """

    details "Design points that are not free choices", ~S"""
    - **Graph colouring.** Vertices sharing no edge update together and still
      read their neighbours' latest positions: Gauss-Seidel convergence at Jacobi
      cost. Updating every vertex at once oscillates on stiff cloth.
    - **Positive semi-definite Hessians.** A compressed spring's exact Hessian is
      indefinite and a Newton step against an indefinite Hessian moves uphill.
      The transverse term is clamped. The contact Hessian is the normal outer
      product only, because the curvature term goes indefinite exactly where the
      surface is concave, which is where the garment sits.
    - **An augmented Lagrangian for pins, a penalty for contact.** A pin's
      residual goes to zero because its target is a point, so the multiplier
      stops growing. Contact is an inequality with no physical scale to cap a
      multiplier against: a vertex of this cloth weighs a gram and needs about
      0.01 N to hold up, and the multiplier ramped until it threw the sheet clear
      of the body at 2 m/s.
    - **Bending measured from the rest shape, not from flat.** The quadratic
      bending model's Hessian contribution is k*w*w*I, positive semi-definite by
      construction. A model keyed to flatness would iron the sleeves, because a
      garment's rest shape is not flat.
    """

    details "Two measurement habits this forced", ~S"""
    **Instantaneous speed is not a settling metric.** The identical configuration
    reported a maximum vertex speed of 0.26 on one run and 1.78 on the next while
    its positions agreed to three hundredths of a millimetre. Under contact
    chatter the instantaneous value swings sevenfold between runs that are both
    converged. Settling is falling position drift over a window.

    **Damping is not monotone.** At 240 Hz a damping of 0.20 is ferocious enough
    that a hanging chain creeps quasi-statically and is still drifting 8.2 mm per
    half second after eight seconds, where the same chain at 0.05 swings to rest
    and reaches zero in seven. Overdamping does not settle cloth; it stops cloth
    from settling.
    """

    details "Verified, and not yet verified", ~S"""
    Cloth dropped on the real body holds zero vertices inside, with clearance
    steady at 3.63 mm, about two stacked coins, while position drift per half
    second falls 221 mm, 55, 44, 20, 5.2, 0.125.

    Not yet done: the triangle membrane constraint is unwritten, so the cloth
    resists stretch along its edges and folding at its hinges but not shear. The
    real garment has not been draped; only a test square has.
    """

    details "Retracted claims", ~S"""
    **"`contact.dist` is the cloth's penetration depth."** It is not, for a cloth
    element contact. A garment verified outside every collider by at least
    4.55 mm, in agreement with the body surface, still reported 43 contacts at
    "worst -60.31 mm". Every penetration figure taken from that field measured
    something else. The real starting overlap, measured against the body: 74
    vertices inside, worst 45.9 mm.

    **"The convex pieces bridge the concavities."** Only the eleven-piece
    decomposition did, on 12 vertices. At 72 and 196 pieces they call inside
    exactly the same 74 vertices the body does, at the same depths.

    **"A deeply infeasible start is what diverges."** It is not. A start verified
    clear still diverged on its first step with contact and gravity both switched
    off. The cause is strain: a push that is smooth in displacement can be
    violent in strain, 1,732 percent on one 3.42 mm edge, and an elastic model
    integrates strain.
    """

    related ~S"""
    RFD 2248 (the body as a closed solid, which the contact query depends on),
    RFD 2247 (property testing). `AvbdSolver.h`, `PERF_FINDINGS.md`,
    `Tools/rig/avbd.py`.
    """

    drafted_by :ai
  end
end
