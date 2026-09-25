# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2198. `mix rfd.render` renders rfd/2198-lladao-speed-work-for-dressing-overlay/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2198 do
  use RFD.DSL

  rfd 2198, "LLaDA-o speed work for the dressing overlay" do
    state :discussion

    feature "distillation and pruning to make LLaDA-o viable as an
inference-time dressing overlay generator"

    scope "speed-side work only; the quality-side result opening it is
`logbook-lladao-n1-quality-beats-omnigen2.md`"

    decision ~S"""
    LLaDA-o becomes a candidate primary generator for RFD 2186's dressing
    overlay, contingent on shipping-viable speed. Current bf16 sharded on
    two GPUs is a measurement substrate: ~1000 s per edit vs OmniGen2's
    ~72 s. Three levers, ordered by session-cost per expected impact:

    - **Step-count sweep** across 2/4/8/16/32/50 timesteps. No training,
      one ladder on shard-90 held-out. Session-scoped.
    - **LCM-style distillation on block diffusion** using upstream
      `train/pretrain_unified_navit.py` with our
      `chibifire/editscore-reward-train` parquet adapted to
      `UnifiedEditIterableDataset` Format B. Multi-day, needs LoRA plus
      2-GPU sharded training plus gradient checkpointing.
    - **Pruning or a smaller-variant training.** No smaller LLaDA-o
      upstream; multi-week; out of scope here.
    """

    problem ~S"""
    OmniGen2 baseline on shard-90 held-out: 3.36 mean, 5/20 pairs at 0.00
    including subject_remove and material_alter. LLaDA-o at bf16 scored
    7.266 on the first of those pairs (n=1). Lumina2-family LoRAs also do
    not close the gap (`logbook-lumina2-distill-n1000-shelved`). The
    obstacle to LLaDA-o is speed, not quality; this RFD scopes closing it.
    """

    related ~S"""
    RFD 2186, RFD 2183, RFD 1170 (LLaDA-o stays shelved there — different
    target). Memory `[[llada-diffusion-lm-shelved]]`. Logbook
    `logbook-lladao-n1-quality-beats-omnigen2.md`.
    """

    drafted_by :ai
  end
end
