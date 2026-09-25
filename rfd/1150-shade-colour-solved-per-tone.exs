# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 1150. `mix rfd.render` renders rfd/1150-shade-colour-solved-per-tone/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD1150 do
  use RFD.DSL

  rfd 1150, "Shade colour is solved per tone, not multiplied" do
    state :discussion

    feature "skin tone equity in a toon material"

    scope "`6-datasource/anny-render-corpus/anime_materials.usda`,
`check_anime_materials.py`, `anime-materials.cff`"

    attest_in :none

    decision ~S"""
    The multiplier is solved per tone to hold the separation at dE 12.
    `anime_materials.usda` stores the tone identities and the target and
    nothing else, because the multiplier, the shade colour and the achieved
    separation all follow from those.

    The dark end is bounded and reported rather than clamped: dE 12 at Monk
    10 needs shade L\* 2.9, and the gate prints what each tone reached.

    Applying a scale defined on photographs of real skin to a toon material
    is a substitution, recorded as one. No anime skin-tone standard exists.
    """

    problem ~S"""
    MToon extends glTF `pbrMetallicRoughness` rather than replacing it, so
    the lit colour is `baseColorFactor` and the extension adds a shade
    colour nothing in PBR constrains. Somebody has to choose it.

    The obvious choice, one multiplier for every tone, fails on equity.
    At `x0.6` the lit-to-shade separation is dE 17.28 at Monk 1
    and dE 4.83 at Monk 10, a factor of 3.6. The terminator is the shading
    cue a detector reads, so one multiplier builds a detection gap into the
    corpus that would later present as a model defect.
    """

    references ~S"""
    - `DETAILS.md` carries the ladder and the solved multipliers.
    """

    related ~S"""
    RFD 1149 gives the material. RFD 1151 decides which axes are weighted.
    """

    details_title "Shade colour is solved per tone, not multiplied"

    details "The flat multiplier, measured", ~S"""
    | Monk | lit L\* | shade L\* at x0.6 | dE | solved multiplier for dE 12 |
    | ---: | ---: | ---: | ---: | ---: |
    | 1 | 94.2 | 77.0 | 17.28 | x0.7080 |
    | 3 | 93.1 | 76.0 | 17.22 | x0.7072 |
    | 5 | 77.9 | 63.2 | 15.15 | x0.6722 |
    | 7 | 42.5 | 33.3 | 9.89 | x0.5316 |
    | 9 | 21.1 | 15.3 | 5.89 | x0.3166 |
    | 10 | 14.6 | 9.8 | 4.83 | x0.1770 |

    One multiplier spans dE 4.83 to 17.28, a factor of 3.6. Equal RATIO gives unequal CONTRAST,
    because CIELAB scales non-linearly in reflectance.
    """

    details "Nothing derivable is stored", ~S"""
    `anime_materials.usda` carries the ten tone identities and `targetDeltaE` and nothing else.
    The multiplier, the shade colour and the achieved separation are all functions of those, so
    `check_anime_materials.py` re-derives them and the layer cannot drift from the solver.

    Five controls. Three reject: a scale missing tones, an unreachable target silently clamped,
    and a LIGHT-ONLY scale, which is rejected as certifying nothing. A flat multiplier looks fine
    when the dark end is absent, and that is how a corpus certifies an equity it never tested.
    """

    details "The dark end is bounded", ~S"""
    Holding dE at 12 needs shade L\* 2.9 at Monk 10, which is near black. The gate prints what
    each tone achieved rather than clamping, so a tone that cannot reach the target is visible.
    """

    details "The substitution, recorded", ~S"""
    The Monk scale is defined on photographs of real skin; anime skin is an artistic choice.
    Applying one to the other gives coverage of a perceptual range and claims nothing about a
    population.

    No anime skin-tone standard exists to use instead. Danbooru's tag group carries pale, fair,
    light, tan, dark, very dark and black skin with no colour values, defined against "the usual
    Eurasian skin tone", and its own forum records canonically dark-skinned characters being
    redrawn as tans. Its `alternate_skin_color` tag also confirms that characters with non-human
    skin have no Monk code and need a cell of their own.

    CIELAB at D65 is authoritative upstream and the sRGB hex this layer carries is the published
    conversion from it. That is a known substitution to replace with the CIELAB triple.
    """

    details "Left unmeasured", ~S"""
    The rendered dE at the exposure a viewer uses, which RFD 1149 records is pi times ours.
    Subsurface: a 2048 square `sss.png` ships with the basemesh and nothing binds it, so an
    albedo-only sweep understates how dark and light skin differ at a terminator.
    """

    drafted_by :ai
  end
end
