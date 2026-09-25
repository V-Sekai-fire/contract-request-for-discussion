# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2206. `mix rfd.render` renders rfd/2206-video-call-vrm-portrait/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2206 do
  use RFD.DSL

  rfd 2206, "Video-call VRM portrait convention" do
    compact_head true

    state :discussion

    feature "the visual convention for a VRM avatar staged as a
FaceTime-style portrait, fixed eye-level camera, LookAt on the
camera with periodic glance-away, breathing sway, blink cycle,
reaction blendshapes that fade over about the width of a golf ball
of time (~1.6 s)"

    scope "any browser demo or shipped surface that presents a VRM
as an interlocutor rather than an inhabitant of a world; today's
concrete case is the Starforged play surface in
`7-service/service-sqlar-cas/docs/`"

    decision ~S"""
    A VRM presented as an interlocutor is staged as **a 3D character in
    a small diorama, framed like a video call**. The frame is fixed;
    the character animates within it; there is no world navigation.
    Concretely:

    `DETAILS.md` carries the full text of this RFD.
    """

    problem ~S"""
    The reflex-executor demo that shipped in
    `7-service/service-sqlar-cas/docs/` first framed its VRM as an
    inhabitant of a scene, WASD, orbit camera, gamepad. The Starforged
    retarget of the same page kept the WASD wiring alive, and the
    character read as a doll on a stage rather than as the person the
    player was talking to. The retarget was a *decision-point* game
    (continues in `DETAILS.md`)
    """

    related ~S"""
    - RFD 1170 (presence loop), this RFD is its visual convention.
    - RFD 2205 (Taskweft in Bao), the Starforged play surface that
      this convention was first applied to.
    - [RFD 2213](../2213-vrm-via-godot-sandbox-elf/), how the VRM
    (continues in `DETAILS.md`)
    """

    details_title "Video-call VRM portrait convention"

    details "Amendment 2026-09-05: runtime swap to Godot `platform=web`", ~S"""
    The portrait originally shipped as `@pixiv/three-vrm` in
    `7-service/service-sqlar-cas/docs/vrm.js`. Per [RFD
    2210](../2210-atelier-godot-web-shipping-surface/)
    (L3) and [RFD 2216](../2216-threejs-blocklist/) (three.js blocklist),
    the three-vrm path is retired. VRM 1.0 loading now happens via
    [RFD 2213](../2213-vrm-via-godot-sandbox-elf/), `V-Sekai/godot-vrm`
    compiled to a RISC-V ELF loaded by `modules/sandbox` (libriscv)
    inside a Godot `platform=web` export.

    The convention this RFD carries (video-call framing, LookAt on
    camera, breathing/blink idle, reaction blendshapes, no world
    navigation) stays the same. The runtime that renders the portrait
    moves from three-vrm-in-a-browser-canvas to Godot-in-a-browser-
    canvas. VRM asset (`SK_VRM1_Constraint_Twist_Sample`) unchanged.

    The retracted-shape section below still holds, it retracted the
    world-navigation input handlers regardless of runtime. Everything
    below that references three-vrm specifically applies to how the
    convention was implemented, not how it's implemented today; treat
    those references as historical.
    """

    details "The retracted shape", ~S"""
    Before this convention landed, `docs/vrm.js` carried:

    - WASD / arrow-key handlers driving `avatar.pos.x, z`.
    - Pointer-lock mouse look driving `orbit.yaw, pitch`.
    - Mouse-wheel zoom driving `orbit.dist`.
    - Gamepad L-stick / R-stick reads for the same three targets.
    - A camera pose derived per frame from `orbit.*` around a target
      parented to the avatar's chest.

    That shape reads naturally for a *scene* (a character walking a
    world), and it read wrong for a *dialogue* (a character talking
    to the player through a phone-shaped frame). Nothing about the
    handlers was buggy, they applied inputs faithfully. The
    convention is a signal to the character (the player is holding
    still and listening) not a limitation on the inputs.
    """

    details "The reference implementation", ~S"""
    `docs/vrm.js` after the retarget:

    - Camera constructed once at boot; parent is `null` (world-space
      pinned) rather than the avatar's head bone. Head-bone-parenting
      was tried and rejected: it slid on breathing sway and read as
      the room shaking, not the character breathing.
    - `applyLookAt(now)` reads the head-bone world position each
      frame, offsets +0.55 m along the character's forward axis at
      +0.02 m Y (eye height offset), and writes the camera position.
      Cheap; runs before the render call.
    - `applyGlanceAway(now)` maintains one piece of state, the epoch
      of the next glance, and briefly targets a point offset from the
      camera by ~0.25 m along the character's right or up axis (uniform
      random each cycle). Duration 300 ms. Next glance scheduled 4-7 s
      out.
    - `applyBreathing(now)` writes a small rotation on `Spine` and
      `UpperChest`, 0.02 rad amplitude, 4 s period. Amplitude and
      period were picked by eye; larger read as swaying, smaller
      wasn't visible.
    - `applyBlink(now)` fires the expressionManager `blink` at ~4 s
      period with a 100 ms held-closed window. `@pixiv/three-vrm`'s
      built-in blink cycler was declined because it uses the same
      hook and adding two blinkers is hard to debug.
    - `fireReaction(kind)` sets `expressionManager` `happy` /
      `neutral` / `sad` to 1.0, then a per-frame decay drops it back
      to 0 over the next ~1.6 s. The window is deliberately short:
      Starforged play surfaces a menu after each reaction, and a
      facial expression that holds past the next menu confuses the
      next beat.
    """

    details "Diorama backdrops", ~S"""
    Loaded once at scene start via three.js `GLTFLoader`. Static; no
    animation. Swap per-scene by unloading the current backdrop and
    loading a new one. Small target: any single backdrop under ~500 KB.
    The Starforged demo ships `scenes/{cockpit,station-bar,deckplate}.gltf`
    as reference set.
    """

    details "Verification", ~S"""
    - The Playwright script at `7-service/service-sqlar-cas/scripts/qa_demo.mjs`
      asserts:
     , `vrm.expressionManager.getValue('happy') > 0` within 200 ms of
        a strong-hit;
     , `vrm.expressionManager.getValue('happy') < 0.05` at 2000 ms
        after (reaction has decayed);
     , the camera position is unchanged across 10 s of idle (no
        world-navigation input reaches the camera).
    - **Negative control** (rule 2): the test suite includes a
      scripted keyboard event dispatching WASD; the camera position
      MUST remain unchanged. A revision that reintroduces the WASD
      handler fails this assertion loudly.
    """

    details "Trademark note", ~S"""
    The convention is inspired by a genre of consumer video-calling
    apps that share the same framing (eye-level, portrait 4:5,
    head-and-shoulders composition). The RFD describes the shape by
    its generic vocabulary and does not name any specific app or
    platform. See CLAUDE.md's "Trademarks Stay Out of Shipping
    Artifacts" clause.
    """

    details "From the README, moved here on 2026-09-07", ""

    details "Decision", ~S"""
    A VRM presented as an interlocutor is staged as **a 3D character in
    a small diorama, framed like a video call**. The frame is fixed;
    the character animates within it; there is no world navigation.
    Concretely:

    1. **Camera.** Eye-level (Head bone Y, ~1.52 m off the floor for
       an adult VRM, about the height of an adult wrist reached
       overhead), offset ~0.55 m along Z (about eight stacked AA
       batteries), no downward pitch. Targets a point just below the
       eyes so head + shoulders + up-to-the-ribcage fill the frame.
       Portrait 4:5 aspect (phone-call-native).
    2. **LookAt.** The VRM's `LookAt` target follows the camera every
       frame via `godot-vrm`'s `VRMTopLevel` LookAt proxy (loaded as a
       sandbox ELF per [RFD 2213](../2213-vrm-via-godot-sandbox-elf/)).
       The player IS the caller. A small time-based glance-away every
       4-7 s for ~300 ms (about the width of a pencil of time) prevents
       the death-stare failure mode.
    3. **Idle motion.** Ambient sway on `Spine` / `UpperChest` at 0.02
       rad amplitude with a 4-s sinusoid for breathing. Blink cycle
       ~4 s period with 100 ms closed.
    4. **Reactions.** A move outcome (`strong-hit` / `weak-hit` /
       `miss`) fires a VRM expression blendshape (`happy` / `neutral`
       / `sad`) that holds for ~1.5 s then decays over ~100 ms back to
       neutral. Total envelope ~1.6 s, about the width of a golf ball
       of time. Reuses the VRM expression node `godot-vrm` exposes.
    5. **Diorama backdrop.** A low-poly scene-flavored backdrop behind
       the character, swappable per-scene from a small `scenes/*.gltf`
       set. Kept deliberately low-detail so the character reads as the
       subject.
    6. **What is banned.** No WASD, no arrow-key movement, no
       pointer-lock mouse look, no wheel zoom, no gamepad stick reads,
       no `avatar.pos` mutation, no `orbit.yaw / pitch / dist` camera
       state. A demo that presents a VRM as an interlocutor and lets
       the player fly the camera around it undoes the convention.
    """

    details "Problem", ~S"""
    The reflex-executor demo that shipped in
    `7-service/service-sqlar-cas/docs/` first framed its VRM as an
    inhabitant of a scene, WASD, orbit camera, gamepad. The Starforged
    retarget of the same page kept the WASD wiring alive, and the
    character read as a doll on a stage rather than as the person the
    player was talking to. The retarget was a *decision-point* game
    where the player is in dialogue with a character; the video-call
    frame is what makes that reading legible without any extra prose.
    This RFD writes that legibility down as a convention future
    character-facing demos default to.
    """

    details "Non-goals", ~S"""
    Not a convention for third-person action, exploration, or world
    demos, those keep their world navigation. Not a rig spec (the
    underlying VRM is unchanged). Not a scene-content spec (dioramas
    are per-demo; only that they exist and stay low-detail is
    mandated).
    """

    details "Related", ~S"""
    - RFD 1170 (presence loop), this RFD is its visual convention.
    - RFD 2205 (Taskweft in Bao), the Starforged play surface that
      this convention was first applied to.
    - [RFD 2213](../2213-vrm-via-godot-sandbox-elf/), how the VRM
      loads in the current native Godot binary (godot-vrm ELF via
      libriscv sandbox); the earlier `@pixiv/three-vrm` reference
      implementation at `7-service/service-sqlar-cas/docs/vrm.js`
      is retired with the three.js blocklist (RFD 2216).
    """

    drafted_by :ai
  end
end
