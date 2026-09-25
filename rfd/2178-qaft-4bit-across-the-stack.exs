# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2178. `mix rfd.render` renders rfd/2178-qaft-4bit-across-the-stack/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2178 do
  use RFD.DSL

  rfd 2178, "QAFT 4-bit across the model stack" do
    state :discussion

    feature "target every model in the atelier-workshop at 4-bit\nQuantization-Aware Fine-Tuning"

    scope "every model row in RFD 1102's task catalog"

    decision ~S"""
    Every model in the atelier-workshop (the pipeline) targets QAFT 4-bit; three classes (A
    upstream available, B feasible locally, C infeasible locally) track where each stands.
    """

    problem ~S"""
    RFD 1027 (QAFT-first weights) committed QAFT-first as the default weights format. RFD 2139
    (QAFT stack survey, abandoned) found only Gemma-4-12B ships a true upstream QAT Q4_0 release.
    Wan-VACE, Pixal3D, VoxHammer, MoGe-3, and the audio-panel models run at published precision.
    The plan needs a per-model position: which model is QAFT'd, when, at what compute cost.
    """

    section "The three classes", ~S"""
    - Class A (upstream QAFT available): use verbatim. Gemma-4-12B QAT Q4_0 today.
    - Class B (upstream QAFT feasible locally): the workspace produces one from published weights
    via a QAFT fine-tune on the RTX 3090. Small models (Qwen3-TTS-1.7B, Kimodo, SkinTokens,
    MoGe-3, rf-detr-Seg, WavLM, wav2vec2, ipa-whisper) fit in one overnight run each.
    - Class C (upstream QAFT infeasible locally): Wan-VACE 14B, Pixal3D 24 GB base. QAFT needs
    multi-day runs; parked until compute expands or an upstream Q4 release lands.

    See [DETAILS.md](DETAILS.md) for the per-model class, size, and compute estimate. See RFD 1027
    (QAFT-first weights) for the QAFT-first rule.
    """

    related ~S"""
    Extends RFD 1027 (QAFT-first weights, committed). Consumed by RFD 2167 (voice-reward
    distillation, parked, needs Class B Qwen3-TTS QAFT).
    """

    details_title "QAFT 4-bit across the model stack"

    details "Per-model table", ~S"""
    Compute estimates assume the RTX 3090 (24 GB) and a QAFT fine-tune on
    each model's own pretraining data or a distillation-appropriate
    substitute. "Fits" = QAFT run fits 24 GB VRAM. "Overnight" = <12 h.
    "Multi-day" = >36 h continuous.

    | Model | Params | Upstream QAFT? | Class | QAFT compute | Notes |
    | --- | ---: | :---: | :---: | --- | --- |
    | Gemma-4-12B | 12B | ✓ Q4_0 GGUF (Google) | A | 0 (verbatim) | The anchor case; RFD 1027's canonical example |
    | Wan-VACE | 14B | ✗ | C | Multi-day, tight | Doesn't fit 24 GB in QAFT config without heavy gradient checkpointing; parked |
    | Pixal3D (image → mesh) | ~24 GB bf16 | ✗ | C | Multi-day, tight | Same 24 GB ceiling; staged inference already at peak; QAFT training doesn't fit |
    | VoxHammer | 0 (no weights, RFD 1162) | n/a | n/a | 0 | Nothing to quantize |
    | TRELLIS.2 | ~8B | ✗ | B | Overnight | Fits QAFT run at moderate batch |
    | MoGe-3 | ~1B | ✗ | B | Hours | Small; trivial run |
    | SkinTokens | ~1B | ✗ | B | Hours | Small |
    | Kimodo | ~0.6B | ✗ | B | Hours | Small |
    | rf-detr-Seg | ~0.2B | ✗ | B | Hours | Very small |
    | LaMa (inpainting) | ~0.2B | ✗ | B | Hours | Very small |
    | Qwen3-TTS-12Hz-1.7B-Base | 1.7B | ✗ | B | Overnight | Blocks RFD 2167's voice-reward distillation until done |
    | Voxtral Mini 3B | 3B | ✗ | B | Overnight | Fits comfortably |
    | Whisper large-v3 | 1.55B | ✗ | B | Hours | Small |
    | Parakeet TDT 0.6B v3 | 0.6B | ✗ | B | Hours | Small |
    | wav2vec2 large | 0.3B | ✗ | B | Hours | Small |
    | ipa-whisper (small + base) | ~0.5 GB | ✗ | B | Hours | Small |
    | WavLM Base+ SV | ~0.1B | ✗ | B | Minutes | Trivial |
    | allosaurus (universal + 27) | ~0.03B | ✗ | B | Minutes | Trivial; per-language head |
    """

    details "Sequencing", ~S"""
    Class-B QAFT rungs, cheapest first, so each result unblocks the next:

    1. **Voice-adjacent small models first**, Qwen3-TTS-1.7B, wav2vec2,
       Parakeet, ipa-whisper. Overnight batch. Unblocks RFD 2167
       (voice-reward distillation) because both the reward LoRA base and
       the TTS candidate generation stop dominating inference cost.
    2. **Segmentation + inpainting**, rf-detr-Seg, LaMa. Hours. Small
       in the compute budget; large in the RFD 1168 layer-decomposition
       path's per-view cost.
    3. **Motion + rigging**, Kimodo, SkinTokens, MoGe-3. Hours each.
    4. **Mid-tier vision + audio**, TRELLIS.2 (~8B), Voxtral (3B),
       Whisper large-v3. Overnight runs.
    5. **Class C (Wan-VACE, Pixal3D)**, parked. Either an upstream Q4
       lands or the workspace acquires >24 GB training capacity.
    """

    details "Compute cost of the plan", ~S"""
    Rough total for Class B (all rungs 1-4): about a week of continuous
    3090 wall-time if run serially. Roughly a weekend if parallelised
    across a Mac (MPS QLoRA for the smallest) and the 3090 (true QAFT
    for the mid-tier). CLAUDE.md's Compute constraint applies: rented
    compute stays blocklisted; runs happen on the desktop machine.
    """

    details "Retraction / adjustment note", ~S"""
    RFD 2139 read "no true-QAFT 4-bit checkpoints exist upstream" as
    "only Gemma runs QAFT-quantized." That reading conflated "upstream
    publishes one" with "the workspace can have one." This RFD splits
    those two into Class A vs Class B. Wan-VACE and Pixal3D stay in
    Class C, matching RFD 2139's concern for those specific models.
    """

    drafted_by :ai
  end
end
