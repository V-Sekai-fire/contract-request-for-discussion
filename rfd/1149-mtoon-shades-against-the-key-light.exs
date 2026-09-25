# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 1149. `mix rfd.render` renders rfd/1149-mtoon-shades-against-the-key-light/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD1149 do
  use RFD.DSL

  rfd 1149, "MToon shades against the key light" do
    state :discussion

    feature "the toon material and how it renders"

    scope "`6-datasource/anny-render-corpus/mtoon.py`,
`mtoon_forward.py`, `mtoon.slang`, `check_mtoon_reference.py`"

    attest_in :none

    decision ~S"""
    The model is `VRMC_materials_mtoon-1.0`, rendered by a forward
    integrator that shades every hit against the key light with a shadow
    ray. In Dr.Jit ops it widens under `llvm_ad_rgb`, so the forward path
    is both correct and faster than the deferred one it replaced: 40.6 ns
    per pixel against 62.2, with shadows the deferred path had dropped.

    The port is held against `@pixiv/three-vrm` pixel for pixel rather
    than trusted because it was transcribed from the spec.
    """

    problem ~S"""
    The corpus needs an anime material beside its photographic one, and
    MToon is what VRM avatars carry. Bound as a Mitsuba BSDF it rendered
    lit-colour-to-black: the shade colour never reached film.

    MToon paints shade where `dot(N, L) < 0`, and a physically based
    integrator contributes nothing there because the light sits below the
    horizon. Its ramp reads THE key light rather than each sampled
    direction, which exceeds what a BSDF interface expresses. Rendering
    `lit == shade` and `lit != shade` gave matching images, which settled
    it by measurement rather than by argument.
    """

    references ~S"""
    - `DETAILS.md` carries the measurements and the factor of pi.
      `SKILL.md` is the procedure for holding a port against a reference.
    """

    related ~S"""
    RFD 1150 decides the shade colour. RFD 1141 sends artifacts to
    Hugging Face.
    """

    details_title "MToon shades against the key light"

    details "Held against three-vrm, pixel for pixel", ~S"""
    A unit sphere under an orthographic camera framed exactly to it, so pixel (u, v) carries
    normal (u, v, sqrt(1, u^2, v^2)). No plateau finding and no fitting: our model is evaluated
    at precisely the normal the render used. three 0.185.1, three-vrm 3.5.5, headless Chromium
    through swiftshader, colour management off and the output colour space linear.

    After dividing ours by pi:

    | shadingToonyFactor | px compared | over 4/255 | p99 | max |
    | ------------------ | ----------- | ---------- | ------ | ------ |
    | 0.9 | 3048 | 0 | 0.0020 | 0.0025 |
    | 0.5 | 3048 | 0 | 0.0020 | 0.0021 |
    | 0.0 | 3048 | 0 | 0.0020 | 0.0021 |
    | 1.0 | 3048 | 2 | 0.0018 | 0.1351 |

    One 8-bit readback step is 0.0039, so three of the four agree below the noise floor of the
    measurement. The two pixels at a hard ramp are the terminator rather than the model: the
    sphere's tessellated normal disagrees with the analytic one by a hair and the step turns that
    into the whole base-to-shade gap, which over pi is 0.1337 against the 0.1351 measured.
    """

    details "The factor of pi, and which side is the outlier", ~S"""
    Unscaled, theirs over ours is a near-constant 0.3167 to 0.3183 against 1/pi = 0.31831, flat
    across every toony value, which is a uniform scale rather than a difference in shape.

    Two independent implementations apply it by two different mechanisms. V-Sekai's Godot port
    writes `vec3 lighting = lightColor / 3.14159;` into `mtoon_common.gdshaderinc:156` by hand,
    and three-vrm inherits `RECIPROCAL_PI * diffuseColor` from three.js. The VRM 1.0 pseudocode
    ends `color = color * lightColor` with no such term, so it is the spec text that omits what
    every renderer does rather than a convention either engine invented.

    A tone ladder feels this. CIELAB scales non-linearly, so one material at two exposures gives
    two dE readings, and the targets have yet to be checked at the exposure a viewer uses.
    """

    details "VRM0 and VRM1.0 are different parameterisations", ~S"""
    The Godot port implements MToon 3.3, whose ramp is

        clamp((I, shadeShift) / (mix(1, shadeShift, shadeToony), shadeShift), 0, 1)

    and VRM 1.0 uses `linearstep(-1 + shadingToonyFactor, 1, shadingToonyFactor, ...)`. `mtoon.py`
    targeted the VRM0 form for one commit and now implements VRM1.0. A difference worth naming
    because it silently inverts a term: VRM0 lerps the rim toward BLACK as `rimLightingMix` falls
    and VRM1.0 lerps toward WHITE, so `rimLightingMixFactor` 0 leaves the rim at full strength.
    """

    details "What a deferred G-buffer cost", ~S"""
    | approach | ns/px | 4K frame | shadows |
    | --- | ---: | ---: | :---: |
    | Python forward, scalar_rgb | 102,000 | 848 s | yes |
    | deferred G-buffer plus a Slang kernel | 62.2 | 0.516 s | **no** |
    | wide forward, Dr.Jit, llvm_ad_rgb | 40.6 | 0.337 s | yes |

    The deferred path silently dropped the shadow ray, which is the whole reason the test shape is
    an abacus rather than a sphere: a convex shape cannot occlude itself. So it was slower AND
    lost
    the thing the shape was chosen for.
    """

    details "What the Slang kernel bought", ~S"""
    `mtoon.slang` compiles to C++ and agrees with `mtoon.py` to 7e-08 against a float32 epsilon of
    1.19e-07, which chains the validation to three-vrm through two differentials.

    The forward integrator shades faster, so the kernel packs frames instead. The win there came
    from the wrapper: Slang's CPU target emits scalar code and one call runs every thread group
    serially:

        original pow, numpy float64   0.520 s per 4K frame
        numpy lookup table            0.231
        Slang, one thread             0.221
        Slang, group range threaded   0.062

    Against a lookup table the kernel alone bought 4 per cent. Splitting the group range across
    cores bought 3.8x, which belongs to the wrapper rather than to Slang.
    """

    details "Left unmeasured", ~S"""
    Whether the tone targets hold at the exposure a viewer uses, given the factor of pi.
    `giEqualizationFactor`, which the model does not carry and the comparison set to zero.
    Shadowing against three-vrm, where shadow maps and ray-traced occlusion legitimately differ,
    so a per-pixel comparison measures the difference between two renderers.
    """

    drafted_by :ai
  end
end
