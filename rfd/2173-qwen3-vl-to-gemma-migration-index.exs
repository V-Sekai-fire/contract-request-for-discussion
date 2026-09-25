# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2173. `mix rfd.render` renders rfd/2173-qwen3-vl-to-gemma-migration-index/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2173 do
  use RFD.DSL

  rfd 2173, "Qwen3-VL to Gemma-4-12B migration index" do
    state :committed

    feature "documentation index for the reasoning-core swap"

    scope "every open RFD that names Qwen3-VL as the reasoning core"

    decision ~S"""
    This RFD is the citable index for the Qwen3-VL to Gemma-4-12B swap; ten open RFDs still name
    Qwen3-VL, and each migrates its mention as follow-on when next touched.
    """

    problem ~S"""
    RFD 2169 (studio-core abandonment) named Gemma-4-12B (QAT Q4_0) as the reasoning core the
    workspace actually runs. RFD 1173 (edit-reward corpus, PR #179) followed with the substrate
    table swap. Ten open RFDs still name Qwen3-VL, but not all of those mentions are drift: some
    are load-bearing references to real artifacts.

    Three classes of mention: aspirational future-intent (drift, fix); shipped-artifact facts
    (keep, EditScore's published LoRA is over Qwen3-VL-8B); measured runs (keep, RFD 2161 measured
    Qwen3-VL-4B MLX at 0.9 s load and 1.9 s first token). Bulk-swap erases the last two.
    """

    section "Details", ~S"""
    Per-RFD annotations sit in [DETAILS.md](DETAILS.md); each RFD retains its current text until
    otherwise edited. This RFD provides the citable pointer so a reader hitting a stale Qwen3-VL
    mention gets the reason without a rewrite pass across ten RFDs.

    RFD 1157 (EditScore reward model) leads: its analysis of the Hailo HEF projector-drop against
    Qwen3-VL's mm_* tensor shape rewrites against Gemma's projector shape.
    """

    related ~S"""
    Spine: urn:oid:1.3.6.1.4.1.66606.1.1.1173 (multimodal pipeline).
    Anchor: urn:oid:1.3.6.1.4.1.66606.1.2.2169 (studio-core abandonment that carried the
    reasoning-core swap).
    Applies to: RFDs 1089, 1157, 1163, 1167, 1168, 1169, 1170, 1171, 2161, 2167 (see DETAILS.md
    for per-RFD annotations).
    """

    details_title "Qwen3-VL to Gemma-4-12B migration index"

    details_preamble ~S"""
    Each open RFD that names Qwen3-VL is annotated below with the class
    of mention and what to do when the RFD is next edited. Class key:

      aspirational  the mention describes future intent that RFD 2169
                    walked back; swap Qwen3-VL -> Gemma-4-12B on next edit.
      measured      the mention describes a real measurement or a
                    shipped-artifact fact (EditScore's published LoRA is
                    over Qwen3-VL); keep, add a footnote citing this RFD.
      mixed         some mentions are aspirational, others measured;
                    per-line judgement.
    """

    details "Per-RFD annotations", ~S"""
      RFD 1089  aspirational, HY-World's trajectory stage runs vLLM
                plus Qwen3-VL-8B (three mentions in DETAILS.md's stage
                table + vLLM server spec).

      RFD 1157  aspirational, 'EditScore is a LoRA over Qwen3-VL, and
                llama-cpp-npu-vision accelerates that family'. The
                *base* migrates; the currently published LoRA does not.
                Rewrite against Gemma's projector shape when next edited.

      RFD 1163  measured, weft_score.py loads EditScore's published
                Qwen3-VL-8B LoRA at 6.75 GiB NF4, 28-36 s per score.
                Keep verbatim. Footnote citing this RFD.

      RFD 1167  measured, ladder rung 3 data: EditScore Qwen3-VL-8B
                [4] measured at runtime: 6.75 GiB NF4, 28-36 s a score.
                Keep. Footnote.

      RFD 1168  aspirational, 'RFD 1166 ranks EditScore, a LoRA over
                Qwen3-VL-8B at 6.75 GiB, as the gate'. Swap the base
                name on next edit; the gate role is unchanged.

      RFD 1169  aspirational (title too), 'The audio tower for
                Qwen3-VL, and which half compiles'. Retitle to name
                Gemma-4-12B when next edited; the audio tower work
                (Qwen3-ASR-1.7B selection) is orthogonal and stays.

      RFD 1170  mixed, table row 'Qwen3-VL-8B, local' is aspirational
                (swap); 'gemma-4-31B, API' is stale from before RFD 1155
                abandoned Gemma 4 as an accelerator target (separate
                question from the reasoning-core swap).

      RFD 1171  mixed, 'think' role row 'Qwen3-VL-8B runs, host' is
                aspirational (swap). EditScore gate rows referencing
                'a LoRA over Qwen3-VL-8B at 6.75 GiB' are measured
                (keep with footnote).

      RFD 2161  measured, MLX 4-bit smoke test with
                EditScore/EditScore-Qwen3-VL-4B-Instruct LoRA: 3.1 GB
                base + 270 MB adapter, 0.9 s load, 1.9 s first token.
                Keep verbatim; the whole RFD documents this specific
                configuration. Footnote citing this RFD.

      RFD 2167  aspirational, parked (RFD README carries Shelved note).
                Will name Gemma directly when unparked.
    """

    details "Why one index instead of ten rewrites", ~S"""
    A rewrite pass across ten RFDs would either erase measured artifact
    facts (bulk-swap) or take longer than the drift itself is worth
    (per-line judgement in ten places). One index carries the reason and
    the plan; downstream readers follow the pointer.

    RFD 1157 is the load-bearing next edit: it names Qwen3-VL as the
    family llama-cpp-npu-vision accelerates, and its rewrite against
    Gemma's projector shape unblocks the deployed-EditScore swap for the
    whole chain.
    """

    drafted_by :ai
  end
end
