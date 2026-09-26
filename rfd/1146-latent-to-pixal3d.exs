# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 1146. `mix rfd.render` renders rfd/1146-latent-to-pixal3d/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD1146 do
  use RFD.DSL

  rfd 1146, "The latent-to-Pixal3D loop" do
    state :published

    feature "loop 4 of the four-loop plan"

    scope "`fourloops-plan.usda`"

    attest_in :none

    decision ~S"""
    Build it, and treat the router as uncalibrated until measured.

    The statistic is spread over mean, and a spread above 0.15 selects the
    latent arm. `routerCalibrated` is 0 in the plan, so that threshold is a
    starting value rather than a result. A router that picks the wrong arm
    produces a repair that cannot help, and the loop still terminates.

    **The hazard is an arm that cannot take what the loop holds.**
    VoxHammer raises `NotImplementedError` outside stub mode, and it takes
    a mesh where the loop carries a latent. So the arm passes through
    `/extract` first, and a route that skips that step fails inside the
    tool rather than at the boundary.
    """

    problem ~S"""
    Loop 4 is the only one that leaves the image plane. Pixal3D proposes a
    latent state, then views, then a glb; EditScore scores; and the repair
    arm forks between VoxHammer and OmniGen2. At size XL it is the largest
    of the four, and it is the only loop with a router.

    The router decides which repair arm runs, and it decides on a statistic
    nobody has calibrated.
    """

    related ~S"""
    RFD 1143, RFD 1144 and RFD 1145 are the other three loops. RFD 1122 is
    the goal, and RFD 1132 lists what converts.
    """

    drafted_by :ai
  end
end
