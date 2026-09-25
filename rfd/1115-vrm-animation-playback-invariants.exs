# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 1115. `mix rfd.render` renders rfd/1115-vrm-animation-playback-invariants/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD1115 do
  use RFD.DSL

  rfd 1115, "VRM animation playback, one mixer, normalized bones" do
    state :committed

    scope "`animationManager.js`, `loadMixamoAnimation.js`,
`kimodoMotionLoader.js`, `vrmMixamoPlaybackGuard.js`,
`viewportExpressionVrm.js`, `studioAnimations.js`"

    attest_in :none

    decision ~S"""
    An `AnimationMixer` track targets a normalized humanoid bone name,
    through `resolveVrmBoneTrackName`, never a raw skeleton bone name.
    Every frame, after `mixer.update(delta)`, call `humanoid.update()`,
    then `vrm.update(delta)`. The mixer root stays `vrm.scene`.

    When `primaryAnimationVrm` is set, `_getActiveAnimationControls()`
    returns VRM controls only. `_silenceOrphanFbxMixer()` stops any
    leftover FBX mixer, on every preset swap and every Kimodo apply. A
    preset swap sets `weightIn=1` and `weightOut=0` on the primary VRM,
    never cross-fade-stacked. A VRM0 upload gets the standard axis flip
    on every bone, legs, shoulders, and arms alike. Skipping the
    shoulder tracks alone twists the arms.

    See `DETAILS.md` for the forbidden-change list, the protected files,
    and the pre-merge test commands.
    """

    problem ~S"""
    A Mixamo FBX preset and a Kimodo motion clip both drive the same
    VRM, through retargeted humanoid bone tracks. Two failure modes kept
    recurring: an orphan FBX mixer layering under the VRM mixer, and a
    mixer track written against a raw skeleton bone name instead of a
    normalized humanoid one. The second failure is silent: the mixer
    time advances, the console logs a loaded clip, and the avatar stays
    frozen, since `humanoid.update()` never sees a bone it does not
    recognize.
    """

    related ~S"""
    RFD 1045 gives the Kimodo model feeding this retarget. RFD 1104
    gives the upload-passthrough policy this path must not disturb.
    """

    details_title "VRM animation playback, one mixer, normalized bones"

    details_preamble ~S"""
    Sourced from `vrm-animation-protected.mdc` (user-confirmed 2026-06-27)
    and `weftspun3d-vrm-animation-playback.mdc`, near-duplicate rules
    this RFD merges into one design.
    """

    details "Retarget sampling", ~S"""
    `withNeutralVrmSceneRootForRetarget` runs only while sampling a
    retarget pose. It restores the scene root afterward. Loot FBX URLs
    stay canonical (`2_Idle.fbx`, not `Idle.fbx`); the mixer will not
    resolve a renamed or relocated file.
    """

    details "Forbidden without an explicit user request", ~S"""
    - Disabling the VRM0 quaternion or vector flip on a passthrough
      upload. This causes buckled knees.
    - Skipping the shoulder tracks (`mixamorigLeftShoulder`,
      `mixamorigRightShoulder`) on passthrough. This causes twisted
      arms.
    - Running the FBX reference mixer alongside the primary VRM mixer.
      This causes layered limbs.
    - A passthrough-only animation shortcut in `loadMixamoAnimation.js`
      or `kimodoMotionLoader.js`, without approval.
    - Reverting `resolveVrmBoneTrackName`, `_getActiveAnimationControls`,
      `_silenceOrphanFbxMixer`, `setAnimationFrameHook`, or
      `syncAnimationPrimaryTarget`, without a replacement in the same
      change.
    - The studio bar loading anything but `LOOT_DEFAULT_ANIMATIONS`;
      `_studioDefaultsLoaded` blocks a trait-manifest overwrite.
    - `normalizeLootAssetUrl` collapsing an `https://` prefix.
    """

    details "Protected files", ~S"""
    `animationManager.js`, `loadMixamoAnimation.js`,
    `kimodoMotionLoader.js`, `viewportExpressionVrm.js`,
    `vrmMixamoPlaybackGuard.js`, `studioAnimations.js`.
    """

    details "Before merging an animation change", ~S"""
    ```bash
    npm run test:run, src/__tests__/loadMixamoAnimation.test.js \
      src/__tests__/animationManager.playback.test.js \
      src/__tests__/kimodoMotionLoader.test.js \
      src/__tests__/vrmMixamoPlaybackGuard.test.js
    npm run test:anim-smoke   # optional; needs a LAN HTTPS dev URL, ?animSmoke=1
    ```

    Re-test by hand too: upload a passthrough VRM, apply the Walking
    preset, then apply a Kimodo motion.
    """

    drafted_by :ai
  end
end
