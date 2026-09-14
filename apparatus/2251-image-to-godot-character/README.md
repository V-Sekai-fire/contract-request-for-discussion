# Apparatus 2251: image to godot character as an fbd

Runs the RFD 2251 rung 1 smoke test. Reads one image, produces one GLB
mesh by calling `Pixal3DModel.image_to_glb` in the assembled Godot
binary, from Elixir through `TaskweftFbdTeacher.Runner.Character`.

## Fixture

The reference image is
`6-datasource/anny-render-corpus-generated/ladder/T_Az000_A.png`: an
ANNY body rendered by OmniGen2 at azimuth 0 (front view), from the
license-clean corpus placed on `6-datasource` of the workspace. Its
own [CITATION.cff](../../../6-datasource/anny-render-corpus-generated/)
records the license and the generation provenance.

An input to a one-shot inference smoke test is not training data, so
the generated-synthetic corollary in `CLAUDE.md` does not apply here.
The mesh this apparatus produces is not fed back into any corpus.

## Prerequisites

1. The assembled Godot binary, built by `service-godot-build` off the
   `main/fabric-0.2.4` assembly with `feat/module-ggml` and
   `feat/module-pixal3d` merged. Path exported as `GODOT_ASSEMBLY_BIN`.
2. Trellis2 GGUF checkpoints, placed under one directory. At the
   minimum: `dino.gguf`, `ss_flow.gguf`, `ss_dec.gguf`; the fine
   pipeline additionally wants `slat_flow.gguf` and `shape_dec.gguf`.
3. `interactor-taskweft-function-block-diagram-teacher` compiled with
   the RFD 2251 rung 1 branch merged.

## Run

    cd 3-interactor/taskweft-function-block-diagram-teacher
    iex -S mix

    iex> {:ok, r} = TaskweftFbdTeacher.Runner.Character.start([])
    iex> TaskweftFbdTeacher.Runner.Character.run(r, %{
    ...>   image: "2-contract/manuals-weftspun/apparatus/2251-image-to-godot-character/reference/body.png",
    ...>   gguf_dir: System.get_env("PIXAL3D_GGUF_DIR"),
    ...>   out: "/tmp/2251-rung1-body.glb"
    ...> })

The refusal paths (missing binary, missing script, missing image,
missing gguf dir) are covered by `runner_character_test.exs` in the
teacher repo; this apparatus exercises the happy path.

## Reference

The upstream workflow this apparatus mirrors is Tripo3D's GPT-6 Astra
character workflow, read 2026-09-13. The article stays behind its
copyright and is not vendored here; RFD 2251 links to the mapping
table between their steps and the modules the workspace already
carries.

## What this rung does not do

Head, hair, expressions, animation, render. Each is a later rung
that adds one FBD block or one module method as it lands.
