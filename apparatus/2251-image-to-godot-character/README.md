# Apparatus 2251: image to godot character as an fbd

Runs the RFD 2251 character workflow end to end from Elixir through the
assembled Godot binary. Seven FBD blocks, six laddered rungs, each block
backed by an existing entities-godot module method or plain Godot API.

## Fixture

The reference image is
`6-datasource/anny-render-corpus-generated/ladder/T_Az000_A.png`: an
ANNY body rendered by OmniGen2 at azimuth 0 (front view). Its own
[CITATION.cff](../../../6-datasource/anny-render-corpus-generated/)
records the license and the generation provenance. An input to a
one-shot inference smoke test is not training data, so the
generated-synthetic corollary in `CLAUDE.md` does not apply.

## The six rungs

| rung | block | backing | entities-godot method |
| --- | --- | --- | --- |
| 1 | `generate_part` | `feat/module-pixal3d` | `Pixal3DModel.image_to_glb` |
| 2 | `rig` | `feat/module-skin-tokens` | `SkinTokensModel.rig_file` |
| 3 | `animate` | `feat/module-kimodo` | `KimodoModel.generate_motion` |
| 4 | `assemble` | plain Godot API | `GLTFDocument.append_from_file/generate_scene/write_to_filesystem` |
| 5 | `expressions` | plain Godot API | `MeshInstance3D.set_blend_shape_value` per named blend shape |
| 6 | `render` | plain Godot API | `SubViewport` + `Camera3D` + `Image.save_png` |

The 7th block from RFD 2251, `prepare_reference`, is the operator's
responsibility: one image in, three-part-scoped crops out, done outside
the runner.

## Prerequisites

1. The assembled Godot binary, built by `service-godot-build` off the
   `main/fabric-0.2.4` assembly with all six `feat/module-*` branches
   the workflow needs merged. Path exported as `GODOT_ASSEMBLY_BIN`.
2. Trellis2 GGUFs under one directory: `dino.gguf`, `ss_flow.gguf`,
   `ss_dec.gguf`, and (for the fine pipeline) `slat_flow.gguf`,
   `shape_dec.gguf`.
3. A skin-tokens bundle GGUF for the rig block.
4. A kimodo motion GGUF and text GGUF for the animate block.
5. `interactor-taskweft-function-block-diagram-teacher` compiled with
   the RFD 2251 runner branches merged.

## Run

    cd 3-interactor/taskweft-function-block-diagram-teacher
    iex -S mix

    iex> {:ok, r} = TaskweftFbdTeacher.Runner.Character.start([])
    iex> TaskweftFbdTeacher.Runner.Character.run(r, %{
    ...>   image: "2-contract/manuals-weftspun/apparatus/2251-image-to-godot-character/reference/body.png",
    ...>   gguf_dir: System.get_env("PIXAL3D_GGUF_DIR"),
    ...>   out: "/tmp/2251-body.glb",
    ...>   skin_tokens_bundle: System.get_env("SKIN_TOKENS_BUNDLE"),
    ...>   animate_prompt: "walking forward, natural gait",
    ...>   kimodo_motion_gguf: System.get_env("KIMODO_MOTION_GGUF"),
    ...>   kimodo_text_gguf: System.get_env("KIMODO_TEXT_GGUF"),
    ...>   head_glb: "/tmp/2251-head.glb",
    ...>   expression: "smile",
    ...>   expression_value: 0.7,
    ...>   preview_out: "/tmp/2251-preview.png"
    ...> })

Every optional key stays purely additive: leave a stage out and its
files are not produced; the earlier stages still write theirs. The
runner test suite covers the refusal path for every optional key
pointing nowhere.

## Reference

The upstream workflow this apparatus mirrors is Tripo3D's GPT-6 Astra
character workflow, read 2026-09-13. The article stays behind its
copyright; RFD 2251 carries the mapping table between their steps and
the modules the workspace already carries.

## What this workflow does not do

Multi-part assembly (the current pass is body + one head; hair is a
later rung), continuous blendshape blending (only discrete named
targets), physics-based hair or cloth (RFD 2249 handles cloth in its
own binary), motion retargeting between the kimodo skeleton and the
rigged mesh (motion JSON is written for a downstream step).
