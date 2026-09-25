# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 1175. `mix rfd.render` renders rfd/1175-game/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD1175 do
  use RFD.DSL

  rfd 1175, "game" do
    state :discussion

    flight_level :l2

    feature "one native binary that is both the interactive demo and
the video head that records it"

    scope "`3-interactor/entities-godot-sandbox`; every part the
atelier ships lands in this binary"

    attest_in :none

    decision ~S"""
    One Godot binary (Vulkan; MoltenVK on macOS) shows a VRM avatar
    framed like a video call, and at each decision point offers the
    legal Starforged moves from the Taskweft planner; the chosen move's
    outcome drives a VRM expression while motion-bricks (ggml, Vulkan)
    generates the body motion between decisions. The same binary with
    `--headless --write-movie` walks a shot list and encodes CineForm,
    so the video is the game recorded rather than a second deliverable.
    `DETAILS.md` carries what the player sees, the loop, the runtime
    stack and the video head.
    """

    problem ~S"""
    The demo was two deliverables, a video and a game, with two asset
    paths that could drift. One binary with two heads removes the second
    path and makes every shipped part prove itself in the thing a player
    runs.
    """

    related ~S"""
    RFD 2210 (the shipping surface this binary is), RFD 2177 (flight
    levels; this RFD is L2 in the register).
    """

    details_title "game"

    details "What the player sees", ~S"""
    A native window on the operator's desktop. Inside, a VRM avatar
    framed like a video call, eye-level camera, ~1.52 m off the
    floor, portrait 4:5 aspect. LookAt tracks the camera every frame
    with a 300 ms glance-away every 4–7 s to break the death-stare.
    Ambient breathing sway at 0.02 rad on the spine, 4 s sinusoid.
    Blink cycle 4 s / 100 ms closed. The player IS the caller.
    """

    details "Loop", ~S"""
    At each decision point, the Taskweft planner supplies the legal
    moves (Starforged rules baked into `starforged.sqlite`, ~433 rows).
    Player picks one from a Godot Control-node VN layout. The chosen
    move's outcome (`strong-hit` / `weak-hit` / `miss`) fires a VRM
    expression blendshape (`happy` / `neutral` / `sad`) that holds
    ~1.5 s then decays over ~100 ms, total envelope ~1.6 s.
    Motion-bricks (ggml, 183 M params, NVIDIA Open Model License,
    Q4 GGUF) generates body motion between decisions.
    """

    details "Runtime stack", ~S"""
    - **Godot** as the runtime, Vulkan renderer (MoltenVK on macOS).
    - **VRM 1.0** loads via `godot-vrm` compiled to RISC-V ELF and
      run in the `modules/sandbox` (libriscv) sandbox, no forked C++,
      no unsandboxed GDScript addon.
    - **ggml** with Vulkan backend for every inference call
      (motion-bricks, Kimodo text-to-motion, EditScore judgment).
    - **Model bundle**: ZSTD-compressed SQLite on local disk, loaded
      via `sqlite3_open()` on install path.
    - **CineForm** encoder (ffmpeg blocklisted).
    - **Nord palette** for demo chrome.
    """

    details "Video head", ~S"""
    Same binary invoked with `--headless --write-movie shot<NN>.<ext>`
    walking a shot list. Same `.tscn` / `.tres` assets. The video is
    the game recorded, not a second deliverable.
    """

    drafted_by :ai
  end
end
