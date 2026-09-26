# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 1102. `mix rfd.render` renders rfd/1102-supported-atelier-modules/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD1102 do
  use RFD.DSL

  rfd 1102, "The supported task catalog, one live source" do
    state :committed

    scope "RFDs 1036 (packaging), 1173 (pipeline), 2136 (gacha ladder), 2188 (one ggml across workspace), 2210 (atelier surface), 2230 (ggml adapters)"

    attest_in :none

    decision ~S"""
    Every module in the atelier catalog runs on **ggml** (RFD 2188).
    Weights ship as GGUF, quantised to Q4. The set of Docker images
    this workspace ships per RFD 1036 (plain HTTP, `/health` +
    `/predict`, weights at build time, one model per image) runs on
    the local desktop GPU per CLAUDE.md via ggml's Vulkan backend
    (RFD 2231's substitute), and feeds the two pipelines the workspace
    operates:

    - **MaskScore corpus construction** (RFD 1173): eight stubs across
      mesh/depth/pose/keypoints/multimodal/speech/text/video. Five
      shipped on HF (RFD 2164 speech + Rung 1 walking skeleton).
    - **The gacha critical path** (RFD 2136): ten-rung ladder from a
      language prompt to a public roll-button-dispensed VRM.

    Consumer projects wrap the shared `2-contract/ggml/` runtime; the
    native `modules/ggml/` module (RFD 2230) exposes a GDExtension
    surface (`Ggml.load_model`, `Ggml.run_inference`, `Ggml.load_lora`)
    consumed by per-model GDScript adapter files loaded under Godot's
    script sandbox.

    `DETAILS.md` carries the current per-task table (with per-model
    GGUF sizes and port-needed flags), the six-step migration recipe,
    the two pipeline diagrams, and the packaging pointer.
    """

    related ~S"""
    RFD 1036 (Docker packaging), RFD 1053 (OpenUSD internal + glTF/VRM
    at edge), RFD 1027 (GPU tier), RFD 1173 (multimodal pipeline),
    RFD 2136 (gacha ladder), RFD 2164 (Speech stub shipped), RFD 2188
    (one ggml across workspace), RFD 2210 (atelier native shipping
    surface), RFD 2214 (model bundle SQLite+ZSTD), RFD 2229
    (interchangeable-parts consolidation), RFD 2230 (ggml adapters in
    godot-sandbox), RFD 2231 (Vulkan renderer).
    """

    details_title "The supported task catalog, one live source"

    details_preamble ~S"""
    Every module in the atelier catalog runs on **ggml** (RFD 2188 —
    one ggml source across the workspace at `2-contract/ggml/`).
    Weights ship as GGUF, quantised to Q4 unless a measurement asks
    for wider precision. Consumer projects wrap the shared runtime;
    per-model adapters (tokenizer, prompt template, LoRA, sampler
    config) are GDScript files loaded under Godot's script sandbox per
    RFD 2230. Models with no upstream GGUF conversion carry a "port
    needed" note; the six-step migration recipe is at the end of this
    file.
    """

    details "Model catalog", ~S"""
    | Task                          | Model                         | Weights (Q4 target)             | Runtime                                        |
    | ----------------------------- | ----------------------------- | ------------------------------- | ---------------------------------------------- |
    | Text/image reasoning          | Gemma-4-12B (QAT Q4_0)        | ~6 GB Q4_0 GGUF                 | ggml native (llama.cpp Vulkan backend)         |
    | Reward model (image editing)  | Qwen3-VL-8B + EditScore LoRA  | ~4 GB Q4 GGUF + LoRA GGUF sidecar | ggml native; LoRA applied via `Ggml.load_lora` |
    | Text/image → image            | Wan-VACE                      | ~7 GB Q4 GGUF                   | ggml native; **port needed** (upstream is torch) |
    | Image → coarse mesh           | Pixal3D (TRELLIS.2 impl)      | ~2 GB Q4 GGUF                   | ggml native; **port needed**                   |
    | Mesh refinement               | VoxHammer                     | no weights                      | ggml native (procedural, no model file)        |
    | Image → mesh (fast)           | Pixal3D (TRELLIS.2 impl)      | same row as above               | one repo, one GGUF, one row per Pixal3D-is-TRELLIS.2 memory |
    | Metric depth                  | MoGe-3                        | ~250 MB Q4 GGUF                 | ggml native; **port needed**                   |
    | Auto-rig                      | SkinTokens                    | GGUF (skin-tokens.cpp)          | ggml native (vendor's own runtime, already GGML) |
    | Text → motion                 | Kimodo                        | GGUF (motion-bricks-cpp rev)    | ggml native; SOMA pose format (77 rotvecs → 78 with root identity prepended) |
    | Mesh segmentation             | rf-detr-Seg (RFD 1168)        | GGUF (segmentation head)        | ggml native; **port needed** from ONNX         |
    | Layer decomposition           | rf-detr-Seg + LaMa inpainting | GGUF each                       | ggml native; **port needed**                   |
    | Mesh retopology               | AutoRemesher, xatlas UV       | no weights                      | native binary (format-adjacent tools)          |
    """

    details "Voice + ASR (RFD 2164)", ~S"""
    | Task                          | Model                                      | Weights (Q4 target)   | Runtime                                    |
    | ----------------------------- | ------------------------------------------ | --------------------- | ------------------------------------------ |
    | Voice cloning                 | Qwen3-TTS-12Hz-1.7B-Base                   | ~900 MB Q4 GGUF       | ggml native; **port needed**              |
    | ASR (canonical)               | Parakeet TDT 0.6B v3 (CC-BY-4.0)           | ~350 MB Q4 GGUF       | ggml native; **port needed** from Nemo    |
    | ASR panel (7 tracks)          | Parakeet TDT 0.6B v3, Voxtral Mini 3B, wav2vec2, Voxtral-IPA, Gemma-4-12B GBNF-IPA, allosaurus universal + eng | ~various Q4 GGUFs     | ggml native for each; Gemma-4-12B already GGUF; Voxtral + wav2vec2 + allosaurus **ports needed** |
    | Speaker embedding             | Microsoft WavLM Base+ SV                   | ~100 MB Q4 GGUF       | ggml native; **port needed**              |
    """

    details "Migration recipe (per model)", ~S"""
    Same recipe RFD 2229 named as the interchangeable-parts consolidation
    shape, one row per consumer:

    1. **Q4 quantize**, QAT if we train the model, PTQ per the CLAUDE.md
       Post-training-quantization blocklist exemption (a vendor's own
       runtime is exempt from the QAT-only rule) otherwise. Target Q4_0
       for text models, Q4_K_M for vision if the K-quant produces a
       measurable EditScore win over Q4_0 on held-out inputs.
    2. **GGUF conversion**, via llama.cpp's `convert_hf_to_gguf.py` for
       HF-hosted models; per-model script for non-HF checkpoints. Ports
       for `Wan-VACE`, `Pixal3D`, `MoGe-3`, `rf-detr-Seg`, `LaMa`,
       `Qwen3-TTS`, `Parakeet`, `Voxtral`, `wav2vec2`, `allosaurus`,
       `WavLM` all follow this step.
    3. **ZSTD-SQLite bundle**, RFD 2214 shape; `sqlite3_open()` on
       local disk. One `.zstd.sqlite` per model bundle, install-time
       download via the release channel.
    4. **`Ggml.load_model()` GDExtension call**, RFD 2230 surface; the
       native `modules/ggml/` module hands bytes to ggml.
    5. **GDScript adapter**, per-model `.gd` file at
       `res://adapters/<name>.gd`, extends `GgmlAdapter`, defines
       `format_prompt` / `decode_output` / `apply_lora` per model
       quirks.
    6. **Docker image**, per RFD 1036 `/health` + `/predict` shape
       still applies; the container binary is now the native Godot
       binary + shared `modules/ggml/` + the model's ZSTD-SQLite
       bundle + adapter `.gd`. One model per image (packaging stays
       RFD 1036), one runtime across images.
    """

    details "Pipeline: MaskScore corpus construction (RFD 1173)", ~S"""
        input      Docker container per model, /health + /predict (RFD 1036)
             |
        render     Mitsuba llvm_ad_rgb or metal_ad_rgb, sphere_hammersley
             |
        MaskScore  mask → reconstruct → score decoded outputs
             |     (reconstruct model = ggml native per this RFD)
        parquet    3-file ZSTD per stub (root + candidates + scores),
                   ETNF (no nulls, interned vocab), RFD 2165.1 schema
             |
        HF         chibifire/maskscore-rung-1-bootstrap, 5 of 8 stubs shipped
                   (mesh, depth, pose, keypoints, multimodal, speech)
    """

    details "Pipeline: Gacha critical path (RFD 2136)", ~S"""
    Ten rungs, each producing an output the next rung consumes:

        0. Language prompt → image           (OmniGen2, Q4 GGUF + Flow LCM LoRA GGUF)
        1. Image → mesh                      (Pixal3D, Q4 GGUF)
        2. Mesh → judged                     (EditScore over Qwen3-VL-8B Q4 GGUF)
        3. Judged → repaired                 (VoxHammer, procedural, N-attempt bound)
        4. Repaired → skinned                (skin-tokens.cpp against ANNY, GGUF)
        5. Skinned → tagged                  (SAM2 or rf-detr-Seg + OmniGen2 per RFD 2183, all GGUF)
        6. Tagged → VRM                      (portable character)
        7. Prompt list → pool                (~50 VRMs, judged, seed-reproducible)
        8. Pool → roll button                (native Godot binary head per RFD 2210)
        9. Public                            (hosted with sponsor link)

    Runtime motion: motion-bricks.cpp (already ggml/GGUF) generates
    keyframe-driven animation from the shipped VRM. Apache-2.0 code,
    NVIDIA Open Model License on weights (same license class already
    accepted for Kimodo-SOMA-* per RFD 1028). 183M params. Runs
    alongside rungs 7-9 as the animation source for the pool preview
    and hosted roll page. Loaded through the shared `modules/ggml/`
    module per RFD 2230.
    """

    details "Format boundary", ~S"""
    Internal: OpenUSD `.usda` / `.usdc` (RFD 1053 `committed`), each
    stage adds a layer.
    Transmission: glTF binary (asset), VRM (avatar), USDZ (archive).
    Convert at the boundary only.
    """

    details "Packaging", ~S"""
    Per RFD 1036 (`committed`): plain Docker, `/health` + `/predict`,
    weights at build time, two-stage Dockerfile (`contract` + `worker`),
    one model per image. Target 24 GB card (local desktop GPU per
    CLAUDE.md). The container's inference binary is the shared native
    Godot binary from `entities-godot-sandbox` (RFD 2210) with the
    per-model adapter mounted; the runtime is ggml with the Vulkan
    backend per RFD 2231's substitute (Vulkan on native).
    """

    details "Related", ~S"""
    RFD 1036 (Docker packaging), RFD 1053 (OpenUSD internal + glTF/VRM
    at edge), RFD 1094 (multi-image routing), RFD 1084 (avatar pipeline
    client side), RFD 1088 (HTTPS setup), RFD 1085 (code map), RFD 1105
    (webcam avatar control), RFD 1108 (XR floor anchoring), RFD 2188
    (one ggml across workspace), RFD 2214 (model bundle SQLite+ZSTD),
    RFD 2229 (interchangeable-parts consolidation policy), RFD 2230
    (ggml adapters in godot-sandbox), RFD 2210 (atelier shipping
    surface, native).
    """

    drafted_by :ai
  end
end
