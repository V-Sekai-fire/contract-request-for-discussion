# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2156. `mix rfd.render` renders rfd/2156-safegdscript-compile-step/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2156 do
  use RFD.DSL

  rfd 2156, "SafeGDScript compile step for RECTGTN GDScript output" do
    state :discussion

    feature "compile taskweft-emitted GDScript (RFD 2155) into a
RISC-V ELF the Godot Sandbox (RFD 2154) loads"

    scope "taskweft (a `mix openplc.gd-compile` task) or a sidecar"

    decision ~S"""
    **Parked.** Two candidate routes, both preserving RFD 2150's FBD
    authoring and RFD 2154's in-process linking:

    1. **Runtime compile inside the Sandbox.** Load `gdscript.elf` (ships
       with godot-sandbox releases), feed it the `.gd` source, receive a
       compiled program a second Sandbox loads. No CLI to install.
    2. **CLI-side compile.** Build SafeGDScript standalone from godot-
       sandbox sources (`riscv64-elf-gcc` already installed for RFD
       2149), invoke from a `mix openplc.gd-compile` task like `mix
       openplc.compile` invokes `openplc-cli`.

    Route 1 is smaller; route 2 is standard tool-shape and unlocks
    compile-time verification. Lands when the first RECTGTN-authored plan
    runs in Godot Sandbox.
    """

    problem ~S"""
    RFD 2155 stage 1 emits `.gd` that mirrors the state machine
    `Taskweft.OpenPLC.PLCopen.emit/1` encodes as FBD. RFD 2154's Godot
    Sandbox loads RISC-V ELFs. Between them: **SafeGDScript**, godot-
    sandbox's GDScript-to-RISC-V compiler (Dec 2025 "42 demo projects"
    milestone hit feature parity). Nothing today invokes it from
    taskweft's build.
    """

    references ~S"""
    1. SafeGDScript: https://libriscv.no/blog/godot-sandbox-fortytwo/
    2. RFD 2150, RFD 2154, RFD 2155
    """

    drafted_by :ai
  end
end
