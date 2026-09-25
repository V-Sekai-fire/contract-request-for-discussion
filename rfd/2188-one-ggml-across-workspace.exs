# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2188. `mix rfd.render` renders rfd/2188-one-ggml-across-workspace/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2188 do
  use RFD.DSL

  rfd 2188, "One GGML across the workspace" do
    state :discussion

    feature "a single canonical GGML source tree the whole workspace consumes"

    scope "every C/C++ project in `3-interactor` that links a tensor runtime"

    decision ~S"""
    `weftspun/ggml` is the one canonical GGML source in this workspace.
    Every consumer references it through the manifest; vendored copies
    are deleted; a prek gate refuses any new consumer that brings its own.

    Manifest points at branch `weftspun-consolidated`, seeded from
    `ggml-seethrough` HEAD (`3404c951`, 2026-08-29) — the richest tip,
    carrying 14+ custom backends. `upstream-tracking` branch was pushed
    at `ggml-org/ggml master` (2026-08-30) as a future rebase base.

    Placed at `2-contract/ggml`: the tensor runtime is a contract every
    interactor consumes. There is no `0-shared` hexagon side.
    """

    problem ~S"""
    Discovery found six divergent copies, two with conflicting-SHA
    manifest entries under the same project name (drift alive at the
    moment of writing). See DETAILS.md for the table and the
    skipped-cherry-pick list.

    Phase 1 lands the framework: canonical repo, manifest change,
    singleton gate, RFD. Phase 2 migrates the remaining consumers one
    PR at a time, resolving the two Metal cherry-pick conflicts by hand
    against the newer backend surface.
    """

    related ~S"""
    RFD 1000 (hexagon-side placement rule), RFD 1102 (task catalog
    gacha pipeline consumes ggml through skin-tokens.cpp and
    motion-bricks.cpp), CLAUDE.md's ggml/GGUF blocklist row (the vendor's
    own runtime is exempt — this RFD is that exemption's canonical form).
    """

    details_title "One GGML across the workspace"

    details "Discovery: HEAD dates for every ggml copy found", ~S"""
    Measured 2026-09-03 across the workspace.

    | copy | HEAD SHA | HEAD date | notes |
    |---|---|---|---|
    | `3-interactor/ggml-seethrough` | `3404c951` | 2026-08-29 | on branch `seethrough-metal-diag-mask-inf`, 14+ custom backends (Vulkan/Metal/CUDA/CoreML/HIP/SYCL/CANN/OpenVINO/Hexagon/OpenCL/MUSA/WebGPU/BLAS/RPC/ZenDNN/ZDNN). "NOT UPSTREAM MATERIAL" per its commit message. Chosen as base. |
    | `3-interactor/trellis2cpp/ggml` | `331b9cba` | 2026-03-31 | on branch `sam3-metal-ops`. Two commits unique from ggml-seethrough HEAD: `7a466633` Metal conv\_transpose\_2d + depthwise + K/V type check; `331b9cba` Metal flash\_attn\_ext head\_dim=16 and head\_dim=56. |
    | `3-interactor/nx-ggml/native/nx_ggml/third_party/ggml` | subtree, no independent history | n/a | vendored under the NIF |
    | `3-interactor/rf-detr-cpp/third_party/ggml` | subtree, no independent history | n/a | vendored |
    | `3-interactor/llama-cpp-npu-vision-upstream/ggml` | inside llama.cpp | 2026-09-02 | ggml lives under llama.cpp's tree, not independently rebasable. HEAD date is llama.cpp's, not ggml's. |
    | `3-interactor/turboquant-godot/thirdparty/llama_cpp/ggml` | inside llama.cpp | n/a | same shape as above |
    | `3-interactor/skin-tokens-cpp` | not checked out | n/a | manifest projects `skin-tokens.cpp` and `motion-bricks.cpp` did not sync to disk in this session, Phase 2 migration blocked until the sync completes |
    | upstream `ggml-org/ggml` `master` | `d4716378` | 2026-08-30 | pushed to `weftspun/ggml:upstream-tracking` for future rebase base |

    The user's intuition ("ggml-seethrough has the newest stuff") held: it
    has the freshest independent ggml history and by far the widest
    backend surface. The llama.cpp-embedded copies are newer as
    llama.cpp checkouts but their ggml half sits under that project's
    own git and is not a candidate for the canonical branch.
    """

    details "Consolidation branch", ~S"""
    `weftspun/ggml:weftspun-consolidated` pushed at `3404c951`
    (ggml-seethrough HEAD, unmodified). The manifest points at that
    branch name so a rebase moves the tip forward without a manifest
    edit.
    """

    details "Cherry-pick skipped commits, then re-resolved", ~S"""
    Cherry-picked onto `weftspun-consolidated` from `sam3-metal-ops`:

    | commit | subject | first outcome | resolution |
    |---|---|---|---|
    | `7a466633` | Metal conv\_transpose\_2d, depthwise conv\_2d, K/V flash\_attn\_ext type check, WIN\_PART / WIN\_UNPART on Metal | **SKIPPED**: conflicts in ggml-metal-device.h, ggml-metal-ops.cpp, ggml-metal.metal | **DROPPED after re-verification**. Per-intent verdicts below |
    | `331b9cba` | Metal flash\_attn\_ext head\_dim=16 and head\_dim=56 | **SKIPPED**: dependent on `7a466633`, and first pass claimed the template mechanism was restructured | **PORTED** as PR https://github.com/weftspun/ggml/pull/1 |

    ### 7a466633 per-intent verdicts

    | intent | verdict | evidence |
    |---|---|---|
    | conv\_transpose\_2d on Metal | verified covered | consolidated has identical (f32\_f32, f16\_f32) template pair at ggml-metal.metal:5508. Algorithm differs (threadgroup shared-sum reduction on consolidated) but the surface and dtype coverage match |
    | depthwise conv\_2d (CONV\_2D\_DW) | verified covered with more | consolidated has kernel\_conv\_2d\_dw templated over TK (_f32\_f32, _f16\_f32) plus a tiled variant with the same coverage. sam3's plain kernel\_conv\_2d\_dw\_f32 is a strict subset |
    | flash\_attn\_ext K/V type check | verified covered | identical assertion `op->src[1]->type == op->src[2]->type` at ggml-metal-ops.cpp:2721 |
    | WIN\_PART / WIN\_UNPART on Metal | genuinely missing, deferred | sam3 added Metal kernels; consolidated has these ops only in the CPU backend (ggml-cpu.c:2019-2023). No consumer in the workspace uses SAM3-style windowed attention today. CPU fallback correct. Port when a consumer needs it |

    ### 331b9cba resolution

    The first close-out claimed the template mechanism had been restructured and dk16/dk56 could
    not be added. That was wrong. The template shape on consolidated matches sam3 exactly; adding
    two head-dim slots was a mechanical change once the vec dispatch was ruled out.

    PR https://github.com/weftspun/ggml/pull/1 adds 16 template instantiations (dk16, dk56 × 8 K/V
    dtypes) plus 2 entries in the head-size whitelist in supports_op. Vec templates omitted
    because `ggml_metal_op_flash_attn_ext_use_vec` gates on `ne00 % 32 == 0`, which excludes 16
    and 56. **Merged 2026-09-03.**

    **Verified on Apple M2 Pro.** `test-backend-ops`'s default FLASH\_ATTN\_EXT generator loops
    hsk over `{ 40, 64, 72, 80, 96, 128, 192, 256, 320, 512, 576 }`, no 16 and no 56. With 16
    added test cases enumerating hsk=16 and hsk=56 across all 8 K/V dtypes and `-b MTL0`:
    **4768/4768 tests passed** against the CPU reference (baseline 4752 + 16 new = 4768), and the
    Metal pipeline compile log confirmed the new kernels were actually reached:
    `kernel_flash_attn_ext_{f16,f32,bf16}_dk{16,56}_dv{16,56}`. Wall clock 49 s.

    Household anchor: this is a build+test on the same M2 Pro that runs the rest of the desk. The
    "no Metal build+run capability" caveat that appeared in the first PR body was wrong and has
    been retracted from the PR body it stood in.

    The `sam3-metal-ops` branch stays for archaeology.

    ### Correction the record keeps

    The first close-out was too fast. Two claims failed the same test: "the newer surface
    restructured the target" was said without reading whether the restructure actually broke the
    port. The re-investigation kept the same three intents already-covered verdicts, added the
    WIN\_PART/WIN\_UNPART deferral (which the first pass called "not clearly needed" without
    evidence), and reversed the dk16/dk56 verdict from "not portable" to "portable with 18 lines."
    The verdicts moved because they were re-measured; the retraction stays here rather than being
    tidied out.
    """

    details "Compatibility test matrix", ~S"""
    Phase 2 walks this per-consumer. Not run in Phase 1.

    | consumer | manifest path | current ggml source | Phase 2 migration owner |
    |---|---|---|---|
    | `skin-tokens.cpp` | `3-interactor/skin-tokens-cpp` | its own | this RFD's follow-up PR |
    | `motion-bricks.cpp` | `3-interactor/motion-bricks-cpp` | its own | ditto |
    | `rf-detr-cpp` | `3-interactor/rf-detr-cpp` | `third_party/ggml` subtree | rf-detr keypoint pipeline owner |
    | `nx-ggml` | `3-interactor/nx-ggml` | `native/nx_ggml/third_party/ggml` subtree | nx-ggml NIF owner |
    | `llama-cpp-npu-vision-upstream` | `3-interactor/llama-cpp-npu-vision-upstream` | ggml under llama.cpp | vendor-runtime exempt (CLAUDE.md ggml row), no migration |
    | `turboquant-godot` | `3-interactor/turboquant-godot` | ggml under llama.cpp | vendor-runtime exempt, no migration |
    """

    details "Phase 1 landing PRs", ~S"""
    - `weftspun/ggml`: pushed `weftspun-consolidated` and
      `upstream-tracking` branches. No PR, direct branch push.
    - `weftspun/request-for-discussion`: this RFD, S2188 in
      `SERIALS-vsekai-fabric.usda`, `scripts/check_ggml_singleton.py`,
      hook wiring in `.pre-commit-config.yaml`.
    - `weftspun/weftspun-keypoint`: manifest change collapsing the two
      conflicting `<project name="ggml">` entries into one pointing at
      `weftspun-consolidated` under `2-contract/ggml`.
    """

    details "Phase 1 non-goals", ~S"""
    - `skin-tokens.cpp` proof-of-pattern migration deferred: the
      manifest projects did not check out in this session. Named and
      counted per CLAUDE.md rule 3, a silent skip would have read as a
      pass.
    - No consumer's CMake was edited in Phase 1.
    - No build was verified in Phase 1.
    """

    drafted_by :ai
  end
end
