# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2184. `mix rfd.render` renders rfd/2184-omnigen2-sdcpp-port-lean4-verified/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2184 do
  use RFD.DSL

  rfd 2184, "Port OmniGen2's Lumina2 DiT into stable-diffusion.cpp, Lean4-verified" do
    compact_head true

    state :discussion

    feature "GGUF Q4_K_M inference of OmniGen2 via stable-diffusion.cpp, with
Lean4 proofs certifying the ggml graph agrees with the PyTorch reference"

    scope "new project `3-interactor/omnigen2-sdcpp-port` (C++/ggml + Lean4);
new upstream mirror `3-interactor/stable-diffusion-cpp-upstream`"

    decision ~S"""
    Add a Lumina2 block family to stable-diffusion.cpp, then compose the
    OmniGen2 DiT out of those blocks, then land the GGUF weight loader that
    maps `calcuis/omnigen2-gguf`'s Q4_K_M safetensors to ggml tensors.

    `DETAILS.md` carries the milestones, verification, scope revisions and what is not in this
    RFD.
    """

    problem ~S"""
    Session 2026-09-02 measured OmniGen2 on the 3090:
    """

    related ~S"""
    - **RFD 2158 (abandoned)**, Lean 4 FBD compiler self-host, whose Stage
      0-1 work established the Lean-writes-real-bytes pattern this RFD
      reuses at a different target (ggml tensor semantics vs RISC-V ELF).
    - **`formal/rfdetr_proofs/`** in `3-interactor/rf-detr-cpp/`, the
      working template for Lean4 proofs alongside a ggml port.
    - Upstream: `github.com/leejet/stable-diffusion.cpp`,
      `github.com/OmniGen2/OmniGen2`, `github.com/city96/ComfyUI-GGUF`,
      `huggingface.co/calcuis/omnigen2-gguf`.
    - **Blocklist row** at the workspace's `BLOCKLIST.md` for
      `Qwen-Image-Edit` and `FLUX.1-Kontext-dev`: both are the obvious
      ready-made ggml-stack image editors but blocked, which is precisely
      why the OmniGen2 port is warranted rather than a substitution.
    """

    details_title "Port OmniGen2's Lumina2 DiT into stable-diffusion.cpp, Lean4-verified"

    details "Problem", ~S"""
    Session 2026-09-02 measured OmniGen2 on the 3090:

    - **bf16 + sequential CPU offload:** 12 s/step × 50 = 10 min per 1024²
      image. 15.5 GB weights spilled through PCIe every step.
    - **bf16 + no offload:** fits at 97 % VRAM but activations at 1024²
      push over → OOM risk.
    - **bitsandbytes nf4 (PTQ):** hits bnb's slow-kernel fallback because
      `hidden_size=2520` isn't a multiple of the fast kernel's blocksize=64.
      Measured 10+ min without completing one denoising step.

    The community demonstrably runs OmniGen2 at Q4_K_M, `calcuis/omnigen2-gguf`
    ships the weights, `ComfyUI-GGUF` loads them. But that runtime is
    ComfyUI-specific and drags a large Python stack; the workspace prefers
    ggml through a headless C++ path (llama.cpp, stable-diffusion.cpp) so
    inference is one binary + one weights file, no orchestrator, no
    supply-chain surface for a rewrite of the diffusers pipeline.

    `stable-diffusion.cpp` (leejet/stable-diffusion.cpp) is the right family:
    plain C/C++ on ggml, first-class GGUF, no Python at runtime. But its
    supported model list (SD1.x/2.x, SDXL, SD3, FLUX.1-dev/schnell,
    FLUX.2, Chroma, Qwen Image, plus image-edit models Flux-Kontext / Qwen
    Image Edit / Boogu / Mage-Flow-Edit) **does not include OmniGen2's
    architecture family**.

    Session 2026-09-02 also verified, from `transformer_omnigen2.py` in
    the OmniGen2 checkout, that OmniGen2 is a **Lumina2-family DiT**, not
    a FLUX descendant:

    ```python
    from .block_lumina2 import LuminaLayerNormContinuous, LuminaRMSNormZero,
        LuminaFeedForward, Lumina2CombinedTimestepCaptionEmbedding
    ```

    Single `OmniGen2TransformerBlock`, not FLUX's `DoubleStreamBlock` +
    `SingleStreamBlock` split. Custom `OmniGen2RotaryPosEmbed`, not
    `FluxPosEmbed`. RMS norm + SwiGLU + fused attention, LLaMA-family
    primitives Lumina2 inherits. So stable-diffusion.cpp's existing FLUX
    loader is not adaptable to OmniGen2 with a few weight-remap tweaks.
    The port needs the Lumina2 block family added first.
    """

    details "Decision", ~S"""
    Add a Lumina2 block family to stable-diffusion.cpp, then compose the
    OmniGen2 DiT out of those blocks, then land the GGUF weight loader that
    maps `calcuis/omnigen2-gguf`'s Q4_K_M safetensors to ggml tensors.

    **Lean4 as an assist** (not a substitute for measurement): the ggml
    graph code is easy to write and hard to check numerically at scale.
    Each ggml block that gets added is paired with a Lean4 spec of the same
    block's mathematical semantics, the reduction axes of an RMSNorm, the
    shape law of `axes_lens=[1024,1664,1664]` RoPE, the modulation gating
    formula. The proofs certify the ggml graph performs the intended
    composition of operations before we numerically diff against the
    PyTorch reference. This is the same shape `formal/rfdetr_proofs/` uses
    today for the RF-DETR backward primitives, the pattern transfers.

    The two artefacts that verify each block:

    1. **Lean4 spec**, the block's operation as a total function, typed
       in tensor shape + dtype (`LuminaRMSNormZero.apply` etc.), with the
       composition lemmas that let a `TransformerBlock` reduce to a
       sequence of primitive-block calls.
    2. **ggml graph test**, `test_lumina_rmsnorm_zero.cpp` builds the
       block with ggml, runs it on synthetic input, diffs against
       PyTorch. Bound: whatever `test_backbone`-style tolerance the port's
       own gate later settles on.

    A Lean4 proof that stands alone does not certify correctness of the
    ggml graph; a numeric diff that passes does not certify absence of
    edge-case bugs the diff's inputs did not exercise. **Both are required
    per block.** A block that has one but not the other is not "done" in
    this RFD's sense.

    ### Milestones

    Ladder in the Gall's-law sense: no rung is added until the one below
    it demonstrably runs a real reference.

    1. **Fork stable-diffusion.cpp** into `weftspun/stable-diffusion-cpp-upstream`.
       Add `3-interactor/omnigen2-sdcpp-port/` as the workspace-side project
       holding the Lumina2 additions as PR-shaped patches + the Lean4 proofs
       under `formal/lumina2_proofs/`.
    2. **Land `LuminaRMSNorm` + `LuminaRMSNormZero` in ggml** with Lean4
       spec and numeric diff against `block_lumina2.py`'s reference.
       Standalone gated test.
    3. **Land `LuminaFeedForward` (SwiGLU MLP)** with the same pair.
    4. **Land `OmniGen2RotaryPosEmbed`**, the axes_lens=[1024,1664,1664]
       3D positional encoding, with Lean4 spec of the axis-alignment law.
       This is where FLUX-family RoPE code helps as reference but does not
       directly apply.
    5. **Compose `OmniGen2TransformerBlock`** from the primitives, one
       Lean4 lemma that reduces the composite to the sequence, and one
       ggml graph test that diffs against upstream.
    6. **Compose full `OmniGen2Transformer2DModel`**, 32 layers stacked,
       plus `Lumina2CombinedTimestepCaptionEmbedding` for the input path.
       End-to-end forward-pass diff against the fp32 PyTorch model on one
       canonical (image, instruction) pair.
    7. **GGUF weight loader**, map `calcuis/omnigen2-gguf` Q4_K_M
       safetensors keys to ggml tensor names, verify inference matches the
       ComfyUI-GGUF reference on the same input.
    8. **Integration with stable-diffusion.cpp's driver**, the CLI accepts
       `--model omnigen2-fp32-q4_k_m.gguf --edit --input source.png
       --prompt "..."` and writes the edit to disk.
    9. **Ship a PR upstream to leejet/stable-diffusion.cpp** adding the
       Lumina2 block family as a first-class supported architecture, with
       OmniGen2 as the first consumer.

    Estimated calendar time: **2-4 weeks** at a milestone every 2-4 days.
    Estimated per-rung compute: milestone 6's numeric diff needs the fp32
    PyTorch reference forward (~10 min on the 3090); nothing else needs
    heavy GPU time.
    """

    details "Verification", ~S"""
    Every ggml block that lands carries the pair, Lean4 spec + numeric
    diff, described above. Rungs 5 and 6 additionally carry:

    - **A negative control** (rule 2): a block wired with the wrong RoPE
      axis assignment MUST fail the numeric diff, and the Lean4 spec's
      composition lemma MUST refuse to type-check. Both directions.
    - **A silent-skip guard** (rule 3): any block whose ggml test is
      compile-skipped because a dependency isn't landed FAILS the port's
      CI job by name. No "green" summaries with 4 of 5 blocks tested.

    The gate that decides RFD closure is not "the port compiles", it is
    **the fp32 forward-pass diff at milestone 6 is below the tolerance set
    in `test_omnigen2_forward.cpp`, and the Q4_K_M inference at milestone 7
    produces images within the sha256-region-match of ComfyUI-GGUF on the
    same seeded (image, instruction) pair.**
    """

    details "Related", ~S"""
    - **RFD 2158 (abandoned)**, Lean 4 FBD compiler self-host, whose Stage
      0-1 work established the Lean-writes-real-bytes pattern this RFD
      reuses at a different target (ggml tensor semantics vs RISC-V ELF).
    - **`formal/rfdetr_proofs/`** in `3-interactor/rf-detr-cpp/`, the
      working template for Lean4 proofs alongside a ggml port.
    - Upstream: `github.com/leejet/stable-diffusion.cpp`,
      `github.com/OmniGen2/OmniGen2`, `github.com/city96/ComfyUI-GGUF`,
      `huggingface.co/calcuis/omnigen2-gguf`.
    - **Blocklist row** at the workspace's `BLOCKLIST.md` for
      `Qwen-Image-Edit` and `FLUX.1-Kontext-dev`: both are the obvious
      ready-made ggml-stack image editors but blocked, which is precisely
      why the OmniGen2 port is warranted rather than a substitution.
    """

    details "Scope revision after milestone-1 discovery (2026-09-03)", ~S"""
    The initial draft above estimated "2-4 weeks" on the assumption that the
    Lumina2 block family had to be added to stable-diffusion.cpp from scratch.
    Landing milestone 1 revealed that sdcpp **already ships two Lumina2-family
    model heads**: `src/model/diffusion/z_image.hpp` (which explicitly references
    `Alpha-VLLM/Lumina-Image-2.0` in a source comment) and
    `src/model/diffusion/boogu.hpp`, an image-edit model with an even closer
    match to OmniGen2's config:

    | Field | Boogu | OmniGen2 | Match? |
    |---|---|---|---|
    | `axes_dim` | `{40, 40, 40}` | `[40, 40, 40]` | **yes** |
    | `num_layers` | 32 | 32 | **yes** |
    | `num_kv_heads` | 7 | 7 | **yes** |
    | `patch_size` | 2 | 2 | **yes** |
    | `norm_eps` | 1e-5 | 1e-5 | **yes** |
    | `timestep_scale` | 1000.0f | 1000.0 | **yes** |
    | `multiple_of` | 256 | 256 | **yes** |
    | `hidden_size` | 3360 | 2520 | different, config-only |
    | `num_double_stream_layers` | 8 | (n/a in OmniGen2 config) | needs check |
    | mllm text encoder | qwen_image | Qwen2.5-VL slice | different integration |

    So the LOAD-BEARING work, `LuminaRMSNormZero`, `LuminaFeedForward`,
    3D RoPE with `axes_dim = {40, 40, 40}`, AdaLN modulation, is already
    implemented and shipping. The port is **adapt Boogu's implementation to
    OmniGen2's config + integrate OmniGen2's specific text-encoder path**,
    not build the Lumina2 blocks from scratch.

    **Revised milestone map:**

    - **Milestones 2, 3, 4:** superseded by existing Boogu/ZImage code. No
      new ggml blocks needed. Lean4 specs of the shared primitives still
      worthwhile as documentation, but not blocking.
    - **Milestone 5 (composite block):** reduces to "instantiate Boogu's
      `DoubleStreamBlock`/`SingleStreamBlock` with OmniGen2's `hidden_size`
      = 2520 and check double-stream layer count from OmniGen2's config."
    - **Milestone 6 (full model):** likewise a config-value port, plus
      OmniGen2's text-encoder path. The novel work is the mllm integration
      (Qwen2.5-VL vs qwen_image), not the DiT.
    - **Milestone 7 (GGUF loader):** same scope as before. Weight-name
      remap from calcuis's Q4_K_M to stable-diffusion.cpp's tensor names.
    - **Milestone 8 (CLI):** likely inherits from Boogu's CLI path with
      minimal changes.

    **Revised calendar estimate: days, not weeks.** Milestones 5-8 as
    config-value/weight-remap work land in ~1-3 days of focused effort each.
    Milestone 9 (upstream PR) may be as small as "wire OmniGen2 into the
    existing Boogu code path with OmniGen2's config struct."

    **Load-bearing question that decides the revision:** does Boogu's
    `DoubleStreamBlock` layout with OmniGen2's `hidden_size=2520` produce
    numerically-identical outputs to `OmniGen2TransformerBlock.forward()` in
    the diffusers reference, given the same weights? If yes, the port is
    config-mostly. If no, some Boogu-specific choice (adaLN split, gating,
    residual placement) differs from OmniGen2 and warrants a per-difference
    audit, still much less work than a from-scratch block family.

    The Lumina2 upstream benchmark (`Alpha-VLLM/Lumina-Image-2.0`, fired
    2026-09-03 as `bu8k6yvbc`) will settle the reference-speed baseline that
    milestones 6 and 7 must meet.
    """

    details "What is NOT in this RFD", ~S"""
    - The MaskScore image pilot's tonight-scoped fallback (bf16 +
      `enable_model_cpu_offload`) is out of scope; that path proceeds
      regardless and produces pilot data while this port is landing.
    - Video-family DiTs (Wan-VACE etc.) are not scoped even though
      stable-diffusion.cpp lists them, the workspace's current need is
      image editing, and video would double the surface.
    - The `mllm/` half of OmniGen2 (Qwen2.5-VL slice) is not ported here —
      it runs through the standard llama.cpp mtmd path that this
      workspace's `3-interactor/llama-cpp-npu-vision-upstream` already
      exercises. Only the DiT half needs the port.
    """

    drafted_by :ai
  end
end
