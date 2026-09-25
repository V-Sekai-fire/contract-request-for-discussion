# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2242. `mix rfd.render` renders rfd/2242-ggml-consumers-as-native-godot-modules/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2242 do
  use RFD.DSL

  rfd 2242, "ggml consumers as native Godot modules stacked on modules/ggml" do
    compact_head true

    state :discussion

    flight_level :l2

    feature "each ggml consumer in the workspace becomes a native
Godot engine C++ module inside `entities-godot-sandbox/modules/`,
all stacked on a foundational `modules/ggml/` that hosts the
ggml library itself. GDScript adapters are not the interface."

    scope "`entities-godot-sandbox/modules/ggml/` (new),
`modules/motion_bricks/`, `modules/skin_tokens/`,
`modules/pixal3d/`, `modules/kimodo/`, `modules/rf_detr/`,
RFD 2230 (retracts its GDScript-adapters shape), RFD 2229
(this is another consolidation landing under its policy)"

    decision ~S"""
    Operator, 2026-09-09, verbatim: *"consolidate so that each of
    the ggml users is a godot engine c++ module on top of
    entities-godot master. you probably want to stack the code on
    top of a ggml module"*.

    Reverses the arrangement RFD 2230 was proposing (single native
    module + GDScript adapters). Everything is native C++, stacked
    at the `#include` and link level, no GDScript layer between
    consumer code and ggml.

    `DETAILS.md` carries the full text of this RFD.
    """

    related ~S"""
    RFD 2188 (one ggml across the workspace), the source consolidation this builds
    on. RFD 2211 (the base tree). RFD 2229 (interchangeable parts), the policy this
    lands one of. RFD 2230 (GDScript adapters), retracted by the decision above.
    RFD 2212 (motion-bricks as a native module), reinstated as one leaf.
    `DETAILS.md` carries what each contributes.
    """

    details_title "ggml consumers as native Godot modules stacked on modules/ggml"

    details "What each related RFD contributes", ~S"""

    - RFD 2188 (one ggml across workspace), the source
      consolidation this RFD builds on. `modules/ggml/#thirdparty/`
      vendors `2-contract/ggml` at the workspace's canonical
      revision.
    - RFD 2211 (base tree entities-godot-sandbox), the tree the
      new modules land in. Base branch is Godot upstream `master`
      per the operator's directive, not the current
      `main` / `multiplayer-fabric` line.
    - RFD 2229 (interchangeable-parts policy), the policy this
      RFD lands one of. `check_manifest_dupes.exs` goes green
      when every consumer's private ggml submount is replaced by
      the shared `modules/ggml/#thirdparty/ggml/`.
    - RFD 2230 (ggml adapters as sandboxed GDScript), retracted
      by this RFD's decision. 2230's Layer-1 (native `modules/ggml/`)
      survives as this RFD's foundation module; its Layer-2 and
      Layer-3 (GDScript adapters) do not.
    - RFD 2212 (motion-bricks-as-native-godot-module), the
      earlier per-consumer-native-module shape this RFD reinstates
      as one leaf of the tree.
    - `turboquant-godot/modules/llm/`, the existing reference
      implementation of a native ggml-wrapping Godot module (ggml
      + llama.cpp + Metal/Vulkan/WebGPU builders). Seed for
      `modules/ggml/`; the llama.cpp portion moves to a separate
      `modules/llama_cpp/` in a follow-up.
    - `entities-godot-sandbox/modules/cineform/`, the reference
      template for a downstream consumer module. Vendored
      `#thirdparty/` + `env_thirdparty.add_source_files` +
      per-clone warning suppression.
    """

    details "The arrangement", ~S"""
    Six modules in `entities-godot-sandbox/modules/`, layered:

        modules/ggml/                     ← foundation. Vendors ggml.
        modules/motion_bricks/            ← stacks on modules/ggml
        modules/skin_tokens/              ← stacks on modules/ggml
        modules/pixal3d/                  ← stacks on modules/ggml
        modules/kimodo/                   ← stacks on modules/ggml
        modules/rf_detr/                  ← stacks on modules/ggml

    Stacking is at the C++ level: consumer modules `#include
    "modules/ggml/ggml_engine.h"` and link against Godot's
    all-modules-together binary. No SCsub-level `Depends` between
    modules, matching the `multiplayer_fabric_asset` →
    `multiplayer_fabric` precedent already in the tree.

    Every module has the shape SCsub + config.py + register_types.
    {h,cpp} + module code + `#thirdparty/<name>/` vendored sources.
    `modules/ggml/` registers at `MODULE_REGISTRATION_LEVEL_CORE`;
    every consumer registers at `MODULE_REGISTRATION_LEVEL_SCENE`.
    """

    details "Why native C++ and not GDScript adapters", ~S"""
    RFD 2230 argued for GDScript adapters. That shape trades
    performance and type-safety for run-time swappability, and
    swappability is not the property the atelier's runtime needs.
    Every consumer here already has a stable C ABI
    (`motionbricks.h`, `skintokens.h`, `kimodo_capi.h`,
    `trellis2_capi.h`), so wrapping them into a Godot Resource is
    a mechanical port with type-checked signatures; a GDScript
    adapter reintroduces a dynamic-typed layer that does nothing
    the C ABI does not already do.

    The one exception is `rf-detr-cpp`, which does not have a C
    ABI yet — its public surface is C++ classes with `ggml_tensor*`
    on the signatures. Adding `rfdetr_capi.{h,cpp}` upstream in
    `rf-detr-cpp` is the missing precondition, and lands as its
    own PR ahead of `modules/rf_detr/`.
    """

    details "Interchangeable-parts obligation", ~S"""
    RFD 2229 requires every new component to name what it
    substitutes for.

    - `modules/ggml/` substitutes for `2-contract/ggml`'s
      standalone CMake build and for every consumer's private
      `ggml/` submount.
    - `modules/motion_bricks/` substitutes for
      `3-interactor/motion-bricks-cpp/`'s standalone CMake project.
      The source-of-truth code stays in the standalone repo;
      `modules/motion_bricks/#thirdparty/motion_bricks/` vendors
      it via `scripts/import_module_source.py`.
    - Same substitution shape for `skin_tokens`, `pixal3d`,
      `kimodo`, `rf_detr`.
    - `turboquant-godot/modules/llm/` gets a retraction PR after
      `modules/ggml/` lands, pointing at
      `entities-godot-sandbox/modules/ggml/`.

    Not substituted (out of scope): `nx-ggml` (Elixir NIF, not a
    Godot module), `transport-shepherd` (Elixir gate that
    references ggml.h only), `stable-diffusion.cpp` (pins its own
    older ggml SHA, RFD 2188 already scoped it out),
    `entities-gyre` (empty directory).
    """

    details "Sequencing", ~S"""
    1. This RFD lands `:discussion`. RFD 2230 flips to
       `:abandoned` with a one-line pointer here.
    2. `V-Sekai-fire/rf-detr-cpp` PR adds `rfdetr_capi.{h,cpp}`.
       Nothing else consumes rf-detr yet, so this ships alone
       against `master`.
    3. `V-Sekai-fire/entities-godot-sandbox` new branch
       `ggml-consolidation` off Godot upstream `master`. Adds
       `modules/ggml/` seeded from `turboquant-godot/modules/llm/`,
       minus the llama.cpp portion and minus
       `resource_importer_gguf.{cpp,h}` (return in a follow-up).
    4. Same branch adds the five consumer modules, each with a
       minimal Resource stub over their C ABI. Full
       feature-parity per consumer lands in follow-up PRs.
    5. `weftspun-keypoint/default.xml` drops
       `3-interactor/skin-tokens-cpp/ggml` (the last remaining
       ggml submount) and, optionally, the five consumer project
       entries whose code is now vendored inside modules.
       `check_manifest_dupes.exs` exits 0.
    6. `turboquant-godot/modules/llm/` retraction PR points at
       `entities-godot-sandbox/modules/ggml/`.
    """

    details "Verification", ~S"""
    1. `scons --dry-run p=macos target=editor` on the new branch
       parses every new module's SCsub without a build. Runs in
       seconds; catches SCsub-level syntax errors and missing
       source files.
    2. Full `scons p=macos target=editor tools=yes dev_build=yes`
       compiles the engine with all new modules enabled. First
       pass takes tens of minutes per module with sccache cold.
       Runs in CI, admin-merge past initial red if item 1 is
       green.
    3. `ClassDB.class_get_method_list("MotionBricksModel")` and
       equivalents in a running editor instance confirm the
       modules register real Godot classes and not empty stubs.
    4. `elixir check_manifest_dupes.exs --manifest default.xml`
       exits 0 after step 5 of Sequencing.
    """

    drafted_by :ai
  end
end
