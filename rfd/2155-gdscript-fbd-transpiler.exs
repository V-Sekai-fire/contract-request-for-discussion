# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2155. `mix rfd.render` renders rfd/2155-gdscript-fbd-transpiler/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2155 do
  use RFD.DSL

  rfd 2155, "GDScript <-> IEC 61131-3 FBD transpiler" do
    state :prediscussion

    feature "bidirectional transpile between GDScript and PLCopen FBD
(RFD 2150): Godot users author in a familiar language, taskweft renders
RECTGTN-produced FBD back as GDScript for humans"

    scope "taskweft, new sibling `taskweft-gdscript-fbd`"

    decision ~S"""
    **Parked.** Design frozen against UdonSharp's pattern. Lands when
    the first taskweft user names a GDScript-authored domain. `DETAILS.md`
    carries the UdonSharp study and the GDScript subset covered stage 1.
    """

    problem ~S"""
    RFD 2150's target is PLCopen FBD. Godot devs author in GDScript.
    The gap is what Merlin's **UdonSharp** solved for VRChat: Udon is a
    node graph, C# is a familiar language, UdonSharp compiles C# to Udon
    so the author never sees the graph unless they want to. Taskweft has
    the same shape:

    1. **GDScript author**: `.gd` -> transpiler -> FBD -> RFD 2150
       compile -> RFD 2154 loads into Godot Sandbox.
    2. **FBD reader**: compiled RECTGTN plan renders back as `.gd` for
       humans debugging the state machine in Godot's editor.

    godot-sandbox ships **SafeGDScript** (its own GDScript-to-RISC-V
    compiler; Dec 2025 "42 demo projects" milestone landed feature
    parity). SafeGDScript is the second half: transpiler emits GDScript,
    SafeGDScript compiles to RISC-V, Godot Sandbox loads it. No OpenPLC
    Editor needed for GDScript-authored plans.
    """

    references ~S"""
    1. UdonSharp: https://github.com/vrchat-community/UdonSharp
    2. SafeGDScript: https://libriscv.no/blog/godot-sandbox-fortytwo/
    3. RFD 2148, 2145, 2149
    """

    drafted_by :ai
  end
end
