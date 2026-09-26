# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2254. `mix rfd.render` renders rfd/2254-order-independent-transparency-for-cad/README.md
# and DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2254 do
  use RFD.DSL

  rfd 2254, "order-independent transparency for computer-aided design" do
    state :prediscussion

    feature "Mix-blended surfaces composite in any draw order on the
Mobile and Forward+ renderers, so a CAD assembly with parts
turned transparent reads correctly from every angle"

    scope "`entities-godot` branch `feat/oit-avboit` (PR #110);
`4-entities/order-independent-transparency`, the project that
checks it"

    decision ~S"""
    The engine patch exists so that computer-aided design can turn
    parts transparent. A ghosted housing over a gear train, a curve
    net drawn inside the solid it defines: the parts nest and
    interpenetrate, and no order of meshes is correct for all of
    them at once. The patch composites through a froxel
    transmittance grid (Drobot, SIGGRAPH 2025) and the order stops
    mattering. Hair is not the reason; the hair cap in the project
    repository is a stress fixture, and DETAILS.md says why.
    """

    problem ~S"""
    A per-mesh sort cannot keep an inner part and its housing in the
    right relation: they overlap in depth, so whichever draws second
    is wrong somewhere on screen. Smoke, cloth sleeves and any two
    intersecting surfaces fail the same way.
    """

    related ~S"""
    - RFD 1033 (geometric algorithms), the curve-net and solid
      operators whose result this view shows.
    - RFD 2247 (property testing), the doctest-and-witness shape
      of the patch's tests.
    - RFD 2216 (Three.js blocklist), why this is in the engine and
      not in a viewer.
    """

    drafted_by :ai

    details_title "order-independent transparency for computer-aided design"

    details "What is shipped", ~S"""
    An engine patch on `entities-godot`, not a module: the splat pass
    lives inside the scene shader as a pass mode, and the froxel
    buffers, the integrate dispatch and the fullscreen resolve are
    one effect shared by the Mobile and Forward+ renderers. A project
    setting turns it on. Surfaces with a blend mode other than Mix,
    and every surface under the Compatibility renderer, keep sorted
    blending.

    The math is pinned in Lean 4 first, in
    `4-entities/order-independent-transparency/lean/Oit/`, and the
    engine's `oit_math.h` is held to it by doctest cases and a
    witness-cpp ladder, with an FNV-1a hash over 4096 quantised rows
    that both sides carry as one literal. A hand edit to either side
    fails one command.
    """

    details "What is measured", ~S"""
    `checks/run.sh` in the project repository captures each scene
    with OIT on and off, sorted and scrambled, on both renderers, in
    mono and stereo, at one sample and at 4x MSAA, and counts the
    pixels that differ by more than 3 of 255.

    | run | parity band | order band | control |
    | --- | --- | --- | --- |
    | Mobile, box stack | 710 of 400,000 | 0 | planted scramble caught |
    | Mobile, box stack, 4x MSAA | 1,701 of 400,000 | 0 | occluded window caught |
    | Mobile, hair cap | 33,042 of 400,000 | 0 | planted scramble caught |
    | Forward+, box stack | 745 of 400,000 | 0 | planted scramble caught |
    | Forward+, box stack, 4x MSAA | 844 of 400,000 | 0 | occluded window caught |
    | Forward+, hair cap | 32,858 of 400,000 | 0 | planted scramble caught |

    The parity band is the froxel column's 6-pixel bleed across a
    silhouette, bounded and counted rather than hidden. Mobile
    accumulates at one sample under MSAA, so its edge band doubles;
    Forward+ accumulates at the full sample count and its band does
    not. The order band is the number that matters for CAD: with OIT
    on, scrambling the draw order changes no pixel.
    """

    details "Why hair is the fixture and not the reason", ~S"""
    Transparent hair cards are hard on the art side: too few layers
    expose the scalp, cards intersect, and the result convinces only
    when a practised artist made it. A person building an avatar for
    a social platform cannot carry the feature across either. The
    hair cap stays in `scenes/hair.tscn` because its 33,042
    silhouette pixels find defects the box stack does not; nothing
    ships it.
    """

    details "What it costs on the headset", ~S"""
    Transparency is expensive on a mobile tile renderer, and the
    froxel grid adds a splat pass, an integrate dispatch and a
    resolve over it. The Mobile port is the target because the
    drawing tools run there; the cost is measured on the device
    before a CAD scene ships with the setting on, and a scene that
    cannot afford it turns the parts opaque rather than sorting them.
    """
  end
end
