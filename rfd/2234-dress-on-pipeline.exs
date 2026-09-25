# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2234. `mix rfd.render` renders rfd/2234-dress-on-pipeline/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2234 do
  use RFD.DSL

  rfd 2234,
      "Dress-on pipeline: ANNY body plus garment photo through VoxHammer to a joined dataset" do
    state :discussion

    flight_level :l1

    feature "an ANNY body dressed from a garment photo by two VoxHammer half-torso passes, shipped as MaskScore-shaped parquet"

    scope "`3-interactor/voxhammer-upstream/tools/`, `chibifire/anny-dress-on-stage-train`, task #176"

    decision ~S"""
    The dress-on corpus is built by two sequential VoxHammer passes on one seeded
    Hammersley camera set: a 2D garment composite over the front-most view lifts the
    front half of the torso, a second composite over the rear-most view lifts the back,
    and the splice-before-decode guard keeps each pass exact outside its box. Every
    row ships its inputs, three ranked candidates and geometric scores in the
    MaskScore/EditScore three-parquet shape, with a joined view for the viewer.
    `DETAILS.md` carries the plan as it was worked, section by section.
    """

    problem ~S"""
    Task #176 needs an ANNY body dressed from a second-hand-fashion photo, and
    VoxHammer's image mode does not take a garment photo: it lifts a 2D edit of its
    own render into 3D. The plan records the correction, the seeding hole it closes,
    the renderer swap, the schema the rows must follow, and what was out of scope.
    """

    references ["RFD 1047", "RFD 1048", "RFD 1143", "RFD 2177"]

    related ~S"""
    RFD 1047 and RFD 1048 (VoxHammer text and image editing), RFD 1143 (keypoints to
    ANNY, the first loop), RFD 2177 (flight levels). The plan this RFD preserves was
    the working plan of 2026-09-07; the voxhammer.cpp state it names is the ggml
    target the whole pipeline moves toward.
    """

    details_title "Dress-on pipeline: ANNY body plus garment photo through VoxHammer to a joined dataset"

    details_preamble ~S"""
    The plan as it was worked on 2026-09-07, copied section by section at the operator's
    request ("copy the dress on plan to rfd"). Prose is unchanged apart from em-dash joins
    the DSL flags; the file paths and numbers are those of that day.
    """

    details "Context", ~S"""
    Task #176 dress-on. Take an ANNY parametric body, take a second-hand-fashion garment
    photo, splice the garment onto the body mesh with VoxHammer (a training-free 3D
    latent editor with a splice-before-decode guard that keeps everything outside the
    mask exact), trim the garment out of its photo with BiRefNet in a separate process,
    and ship every finished dressed body plus all its inputs to HuggingFace as ETNF
    satellite parquet tables with a joined view for the HF viewer.

    All environments already exist and are verified: the `default` (edit) env runs
    VoxHammer through Step 4 on the shipped example; the `matting` env runs BiRefNet
    on all three garment views in ~2 s. What is missing is the glue, one new env for
    ANNY, and one design correction found during exploration:

    **VoxHammer's image mode does not take a garment photo.** It takes three
    fixed-name images from `--image_dir` (`voxhammer/edit_pipeline.py:532-534`):
    `2d_render.png` (a render of the unedited body), `2d_edit.png` (that same view
    edited in 2D to show the wanted result), `2d_mask.png` (the changed region in
    that view). The shipped example is a hoodie figure whose face was changed in an
    image editor. So the garment photo must first become a **2D try-on composite
    onto the body render**; VoxHammer then lifts that 2D edit into 3D. Pass 1 scope
    is silhouette + palette only, so a crude alpha-paste of the matted garment over
    the torso is honest and sufficient.

    **Multiview is two sequential half-torso passes on the same Hammersley cameras.**
    `get_cond([...])` stacks images along the batch axis (`trellis_image_to_3d.py:161-168`);
    TRELLIS's stock multi-image mode mixes those at the sampler level, and VoxHammer's
    edit samplers are KV-cached single-cond inversions (`edit_pipeline.py:546-552`),
    so true multi-image conditioning inside the edit is research, not glue. Instead the
    3D mask is **two boxes**, front-torso and back-torso, split at the body's coronal
    plane. Pass 1 edits the front box conditioned on the front garment composited over
    the front-most Hammersley view; pass 2 re-renders pass 1's output with the **same
    seeded cameras** and edits the back box conditioned on the back garment over the
    rear-most view. VoxHammer's splice-before-decode guard keeps pass 1's front exact
    during pass 2. Two ordinary single-image edits; upstream samplers untouched.

    **Views come from `sphere_hammersley_sequence`, never a hand-picked azimuth**
    (CLAUDE.md). `utils/render_rgb_and_mask.py` uses five hand-picked azimuths and is
    NOT used. Step 1's 150-view render (`bpy_render.py:302-336`) is the source of
    every 2D image: pick views by camera position from `transforms.json`. The
    Hammersley offset at `bpy_render.py:304` is `np.random.rand()` **unseeded** —
    every run gets a different camera set, so the driver seeds `np.random` per
    target before each render and records the seed; both passes then share one
    `transforms.json` and one front/rear view index.
    """

    details "Finish the dataset (operator: \"please make the dataset\", 2026-09-07)", ~S"""
    Everything below "Pipeline, per target" is built and proven on the smoke targets;
    this section is the remaining run, in order. GPU rule throughout: **every step on
    the 4090** (`CUDA_VISIBLE_DEVICES=1`, PCI order), the 3090 is the operator's VR
    card; all steps `HF_HUB_OFFLINE=1`; the batch driver at BelowNormal priority.

    1. **Batch 1** (`tools/dress_on_batch.py --out work/batch1 --garments 0 1 2
       --identities all --diagonal --max-rows 3`) is running and resumes from saved
       outputs. Rows: female-p1 × garment 0, female-p50 × 1, male-p50 × 2; rank3
       uses the next garment. Per row it leaves `candidates/{rank1,rank3,rank5}`,
       `aov/*`, `scores/*.json`, USD assets, and appends four parquets under
       `work/batch1/stage/data/`. Controls are asserted before each write; a
       failure stops the batch naming the step.
    2. **Judge** after the batch frees the 4090: `pixi run -e judge env
       CUDA_DEVICE_ORDER=PCI_BUS_ID CUDA_VISIBLE_DEVICES=1 HF_HUB_OFFLINE=1 python
       tools/judge_editscore.py --targets "work/batch1/*__g*"` → `judge/rank*.json`
       per target (EditScore on Qwen3-VL-8B, frozen tuple recorded per row; a
       refusal is `refused=true`, never a score). Proven on this box: 43 s load,
       16 s per evaluation, 17 GB.
    3. **Rebuild the stage with judge rows.** The writer appends per target, so
       re-running it on an existing stage would duplicate root rows: `rm -rf
       work/batch1/stage`, then `write_dress_on_rows.py --target <t> --stage
       work/batch1/stage` for each DONE target (seconds each). The judge negative
       control (rank1 > rank3 > rank5) now gates the emit too.
    4. **Throwaway publish + viewer check**: `tools/publish_dress_on.py --stage
       work/batch1/stage --hub chibifire/anny-dress-on-stage-viewtest --private`
       (token from bao, `agents/<CN>` field `hf_token`, proven with `whoami`).
       Open the viewer: the `dress_on` config must show 3 rows, each with 3
       nested candidates, `scores` per view, `judge` filled. If it shows separate
       tables or a nulled column, fix the shape before the real repo. Delete the
       throwaway afterwards.
    5. **Real publish**: same command against `chibifire/anny-dress-on-stage-train`;
       read back with `list_repo_files` and `load_dataset(..., "dress_on")`.
    6. **Record**: shard facts for rows shipped, judge scores, viewer result;
       memory note. Then the remaining identity × garment pairs (12 rows total)
       as batch 2 with the same command minus `--max-rows`, resumable.

    Local convenience copies (operator's earlier "pretend DESKTOP is hf") are
    still available via `--local ~/Desktop/hf` but the operator has since said
    push to real HF, so the Hub is the destination.
    """

    details "Pipeline, per target", ~S"""
    ```
    identity seed ──► [anny env] anny_body.py ──► body.glb, mask_front.glb, mask_back.glb,
    phenotype.json
                                                       │
    garment row ──► [matting env] mask_offline.py ──► front/back .alpha.png
                                                       │
            ┌── pass k ∈ {front, back} ─────────────────────────────────────────────┐
            │  [render env] render_hammersley.py, Mitsuba 3, seeded 150-view Hammersley  │
            │       → NNN.png + transforms.json + mesh.ply  (pass 2 re-renders pass 1's output)
            │  [render env] pick_view.py  → front-most / rear-most view index by camera pos
            │                project mask_k box corners through that camera → 2d_mask.png
            │                copy renders/NNN.png → 2d_render.png
            │  [matting env] composite_garment.py (garment_k) → 2d_edit.png
            │  [default env] run_edit_test.py --mask_glb mask_k.glb → dressed_k.glb, gaussian_k.ply
            └───────────────────────────────────────────────────────────────────────┘
                         × 2 candidates (rank1 own garment, rank3 wrong garment)
                                                       │
                      [render env] render_hammersley.py --aov --views 64 on rank1/rank3/rank5(input)
                           → view_XXX.{json,png,aov.npz}  (score_render_pair.py contract)
                      [render env] score_render_pair.py ──► geometric scores, outside/inside torso masks
                      [judge env, when run] EditScore ──► judge rows
                                                       │
                      [matting env] write_dress_on_rows.py ──► dress_on{,_candidates,_scores,_judge}.parquet
                                                       │        controls asserted first; refuses on failure
                                                       │
                      [matting env] publish_dress_on.py ──► hf:chibifire/anny-dress-on-stage-train
    ```

    Orchestrated by `tools/dress_on_batch.py` (stdlib only, system Python) which
    shells `pixi run -e <env> python tools/<step>.py` per step and hands files
    between envs. This is the `one-pixi-env-per-usage` rule; the iceoryx2 bus is the
    scaling path once N justifies a persistent BiRefNet process (bus proof is still
    `client-blocks-on-reply` on Python-Windows, so subprocess for batch 1).
    """

    details "Files", ~S"""
    All new files under `C:\fabric-starforged\3-interactor\voxhammer-upstream\` unless noted.

    ### `pixi.toml`, add `anny` feature + environment
    - `[feature.anny.dependencies] python = "3.11.*"`
    - `[feature.anny.pypi-dependencies]`: `torch` with per-package cu128 index (same
      pattern as the matting env, never a feature-wide `extra-index-urls`, that
      trips pixi's dependency-confusion guard), `anny = { path = "../anny", editable = true }`,
      `trimesh`, `roma`, `numpy`.
    - `[environments] anny = { features = ["anny"], no-default-feature = true }`.
    - ANNY is known to work on torch 2.11+cu128 (the mujoco env already runs it).

    ### `tools/anny_body.py` (anny env), identity → body.glb + mask.glb
    - Build the model with `anny.Anny(rig="anny", topology="anny", phenotypes="all",
    local_changes="default", skinning_method="lbs")`
     , the same `CORPUS_CONFIG` as `6-datasource/anny-render-corpus/anny_rig.py:78-80`,
      minus `facial_actions` and minus the corpus's forearm twist fix (not wanted here).
    - Phenotypes come from `tools/identity_appendix_e.py` (below), which returns
      the same `{label: float in 0..1}` dict shape that
      `sample_identities.py:42-63` produces, so this script is source-agnostic.
      Record the source row keys and the 11 named floats.
    - Forward at identity pose (`_identity_pose` pattern, `anny_rig.py:99-101`) →
      `out["vertices"][0]`, `model.faces`.
    - **Pre-normalize to the unit cube** (`scale = 1/max(extent)`, centre at origin)
      BEFORE export, and apply the same transform to the mask. VoxHammer's
      `bpy_render.normalize_scene` (`voxhammer/bpy_render.py:231-250`) then acts as
      ~identity on the body, and `utils/render_rgb_and_mask.py:35` explicitly does
      NOT normalize, rendering at radius 1.8, so a unit-scale body is what both
      consumers expect. This sidesteps the question of whether the mask path
      normalizes independently: both files share one frame and are already unit.
    - Torso masks: `dominant_bone(model)` (`anny_rig.py:93-96`) → vertices whose
      dominant bone name matches spine/chest/breast (print `model.bone_labels` on
      first run to pick the exact names) → their AABB, padded ~8 % → split at the
      torso's coronal midplane (y = centroid, ANNY is y-forward) into two
      `trimesh.creation.box` volumes → same unit transform → `mask_front.glb`,
      `mask_back.glb`. Store the 8 corners of each box in `phenotype.json` so the
      2D projection step needs no re-parse of the GLB.
    - Export with `trimesh.Scene().export("*.glb")`,
    `anny/src/anny/examples/interactive_demo.py:84-102`.
      No skeleton, no UVs: VoxHammer flattens to a static mesh and deletes all
      materials (`bpy_render.py:93-94, 166-171`), so static geometry is exactly right.
    - Emits `phenotype.json` (seed, 11 floats, anny version SHA) for the row.

    ### `tools/identity_appendix_e.py` (anny env), appendix-E anthropometry → ANNY phenotypes
    Operator chose appendix-E over ANNY's own prior. What is known, from the only
    schema documentation on disk (`motion-bricks-cpp/mujoco/rom_map.py:9-14, 65-80`):
    the dataset is `chibifire/starforged-std-3001-appendix-e`, config `human`,
    120 rows, columns `section`-like key, `subcategory`, `angle_deg_min/max`,
    `source`, `percentile`, `sex`. **Only E.3 (16 rows of joint ROM) is documented
    anywhere in the workspace**, and ROM has no ANNY counterpart, phenotypes shape
    `rest_vertices`, ROM constrains `pose_parameters`. The other 104 rows are
    undocumented on disk. So this step is gated:

    **1a. Inspect (first thing in the anny env, 30 s).** Stream the dataset, print
    distinct section/subcategory values per section, and which rows populate
    `percentile` and `sex`. Write the result to `docs/appendix-e-schema.md` in this
    repo so the next reader does not have to re-derive it.

    **1b. If E.1/E.2 carry stature and body mass with percentiles and sex** (the
    `percentile`/`sex` columns exist for a reason, and E.3 leaves them empty only
    because the AAOS ROM reference is not percentile-stratified), build the
    mapping as a `SOURCES["appendix_e"]` function in the same shape as
    `sample_identities.py:42-67` (its docstring says a new population source is
    "adding a function below, not reshaping the schema"):
    - Identity grid for batch 1: `{male, female} × {p5, p25, p50, p75, p95}` = 10
      identities, each a (sex, percentile) → (stature m, mass kg) lookup.
    - `gender` ← sex as 0.0 / 1.0 (`model_data.py:40-55`: a 0..1 male↔female scalar).
    - `age` ← the adult band through `MorphologicalAgeMapping`
      (`shape_distribution.py:17-51`), the only years→parameter bridge ANNY has.
    - `height`, `weight` ← **the workspace's LBFGS residual resolver**, with a
      measurement residual in place of a vertex residual.
      `4-entities/anny-pose-retarget-work/lbfgs_polish.py:1-16` is the pattern:
      `torch.optim.LBFGS(..., line_search_fn="strong_wolfe")` at float64 over ANNY
      parameters, the established follow-up to `AnnyInverter`'s Adam pass
      (`gnm-anny-headfit/headfit.py:11-12` records 1.7e-4 mm on a same-rig target).
      ANNY's forward and `Anthropometry.height` (Z-extent, `anthropometry.py:76`)
      and `.mass` (volume × density, `:90-104`) are all differentiable, so the loop
      minimises `((height(v) − stature)/stature)² + ((mass(v) − mass)/mass)²` over
      `{height, weight}` with autograd, no root-finding, no finite differences.
      ANNY's phenotype space has no metres in it (`phenotype.py:311-337`), which is
      why this is a solve, not an assignment.
    - Regularisation reuses `AnnyInverter._DEFAULT_REG_WEIGHT_KWARGS`
      (`anny_inverter.py:20-32`): `height` 1e-3 (free), `age` 10.0 (near-frozen),
      race 100.0 (frozen), the priors already tuned for exactly this shape of fit.
    - `muscle` held at 0.5 (mass alone cannot separate weight from muscle); record
      that `mass()` uses a hard-coded 980 kg/m³ (`anthropometry.py:104`), a
      systematic bias against any real weight table, the row stores achieved
      beside target so the bias is measured, not hidden.
    - If 1a shows a waist-circumference row, add `Anthropometry.waist_circumference`
      (`:82`, the 46-vertex ring) as a third residual term, same loop, one line.
    - `proportions`, `cupsize`, `firmness`, race terms ← 0.5 (ANNY's neutral); no
      appendix column steers them.
    - The second-opinion referee that guards the vertex fit
      (`pose-consensus/python/silhouette.py`) is not needed here: a scalar
      residual has no correspondence to get wrong, which is the failure it exists
      to catch.
    - **Everything else in the table has no ANNY knob**, limb lengths, breadths,
      non-waist circumferences. `Anthropometry` exposes five scalars only
      (`height, waist_circumference, volume, mass, bmi`). Recorded in the row as
      `unmapped_measurements: list<string>` so the omission is counted, not silent.
    - `AnnyInverter` (`anny_inverter.py:771-809`) is **not** the tool: it needs a
      full `[B, V, 3]` target mesh in ANNY topology, not scalars.
      (`AGENTS.md:61` still names the old `parameters_regressor.py`; stale.)
    - Each ANNY forward is one 13 718-vertex evaluation; a two-scalar solve is
      well under a second per identity on CPU.

    **1c. If 1a shows no body dimensions anywhere in the 104 rows**, the mapping
    cannot be built from this dataset. Say so in `docs/appendix-e-schema.md`,
    record `finding:appendix-e#body_dimensions@absent` in the shard, fall back to
    `SOURCES["anny"]` for batch 1 with `identity_source = "anny-prior"` in every
    row, and raise it to the operator before shipping, this is their call, not a
    silent substitution.

    **SOMA-X is the pivot, and ANNY phenotypes are already its identity vector.**
    `3-interactor/soma-x/soma/identity_model.py:350-392`, `AnnyIdentityModel`
    wraps `anny.create_fullbody_model(all_phenotypes=True, ...)`,
    `num_identity_coeffs = len(phenotype_labels)`, and `get_rest_shape` passes
    `identity_coeffs` straight through as `phenotype_kwargs`. So the 11 `pheno_*`
    columns in the row **are** the SOMA-X identity coefficients for
    `identity_model_type="anny"` (`soma/soma.py:170-172`); no conversion column,
    and none may be added (it would be derivable, which ETNF forbids).

    **GarmentMeasurements is blocklisted** (operator, 2026-09-07: licence).
    `GarmentMeasurementIdentityModel` (`identity_model.py:468-516`) and its
    CAESAR PCA are not an option for any identity path; SOMA-X's other backends are
    unaffected. Do not add it to `BLOCKLIST.md` on this relay, the operator's own
    row and section land through their channel.

    No `scipy`: the solve is torch autograd + `torch.optim.LBFGS`, already in the
    `anny` feature's torch.

    ### `tools/mask_offline.py` (matting env), already written and verified
    - `--batch "<dir>/garment-<id>-*.jpg" <out-dir>` → `<view>.alpha.png` sidecars.
    - The brand close-up mattes at 97 % coverage (no separable background); it is
      stored in the row for provenance and **excluded from conditioning**.

    ### `tools/render_hammersley.py` (render env), Step 1 in Mitsuba 3, replacing Blender
    Operator: "you can also use mitsuba3 to render". Mitsuba is the workspace's
    sanctioned renderer (CLAUDE.md asks the mtoon renderers to consolidate on it)
    and is already exercised in `motion-bricks-cpp/mujoco/bench_silhouette.py`.
    VoxHammer skips its own render when the artefacts exist (`inference.py:31`),
    so this is a drop-in for Step 1 as long as it emits the exact contract
    `voxhammer/extract_feature.py:35-53, 60-74` reads:

    - `mesh.ply`, the mesh normalized into `[-0.5, 0.5]³` (`voxelize_mesh` clips to
      that cube at line 23). Our body is already unit-scaled by `anny_body.py`, so
      this is a copy; for pass 2 it is the decimated pass-1 output.
    - `NNN.png`, 512² **RGBA with a transparent background** (line 46 multiplies
      RGB by alpha, so a black-composited background would double-darken). Mitsuba:
      `scene.integrator = path`, film `rgba`, `sensor.film.pixel_format = "rgba"`,
      no envmap emitter behind the object; a constant emitter for the three-point
      fill that `bpy_render.py:112-134` hard-codes.
    - `transforms.json`, `{"aabb": [[-0.5]*3, [0.5]*3], "scale": s, "offset": [ox,oy,oz],
    "frames": [{"file_path": "NNN.png", "camera_angle_x": 0.6981 (40° in rad), "transform_matrix":
    c2w}]}`
      where `c2w` is in the **Blender/OpenGL convention**, camera looks down its
      −Z with +Y up, because line 49 flips columns 1:3 to reach OpenCV before
      inverting. Build it from `mi.ScalarTransform4f.look_at(origin, target=(0,0,0), up=(0,0,1))`
      and then apply the OpenCV→OpenGL flip so the file matches what Blender wrote.
    - Cameras: `sphere_hammersley_sequence(i, 150, offset)`, the pure function at
      `voxhammer/bpy_render.py:11-40` (identical copy in `trellis/utils/random_utils.py:22`),
      radius 2, fov 40°, with `offset` drawn from a **seeded** RNG and the seed
      written into `transforms.json` as an extra key. This is where the
      reproducibility hole at `bpy_render.py:304` is closed for good.
    - **Second layout, `--aov --views 64`**, for scoring: `view_XXX.json` (camera),
      `view_XXX.png` (RGBA), `view_XXX.aov.npz` with `depth` (H,W) and `normal`
      (H,W,3), the contract `score_render_pair.py:31-41` reads. Mitsuba's `aov`
      integrator (`depth`, `sh_normal`) gives both in one pass; 64 views is the
      MaskScore convention (`maskscore_rung_1_mesh.py:106-108`). Note
      `sphere_hammersley_sequence(i, 64) ≠ (i, 150)`, so this is a distinct
      render, run on every candidate mesh and on the input.
    - **Validation gate before it replaces Blender**: render the shipped
      `assets/example/model.glb` once with Blender (existing path) and once with
      Mitsuba from the same seed; `voxels.ply` must be identical and `features.npz`
      patch-token cosine similarity ≥ 0.98 per voxel. If it is not, the camera
      convention is wrong and every downstream number would be quietly off.

    Why this is worth doing now rather than later: bpy 4.2.0 was the sole reason
    for the Python 3.11 pin in the edit env; the pass-2 re-render of a
    hundreds-of-thousands-face FlexiCubes mesh is where Cycles is slowest; and the
    same Mitsuba scene serves the 2D mask projection below, so one renderer does all
    three jobs.

    `[feature.render]`: `python = "3.11.*"`, pypi `mitsuba = "==3.9.1"` (the pin the
    mujoco env already carries), `trimesh`, `numpy`, `pillow`, `opencv-python`.
    `[environments] render = { features = ["render"], no-default-feature = true }`.

    `[feature.judge]` (only when EditScore runs): `python = "3.11.*"`, torch with a
    per-package CUDA index, `editscore` and its Qwen3-VL backbone exactly as
    `anny-render-corpus/score_edits.py:119-122` loads them (`BASE`, `ADAPTER`,
    `score_range=25`, 512² cap because 1024² does not fit 8 GB per `:98-99`).
    `[environments] judge = { features = ["judge"], no-default-feature = true }`.
    Four usages, four environments; the orchestrator hands files between them.

    ### `tools/pick_view.py` (render env), view selection + 2D mask from the Hammersley render
    - Reads `transforms.json` from Step 1 (`bpy_render.py:329-336`: per-frame
      `transform_matrix` c2w and `camera_angle_x`; radius 2, fov 40°, 512²).
    - **Front-most view** = frame whose camera position has the largest dot with
      the body's forward axis (+y in ANNY's frame, mapped through the same unit
      transform); **rear-most** = smallest. Deterministic given the seed.
    - **2D mask** = project the chosen half-box's 8 corners with the pinhole from
      `camera_angle_x` and the inverse of `transform_matrix`, take the 2D convex
      hull, fill, multiply by the render's alpha so the blob never leaves the body
      silhouette (the shipped `2d_mask.png` is exactly such a blob over the head).
      No second Blender pass, and the cameras match by construction.
    - Copies `renders/NNN.png` → `2d_render.png`. Emits `view.json` (frame index,
      camera position, mask bbox) for the row.

    ### `tools/composite_garment.py` (matting env), the 2D try-on
    - Inputs: `2d_render.png` (RGBA), `2d_mask.png` (half-torso blob), the matted
      garment view for this pass (`garment-<id>-<front|back>.jpg` + `.alpha.png`).
    - Fit the garment's alpha bbox to the mask bbox (uniform scale, centred),
      alpha-composite over the render, **keep the render's alpha channel** so the
      edit env's rembg-shim provider takes the RGBA path (option 2 of its
      precedence) with no sidecar needed.
    - Write `2d_edit.png`. Record `composite_method = "alpha-paste-to-mask-bbox"`.

    ### `run_edit_test.py` (default env), changes
    1. **Vertex-coloured export via the Gaussian, no nvdiffrast.** `edit_pipeline.py:556`
       calls `postprocessing_utils.to_glb(...)`, which unconditionally bakes a
       texture via nvdiffrast (`trellis/utils/postprocessing_utils.py:443-453`);
       our shim raises by design. Monkeypatch `postprocessing_utils.to_glb` from
       the driver (upstream file untouched) with `gaussian_vertex_color_glb(app_rep, mesh, **_)`:
       - mesh: `mesh.vertices.cpu().numpy() @ ZUP_TO_YUP`, `mesh.faces` (rotation
         from `postprocessing_utils.py:457`); skip `postprocess_mesh` (its
         `fill_holes` renders visibility).
       - colour: the Gaussian splat **is** the decoded appearance field. Take
         `app_rep.get_xyz` and the SH-DC colour (`app_rep.get_features[:, 0]` →
         `SH2RGB`), build a `scipy.spatial.cKDTree`, and assign each mesh vertex the
         inverse-distance mean of its k=8 nearest Gaussians. Pack as `COLOR_0`
         (`trimesh.visual.ColorVisuals(vertex_colors=...)`) and export GLB. This is
         what `pixal3d.cpp` itself emits by default (`mesh_export.cpp:502-513`,
         rationale at `mesh_export.h:11-15`). No cameras, no rendering, ~25 lines.
       - also `app_rep.save_ply("dressed_gaussian.ply")` so the row keeps the full
         appearance field for any later re-bake.
       **Upgrade path (recorded, not done):** Pixal3D's `t2_bake_glb`
       (`pixal3d.cpp/trellis2_capi.h:167-183`) is a CPU xatlas UV-atlas bake that
       takes exactly this per-vertex PBR (rgb, metallic, roughness, alpha) and
       returns a GLB with a real texture, CPU-only, no CUDA (`mesh_export.h:14-15`).
       It needs a CMake build of `pixal3d.cpp` (not built on this box; needs only
       Threads + bundled xatlas) and a `T2MESH03` blob writer. When a UV texture is
       required, that is the ~1-day step; nothing in pass 1 needs it.
    2. **Pass `--render_dir` pointing at the Mitsuba output** so `inference.py:31`
       skips Blender. Keep `np.random.seed(target_seed + pass_index)` before
       `run_3d_rendering` anyway, so the Blender fallback (if Mitsuba fails the
       validation gate) is also reproducible. Seeds go into `voxhammer_config`.
    3. **Decimate between passes.** Pass 2's input is pass 1's raw FlexiCubes mesh
       (hundreds of thousands of faces); a 150-view Cycles render of that is slow.
       `trimesh.Trimesh.simplify_quadric_decimation(face_count=60_000)` (pure
       trimesh/open3d, no nvdiffrast) before the pass-2 render. Record the face
       count before/after in `timing.json`.
    4. Accept `--work_dir` and emit a `timing.json` (per-stage wall, peak VRAM via
       `torch.cuda.max_memory_allocated`, face counts) for the row.

    ### `tools/write_dress_on_rows.py` (matting env), the MaskScore / EditScore schema
    Operator: the dataset must follow the MaskScore / EditScore schemas. Those are
    the workspace's **root + candidates + scores** three-parquet ETNF shape
    (`anny-render-corpus/maskscore_rung_1_mesh.py:10-27, 86-135`,
    `maskscore_rung_1_stubs.py:37-53`), and dress-on becomes one more stub in that
    register rather than a schema of its own. The shape is a **scorer-calibration**
    shape: every row carries several candidates with a known ordering, and the emit
    refuses to write unless the identity and negative controls hold. So a dress-on
    row cannot be one output, it needs candidates a scorer can be tested against.

    **Stub registration** (one line in the `STUBS` register, same vocabulary):
    ```
    ("dress_on", "garment_edit", "instruction_following", "input_mesh", "anny_glb")
    ```
    `MASKSCORE.md`, which `maskscore_rung_1_stubs.py:38` cites for these
    vocabularies, is **absent from disk** (Glob finds none). Record that as a
    doc-drift finding in the shard; do not invent a replacement.

    **Candidates per row**, three, each a full front+back VoxHammer edit of the
    *same* identity so garment and body are not confounded:
    ```
    rank1   own garment  , the row's dressed body (best expected)
    rank3   wrong garment, same body, edited with a different row's garment
    rank5   undressed    , the input body, no edit (identity control for geometry,
                            worst on instruction following)
    ```
    Batch 1 = 10 identities × 2 edited candidates × 2 passes = **40 VoxHammer edits**.

    **Tables** (all zstd; `real()` relative paths as `maskscore_rung_1_mesh.py:77-80`,
    assets uploaded beside the parquets, not `struct<bytes,path>` embedding, which
    is not the workspace's shape):

    `dress_on.parquet`, root, one row per (identity, garment):
    ```
    key string ("dress_on/<identity_key>/<garment_id>")
    task_type, dimension, input_column, input_asset, input_asset_kind   (register vocab)
    identity_source, target_stature_m, achieved_stature_m, target_mass_kg, achieved_mass_kg,
    unmapped_measurements
    pheno_gender … pheno_caucasian (11 × float32)   ← also the SOMA-X identity vector
    garment_id, garment_source, garment_front, garment_back, garment_brand, matted_front,
    matted_back
    mask_front_glb, mask_back_glb, hammersley_seed_front, hammersley_seed_back, view_index_front,
    view_index_back
    composite_method, voxhammer_config
    body_provenance, garment_provenance      (interned provenance classes)
    ```
    `dress_on_candidates.parquet`, `(row_key, candidate, rank, candidate_asset)` plus
    `candidate_gaussian`, `candidate_provenance` ("generated:voxhammer:…" for
    rank1/3, "constructed:anny:…" for rank5), `garment_id_used`, `render_2d_front`,
    `edit_2d_front`, `render_2d_back`, `edit_2d_back`, `wall_edit_s`, `peak_vram_mib`.
    Composite key `(row_key, candidate)` as in every existing config.

    `dress_on_scores.parquet`, geometric, **always present**, one row per
    (candidate, view) over **64** Hammersley views, the `score_render_pair.py`
    metric (`:3-7`): `(row_key, candidate, view_index, depth_l1, normal_l1, normal_dot)`
    against the **undressed input's** render, computed twice, on the reference
    alpha outside the torso masks (`*_outside`, VoxHammer's "rest exact" guarantee
    as a number) and inside (`*_inside`, how much changed). No judge needed.

    `dress_on_judge.parquet`, **present only when a judge ran**, one row per
    (candidate, judge): `(row_key, candidate, judge_base, judge_adapter, judge_precision,
    judge_num_pass, prompt_sha, instruction, overall, refused)`, the record
    `score_edits.py:154-163` already emits. Judge = EditScore (Apache-2,
    `omnigen2/OmniGen2-RL`; `EditScore(backbone="qwen3vl", …, score_range=25).evaluate([src,
    edited], instruction)`),
    fed the front `render_2d` and the candidate's front render with the instruction
    "dress this body in the garment shown" plus the garment photo. Frozen-judge
    doctrine: the (base, adapter, precision, num_pass, prompt) tuple is pinned before
    the run and recorded on every row. A refusal is `refused=true`, not a score.
    Absence of a judge row IS "not judged". No nullable column anywhere.

    **The floor (measured 2026-09-07, changes the controls below).** VoxHammer's
    output is a re-decode of the SLat at 64³, so even geometry it never touched
    comes back as the source's *reconstruction*, not the source mesh. On the smoke
    body, output vertices outside the mask sat p50 = 0.0048 / p95 = 0.060 (3.8
    voxels) from the original surface, the reconstruction error of the encoder–
    decoder, not an edit leak. Comparing against the original mesh conflates the
    two. So **rank5 is the source's own unedited decode** (`--export-source-recon`
    in the driver, one extra `decode_slat`), and every geometric control is
    relative to it, rule 4: the floor is reported in the same table.

    **Controls, asserted before the write** (`assert_controls` shape,
    `maskscore_rung_1_mesh.py:58-68`; a failure refuses the whole emit):
    - floor: rank5 (source decode) vs the input render, reported, not gated; it is
      the reconstruction error every other number is read against;
    - rest-exact: rank1 and rank3 `depth_l1_outside` ≤ rank5's + 1/64 on every view
      (the edit did not leak past the mask beyond one voxel over the floor);
    - negative (geometry): rank1 `depth_l1_inside` strictly > rank5's;
    - negative (judge, when present): rank1 `overall` > rank3 `overall` > rank5
      `overall`, a judge that cannot order own-garment above wrong-garment above
      undressed has not measured garment fidelity.

    **Row-writer gates (fail, never skip):** refuse a row whose conditioning used
    `brand` (pass-1 no-logos rule enforced at write time); refuse any absolute
    path (`refuse_if_absolute`, `publish_artifacts.py:96-121`); refuse a ragged
    scores satellite (view count must match across candidates,
    `maskscore_rung_1_mesh.py:109-114`).

    **Joined view for HF**, add one entry to `CONFIGS`
    (`maskscore_rung_1_hf_publish.py:14-33`):
    ```
    "dress_on": {"prefix": ("dress_on",), "cand_composite": ("row_key","candidate"),
                 "score_composite": ("row_key","candidate")}
    ```
    `build_wide` (`:59-78`) nests candidates → scores into the root; an unjudged
    candidate gets `judge: []`, a value not a null. Emits
    `data/dress_on/train-NNNNN-of-MMMMM.parquet`, the viewer's one paginated
    table, beside the four satellites. Shard at ~500 MB.

    **Provenance (CLAUDE.md generated-synthetic conditions 1–2):** the dressed mesh
    is generated, the body is constructed, the garment photo is real. Each column
    carries its provenance class explicitly, the repo is separate from every
    constructed/real corpus, and `voxhammer_config` records model, checkpoint and
    conditioning so the corpus can be regenerated.

    ### `tools/publish_dress_on.py` (matting env), copy `publish_artifacts.py`
    - `hf_token()` from 1Password (`publish_artifacts.py:54-62`, same item).
    - `api.create_repo(..., repo_type="dataset", exist_ok=True)`; `api.upload_folder(...)`
      **without** `delete_patterns` so each run adds shards (incremental, resumable —
      `mirror_base_weights.py:19` is why `upload_folder` and not `push_to_hub`).
    - Preflight `refuse_if_absolute` and `refuse_if_forbidden` over the stage.
    - README card **without a `configs:` block** (auto-parquet picks up
      `data/<config>/`; the block caused "size not coherent" errors upstream).
    - Read-back after upload, as `publish_artifacts.py:537-539` does.

    ### `tools/dress_on_batch.py` (system python, stdlib), orchestrator
    - `--count N --seed S --garment-offset K --out <work>`; per target runs the seven
      steps above via `subprocess.run(["pixi","run","-e",env,"python",...])`,
      each with explicit env vars (`ATTN_BACKEND=xformers SPARSE_ATTN_BACKEND=xformers SPCONV_ALGO=native CUDA_DEVICE_ORDER=PCI_BUS_ID CUDA_VISIBLE_DEVICES=1`
      for the edit env, `activation.env` is not applied when vars are prefixed).
    - Writes rows as it goes; a crash at target k leaves k−1 rows on disk and,
      after publish, on HF.
    - Garment rows streamed from `chibifire/zenodo-second-hand-fashion-v3`
      (`image_front/back/brand` columns already exist, multiview is the schema,
      not something to acquire), filtered to rows with all three views.
    """

    details "Implementation order (risk retired per hour)", ~S"""
    0. **Frame check, 1 min**, `trimesh.load` shipped `assets/example/model.glb`
       and `mask.glb`, print both AABBs. Confirms the shared-frame + unit-scale
       assumption before any ANNY code is written.
    1. `pixi.toml` anny + render features; `tools/identity_appendix_e.py` **1a
       inspect** → `docs/appendix-e-schema.md`; branch 1b or 1c; then
       `tools/anny_body.py` → `body.glb` + two half-torso masks for one identity.
    1m. `tools/render_hammersley.py` **validation gate** on the shipped example:
       Blender vs Mitsuba from one seed → identical `voxels.ply`, feature cosine
       ≥ 0.98. Only then does Mitsuba replace Blender in the loop.
    2. Seeded Step 1 render of `body.glb` → `transforms.json`; `tools/pick_view.py`
       → front view `2d_render.png` + projected `2d_mask.png`. Eyeball the blob.
    3. `tools/composite_garment.py` → `2d_edit.png` (garment 0 front, the floral dress).
    4. `run_edit_test.py` untextured-export + seeding patches → **the gate**: one
       `dressed_front.glb`. Peak VRAM is already known at 17.4 GB of 24.5.
    4b. Pass 2 on `dressed_front.glb` (decimated): rear view + back garment +
       `mask_back.glb` → `dressed.glb`. Negative control below must hold on the
       front half.
    4c. rank3 (wrong garment) on the same identity, and the 64-view AOV renders of
       rank1 / rank3 / rank5(input) → `score_render_pair.py` → geometric scores.
       **The controls are the gate here**: identity (rank5 ≈ 0), rest-exact
       (outside-mask depth_l1 < 1/64), negative (rank1 inside > rank5 inside).
    5. `tools/write_dress_on_rows.py` → four parquets for 1 row; the emit must
       refuse when any control is broken (test it by feeding rank5's render as
       rank1, that must fail the negative control).
    6. **3-row falsifiability**: 3 identities → `chibifire/anny-dress-on-stage-viewtest`
       (throwaway) with EditScore run on 2 of the 3 → HF viewer → `dress_on`
       config shows 3 rows, `candidates` nested ×3 each, `judge` non-empty on 2 and
       `[]` on 1. If it shows separate tables or a nulled column, fix before real
       shards. Delete the throwaway.
    7. `tools/dress_on_batch.py --count 10` → `chibifire/anny-dress-on-stage-train`
       (40 edits, ~10 identities × 3 candidates × 64-view scoring renders).
    8. Shard v13: `design:dress-on#pipeline@2d-tryon-composite-then-voxhammer-lift`,
       `design:dress-on#renderer@mitsuba3-seeded-hammersley-emits-voxhammer-step1-contract`,
       the stage → HF pointer; memory note that VoxHammer image mode is a
       2D-edit lifter, not a photo-conditioned generator.
    """

    details "Coordinator succession (operator confirmed this round, written after plan approval)",
            ~S"""
            Operator confirmed HERD's succession reading. First write after leaving plan
            mode, before any pipeline work, so HERD reads it on resume rather than guessing:

            - Shard v13 gains, mirroring HERD's `doctrine/magi-coordinator-promotion-2026-09-07`:
              `peer:magi#role@fleet-coordinator-succession-of-herd` (basis assigned, start =
              operator confirmation time), `peer:magi#promoted-by@operator-magi-channel-confirmation`
              (the own-operator half that HERD's row could not assert),
              `peer:herd#role@parked-former-coordinator-succeeded-by-magi`,
              `doctrine:fleet-coordinator#reading@succession-confirmed-by-both-operators`.
            - `bao token capabilities` on `territory/herd-a35a77.agents.weftspun/*` and
              `agents/*` **before** assuming coordinator-scope writes work; HERD had
              `mps-admin` and MAGI does not. If a path is `deny`, record it as a fact and
              raise it, do not widen a policy on a relay.
            - Memory `magi-peer-motion-cluster` gains the role change; MEMORY.md line updated.
            - `peer_must_confirm_with_own_operator` still binds MAGI as coordinator.
            """

    details "Verification", ~S"""
    - **Step 0** prints two AABBs; mask ⊂ model in the same units.
    - **Step 1a** `docs/appendix-e-schema.md` lists every section with its
      subcategories and says explicitly whether stature/mass rows exist.
    - **Step 1b** for each of the 10 identities: `|achieved_stature − target| < 5 mm`
      (about three stacked pennies) and `|achieved_mass − target| / target < 3 %`;
      LBFGS reports converged (`strong_wolfe` line search terminated, not
      `max_iter`); **negative control**: the solve with `height` pinned to 0.5
      must *fail* the stature tolerance on the p5 and p95 rows, or the solve is
      decoration. Also assert the p5 and p95 solutions differ in `height` by more
      than the tolerance, a resolver that returns the same body for both has not
      resolved anything.
    - **Step 1** `trimesh.load("body.glb").bounds` within `[-0.5, 0.5]`; vertex count
      13 718 (`topology="anny"`, `anny_render_schema.py:94`); both mask GLBs inside
      the body's torso height band and on opposite sides of its coronal plane;
      `phenotype.json` has 11 floats plus the source keys.
    - **Step 2** `transforms.json` has 150 frames; rendering twice with the same
      seed yields byte-identical `transforms.json` (**the seeding control**);
      the front-most frame's camera has the largest +forward dot; `2d_mask.png`
      is a single white blob over the front torso, inside the body silhouette.
    - **Step 3** `2d_edit.png` is RGBA, alpha coverage ≥ render's; garment pixels
      land inside the `2d_mask.png` blob (assert ≥ 90 % of pasted alpha inside mask).
    - **Step 4 / 4b** each `dressed_*.glb` loads in trimesh, non-empty.
      **Negative control**: sample points on the output outside the pass's mask
      box; nearest-surface distance to the pass's *input* mesh must be within
      voxel size (1/64), that is VoxHammer's whole guarantee, and a check that
      passes on a wholesale regeneration is decoration. For pass 2 this asserts
      pass 1's front survived. `timing.json` present with face counts.
    - **Step 4c** `score_render_pair.py` prints the identity/negative summary;
      rank5 self-score max `depth_l1 ≤ 1e-6`; rank1 `depth_l1_outside` max < 1/64
      on all 64 views; rank1 `depth_l1_inside` mean > rank5's.
    - **Step 5** `pq.read_table` on all four; `null_count == 0` on every column of
      every table; scores satellite has exactly 3 × 64 rows per root row;
      `dress_on_judge.parquet` absent or with only judged rows. **Negative control
      on the writer**: swapping rank1's asset for rank5's must make the emit exit
      non-zero on the negative control.
    - **Step 6** viewer screenshot of the throwaway repo showing the join.
    - **Step 7** read-back: `HfApi().list_repo_files` shows
    `data/dress_on/train-00000-of-00001.parquet`
      plus the four satellites and the referenced assets;
      `load_dataset("chibifire/anny-dress-on-stage-train", "dress_on")` returns 10 rows,
      each with 3 candidates.
    - Every gate ships with its negative control: a row with `brand` in
      `conditioning_views` is refused; a staged file with `C:/` in it is refused.
    """

    details "Delivery after the edit: SOMA-X correctives, no twist bones (follow-on, not this pass)",
            ~S"""
            The dressed body leaves VoxHammer as a static mesh. Making it an animatable
            avatar is the step the operator's
            "ANNY-SOMAX-PHENOTYPES-CORRECTIVE-BLENDSHAPES-TWISTBONES"
            names, and the workspace has already settled its two halves:

            - **Correctives**: SOMA-X's unified pose correctives (`soma/correctives_model.py`,
              README "Unified Pose Correctives (Beta)") supply the pose-dependent
              blendshapes ANNY does not ship, for any identity model including ANNY. The
              identity vector is the same `pheno_*` row above, so the dressed body and its
              corrective set share one parameterization.
            - **Twist bones: none.** `4-entities/godot-soma-twist/README.md:10-42`, the
              shipping answer is a linear elbow→wrist weight ramp on the wrist bone
              (1.0° / 3.6° / 14.0° error at 45/90/135° pronation, better than a twist bone
              plus disperser), because glTF carries no runtime code and humanoid retarget
              profiles drop any bone they cannot name. `anny_rig.fix_forearm_twist`
              (`anny-render-corpus/anny_rig.py:148`) is that ramp.
            - **Garment as SpringBone-rigged hull segments** (operator, earlier): the
              torso-box edit region is the garment's hull; CoACD it (`max_convex_hull` is
              the cost knob, per memory) and attach as VRM SpringBone chains.
            - **G1 / Unitree**: not a dress-on step. SOMA-X's README names BONES-SEED
              (retargeted G1 data) and Kimodo as its humanoid bridges, the Apache-2
              retarget source for #174's microduck-formula training, recorded here so the
              two tasks share one identity vector rather than two.
            """

    details "Architectural target (operator, 2026-09-07): the whole pipeline under ggml", ~S"""
    "pixal3d.cpp and voxhammer.cpp require the entire codebase to be under ggml."
    Every Python step in this plan is therefore a **reference implementation behind
    a file contract**, to be replaced one at a time by a ggml component of a future
    `voxhammer.cpp` shaped like `pixal3d.cpp`. Blender is already off; Mitsuba
    stays, it is C++ (operator), and only its Python binding here is glue.
    **USD in C++ has exactly one sanctioned path.** `3-interactor/datasource-flow`
    (github.com/V-Sekai-fire/datasource-flow) *is* the workspace's OpenUSD
    implementation: it builds OpenUSD 26.05 from source (`SConstruct`,
    `env.BuildOpenUSD`), keeps `pxr::` inside `flow/core`, and exposes a flat C
    ABI in `flow/ports` (`idtx_core.sigs` → dlsym thunks, the same shape as
    `contract-bus`). Hosts, Godot, Unity, the CLI, bind only that ABI.
    tinyusdz and hand-written USD parsers are both **banned** (operator,
    2026-09-07). So `voxhammer.cpp` is a host of flow's port ring for every
    stage it reads or writes (Mesh + displayColor, Cube edit regions, Points
    voxel sets), and takes its transformer blocks, flow samplers and decoders
    from `pixal3d.cpp`, whose DINOv3 ViT-L/16 port is the TRELLIS.2
    conditioner, so TRELLIS-1's DINOv2 ViT-L/14-with-registers reuses the ViT
    core with its own patch embedding and position encoding. First increment
    is the walking skeleton (voxelize, Cube mask, preserve set, seeded
    Hammersley) bit-compared against `work/smoke2/render/*.usda`.
    Readiness, honestly: ANNY LBS + the LBFGS scalar solve are trivial ports; DINOv2
    and BiRefNet (Swin) have ggml ViT precedents; TRELLIS-1's SLat flow samplers and
    VoxHammer's KV-cached inversion are the real port, pixal3d.cpp covers
    TRELLIS.2's generator, not this editor. The file contracts (PLY/USD in,
    `transforms.json`, PNGs, parquet out) are what make the swap incremental.
    """

    details "voxhammer.cpp, state at 2026-09-07T11:10Z", ~S"""
    - `3-interactor/voxhammer.cpp` (local, not in the manifest, not pushed):
      walking skeleton of the non-learned half, **bit-exact** against the Python
      pipeline on `work/smoke2` (voxels 3378 = 3378, delete 3068 = 3068, cameras
      max|Δc2w| = 0, Hammersley offset identical to 15 decimals).
    - Lean 4 specs (`lean/VoxHammer`) with proof-pinned emitted constants;
      `plausible-witness-dag` domain package as the oracle (8 claims: 4 positive
      `provablyNone`, 4 broken twins `found`); linked into the binary as
      `VoxHammer_oracle.dll` through a `.sigs` dispatch table (operator: `.sigs`,
      not the bus). `vh_prepare --self-check` → mask 0x0. The mask rule is
      executed by the proven Lean function.
    - USD: no hand-written parser, no tinyusdz (both banned). `vh_usd_flow.cpp`
      binds datasource-flow's port ring (`idtx_core_import_scene_from_usd`,
      `idtx_core_export_avatar_to_usd`); needs OpenUSD 26.05 built there (in
      progress after adding cmake/ninja/git to its pixi env) and a `Points` node
      kind added to the ring for voxel sets.
    - Models: not started; they build on pixal3d.cpp's ggml ViT/flow/decoder ports.
    """

    details "Out of scope for this pass (recorded, not done)", ~S"""
    - Appendix-E measurements with no ANNY knob (limb lengths, breadths,
      circumferences other than waist), counted per row as `unmapped_measurements`,
      never fitted. Steering them would need new ANNY targets, not a solve.
    - Fixing `anny/AGENTS.md:61` (names the renamed `parameters_regressor.py`) —
      upstream's doc, one line, raise separately.
    - True multi-image conditioning inside one VoxHammer edit (would need
      multidiffusion ported into the KV-cached inversion samplers).
    - Side views (a third and fourth pass on left/right half-boxes), same
      mechanism, not needed for silhouette + palette.
    - Depth / intrinsics from the garment photos. Every camera here is synthetic
      (Hammersley, written by us), so nothing estimates a camera. If a later pass
      wants garment geometry from the photo (drape, thickness) rather than a 2D
      paste, MoGe-3 (`3-interactor/moge-upstream`, RFD 1102's metric-depth row) is
      the tool for depth + intrinsics on that real image; not needed in pass 1.
    - UV-atlas texture via `pixal3d.cpp` `t2_bake_glb` (CPU, needs the C++ build);
      pass 1 ships `COLOR_0` vertex colours from the Gaussian plus the Gaussian PLY.
    - BiRefNet as a bus interactor (subprocess for N=10).
    - A judge other than EditScore (HERD named Gemma-4-12B zero-shot); the judge
      satellite's interned `judge_base/adapter` columns take either without a
      schema change, and the frozen-judge doctrine binds whichever runs.
    - LPIPS in the geometric scorer, `score_render_pair.py:9` defers it too.
    - Removing `bpy` from the edit env's `pixi.toml` (it is stubbed at runtime now;
      pxr and bpy cannot share a process). Do it after batch 1 lands, not under it;
      it also retires the only reason the edit env was pinned to Python 3.11.
    - Replacing the last PLY: the 3DGS Gaussian (`*_gaussian.ply`, the standard
      splat container) as `UsdGeom.Points` with `f_dc`/`opacity`/`scale`/`rot`
      primvars. Everything else crossing a tool boundary is USD now.
    - New standalone `dress-on` repo + manifest placement (tools live in
      `voxhammer-upstream/tools/` for now; CLAUDE.md "one repo per model" says this
      moves once it is more than glue).
    """

    details "Amendments, 2026-09-08: three defects fixed and one design answered", ~S"""
    The corpus was re-staged and republished. A copy pulled before this date
    carries the first two defects.

    **Three candidates shared one mesh.** `stage_asset` keyed its destination
    on the source file's name under a directory that was per row rather than
    per candidate, so rank1, rank3 and rank5 all wrote `candidate.usda` and
    `candidate_gaussian.ply` to one path; the later copies were dropped in
    silence because the writer only copied when the destination was absent.
    Front and back renders collapsed the same way. Measured: 12 distinct
    meshes for 36 candidate rows, and `2d_render_front` byte-equal to
    `2d_render_back` on every row. The published dataset therefore asserted
    that three different candidates share one geometry, and this RFD's own
    negative control could not fail. That control swaps rank1's asset for
    rank5's and requires the emit to exit non-zero, and the two already pointed
    at one file. The destination now carries the candidate and the side, and two
    different sources reaching one destination is refused rather than aliased.
    After: 36 of 36 distinct by content, front differing from back on all 24
    that carry both, and the negative control exits non-zero.

    **The edited candidates declared the wrong scale.** rank1 and rank3
    carried `metersPerUnit = 1` while `body.usda`, rank5 and the masks carried
    the identity's stature, on all twelve targets, so a consumer honouring USD
    units read the two edited candidates 30 to 49 per cent too small. Geometry
    was never affected: every mesh is unit-height and only the declared scale
    lied, which is why the voxel gate, which normalises, stayed green.
    Cause in two places: `run_edit_test.py` called `usd_io.write_mesh` without
    a scale and took its default of 1.0, and `usd_convert.py` then found the
    file present and skipped it. That is rule 3, a silent skip reading as a
    pass. Fixed in three: the scale is required on the driver,
    `dress_on_batch.py` passes it from `phenotype.json`, and the skip became a
    check that refuses a mismatch. Twenty-four declarations repaired with the
    geometry asserted unchanged vertex-for-vertex.

    **Payload now lives in the parquet, amending this RFD's own ruling.** This
    document ruled for assets beside the parquets rather than
    `struct<bytes,path>` embedding. The operator reversed that on 2026-09-08:
    a path is not the data and the publisher drops what it points at, which is
    how the FBD corpora lost their diagrams. Images take the viewer's
    `{bytes, path}` shape and are declared in a `dataset_info` block generated
    from the parquet schema, so a column added to the writer cannot go
    undeclared; meshes, masks and point clouds are bytes with the staged path
    kept as provenance. Verified: 204 images decode to the same pixels as the
    files they replaced, 108 blobs are byte-identical, and a mesh reads back
    through `usd_io.read_mesh` straight from the parquet. The absolute-path
    scan now reads into the parquet's string columns and its embedded OpenUSD
    rather than skipping the file. 441 MB staged, 878 MB published, and no
    `assets/` tree on the Hub: the 156 files from the earlier upload were
    deleted.

    **Separating the garment from the body: answered no**, with the
    measurements in RFD 2239. Vertex colour is flat grey across every group;
    the dressed and undressed decodes differ over the whole body rather than
    at the garment; and the decode does not conserve volume, the dressed mesh
    exceeding the undressed by about 10 litres against a body of 0.0388 cubic
    metres. A distance threshold between the decodes measures TRELLIS, not
    fabric. The route that works uses `composite.json` and `view.json`, which
    already record the paste and the camera exactly, so the garment region is
    known by construction rather than inferred.

    **Scheduled and not started**, parking with the pipeline: the try-on clip,
    whose camera path is designed and measured. A tour of the Hammersley
    views drops the worst step from 160 degrees to 29, and six elevation bands
    give six shots of about one revolution each, roughly 1,970 frames and 66
    seconds at 30 fps. Also the two render corpora, which still have no parquet
    at all.
    """

    drafted_by :ai
  end
end
