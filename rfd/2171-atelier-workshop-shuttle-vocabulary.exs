# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2171. `mix rfd.render` renders rfd/2171-atelier-workshop-shuttle-vocabulary/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2171 do
  use RFD.DSL

  rfd 2171, "The atelier-workshop / shuttle vocabulary" do
    front_matter ~S"""
    ---
    name: rfd-2171-atelier-workshop-shuttle-vocabulary
    description: When naming what the workspace makes (the pipeline) and what leaves it (the deliverable), use "atelier-workshop" and "shuttle". Never "atelier" alone. Never rename the shuttle after nx-shuttle's separate use of the same word.
    tools: Read, Write, Edit
    ---
    """

    state :committed

    feature "naming the pipeline and the deliverable"

    scope "public-facing prose, RFD titles, changelog entries"

    decision ~S"""
    The pipeline is `atelier-workshop`, the deliverable that leaves it is `shuttle`. One word for each, used verbatim in RFD titles, changelogs, and public prose.
    """

    problem ~S"""
    The public tagline names two things: the pipeline that makes characters, and the deliverable that leaves it. "Workshop" alone was doing both jobs and reads as generic. `nx-shuttle` already uses "shuttle" (carrying a graph across to another runtime, weft-across-warp). Without a settled vocabulary, prose drifts between studio, pipeline, workshop, atelier.
    """

    section "Details", ~S"""
    - `atelier-workshop` (the pipeline). The compound keeps the elegance of the French loanword for readers who know it, and the plain-English gloss for those who do not. RFD 2136 (gacha ladder: 10-rung generation pipeline) is the concrete atelier-workshop.
    - `shuttle` (the portable-character deliverable), a portable VRM at rung 6 of RFD 2136. Retained without change; `nx-shuttle` already uses it for the same weft-across-warp metaphor. The two uses do not conflict: one shuttles a character out, the other shuttles a graph across.

    Never use `atelier` alone in shipping prose (loanword, pretentious without the gloss). `Workshop` alone is permitted where context already fixes it (the 2021 `character-workshop` decision doc stays).
    """

    related ~S"""
    Spine: chibifire.com public tagline; RFD 2136 (gacha ladder).
    Applies to: this file and every subsequent public README.
    """

    drafted_by :ai
  end
end
