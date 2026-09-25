# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2160. `mix rfd.render` renders rfd/2160-openusd-as-taskweft-intermediate/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2160 do
  use RFD.DSL

  rfd 2160, "OpenUSD `.usda` as taskweft's intermediate" do
    compact_head true

    state :prediscussion

    feature "one bidirectional intermediate that carries the source
FBD, every derived artefact (`.gd`, Udon asm, `.elf`, `.uasset`),
and provenance to round-trip between them"

    scope "taskweft, taskweft-fbd-compiler, all emitters, taskweft-godot-sandbox"

    decision ~S"""
    Adopt **OpenUSD `.usda`** as the plan's canonical form. CLAUDE.md
    blesses it ("OpenUSD `.usda` if we want to remain text editable";
    zip/gz blocklisted). USD gives hierarchical Prims, typed attributes,
    references + layer composition (native bidirectional shape), and
    asset refs for binary payloads.

    `DETAILS.md` carries the full text of this RFD.
    """

    problem ~S"""
    Each emitter reads PLCopen FBD XML and writes its own format.
    Nothing carries all of them side-by-side. RFD 2159's differential
    (C++ vs Rust ELFs) needs a place to store both outputs alongside
    the input FBD so a checker cross-verifies.
    """

    references ~S"""
    1. CLAUDE.md archive-format rule + blocklist
    2. RFDs 2150, 2148, 2149, 2150, 2152, 2154
    """

    details_title "OpenUSD `.usda` as taskweft's intermediate"

    details "Decision", ~S"""
    Adopt **OpenUSD `.usda`** as the plan's canonical form. CLAUDE.md
    blesses it ("OpenUSD `.usda` if we want to remain text editable";
    zip/gz blocklisted). USD gives hierarchical Prims, typed attributes,
    references + layer composition (native bidirectional shape), and
    asset refs for binary payloads.

    Prim shape per plan: `/Plan/{Domain, Problem, Network, Deliveries,
    Provenance}`. Under `/Deliveries`, two platforms only:
    1. **Godot**: `ElfCpp` / `ElfRust` (asset refs, RFD 2159 cross-check)
    2. **VRChat**: `UdonAsm` (inline Udon assembly)
    Plus `PLCopenXML` (inline XML, source of truth) and optional
    `GDScript` (inline `.gd`). `/Provenance`: emitter versions, hashes,
    timestamps.

    RFD 2159's differential reads `ElfCpp` and `ElfRust` and diffs.
    RFD 2153 writes `UdonAsm`. RFD 2154 loads `ElfCpp`. All emitters
    become USD writers; all consumers USD readers.
    """

    details "Problem", ~S"""
    Each emitter reads PLCopen FBD XML and writes its own format.
    Nothing carries all of them side-by-side. RFD 2159's differential
    (C++ vs Rust ELFs) needs a place to store both outputs alongside
    the input FBD so a checker cross-verifies.
    """

    details "References", ~S"""
    1. CLAUDE.md archive-format rule + blocklist
    2. RFDs 2150, 2148, 2149, 2150, 2152, 2154
    """

    drafted_by :ai
  end
end
