# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2213. `mix rfd.render` renders rfd/2213-vrm-via-godot-sandbox-elf/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2213 do
  use RFD.DSL

  rfd 2213, "VRM 1.0 loading via `godot-sandbox` RISC-V ELF" do
    compact_head true

    state :discussion

    feature "how VRM 1.0 assets load in the atelier native binary
without adding new C++ or forking upstream"

    scope "`3-interactor/entities-godot-sandbox/modules/sandbox`,\n`V-Sekai/godot-vrm`"

    decision ~S"""
    Compile `V-Sekai/godot-vrm` (GDScript addon) to a RISC-V ELF via
    `godot-sandbox`'s toolchain. Ship at
    `res://addons/godot-vrm/godot-vrm.elf`. Load at runtime through
    `modules/sandbox` (libriscv). Godot's `GLTFDocument` +
    `GLTFDocumentExtension` API hands raw VRM bytes to the ELF; the
    ELF returns node/skeleton/expression/spring-bone data.

    `DETAILS.md` carries the full text of this RFD.
    """

    related ~S"""
    - [RFD 2210](../2210-atelier-godot-web-shipping-surface/), L3.
    - [RFD 2211](../2211-base-tree-entities-godot-sandbox/), the
      base-tree choice.
    - [RFD 2230](../2230-ggml-adapters-in-godot-sandbox/), parallel
      path for ggml adapters (GDScript-in-sandbox for orchestration,
      ELF-in-sandbox for third-party untrusted code).
    - RFD 2206 (video-call VRM portrait), uses this ELF path for
      the VRM LookAt + expression node.
    """

    details_title "VRM 1.0 loading via `godot-sandbox` RISC-V ELF"

    details "Decision", ~S"""
    Compile `V-Sekai/godot-vrm` (GDScript addon) to a RISC-V ELF via
    `godot-sandbox`'s toolchain. Ship at
    `res://addons/godot-vrm/godot-vrm.elf`. Load at runtime through
    `modules/sandbox` (libriscv). Godot's `GLTFDocument` +
    `GLTFDocumentExtension` API hands raw VRM bytes to the ELF; the
    ELF returns node/skeleton/expression/spring-bone data.
    """

    details "Rejected", ~S"""
    - **New C++ `modules/vrm/`** subclassing `GLTFDocumentExtension` —
      duplicates work already done in godot-vrm's GDScript. Possible
      follow-up when sandbox overhead measurably hits latency.
    - **Bundle godot-vrm as a plain GDScript addon**, parsing runs
      in the main GDScript VM; no isolation from a malicious VRM.
    """

    details "Cascade", ~S"""
    `modules/sandbox` (libriscv) is on the KEEP list because its
    ELF-execution capability makes this work.
    """

    details "Related", ~S"""
    - [RFD 2210](../2210-atelier-godot-web-shipping-surface/), L3.
    - [RFD 2211](../2211-base-tree-entities-godot-sandbox/), the
      base-tree choice.
    - [RFD 2230](../2230-ggml-adapters-in-godot-sandbox/), parallel
      path for ggml adapters (GDScript-in-sandbox for orchestration,
      ELF-in-sandbox for third-party untrusted code).
    - RFD 2206 (video-call VRM portrait), uses this ELF path for
      the VRM LookAt + expression node.
    """

    drafted_by :ai
  end
end
