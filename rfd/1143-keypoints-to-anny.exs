# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 1143. `mix rfd.render` renders rfd/1143-keypoints-to-anny/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD1143 do
  use RFD.DSL

  rfd 1143, "The keypoints-to-ANNY loop" do
    state :published

    feature "loop 1 of the four-loop plan"

    scope "`fourloops-plan.usda`"

    attest_in :none

    decision ~S"""
    Propose with Keypoints, AnnyFit and Render; score with EditScore and
    the Referee; repair by refitting. The artifact is a render png. It is
    the largest of the four at size L, and it runs fourth in the task order
    because the harness comes first.

    Two scorers rather than one, because they answer different questions.
    EditScore reads the image and the Referee reads the body, and a fit
    that looks right while the joints are wrong passes the first alone.

    **The hazard is the joint count.** The detector emits 17 keypoints and
    the render asset emits 23. A comparison across those two takes an
    explicit subset, or it compares different things and reports a number
    for it. RFD 1122 records the same gap for the wholebody chain.
    """

    problem ~S"""
    `fourloops-plan.usda` carries four loops as prims, each with its
    stages, its artifact and one line of hazard. A prim holds the wiring
    and cannot hold the argument, so the reason a loop is shaped this way
    lived in a logbook entry that the plan named as a source.

    All four loops are wanted. What was missing is a document per loop:
    the plan holds the wiring for four, and one logbook entry held the
    argument for all of them. This RFD is loop 1's own.
    """

    related ~S"""
    RFD 1144, RFD 1145 and RFD 1146 are the other three loops. RFD 1122 is
    the goal, and `logbook-fourloops-first-runs.md` holds the first runs.
    """

    drafted_by :ai
  end
end
