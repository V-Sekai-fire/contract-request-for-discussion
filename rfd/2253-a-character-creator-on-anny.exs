# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2253. `mix rfd.render` renders rfd/2253-a-character-creator-on-anny/README.md
# and DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2253 do
  use RFD.DSL

  rfd 2253, "a character creator on ANNY" do
    state :prediscussion

    feature "a character creator a person opens: sliders over the baked ANNY
asset in the one Godot binary, exporting the shuttle that
RFD 2251's chain consumes"

    scope "`4-entities/anny-creator`, a Godot project the RFD 2239 binary runs;
the baked ANNY asset; RFD 2251's `rig` through `render`"

    decision ~S"""
    The creator is RFD 2251's second front door: where 2251 hands the
    chain a generated body, a person sets 948 target weights on the
    baked ANNY asset. Six phenotype axes, 52 facial actions under
    FACS action-unit numbers, 254 signed local dials by body region.
    Joints follow the shape through ANNY's own joint tables.
    `rig` through `render` are 2251's blocks, unchanged. Export is
    pure data: morph targets, skin weights, one humanoid bone map.
    """

    problem ~S"""
    VRoid Studio is proprietary, MakeHuman is ageing, SMPL is
    non-commercial; a person wanting a permissive parametric human has
    no creator to open. Every part of one is here: the model, the
    joint tables, the anthropometry tables, a slider demo in the
    Python the runtime forbids. Nothing joins them into a thing used.
    """

    related ~S"""
    - [RFD 2251](../2251-image-to-godot-character-as-an-fbd/): the chain
      this creator feeds; its `assemble` block is the seam.
    - [RFD 2239](../2239-traits-and-one-binary/): the binary the creator
      runs in; nothing at runtime reaches Python.
    - [RFD 2244](../2244-one-deformation-operator/): a slider is a static
      target weight over ANNY corners and nothing else.
    """

    details_title "a character creator on ANNY"

    details "This RFD was drafted by an AI and read by a human before it shipped.", ~S"""
    Drafted 2026-09-15 from a survey of the RFD corpus and the tree,
    after the operator asked for work whose payoff lands with people
    outside the workspace and pointed at RFD 2251 as the thing to
    build on. The seam with 2251 is the operator's call; the slider
    math and the check list are the AI's proposal.
    """

    details "Who it is for", ~S"""
    A VTuber, an indie developer, an artist or a researcher who wants
    a rigged, expressive human they may ship commercially. Today that
    person picks between a proprietary creator, a Python creator whose
    community has thinned, and a body model whose licence forbids the
    shipping. ANNY is Apache-2.0 and descends from the MakeHuman
    targets, so the permissive parametric human already exists as a
    model. It does not exist as a thing a person opens, and a creator
    is the kind of tool that is opened for a decade once it is good.
    """

    details "What exists, by path", ~S"""
    Every ingredient is in the tree. The creator is the join.

    | ingredient | path | what it gives the creator |
    | --- | --- | --- |
    | baked asset | `4-entities/anny-creator/tools/bake_anny.py`, run once under the `bake` pixi environment | the `anny` topology at 13,718 vertices and 27,420 triangles, 104 joints, 8 of 9 influences kept (2 vertices lose a 0.001 weight), 948 morph targets in one 64 MB glb |
    | phenotype math | `3-interactor/anny/src/anny/models/phenotype.py`, `utils/interpolation.py` | six free axes over 17 anchor slots; race, cup and firmness are constants folded into the bake |
    | joint tables | `3-interactor/anny/src/anny/data/cached/anny.pth`, read by the bake | per-target joint head deltas and orientation-matrix deltas, linear in the same coefficients |
    | facial actions | `3-interactor/anny/src/anny/data/faceunits01/targets/faceunits/` | 52 targets, computed as deltas by `compute_blendshape_targets.py` |
    | local dials | `3-interactor/anny/src/anny/data/mpfb2/targets/` | 254 targets grouped by body region |
    | partition proofs | `2-contract/hm08-partition` | `body`, `HelperGeometry`, `JointCubes` partition the mesh with no gap; Lean 4, no `sorry` |
    | keypoint anchors | `2-contract/anny-keypoint-anchors` | 133 COCO-WholeBody anchors, for a later image front door |
    | anthropometry | `6-datasource/starforged-std-3001-appendix-e`, `human` config | percentile spans for presets |
    | slider reference | `3-interactor/anny/src/anny/examples/interactive_demo.py` | 740 lines of Gradio with GLB export: the parameter math to port, never to run |
    | runtime | `4-entities/godot-rfd-2251-fire` | the binary with `skin_tokens`, `kimodo`, `pixal3d`, `llm`, `motion_bricks` |
    """

    details "The slider math", ~S"""
    Three kinds of control, one operator underneath (RFD 2244).

    A phenotype axis is a scalar in [0, 1]. ANNY resolves it to
    weights over that axis's anchors by piecewise-linear
    interpolation (`linear_interpolation_coefficients`; age anchors
    run from a third below zero to one), and the weight on a macro
    target is the product of the anchor weights its name carries:
    four factors for a `universal` target, five for `height` and
    `proportions`. The bake folds the constant race, cup and firmness
    slots in and merges rows that share a free pattern, leaving 388
    macro targets. `scripts/anny_coeffs.gd` is the port, checked
    against the Python model on 20 seeded parameter vectors before a
    slider is trusted.

    A facial action and a local dial are direct target weights. The
    creator groups the 254 dials by the body region ANNY's target
    index files them under, so the panel reads as head, torso, arms,
    legs, hands and feet rather than as a list of 254 names.

    ANNY's `anny` rig does not read the JointCubes; that is the
    `makehuman` rig's strategy. It carries, for every target, a delta
    on each joint head and a delta on a per-joint 3x3 matrix whose
    nearest rotation is the joint's rest orientation, both linear in
    the same coefficient vector the mesh uses. The bake writes those
    tables beside the glb and `scripts/anny_rig.gd` evaluates them
    (polar iteration for the nearest rotation), then writes bone
    rests and the matching skin bind poses. The creator never authors
    a joint position, so a slider moves the skeleton with the skin,
    which is the property a creator needs and a static rig lacks.
    """

    details "The seam with RFD 2251", ~S"""
    RFD 2251's `prepare_reference`, `generate_part` and `assemble`
    produce a body from an image. The creator produces a body from a
    person, and hands the chain the same thing those three blocks do:
    one scene with a mesh the later blocks can rig, express, animate
    and render. `rig` finds a skeleton already bound, so it retargets
    rather than solves. `expressions` finds the 52 targets on the
    head. `animate` and `render` do not know which front door was
    used, and that is the test that the seam is in the right place.

    Export follows the deployment rule: the glTF carries morph
    targets, skin weights and animation samplers, and the VRM 1.0
    extension carries the humanoid bone map from ANNY's joints. No
    driver, no constraint, no runtime script rides in the file. The
    route to the VRM bytes is RFD 2213's sandboxed writer when it
    lands and a direct extension write until then.
    """

    details "What is measured before it ships", ~S"""
    | check | pass condition | control |
    | --- | --- | --- |
    | slider parity | for 20 seeded parameter vectors, the ported shape and the Python model agree at every vertex within the asset's own glb round-trip error | a deliberately mis-ordered anchor table must fail |
    | joints follow shape | every joint sits at its cube centroid after any slider move | a planted cube range one vertex short must fail |
    | pure-data export | the exported glTF parses with no extension outside `KHR_*` and `VRMC_*`, and no node carries a script | a file with one driver added must fail |
    | presets hit the table | the 5th, 50th and 95th percentile stature presets land within a stated tolerance of the Appendix E `human` rows | a preset built from the fictional config must fail |
    | topology pinned | the loaded asset has 13,718 vertices, 27,420 triangles and 104 bones, the `anny` topology; the SMPL-X interop topology is never baked | an asset at the SMPL-X vertex count must fail |

    A tolerance is stated in millimetres and in a household object
    when the check is written, not here, because the asset's
    round-trip error is measured at that point rather than assumed.
    """

    details "Names that stay out of the artifact", ~S"""
    ANNY's 52 facial-action labels are the convention name of a
    proprietary blendshape set, which the working agreements block
    from shipping artifacts. The creator's panel, its export and its
    documentation use FACS action-unit numbers. The source labels
    stay in the source, where they are NAVER's to keep.
    """

    details "What this RFD does not decide", ~S"""
    Clothing: dress-on (RFD 2234) is a corpus pipeline today and a
    creator garment panel later, on the same operator. Hair, which
    the fixture does not carry. A web build: three.js and WebGPU are
    blocklisted, so a browser form means the engine's own web export
    and is a separate decision. The image front door: RFD 2251 owns
    it, and the keypoint anchors are the bridge when it is wanted.
    """
  end
end
