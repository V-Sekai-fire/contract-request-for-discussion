# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2165. `mix rfd.render` renders rfd/2165-maskscore-unified-8-stub-emit/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2165 do
  use RFD.DSL

  rfd 2165, "MaskScore unified 8-stub emit refactor" do
    state :discussion

    feature "one emit script covering all 8 MaskScore stubs (mesh,
depth, pose, keypoints, multimodal, text, speech, video) at 10 ranks
per candidate per edit, ETNF three-parquet form."

    scope "`6-datasource/anny-render-corpus`"

    preamble ~S"""
    Shelved 2026-09-02: 2165.1 (schema, #33) and 2165.2 (port 5 shipped
    stubs, #35) shipped; 2165.3 (speech+text+video port) and 2165.4 (HF
    republish) remain.
    """

    decision ~S"""
    Extend `maskscore_rung_1_stubs.py` with an unified schema:

      root         (key, task_type, dimension, input_column, input_asset,
                    input_asset_kind, poses)
      candidates   (row_key, candidate, rank, candidate_asset)
      scores       (row_key, candidate, view_index_or_frame,
                    metric_name, metric_value)

    `metric_name` is an interned vocabulary (depth_l1, normal_l1,
    normal_dot, wavlm_cos, wer, vlm_score). All 8 stubs share these three
    tables. Consumers join on row_key to sweep across modalities.
    """

    problem ~S"""
    The Rung 1.5 5-stub emit and each new stub's separate emit script
    share the same shape and could drift. Text (RFD 2163), speech (RFD
    2164) and video (part of RFD 2162) each land their own parquets.
    Cross-stub joins require a stable row_key convention and matching
    candidate-satellite schemas.
    """

    related ~S"""
    Spine: urn:oid:1.3.6.1.4.1.66606.1.1.1173 (MaskScore).
    Depends on urn:oid:1.3.6.1.4.1.66606.1.2.{2162,2163,2164} landing first.
    """

    drafted_by :ai
  end
end
