# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2252. `mix rfd.render` renders rfd/2252-llm-module-splits-and-drafts/README.md
# and DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2252 do
  use RFD.DSL

  rfd 2252, "the llm module splits across cards and drafts" do
    state :discussion

    feature "`modules/llm` carries the split, batch, drafter and jinja\nknobs a Gemma4-31B QAT recipe on 4090 + 3090 needs for 220 tok/s"

    scope "`4-entities/godot-language-model/modules/llm`: `LLMContext`,\n`LLMModel`, a new `LLMDraft`, `LLMChat`. No llama.cpp change."

    decision ~S"""
    Ten properties land. `LLMModel` gains `split_mode`, `main_gpu`
    and `tensor_split`. `LLMContext` gains `n_batch`, `n_ubatch`,
    `n_parallel` and `kv_unified`. `LLMChat` gains `min_p` and
    `jinja_template`. Speculative decode ships as `LLMDraft`, a
    RefCounted that `LLMChat.setup` takes as an optional argument.
    `DETAILS.md` carries the knob table, the types and the defaults.
    """

    problem ~S"""
    The surface exposes `model_path`, `n_gpu_layers`, `n_ctx`,
    `cache_type_k/v`, `flash_attn` and the sampler triple. A GGUF
    Gemma4-31B recipe on 4090 + 3090 cannot be expressed against
    it: no split mode, no `main_gpu`, no batch sizing, no drafter,
    no jinja toggle. The first four gate 220 tok/s; jinja is
    correctness.
    """

    related ~S"""
    - [RFD 1155](../1155-gemma4-towers-not-decoder/): the Gemma4
      pick this recipe realises.
    - [RFD 2212](../2212-motion-bricks-as-native-godot-module/):
      the native-Godot-module pattern this RFD applies to `llm`.
    - [RFD 2242](../2242-ggml-consumers-as-native-godot-modules/):
      the ggml-consumer siblings on the same manifest.
    - upstream `noonghunna/club-3090` `dflash.yml`, read 2026-09-15,
      preserved under `apparatus/2252-llm-module-splits-and-drafts/`.
    """

    details_title "the llm module splits across cards and drafts"

    details "This RFD was drafted by an AI and read by a human before it shipped.", ~S"""
    Drafted from a conversation with the operator on 2026-09-15,
    from the club-3090 `dflash.yml` above, and from a walk of
    `4-entities/godot-language-model/modules/llm/doc_classes/*.xml`.
    The 220 tok/s target and the 4090 + 3090 rig are the operator's;
    the ten-property split is the AI's proposal.
    """

    details "The knob table", ~S"""
    Every row is a llama.cpp flag from the retired-beellama compose
    that has no home on today's `modules/llm` surface. The godot
    property is what the RFD proposes; the class is where it lands.

    | llama.cpp flag | godot property | class |
    | --- | --- | --- |
    | `--split-mode {none,layer,row}` | `split_mode` | LLMModel |
    | `--main-gpu <int>` | `main_gpu` | LLMModel |
    | `--tensor-split <floats>` | `tensor_split` | LLMModel |
    | `-b <int>` | `n_batch` | LLMContext |
    | `-ub <int>` | `n_ubatch` | LLMContext |
    | `-np <int>` | `n_parallel` | LLMContext |
    | `--kv-unified` | `kv_unified` | LLMContext |
    | `--min-p <float>` | `min_p` | LLMChat |
    | `--jinja` | `jinja_template` | LLMChat |
    | `--spec-draft-model <path>` | `draft_model.model_path` | LLMDraft |
    | `--spec-draft-ngl <int>` | `draft_model.n_gpu_layers` | LLMDraft |
    | `--spec-type {none,dflash}` | `spec_type` | LLMDraft |
    | `--spec-draft-n-max <int>` | `n_max` | LLMDraft |
    | `--spec-draft-n-min <int>` | `n_min` | LLMDraft |
    | `--spec-dflash-cross-ctx <int>` | `dflash_cross_ctx` | LLMDraft |

    Types and defaults: `split_mode` is an enum (none/layer/row),
    `main_gpu` an int, `tensor_split` a PackedFloat32Array;
    `n_batch` defaults to 2048, `n_ubatch` to 512, `n_parallel` to
    1, `kv_unified` is a bool, `jinja_template` a bool defaulting
    to true, `min_p` a float. `LLMDraft` holds `draft_model`
    (LLMModel), `spec_type` (enum: none/dflash), and `n_max`,
    `n_min` and `dflash_cross_ctx` as ints.

    The beellama engine is retired upstream as of 2026-07-27. The
    flag set is portable to llama.cpp mainline once the dflash
    draft type lands there, and `LLMDraft.spec_type` carries `none`
    for the interim. The club-3090 rig measures ~157 tok/s with the
    dflash draft on its 2026-06-01 dual-3090 bench, and the full
    compose path is
    `models/gemma-4-31b/beellama/compose/dual/beellama-q4ks-dflash/dflash.yml`.

    `--cache-ram 0` and `--no-host` are process-wide flags rather
    than per-context knobs; they belong on `LLMServer` boot config,
    not the property surface, and land in a follow-up.
    """

    details "The 220 tok/s target and its baseline", ~S"""
    The operator measures ~20 tok/s on an M2 Pro mini running
    `gemma-4-12B-it-qat-assistant-MTP-Q4_0` under status-quo
    llama.cpp. The 220 tok/s target is on 4090 + 3090 with
    Gemma4-31B QAT at Q4. The knob set above is the necessary
    condition, not the sufficient one; the measured number belongs
    in a logbook entry, not this RFD.
    """

    details "The tok/s ladder", ~S"""
    Every rung names the config, the knob it turns on, the number,
    and the source of the number. Rung 0 is the operator's measured
    floor; rungs 1 and 3 are club-3090's dual-3090 numbers on
    Gemma4-31B-Q4_K_S measured 2026-06-01 and cited as the class,
    not this rig; rung 2 is a projection from the 3090's ~35 TFLOP
    fp16 versus the 4090's ~82.6 TFLOP; rung 4 is the operator's
    target. Rung 4 is eleven times rung 0, and the ladder is what
    closes that factor.

    | rung | config | knob | tok/s | source |
    | --- | --- | --- | --- | --- |
    | 0 | M2 Pro mini, Gemma4-12B QAT Q4_0 | status quo | ~20 | operator, 2026-09-15 |
    | 1 | 1× 3090, Gemma4-31B Q4_K_S, no draft | `n_gpu_layers=-1`, `flash_attn`, `cache_type_k/v` | ~35 | club-3090 dual/2 as floor |
    | 2 | 1× 4090, same, no draft | + `main_gpu=0` (4090 = card 0) | ~80 projected | 4090 ÷ 3090 fp16 ratio |
    | 3 | 4090 + 3090, no draft | + `split_mode=layer`, `tensor_split` (60 layers ≈ 42/18) | ~90 | club-3090 dual-3090 = 37 → 4090+3090 pool larger |
    | 4 | rung 3 + dflash draft (IQ4_XS) | + `LLMDraft`: `spec_type=dflash`, `n_max`, `dflash_cross_ctx` | ~220 target | operator, 4.2× club-3090 accept applied to rung 3 |

    Rung 3 to rung 4 is the club-3090 measured multiplier of 4.2×
    (dflash-on ÷ dflash-off, 2× 3090, 2026-06-01), which is
    exactly the multiplier `LLMDraft` unlocks. Everything below
    that ladder is on the current property surface; everything at
    rung 3 and above needs the ten properties in the knob table.
    """

    details "Beyond 220: the second half of the ladder", ~S"""
    The target 220 tok/s is the stopping point of the first half,
    not the ceiling. Four rungs beyond it, each one a smaller step
    and a narrower assumption. The multipliers compound against
    rung 4; where a rung already has a measured multiplier it is
    cited, and where it does not the rung is marked projected with the assumption stated. Rung 8 sits at roughly twice rung 4,
    and the second half of the ladder is what buys that factor.

    | rung | config | knob | tok/s | source |
    | --- | --- | --- | --- | --- |
    | 5 | rung 4 + MTP draft head | swap `spec_type=dflash` for `spec_type=mtp`, `draft_model` = `gemma-4-31b-mtp` | ~260 projected | assistant-MTP measured +18% over dflash on Qwen at club-3090 |
    | 6 | rung 5 + turbo4 V-cache | `cache_type_v=turbo4` (already exposed) | ~285 projected | 10% from smaller V-cache raising batch throughput at long ctx |
    | 7 | rung 6 + CUDA-graph replay | `LLMContext.cuda_graphs` (new bool, follow-up RFD) | ~330 projected | 15% typical on decode-heavy small-batch, llama.cpp CUDA-graph PR bench |
    | 8 | rung 7 + IQ3_M weight quant | swap Q4_K_S GGUF for IQ3_M | ~430 projected | ~30% from lower bandwidth per token, at some quality cost |

    Rungs 5, 6 and 8 stay on the same property surface as rung 4
    (MTP is a `spec_type` enum value; turbo4 is a `cache_type_v`
    string; IQ3_M is a different GGUF at `model_path`). Rung 7 is
    the only new property in the second half, and it is called
    out here so a future RFD can pick it up rather than being
    written into this one. The rung 8 quality cost is not
    measured; a logbook entry gates it.
    """

    details "The physical ceiling and the third half", ~S"""
    The 4090's memory bandwidth is 1008 GB/s. At Q4 weight
    (~0.5 byte per parameter) times 31B parameters, one full
    decode pass reads ~15.5 GB, so the single-stream memory-bound
    wall on the 4090 is ~65 tok/s. Rung 4 already stands 3.4×
    over that wall, which is exactly what speculative decode
    buys: an accepted draft token amortises the read that would
    otherwise cost a full pass. Every rung past 4 is either a
    smaller read (IQ3_M at rung 8 drops the wall to ~84 tok/s
    single-stream) or a higher accept rate (rungs 5, 9, 10). A
    rung that promises past ~700 tok/s on this hardware needs its
    assumption named, or the rung is decoration.

    | rung | config | knob | tok/s | source |
    | --- | --- | --- | --- | --- |
    | 9  | rung 8 + EAGLE-3 tree draft | `spec_type=eagle3` (enum grows), tree drafter | ~540 projected | EAGLE-3 paper accept ≈ 1.25× dflash on chat |
    | 10 | rung 9 + drafter pinned to 3090 | `LLMDraft.draft_device=1` (new int), target stays on 4090 | ~620 projected | remove drafter contention from the 4090 |
    | 11 | rung 10 + prefix cache reuse | `LLMContext.prefix_cache=true` (new bool) | ~700 projected on repeated-prompt traffic | amortises prefill, does nothing for cold prompts |

    Rungs 9, 10 and 11 add three properties beyond the ten in the
    knob table: an `eagle3` variant on `spec_type`, a
    `draft_device` on `LLMDraft`, and a `prefix_cache` on
    `LLMContext`. They land in a separate RFD if the operator
    picks them up, not in this one. Rung 11's number is on
    repeated-prompt traffic only; the presence loop of RFD 1170
    is exactly that traffic, so the rung is not decoration for
    the workspace's actual load.

    A twelfth rung is not written. The 3090's memory bandwidth
    is 936 GB/s and its fp16 throughput is ~35 TFLOP, and every
    rung past 11 either raises the accept rate past what any
    published drafter measures on chat, or moves the model off
    the rig the operator has. Both belong in a different RFD.
    """
  end
end
