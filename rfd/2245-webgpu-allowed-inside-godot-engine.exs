# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2245. `mix rfd.render` renders rfd/2245-webgpu-allowed-inside-godot-engine/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2245 do
  use RFD.DSL

  rfd 2245, "WebGPU allowed inside Godot engine" do
    state :discussion

    feature "carve-out on the WebGPU blocklist row: WebGPU is allowed
inside a Godot engine fork; workspace deployment target stays Vulkan"

    scope "`CLAUDE.md` (row cell unchanged), `BLOCKLIST.md`
(section body amended), `weftspun-keypoint/default.xml` (add
entities-webgpu fork alongside entities-godot)"

    decision ~S"""
    WebGPU is allowed as a RenderingDevice driver inside a Godot
    engine fork. The row still blocks WebGPU as a workspace render
    or compute target, so the atelier shipping surface stays Vulkan
    and MoltenVK per RFD 2210, and the atelier binary selects
    `RenderingDevice`'s Vulkan backend at boot. An engine carrying
    both drivers keeps that pick and gives an in-tree WebGPU path if
    upstream ever wants one.
    """

    problem ~S"""
    The WebGPU row blocks "Godot forks whose sole purpose is a
    WebGPU renderer". Read literally that reaches the entities-webgpu
    fork, where davnotdev's driver is being ported. The row's intent
    was to keep the deployment target on Vulkan, not to ban WebGPU
    code inside an engine tree. Operator directive 2026-09-11.
    """

    related ~S"""
    - [RFD 2210](../2210-atelier-godot-web-shipping-surface/): the
      atelier ships Godot's Vulkan renderer, untouched here.
    - [RFD 2211](../2211-base-tree-entities-godot-sandbox/):
      entities-godot-sandbox stays the atelier substrate.
    - [RFD 2216](../2216-threejs-blocklist/): the sibling row naming
      WebGPU as blocklisted, its argument unchanged.
    """

    details_title "webgpu allowed inside godot engine"

    details "What changes, and where", ~S"""
    The WebGPU section of `BLOCKLIST.md` gains a Godot-engine-fork
    carve-out under "What the row does not cover". The row's summary
    cell in `CLAUDE.md` already scopes narrowly to "a workspace
    render / compute target", so it needs no edit.

    The amendment reads:

    > A Godot engine fork carrying a WebGPU RenderingDevice driver
    > alongside Vulkan is in-scope. The row blocks WebGPU as the
    > *workspace deployment target*; it does not block WebGPU code
    > inside a Godot engine tree. The atelier binary still selects
    > the Vulkan backend at boot, and the shipping surface stays
    > `entities-godot-sandbox` with MoltenVK on macOS.
    """

    details "Manifest entry", ~S"""
    `weftspun-keypoint/default.xml` gains one project for the
    entities-webgpu fork alongside entities-godot. The revision is
    the branch on which the WebGPU driver is being ported
    (davnotdev/godot@webgpu on top of feat/ci-ar-response-file).

    Path lands under `4-entities/entities-webgpu` (side 4, one repo
    per model, next to entities-godot).
    """

    details "What this does not open", ~S"""
    - `Ggml.WebGPU=ON` and successor flags stay blocked. The
      inference substrate is ggml + Vulkan on native (RFD 2188).
    - Dawn / wgpu-native as a workspace build dependency stays
      blocked. Any WebGPU code lives inside the Godot engine tree
      and links through Godot's own driver.
    - ORT-Web + TFJS WebGPU execution providers stay blocked; the
      ORT-Web / TFJS row above the WebGPU row is not touched.
    - three.js as an in-browser 3D runtime stays blocked (RFD 2216).
    """

    drafted_by :ai
  end
end
