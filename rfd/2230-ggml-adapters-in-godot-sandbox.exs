# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2230. `mix rfd.render` renders rfd/2230-ggml-adapters-in-godot-sandbox/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2230 do
  use RFD.DSL

  rfd 2230, "ggml model adapters as sandboxed GDScript over one native module" do
    compact_head true

    state :discussion

    feature "ggml lives as a single native module inside\n`entities-godot-sandbox`; model-specific adapter code (tokenizer,\nprompt templates, LoRA scaling, sampler config, per-model quirks)\nmoves out of per-project C++ into GDScript loaded at runtime with\nsandbox permissions"

    scope "`entities-godot-sandbox/modules/ggml/` (new), motion-\nbricks-cpp / kimodo / skin-tokens-cpp adapter code, RFD 2212\n(motion-bricks-as-native-module rescopes), RFD 2229 (this is one\nof its named consolidations landing)"

    decision ~S"""
    Operator, 2026-09-05, verbatim: *"Are you able to move the ggml
    model adapters and process from c++ to godot-sandbox gdscript
    if we add ggml to entities-godot?"*.

    `DETAILS.md` carries the full text of this RFD.
    """

    related ~S"""
    - RFD 2188 (one ggml across workspace), the source consolidation
      this RFD ships against.
    - RFD 2211 (base tree entities-godot-sandbox), the tree the
      new module lands in.
    - RFD 2212 (motion-bricks-as-native-godot-module), this RFD
      supersedes 2212's shape; 2212's L1 execution work becomes
      Step 2 of this RFD's sequencing.
    - RFD 2213 (VRM via godot-sandbox ELF), the parallel path for
      cases needing full ELF sandbox rather than GDScript sandbox.
    - RFD 2214 (model bundle SQLite+ZSTD), the bundle loader
      surface adapters call.
    - RFD 2229 (interchangeable-parts consolidation policy), the
      policy this RFD lands one of; the three-C++-module → one-
      native-module-plus-N-GDScript-adapters shape is exactly what
      2229's ggml-consumers row proposed.
    """

    details_title "ggml model adapters as sandboxed GDScript over one native module"

    details "Operator directive", ~S"""
    Operator, 2026-09-05, verbatim: *"Are you able to move the ggml
    model adapters and process from c++ to godot-sandbox gdscript
    if we add ggml to entities-godot?"*.

    **Answer:** yes, cleanly, with a native/adapter split. The
    precondition, adding ggml as a shared module under
    `entities-godot-sandbox`, is exactly the shape RFD 2229's
    interchangeable-parts policy asks for: one ggml surface every
    consumer links, not N per-project C++ modules.
    """

    details "The layering", ~S"""
    **Layer 1, native, one module.** `entities-godot-sandbox/modules/ggml/`
    hosts `2-contract/ggml/` (RFD 2188 canonical source) plus ggml's
    Vulkan backend (MoltenVK on macOS). Exposes a small GDExtension
    surface, GDScript-callable:

    ```gdscript
    var model := Ggml.load_model("res://models/motion-bricks.gguf")
    var lora := Ggml.load_lora("res://models/motion-bricks-walk.lora")
    model.apply_lora(lora)
    var tokens := Ggml.tokenize("walk forward 60 frames")
    var out := model.run_inference(tokens, {"max_new_tokens": 60})
    ```

    The native module handles: model file mmap, KV cache, backend
    dispatch (CPU / Metal / Vulkan / WebGPU), sampler primitives,
    tensor arithmetic. Nothing about a specific model's chat template
    or LoRA layout lives here.

    **Layer 2, GDScript, per-model adapters.** One `.gd` file per
    model. Each adapter is a Resource subclass extending
    `GgmlAdapter`:

    ```gdscript
    # res://adapters/motion_bricks.gd
    class_name MotionBricksAdapter extends GgmlAdapter

    const MODEL_PATH := "res://models/motion-bricks.gguf"
    const TOKENIZER := "sentencepiece-motion"

    func format_prompt(motion_desc: String, frames: int) -> String:
        return "<motion>%s</motion><frames>%d</frames>" % [motion_desc, frames]

    func decode_output(tokens: PackedInt32Array) -> Array:
        # motion-bricks specific: tokens -> pose keyframes
        ...
    ```

    Adapters run under Godot's script permission system + the
    existing `modules/sandbox/` capabilities: an adapter loaded at
    runtime from disk (or from the SQLite model bundle per RFD 2214)
    cannot escape the GDScript sandbox, cannot open arbitrary files,
    cannot spawn processes. Same shape RFD 2213 relies on for VRM.

    **Layer 3, game / video code.** Consumers instantiate adapters
    by resource path, feed them domain input, get domain output. The
    game never touches ggml types directly.
    """

    details "What this consolidates", ~S"""
    Names the RFD 2229 candidates that this RFD acts on:

    | project | before | after |
    |---|---|---|
    | motion-bricks-cpp | own C++ module + own ggml pin + own CMake | one shared `modules/ggml/` + `motion_bricks.gd` adapter |
    | kimodo | own C++ module + own ggml pin | shared `modules/ggml/` + `kimodo.gd` adapter |
    | skin-tokens-cpp | own C++ module + own ggml pin | shared `modules/ggml/` + `skin_tokens.gd` adapter |

    Result: **one native module, N GDScript adapter files**, instead
    of N per-project C++ modules with parallel build systems and
    parallel ggml pins.
    """

    details "Trade vs the RISC-V ELF path", ~S"""
    RFD 2213 puts godot-vrm inside a sandbox as a compiled ELF via
    libriscv (`modules/sandbox/`). Adapter-in-GDScript trades vs
    adapter-in-ELF:

    | | GDScript adapter | RISC-V ELF adapter |
    |---|---|---|
    | build | none (script edit + reload) | cross-compile to riscv-elf |
    | iteration | editor hot-reload | rebuild + repackage |
    | third-party untrusted code | can't run C/Rust | can run any language |
    | performance | GDScript VM (fine for orchestration) | libriscv (fine for compute) |
    | sandbox | Godot script permissions | libriscv memory isolation |

    **Recommended pick per case:**

    - **Adapter is orchestration + tensor-shape juggling** (tokenizer
      setup, LoRA scaling factors, chat template, prompt formatting,
      output post-processing): **GDScript**. This is where all three
      ggml consumers live today.
    - **Adapter runs third-party untrusted code** (a downloaded
      planner from a scene marketplace, a mod-supplied model wrapper):
      **RISC-V ELF via libriscv** (same as RFD 2213's VRM path).

    The workspace ships trusted models we hold; GDScript adapters
    cover every current case. The ELF path stays available for the
    mod-supplied case if it appears.
    """

    details "Sequencing", ~S"""
    Follow-up L1 RFDs, one per step:

    1. Add `2-contract/ggml/` as a module under
       `entities-godot-sandbox/modules/ggml/`. Wire the GDExtension
       surface. First `Ggml.load_model()` + `Ggml.run_inference()`
       round-trip.
    2. Author `motion_bricks.gd` adapter. Port whatever's in
       motion-bricks-cpp's adapter code (`src/root.cpp` planner
       glue, tokenizer bindings) to GDScript. Verify inference
       matches the C++ baseline on a fixed motion prompt.
    3. Retract RFD 2212 (motion-bricks-as-native-godot-module) —
       the module doesn't exist as an independent thing anymore;
       its C++ becomes part of `modules/ggml/`'s WebGPU backend
       sourcing, its adapter becomes `motion_bricks.gd`.
    4. Repeat for kimodo and skin-tokens-cpp as separate L1s.
    5. Once all three ggml consumers are on the shared module,
       trim their standalone C++ repos from the goal manifest.
    """

    details "Verification", ~S"""
    - **Inference-parity gate.** For each adapter, a fixture prompt
      round-trips through both the pre-migration C++ path and the
      post-migration adapter+module path; outputs match byte-for-
      byte (or within f32 tolerance for stochastic samplers seeded
      identically).
    - **Adapter-iteration measurement.** Editor reload time on an
      adapter edit against baseline C++ rebuild-and-relink time.
      If the ratio isn't at least 10:1 in GDScript's favor, the
      interchangeable-parts win is fictional.
    - **Module-count enumeration.** `git ls-files modules/*/config.py`
      under `entities-godot-sandbox` shows one ggml-consuming
      module (not three) once migration completes.
    """

    details "Blast radius", ~S"""
    The three consuming projects (motion-bricks-cpp, kimodo,
    skin-tokens-cpp) are pre-ship, no downstream depends on their
    current C++ ABI. This migration doesn't break anyone external.

    Internal churn: RFD 2212's planned `modules/motionbricks/`
    becomes `modules/ggml/`; RFD 2214's model bundle loader still
    returns the same bytes, the caller changes from C++ (`mb_model_load_from_memory`)
    to GDExtension (`Ggml.load_model_from_bytes`).
    """

    details "Related", ~S"""
    - RFD 2188 (one ggml across workspace), the source consolidation
      this RFD ships against.
    - RFD 2211 (base tree entities-godot-sandbox), the tree the
      new module lands in.
    - RFD 2212 (motion-bricks-as-native-godot-module), this RFD
      supersedes 2212's shape; 2212's L1 execution work becomes
      Step 2 of this RFD's sequencing.
    - RFD 2213 (VRM via godot-sandbox ELF), the parallel path for
      cases needing full ELF sandbox rather than GDScript sandbox.
    - RFD 2214 (model bundle SQLite+ZSTD), the bundle loader
      surface adapters call.
    - RFD 2229 (interchangeable-parts consolidation policy), the
      policy this RFD lands one of; the three-C++-module → one-
      native-module-plus-N-GDScript-adapters shape is exactly what
      2229's ggml-consumers row proposed.
    """

    drafted_by :ai
  end
end
