# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2163. `mix rfd.render` renders rfd/2163-maskscore-text-stub-gemma-vlm/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2163 do
  use RFD.DSL

  rfd 2163, "MaskScore Text-stub emit via Gemma VLM on frame pairs" do
    state :discussion

    flight_level :l1

    feature "MaskScore Text stub filled by prompting Gemma-4-12B on
each (frame_a, frame_b) render pair. The instruction column becomes a
model-devised description of the observed edit, ranked into 10
candidates per the RFD 1173 gradient scheme."

    scope "`6-datasource/anny-render-corpus`"

    preamble ~S"""
    Shelved 2026-09-02: no VLM inference budget this cycle for 15 A/B
    render pairs through Gemma-4-12B; resume when local compute frees.
    """

    decision ~S"""
    Loop `llama-mtmd-cli` from RFD 1173.2164's build against both
    frames of every edit (15 total). Prompt is fixed; provenance JSON
    records model SHA, prompt SHA, image SHAs, temperature 0, seed 0.

    Emit 10 rank candidates per edit as in RFD 1173.2164:

      rank1  canonical VLM description
      rank2..6  paraphrase gradient (Gemma-generated distortion prompts)
      rank7..8  describes wrong part (weak/strong)
      rank9..10  describes different edit or nonsense
    """

    problem ~S"""
    The Rung 1.5 five-stub emit left the Text stub unfilled. The initial
    plan used a fixed part vocabulary from See-Through's
    `bodytags_v3.json`. That was retracted in favour of a
    model-devised taxonomy: Gemma looks at the render pair and describes
    the change in its own words. No fixed part vocabulary is applied.
    """

    related ~S"""
    Spine: urn:oid:1.3.6.1.4.1.66606.1.1.1173 (MaskScore).
    Requires urn:oid:1.3.6.1.4.1.66606.1.2.2164.1 (llama.cpp build).
    """

    drafted_by :ai
  end
end
