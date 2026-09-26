# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2264. `mix rfd.render` renders rfd/2264-mesh-repair-by-voxel-remesh/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2264 do
  use RFD.DSL

  rfd 2264, "Mesh repair by voxel remesh" do
    state :discussion

    flight_level :l1

    feature "a watertight garment-and-body mesh, so the closed-solid tests of
RFD 2248 and the winding-number contact of RFD 2249 have an answer"

    scope "the mesh-repair step between garment generation and cloth drape, on
`2-contract/meshoptimizer`"

    decision ~S"""
    Repair the generated mesh by voxel remesh before the drape. meshoptimizer's
    remesher (MIT, placed at `2-contract/meshoptimizer`) samples the input into
    a signed distance field and marches one watertight manifold out of it, so a
    hole, a non-manifold edge and a self-intersection in the input become
    interior detail that the output does not carry.

    This is the operator that establishes RFD 2248's contract rather than
    assuming it: a body or garment that entered as an open surface leaves as a
    closed solid a point-in-solid test can read. VoxHammer edits the mesh (RFD
    2234) and this repairs the edit, so the two are a pass and its guard, not
    the same step.
    """

    problem ~S"""
    A garment lifted by VoxHammer and a surface skinned from pen strokes both
    arrive with holes, non-manifold edges and self-intersections. RFD 2248 asks
    whether a point is inside the body and RFD 2249 queries contact by
    generalised winding number, and neither has an answer on such a mesh. A
    drape run on it reads penetration and coverage against a body that does not
    say where its inside is.
    """

    related ~S"""
    - RFD 2234 (the dress-on pipeline) produces the mesh this repairs.
    - RFD 2248 (the body is a closed solid) is the contract this establishes.
    - RFD 2249 (cloth by vertex block descent) is the drape downstream of it.
    - RFD 2263 (the Skateboard's simulator gate) is the loop all four ride.
    """

    drafted_by :ai
  end
end
