# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2207. `mix rfd.render` renders rfd/2207-nord-palette-for-demos/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2207 do
  use RFD.DSL

  rfd 2207, "Nord palette (or peer) for shipped demos" do
    compact_head true

    state :discussion

    feature "shipped demos and artifacts pick a named FOSS design
palette (Nord as the default, Solarized / Catppuccin / Tokyo Night
/ Rose Pine / Gruvbox as acceptable peers) rather than the warm
amber-on-panel look that Claude artifacts default to"

    scope "every shipped browser demo under `7-service/*/docs/` and
every Artifact this workspace publishes as a deliverable; the same
rule does not bind private one-shot artifacts an operator uses to
inspect an intermediate"

    decision ~S"""
    A demo or artifact that ships as a reviewable surface picks one of
    the following six FOSS-licensed palettes verbatim and sources its
    tokens from that palette's published spec:

    `DETAILS.md` carries the full text of this RFD.
    """

    problem ~S"""
    The mid-session operator redirect that produced the Starforged
    demo's Nord palette was blunt: the warm-terminal look that
    Claude artifacts default to reads as an AI intermediate, not as a
    deliverable. A reviewer who opens a shipped demo and sees the
    default Claude look concludes, correctly, that nobody picked a
    palette. Picking one, any of the six above, closes that reading.
    """

    related ~S"""
    - RFD 2206 (video-call VRM portrait), the shipped surface this
      palette was first applied to.
    - Codebase: `7-service/service-sqlar-cas/docs/index.html`, the
      reference Nord application in this workspace.
    - CLAUDE.md's "Trademarks Stay Out of Shipping Artifacts" clause —
      the six palettes are all trademark-clean and named by their own
      project names.
    """

    details_title "Nord palette (or peer) for shipped demos"

    details "Applying Nord", ~S"""
    Nord defines 16 tokens across four groups (Polar Night, Snow
    Storm, Frost, Aurora). A shipped demo declares them as CSS custom
    properties on `:root` with dark values, then overrides them under
    `:root[data-theme="light"]` with the Snow Storm-anchored light
    variant. `prefers-color-scheme: dark` is a media query on top of
    the `:root` defaults so a viewer that never picked gets the dark
    values by default when their system prefers dark.

    `docs/index.html` is the reference application. Structure:

        :root {
          --nord0: #2E3440;   /* Polar Night, bg */
          --nord1: #3B4252;   /* Polar Night, panel */
          --nord4: #D8DEE9;   /* Snow Storm, fg */
          --nord7: #8FBCBB;   /* Frost, accent 1 */
          --nord8: #88C0D0;   /* Frost, accent 2 */
          --nord11: #BF616A;  /* Aurora, danger */
          --nord14: #A3BE8C;  /* Aurora, success */
          /* … */
        }
        :root[data-theme="light"] {
          --nord0: #ECEFF4;
          --nord4: #2E3440;
          /* … */
        }

    Every surface pulls from these tokens; no hex literal appears
    outside `:root`.
    """

    details "Why not name a single palette", ~S"""
    Two failure modes, both cheaper to close with a peer list than
    with a rewrite later:

    1. **Subject-matter mismatch.** A demo whose subject is a
       parchment interface reads uncanny in Nord's cool blues; Gruvbox's
       warm palette reads correctly. A palette-of-one rule would force
       the demo author to choose between the rule and the demo reading
       right.
    2. **Reader accessibility.** Different palettes carry different
       contrast profiles; a reader with a specific accessibility
       preference is better served by *some* named palette than by any
       one particular one.

    Both close by naming the shape of the choice ("pick a named FOSS
    design palette") rather than the choice itself.
    """

    details "Verification", ~S"""
    The QA runner at `7-service/service-sqlar-cas/scripts/qa_demo.mjs`
    extends to grep the shipped `docs/*.html` and `docs/*.css` for
    raw hex-color literals outside the `:root` declaration. Every
    match is either a token definition or a defect. Negative control:
    a planted `color: #ff0000` in a rule body fails the grep.
    """

    details "Related retractions", ~S"""
    None. Prior demos in `7-service/service-sqlar-cas/docs/` shipped
    under the un-tokenised default; this RFD retires that default
    prospectively for new work and any material redraft.
    """

    details "From the README, moved here on 2026-09-07", ""

    details "Decision", ~S"""
    A demo or artifact that ships as a reviewable surface picks one of
    the following six FOSS-licensed palettes verbatim and sources its
    tokens from that palette's published spec:

    | palette | licence | source |
    |---|---|---|
    | Nord | MIT | nordtheme.com |
    | Solarized | MIT | ethanschoonover.com/solarized |
    | Catppuccin | MIT | catppuccin.com |
    | Tokyo Night | MIT | github.com/enkia/tokyo-night-vscode-theme |
    | Rose Pine | MIT | rosepinetheme.com |
    | Gruvbox | MIT | github.com/morhetz/gruvbox |

    Nord is the default this session's Starforged surface adopted and
    what a new demo picks in the absence of a reason to pick otherwise.
    The five peers are named so the choice is not hardcoded to one
    system, a demo whose subject matter reads better in warm tones can
    pick Gruvbox; a demo tuned for a night-shift reader can pick Tokyo
    Night. What is banned is the un-tokenised amber-on-panel default
    that a first-draft artifact carries when nothing was picked.

    Both light and dark variants are declared. `data-theme="dark"` and
    `data-theme="light"` on the root, plus a `prefers-color-scheme`
    media query, per the artifact-design contract.
    """

    details "Problem", ~S"""
    The mid-session operator redirect that produced the Starforged
    demo's Nord palette was blunt: the warm-terminal look that
    Claude artifacts default to reads as an AI intermediate, not as a
    deliverable. A reviewer who opens a shipped demo and sees the
    default Claude look concludes, correctly, that nobody picked a
    palette. Picking one, any of the six above, closes that reading.

    The rule is about *picking* rather than about *which one*. What the
    existing default fails at is being un-considered; the six peers all
    pass by virtue of being considered and readable.
    """

    details "Non-goals", ~S"""
    Not a component library or a spacing/typography spec. Not a
    mandate to reskin dot-claude, existing internal tooling, or
    operator-private artifacts. Not a mandate that every demo pick
    Nord specifically, the peers exist for cases where a different
    palette reads better on the subject.
    """

    details "Related", ~S"""
    - RFD 2206 (video-call VRM portrait), the shipped surface this
      palette was first applied to.
    - Codebase: `7-service/service-sqlar-cas/docs/index.html`, the
      reference Nord application in this workspace.
    - CLAUDE.md's "Trademarks Stay Out of Shipping Artifacts" clause —
      the six palettes are all trademark-clean and named by their own
      project names.
    """

    drafted_by :ai
  end
end
