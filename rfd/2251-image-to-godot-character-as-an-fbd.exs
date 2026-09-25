# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2251. `mix rfd.render` renders rfd/2251-image-to-godot-character-as-an-fbd/README.md
# and DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2251 do
  use RFD.DSL

  rfd 2251, "image to godot character as an fbd" do
    state :discussion

    feature "a character-from-one-image workflow as an FBD the fbd
teacher (RFD 2236) emits, backed by tools already on the manifest,
running on the Godot binary of RFD 2239"

    scope "`taskweft-function-block-diagram-teacher` and `compiler`,
TRELLIS.2 and Pixal3D as parts generators, SkinTokens and ANNY as
rig, Godot with SceneTreeMCP as assembly and render"

    decision ~S"""
    Seven function blocks in the compiler's PLCopen subset:
    `prepare_reference`, `generate_part` (×3), `assemble`, `rig`,
    `expressions`, `animate`, `render`. Each block's contract is one
    workspace tool. Runtime is Godot over `SceneTreeMCP`. Input is
    one image; output is a VRM. First slice is body + head only.
    `DETAILS.md` carries the block table and the slice.
    """

    problem ~S"""
    Every tool exists; no glue turns one image into a rigged,
    animated character. Tripo3D's seven-step Astra workflow maps
    one-for-one onto our tools, and the mapping is an FBD.
    """

    related ~S"""
    - [RFD 1170](../1170-a-cleanroom-presence-loop/): the presence loop
      whose face-owner this character becomes.
    - [RFD 2236](../2236-fbd-teacher-in-three-steps/): the model that
      emits the FBD this workflow is written in.
    - [RFD 2239](../2239-traits-and-one-binary/): one Godot binary as
      the runtime; this workflow is a caller.
    - [RFD 2244](../2244-one-deformation-operator/): identity and fit
      collapse into one operator; the rig block calls that operator
      over the assembled part set.
    - Tripo3D's Astra workflow (upstream reference), read 2026-09-13,
      preserved as `apparatus/2251-image-to-godot-character/reference.pdf`.
    """

    details_title "image to godot character as an fbd"

    details "This RFD was drafted by an AI and read by a human before it shipped.", ~S"""
    Drafted from a screen-share of Tripo3D's post and a conversation
    with the operator on 2026-09-13. The mapping table below is the
    operator's decision, not the AI's.
    """

    details "The seven blocks", ~S"""
    Each row names a block, its input, its output, and the workspace
    tool that satisfies it. Every tool listed is already on the
    manifest; nothing new needs to land for the block to compile,
    only for the block to run end to end.

    | block | input | tool | output |
    | --- | --- | --- | --- |
    | `prepare_reference` | one image | operator; `interactor-omnigen2` for the three sub-crops (body, head, hair) | three reference PNGs plus the full reference |
    | `generate_part` × 3 | one reference PNG | `interactor-trellis2-image-to-textured-mesh` (body), `interactor-pixal3d-image-to-textured-mesh` (head, hair) | three textured GLBs |
    | `assemble` | three GLBs | `entities-godot` via `SceneTreeMCP`: spawn nodes, align head to body neck, align hair to scalp | one Godot scene, parts selectable |
    | `rig` | assembled scene | `interactor-skintokens-auto-rig` for a biped rig, or `interactor-anny` retarget when the body already carries ANNY topology | one skeleton, weights bound |
    | `expressions` | rigged head mesh | ANNY `data/faceunits01/` blendshapes (FACS action units), attached to the head node | expression state set on the head |
    | `animate` | rigged scene | Route A: import one SOMA-X clip through `interactor-motion`; Route B: keyframe from a short prompt through the fbd teacher | one animation clip |
    | `render` | animated scene | Godot's own render, MoltenVK on macOS; Mitsuba is the oracle when a still needs verification (RFD 2245) | VRM plus a preview MP4 |

    Blender-specific details in Tripo3D's post (the Blender MCP addon,
    material node wiring, IK routes) do not carry across, because Godot
    resource layouts are different. What does carry is the seven-step
    shape and the "body drives scale" rule.
    """

    details "First shipping slice", ~S"""
    Two parts, not three. One image, one body TRELLIS.2 run, one head
    Pixal3D run. Assembly over SceneTreeMCP: spawn two `MeshInstance3D`
    nodes, snap the head's neck vertex to the body's neck bone. Rig
    with SkinTokens over the combined mesh. Skip expressions. Play one
    canned SOMA-X clip through `interactor-motion`. Render to `.glb`
    and one 1920×1080 preview at 24 fps.

    The vertical slice's whole point is to prove the seven blocks
    actually chain through SceneTreeMCP without hand-editing between
    them. Everything the slice cuts: hair, expressions, generated
    animation, material checks: is a later block variant, not a
    later block type.
    """

    details "What this RFD does not decide", ~S"""
    Whether the input image itself is generated (a text-to-image
    front door) or handed in by the operator; that stays a caller
    concern. Whether the animation route defaults to A or B; the
    fbd teacher's reinforcement step (RFD 2236 step 3) is not
    finished, so Route A is the default until Route B is measured.
    Whether the output is VRM specifically or GLB-only; RFD 2244's
    one-deform-operator stage decides which corner set each block
    is allowed to touch, and VRM's blendshape convention follows
    from that once the head block gains expressions.
    """
  end
end
