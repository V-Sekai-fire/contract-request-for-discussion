# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2161. `mix rfd.render` renders rfd/2161-vn-avatar-cleanroom-on-maskscore/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2161 do
  use RFD.DSL

  rfd 2161, "Cleanroom Gemma-Avatar as a visual novel, on MaskScore" do
    state :discussion

    feature "VN with location travel and prompt-driven talking-head
interactions, cleanroom-rebuilt on the RFD 1173 stack"

    scope "taskweft, taskweft-godot-sandbox"

    decision ~S"""
    **Two-team cleanroom, role per model** (retracted from "one Qwen3-Omni
    does everything"):

    1. LLM + visual reward -> Qwen3-VL-4B MLX 4-bit + EditScore LoRA
    2. TTS voice-clone -> ResembleAI/chatterbox
    3. STT -> whisper-small (MLX); VAD -> silero
    4. Viseme -> cleanroom small classifier
    5. Renderer -> libgodot in BEAM (RFD 2154); Body -> ANNY + SOMA
    6. Locations -> `6-datasource/{kenney,thebasemesh,quaternius}-stage`

    Full retraction trail, stack table, Mac-mini smoke in `DETAILS.md`.
    """

    problem ~S"""
    Target uses Gemma + Cerebras + parakeet + Qwen3-TTS + MFCC-viseme +
    Ready Player Me + Mixamo + three.js. Every piece has a substitute
    here; Mixamo is CLAUDE.md-blocklisted.
    """

    section "Compute", ~S"""
    Reward-model role verified on Mac mini M2 Pro 32 GB, zero Vast (0.9s
    load, 1.9s first token; 3.4 GB total). Operator moves to Windows 11
    + RTX 3090; 24 GB reopens QAFT-LoRA training on EditScore-Reward-Data
    (97k rows, apache-2.0) and the Wan-VACE 14B slot without changing the
    small-machine shipping path.
    """

    related ~S"""
    RFD 1173, RFD 2154, RFD 2160.
    """

    details_title "Cleanroom Gemma-Avatar as a visual novel, on MaskScore"

    details "Retractions from the 2026-09-01 compute ladder", ~S"""
    The session that filed this RFD climbed down five rungs of a compute
    ladder. Each pivot's reason is recorded so a future reader does not
    reopen the same bets.

    1. **"Rent an RTX 3090 on Vast"**; two cheapest-tier hosts failed to
       spin up (bad GPU error, image never pulled). Spent $0.003 total
       before pivoting. The Vast market-snapshot dataset survives at
       `6-datasource/vast-market-snapshots/` (three ETNF Parquet snapshots
       with 40% churn per ~12 min at the hot $0.18-0.22 band; Wilson
       95%-lower on pooled 3-snapshot evidence).
    2. **"Qwen3-Omni-30B does thinker + talker + OmniScore reward"** ;
       RETRACTED. The team behind Qwen3-Omni was disbanded (operator
       report), and no true-QAFT 4-bit checkpoint exists upstream for it
       or for Wan-VACE 14B, Pixal3D, VoxHammer, MoGe-3. Full QAFT training
       sized at ~$7-15K compute we do not have.
    3. **"Gemma-4-31B-it-qat as the visual-LLM replacement"**; RETRACTED.
       Google publishes it (apache-2.0, image-text-to-text), but 62.6 GB
       fp16 exceeds the shipping budget once compute constraints landed.
       The mirror plan for `chibifire/gemma-4-31B-it-qat-*` never fired.
    4. **"Gemma-4-E4B-it-qat + train EditScore LoRA ourselves"** ;
       RETRACTED at the smoke stage. EditScore already published its own
       LoRA over Qwen3-VL-4B (`EditScore/EditScore-Qwen3-VL-4B-Instruct`,
       270 MB, apache-2.0 inheriting from base). Training a duplicate
       would burn compute we don't have to reproduce upstream work.
    5. **"Vision encoder split onto Hailo NPU via QFT"**; PARKED. No
       Linux x86_64 host to run the proprietary DFC wheel, no Hailo
       hardware to deploy to. Scaffold survives at
       `3-interactor/editscore-lora-qwen3vl-4b/scripts/gate_vision_encoder.py`
       with a real ONNX export the DFC-side gate can consume when hardware
       arrives.
    """

    details "The stack that landed", ~S"""
    | role | model | licence | footprint on Mac mini M2 Pro 32 GB |
    |---|---|---|---|
    | Visual LLM + reward | `mlx-community/Qwen3-VL-4B-Instruct-4bit` + `EditScore/EditScore-Qwen3-VL-4B-Instruct` LoRA | apache-2.0 | **3.1 GB base + 270 MB adapter, ~0.9 s load, ~1.9 s first token** |
    | TTS voice-clone | `ResembleAI/chatterbox` | mit | ~500 MB, MPS or CPU |
    | STT | `whisper-small` or `distil-whisper` via MLX | mit | ~500 MB |
    | VAD | `silero-vad` | mit | tiny |
    | Viseme (MFCC -> SOMA) | cleanroom small classifier | ours | negligible |
    | Body | ANNY + SOMA rig | ours | fits |
    | Renderer | Godot 4.7 via `lib_godot_connector` | mit | fits |
    | Locations | `6-datasource/{kenney,thebasemesh,quaternius}-stage` | cc-* clean | assets on disk |

    **One real inference proved on Mac mini M2 Pro 32 GB (2026-09-01):**
    `scripts/smoke_editscore_mlx.py` in `3-interactor/editscore-lora-qwen3vl-4b/`
    loaded the MLX 4-bit Qwen3-VL-4B in 0.9 s and generated a one-token
    reward response in 1.9 s from a dummy 224x224 image + edit-instruction
    prompt. Wiring holds; real numbers arrive with real (image, edit) pairs.
    """

    details "Compute pivot: Mac mini -> Windows 11 + RTX 3090", ~S"""
    The operator is moving to Windows 11 with an RTX 3090 (24 GB). That
    changes what becomes viable, in dependency order:

    1. **QAFT-LoRA training on Qwen3-VL-4B against `EditScore/EditScore-Reward-Data`
      (97,300 rows, 161.8 GB, apache-2.0)** returns to the table. The
      `3-interactor/editscore-lora-qwen3vl-4b/scripts/smoke.py` scaffold
      targets this exactly; needs `bitsandbytes` (already linux-64
      target-scoped in `pixi.toml`; add `win-64` when the Windows path is
      real). Model VRAM footprint: Qwen3-VL-4B fp16 ~8.9 GB + optimizer
      state + gradients fits 24 GB comfortably at LoRA rank 32.
    2. **Larger reward candidates** (`EditScore/EditScore-Qwen3-VL-8B-Instruct`,
      `EditScore/EditScore-7B`, `EditScore/EditScore-32B`) become tractable
      at inference on the 3090. The 4B stays as the Mac-mini reference.
    3. **Wan-VACE 14B NF4** (~8.7 GB) fits alongside the reward model on
      the 3090 with swap. Reopens the image-generation slot RFD 1173
      originally sized for.
    4. **Hailo track** stays parked; 3090 does not change Linux/DFC gap.
    """

    details "Original substitution table (retained for the record)", ~S"""
    The target space's `README.md` (fetched cleanroom, README only) names
    `gemma-4-31B-it on Cerebras` as its assistant model. The final
    substitution collapses onto EditScore's own release; the intermediate
    Gemma-4 mapping is retained here so the retraction trail is legible.
    """

    details "True-QAFT-only mirror candidates (2026-09-01, refined)", ~S"""
    The target space's README (fetched cleanroom, README only) names
    `gemma-4-31B-it on Cerebras` as the assistant model; Google's own
    release. Google publishes true-QAFT (quantization-aware training)
    variants for the entire Gemma 4 lineup, including the target's exact
    size. Community forks named "-qat" are excluded because their true-
    QAT provenance is not verifiable without vetting each individually.

    **Vendor-QAFT candidates from `google/` (all Gemma Terms of Use):**

    | candidate                                              | format                 | note                                                            |
    | ------------------------------------------------------ | ---------------------- | --------------------------------------------------------------- |
    | `google/gemma-4-31B-it-qat-w4a16-ct`                   | Compressed-Tensors W4A16 | target's exact model; not GGUF, no blocklist question           |
    | `google/gemma-4-31B-it-qat-q4_0-gguf`                  | GGUF Q4_0              | same model, GGUF (vendor-runtime exemption via llama.cpp)       |
    | `google/gemma-4-31B-it-qat-q4_0-unquantized`           | fp16 (QAT-trained)     | for further fine-tuning on top of QAT weights                   |
    | `google/gemma-4-26B-A4B-it-qat-q4_0-gguf`              | GGUF                   | 26B MoE (4B active); same shape as Qwen3-Omni                  |
    | `google/gemma-4-12B-it-qat-w4a16-ct`                   | CT W4A16               | matches workspace's `gemma4-composer` size                      |
    | `google/gemma-4-E4B-it-qat-w4a16-ct`                   | CT W4A16               | effective 4B                                                    |
    | `google/gemma-4-E2B-it-qat-w4a16-ct`                   | CT W4A16               | effective 2B                                                    |
    """

    details "PTQ-only variants (dropped, not true-QAFT)", ~S"""
    All other 4-bit variants surveyed for these families use post-training
    quantization, not QAT: `Intel/...int4-AutoRound`, every AWQ (including
    `Sabomako/...heretic-AWQ-4bit`; the licence-less community fork noted
    in an earlier pass), every GPTQ, every bitsandbytes NF4. Recorded here
    so a future session does not re-derive their presence and mistake them
    for QAT-refined weights.
    """

    details "MaskScore-stack models (RFD 1173)", ~S"""
    Zero true-QAFT 4-bit checkpoints on Hub as of 2026-09-01 for any of:
    Qwen3-Omni-30B, Wan-VACE 14B, Pixal3D, VoxHammer, MoGe-3. PTQ variants
    exist for the first two only.

    **True QAFT means the model was retrained with a fake-quant simulator
    in the loop** (quantization-aware fine-tuning), so NF4 becomes its
    published precision. PTQ methods (AutoRound, AWQ, GPTQ, bitsandbytes,
    int8-convrot, GGUF) do not qualify: they take a released fp16 checkpoint
    and quantize it after the fact, no re-training.

    Hub was searched for each of the five MaskScore-stack model families
    (RFD 1173) using both the family name and QAFT-specific naming
    conventions (`QAFT`, `QAT`, `-qat`, `quantization-aware`).

    | model family              | true-QAFT 4-bit upstream | PTQ-4-bit exists?                                                 |
    | ------------------------- | ------------------------ | ----------------------------------------------------------------- |
    | Qwen3-Omni-30B (Instruct) | **none**                 | yes; `Intel/...int4-AutoRound` (AutoRound), several AWQ variants |
    | Qwen3-Omni-30B (Thinking) | **none**                 | yes; Sabomako AWQ (source has no licence)                        |
    | Wan-VACE 14B              | **none**                 | only FP8 / INT8 / GGUF (GGUF blocklisted); no 4-bit at all        |
    | Pixal3D                   | **none**                 | no quant variants at all                                          |
    | VoxHammer                 | **none**                 | no quant variants at all                                          |
    | MoGe-3                    | **none**                 | no quant variants at all                                          |

    **Nothing was mirrored** because operator scope is true QAFT only,
    and zero true-QAFT 4-bit checkpoints for any of the five exist
    upstream today. Reproducing the survey: `python3` + `huggingface_hub`
    `list_models(search=<needle>)` filtered client-side for
    `{QAFT, qaft, -qat, quantization-aware}` in the repo id.

    `heretic` (ARA) and `abliterated` are **different** guard-lifting
    techniques; the workspace blocklist row on abliterated weights does
    not extend to heretic. Not relevant to the mirror decision here
    because Sabomako's heretic variant is also PTQ (AWQ), not QAFT.
    """

    details "What the spec side read (its only inputs)", ~S"""
    1. `https://huggingface.co/spaces/victor/gemma-avatar/raw/main/README.md`
      (README only; the space's source tree was not opened).
    2. The operator's VN twist: "visual novel style travel between
      different locations and pop up talking head interactions via
      prompts."

    The implementer side must not open any other file in that space.
    """

    details "Boot order", ~S"""
        personas/*.grafcet.jsonld
          -> mix taskweft.grafcet.lower                  (Elixir, RFD 2148)
          -> personas/lowered/*.htn.jsonld
          -> mix vn_avatar.serve --port 4000             (Elixir, weftspun-studio)
             Elixir Router  ;  WebSocket  ;  Browser (canvas + prompt input)
                 |
                 +-> BusNif -> iox2 (RFD's 2-contract/bus)
                 |             |
                 |             +-> Qwen3-VL worker    (Python, EditScore LoRA reward + text)
                 |             +-> Qwen3-TTS-12Hz worker (Python, RFD 1170)
                 |             +-> Wan-VACE worker    (Python, background gen)
                 |
                 +-> LibGodot NIF (RFD 2154's lib_godot_connector 4.5.1)
                      |
                      +-> headless godot process
                           SubViewport(1024x1024) -> get_texture per frame
                           ANNY-in-Godot scene (soma-x rig, godot-soma-twist joint driver)
                 |
                 +-> taskweft RECTGTN interpreter (RFD 2148)
                      issues bodytags_v3.json part-mask edits ("mouth", "eyewhite")
                      at each dialog beat
                 |
                 +-> MASKSCORE row writer  (RFD 1173, taskweft-nmm-personas pattern)
                 |    -> traces/<session>.jsonl + traces/<session>.parquet
                 +-> USD writer            (RFD 2160)
                      -> scenes/<location>.usda
    """

    details "Language boundaries", ~S"""
    1. **Elixir**; Router, WebSocket, taskweft interpreter, MASKSCORE writer, USD writer.
    2. **Python**; one file per model worker (`env_bus_server.py` shape).
    3. **GDScript**; one file: `vn_bridge.gd`, reads viseme frames off
      `set_program_variable`, writes SOMA facial-action weights onto the
      ANNY rig, publishes SubViewport texture bytes back.
    4. **C++**; none new. The bus NIF from `taskweft-nmm-personas`
      handles iox2.

    Stdio JSON is blocklisted as an Elixir<->Python wire.
    """

    details "Frame protocol on the WebSocket", ~S"""
    Text frames upstream (browser -> server): `{"prompt":"...","persona":"s0042"}`.

    Binary frames downstream (server -> browser), one per Godot frame:

        magic  u32 = 0x56 4E 41 56  ("VNAV")
        kind   u8  = 1 image, 2 audio, 3 text, 4 done
        ts     u64 microseconds since session start
        len    u32 payload bytes
        payload len bytes

    Image frames carry a WebP-encoded 1024x1024 render of the SubViewport.
    Audio frames carry Opus-encoded 20 ms Qwen3-TTS-12Hz output (RFD 1170).
    Text frames carry the current dialog line (redundant with audio, for
    captioning). Done frames end a turn.
    """

    details "SpeakingFaces -> vn-avatar-personas construction", ~S"""
    Per RFD 1173 §"The undivided unit: 1 SpeakingFaces trial":

        for subject in issai/Speaking_Faces subjects:
          pick a representative frame
          fit ANNY canonical rig via AnnyInverter + LBFGS polish
          save soma bones (78 * 3 rot + 3 root translation, float64)
          derive voice-clone conditioning tokens from a 5s audio clip
          pair with a persona .grafcet.jsonld (hand-authored per subject
            for the MVP; later, generated from the transcript vocabulary)

    Row shape:

    | column | type | description |
    | --- | --- | --- |
    | key | string | subject id (SpeakingFaces "s0001".."s0142") |
    | anny_identity | list[float] | ANNY identity params |
    | soma_pose | list[float] | 78x3 + 3, canonical neutral |
    | voice_tokens | list[int] | Qwen3-TTS-12Hz CustomVoice conditioning (RFD 1170) |
    | persona_grafcet | string | path into the same repo |
    | license | string | CC-BY-4.0 attribution to issai/Speaking_Faces |
    """

    details "Trace row shape (mirrors MaskScore §8-stub schema)", ~S"""
    Each VN turn produces one row per modality (text, audio, video):

    | column | type | description |
    | --- | --- | --- |
    | key | string | session_id + turn_index |
    | instruction | string | player's prompt |
    | persona | string | subject id |
    | output_text | string | Qwen3-VL line |
    | output_audio | string | .opus path |
    | output_video | string | .webp sequence path |
    | scores | list[float] | reward-model score per dimension |
    | task_type | string | dialog_reply | scene_transition | expression_change |
    | dimension | string | instruction_following | consistency | overall |
    """

    details "Bootstrap on the rented Vast machine (3090, 24 GiB)", ~S"""
        # 1. Pick a 3090 image with CUDA 12.4 + Python 3.11 + git-lfs preinstalled.
        #    Expect ~$0.20-$0.35/hour on Vast; $40 buys 110-200 hours.

        # 2. Clone this workspace's minimal set (not the whole hexagon).
        for r in \
          2-contract/manuals-weftspun \
          2-contract/bus \
          3-interactor/taskweft \
          3-interactor/taskweft-nmm-personas \
          3-interactor/taskweft-godot-sandbox \
          3-interactor/anny \
          3-interactor/soma-x \
          3-interactor/pose-consensus \
          3-interactor/moge-upstream \
          3-interactor/pixal3d-upstream \
          3-interactor/voxhammer-upstream \
          3-interactor/wan-vace-upstream \
          1-transport/weftspun-studio ; do ...; done

        # 3. Fetch SpeakingFaces (huggingface_hub, CC-BY-4.0), download
        #    Qwen3-VL-4B-Instruct at fp16 (8.9 GiB) + EditScore LoRA
        #    (270 MB), download Wan-VACE NF4 (8.7 GiB). Total < 24 GiB
        #    with swap; no QAFT round required (per RFD 1173).

        # 4. mix vn_avatar.build_personas --subjects 8   (MVP corpus: 8 subjects)
        #    ~30 min on the 3090.

        # 5. mix vn_avatar.smoke                        (one turn end to end)
        #    Asserts: WebSocket receives >=1 image frame + >=1 audio frame,
        #    trace row lands with a non-nil reward-model score.

        # 6. COMMIT AND PUSH before tear down. Everything not in a git
        #    repo goes with the machine (CLAUDE.md).

        # 7. `vast destroy instance <id>` and double-check the console.
    """

    details "MVP smoke, in one sentence", ~S"""
    Player types "hello" into the browser, one WebSocket message goes
    up, one Qwen3-VL line comes back, the anny-in-godot mouth moves,
    the SubViewport streams five WebP frames, one MaskScore trace row
    lands with `task_type = dialog_reply` and a non-nil reward-model
    score, one `.usda` records the scene. Everything after that is
    expansion.
    """

    details "What is not here (deferred to follow-on RFDs)", ~S"""
    1. Voice-in phase 2. Text-in is the MVP.
    2. The full 142-subject corpus. MVP is 8.
    3. 3D locations. MVP uses 2D Wan-VACE background stills.
    4. The RL-train dataset construction. Bench + reward-train are the
      first two; RL-train follows once the reward model is on Hub.
    5. The verifier RFD asserting our SpeechEditReward decode agrees
      with an independent lip-sync ground truth. That is the anti-
      entropy check the follow-on adds.
    """

    drafted_by :ai
  end
end
