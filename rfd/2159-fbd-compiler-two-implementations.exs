# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2159. `mix rfd.render` renders rfd/2159-fbd-compiler-two-implementations/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2159 do
  use RFD.DSL

  rfd 2159, "Two `.elf` implementations of the Lean 4 FBD spec" do
    compact_head true

    state :committed

    feature "ship two independent RISC-V ELF implementations of the
compiler RFD 2157 formalises in Lean 4. Outputs cross-check on the
same fixtures; both are graded against the spec."

    scope "two sibling repos + a differential harness"

    decision ~S"""
    Green-lit; C++ and Rust both to ship.

    `DETAILS.md` carries the full text of this RFD.
    """

    problem ~S"""
    RFD 2157's Lean formalisation is the ground truth. RFD 2158 blocks
    Lean-emitted ELF today (upstream RFC 12655 open). Trusting one
    backend makes soundness a hope; two agreeing backends give the
    property `compile_correct` alone cannot.
    """

    references ~S"""
    1. RFD 2157 (Lean spec), RFD 2158 (self-host blockers)
    2. godot-sandbox CI:
      `libriscv/godot-sandbox/.github/workflows/build_gdscript_elf.yml`
    3. Rust riscv64 target: platform-support docs
    """

    details_title "Two `.elf` implementations of the Lean 4 FBD spec"

    details "Decision", ~S"""
    Green-lit; C++ and Rust both to ship.

    Ship two `.elf` implementations, both cross-compiling today, both
    loading into godot-sandbox unchanged.

    1. **C++**; reuses godot-sandbox's SafeGDScript build recipe.
    2. **Rust**; `cargo build --target riscv64gc-unknown-linux-gnu`.

    Different type systems, different memory models, different codegen ;
    bugs don't correlate. Both must agree on RFD 2157's fixture set
    byte-for-byte; disagreement is a soundness bug flagged against
    whichever impl differs from the Lean spec's reference output.

    `DETAILS.md` carries the differential harness, fixture format, and
    the spec-to-impl obligation table.
    """

    details "Problem", ~S"""
    RFD 2157's Lean formalisation is the ground truth. RFD 2158 blocks
    Lean-emitted ELF today (upstream RFC 12655 open). Trusting one
    backend makes soundness a hope; two agreeing backends give the
    property `compile_correct` alone cannot.
    """

    details "References", ~S"""
    1. RFD 2157 (Lean spec), RFD 2158 (self-host blockers)
    2. godot-sandbox CI:
      `libriscv/godot-sandbox/.github/workflows/build_gdscript_elf.yml`
    3. Rust riscv64 target: platform-support docs
    """

    drafted_by :ai
  end
end
