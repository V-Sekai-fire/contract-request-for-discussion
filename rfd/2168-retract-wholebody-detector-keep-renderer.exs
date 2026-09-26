# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2168. `mix rfd.render` renders rfd/2168-retract-wholebody-detector-keep-renderer/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2168 do
  use RFD.DSL

  rfd 2168, "Retract RFD 1122's bespoke wholebody detector; keep the renderer" do
    state :published

    feature "documentation retraction"

    scope "`rfd/1122-the-wholebody-gap`"

    decision ~S"""
    Retract RFD 1122 (wholebody detector); keep its renderer-first rule and let successor RFDs
    carry deployment. RFD 1122 moves to `abandoned` alongside this document landing.
    """

    problem ~S"""
    RFD 1122 proposed rendering ANNY (the reference rig) to train a 104-point keypoint detector,
    then deploying it. RFD 1143 (propose-score loop, published), RFD 1168 (layer segmentation,
    ideation), and RFD 1173 (edit-reward corpus, discussion) settled the deployment differently,
    so RFD 1122's `discussion` state stopped tracking reality.
    """

    section "What survives", ~S"""
    - Renderer-first, RFD 1122 rule 1. ANNY is posed and photographed; joints come out of camera
    arithmetic. RFD 1143 uses it as the render leg of its propose loop.
    - Two-scorer discipline. RFD 1143 committed EditScore plus Referee, because a fit that looks
    right while the joints are wrong passes the first alone.
    - Renderer as comparison, not detector target. RFD 1173's MaskScore (edit-reward corpus)
    scores generations by comparing renders to targets. No 104-point head trains on the renders.

    Retracted: train a 104-point head on rendered ANNY (RFD 1168 moves layer segmentation into the
    3D latent via rf-detr-Seg), and the wholebody-detector deployment premise. ANNY is the pose
    primitive throughout, propose through score.
    """

    related ~S"""
    Retracts: urn:oid:1.3.6.1.4.1.66606.1.1.1122
    Superseded by: urn:oid:1.3.6.1.4.1.66606.1.1.{1143,1168,1173}
    """

    drafted_by :ai
  end
end
