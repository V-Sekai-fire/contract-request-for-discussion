# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 1104. `mix rfd.render` renders rfd/1104-vrm-upload-display-export/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD1104 do
  use RFD.DSL

  rfd 1104, "Uploaded VRM, rotate the scene root, never the hips" do
    state :committed

    scope "`src/library/vrmLoader.js`, `rigBoneUtils.js`, `VRMExporter.js`"

    attest_in :none

    decision ~S"""
    Rotate `vrm.scene`, the root, never the hips or the armature alone.
    Skip AIGC rig repair entirely when `userData.vrmNormalized` is set.
    Build the skeleton overlay from the primary skinned mesh, not from
    humanoid `Normalized_*` nodes. Yaw on export only when the model's
    world-forward direction actually needs it
    (`getWorldDirection().z > 0.5`), never an unconditional
    `rotateY(π)`. `processModel` early-returns for any VRM or
    `vrmBindPassthrough` model: no autoscale, no AIGC yaw repair.

    See `DETAILS.md` for the passthrough policy, the display-path rules,
    the export-path steps, the implementation map, and the retest
    checklist.
    """

    problem ~S"""
    This project once mutated an uploaded `.vrm` after load, instead of
    rendering it as-is: rotating the armature or hips alone, running
    AIGC rig-repair on it, and always yawing on export. On a VRM0
    UniGLTF multi-skin file (each of body, head, eyes, cornea, hair
    carrying its own skin index, bones as scene siblings), rotating only
    the armature moves bone world matrices relative to the mesh nodes it
    does not touch, drifting the bind worst at the eyes and finger
    extremities.
    """

    related ~S"""
    RFD 1083 gives the AIGC rig contract this upload path deliberately
    does not run. RFD 1084 gives the avatar pipeline that path serves
    instead.
    """

    details_title "Uploaded VRM, rotate the scene root, never the hips"

    details "The problem, in one table", ~S"""
    | Wrong, breaks eyes or fingers                                           | Right                                                          |
    | ----------------------------------------------------------------------- | -------------------------------------------------------------- |
    | Rotate the hips or armature only                                        | Rotate `vrm.scene`, the root, only                             |
    | Run AIGC rig repair (`alignSkinnedMeshToRig`, skeleton display offsets) | Skip repair when `userData.vrmNormalized` is set               |
    | Build skeleton visualization from humanoid `Normalized_*` nodes         | Build it from the primary skinned mesh (`AvatarBody` skeleton) |
    | Always export with `rotateY(π)`                                         | Yaw only when `getWorldDirection().z > 0.5`                    |

    Reference pattern this project follows (this project's own earlier
    code, and `@pixiv/three-vrm`): `VRMUtils.rotateVRM0` adds
    `scene.rotation.y += Math.PI` only when needed;
    `src/library/load-utils.js`'s `loadVRM()` rotates the scene root,
    not the hips; `src/library/modelOrientationUtils.js`'s
    `applyVrm0SceneForwardFix(scene)` applies the same fix.
    """

    details "Upload path", ~S"""
    Entry: drag-drop or the file picker, into `SceneManager.loadVRM`,
    into `VRMLoader.processVRM` with `passthrough: true`.

    Passthrough policy, uploads only:

    1. Facing (VRM0): `applyVrm0SceneForwardFix(vrm.scene)`, on the scene root only, when
    `forward.z > 0.5`.
    2. Flags: set `vrm.scene.userData.vrmNormalized = true` and
    `vrm.scene.userData.vrmBindPassthrough = true`.
    3. No scale, center, floor snap, rebind, bone rename, or AIGC rig repair on upload.

    Log line: `[VRM] Upload passthrough, scene yaw only if needed; no
    scale/rebind/rename`.

    `processModel` must early-return for a VRM or a
    `vrmBindPassthrough` model: no autoscale, no AIGC yaw repair. Never
    call `validateAigcRigContract` or `normalizeRiggedModelTransforms`
    repair paths on an uploaded VRM.

    ### Remote log check (`?remoteLog=1`, writes `logs/remote-log.txt`)

    After a re-upload, grep for:

    ```
    [VRM] Multi-skin layout after normalize
    rotated scene root (all skins move together)
    ```

    Regression signals, meaning the bug returned:

    ```
    rotated armature via hips parent
    VRM0 normalization: rotated model to face camera { beforeZ: 1, afterZ: -1 }
    Processing bone … Normalized_Hips
    ```
    """

    details "Display path", ~S"""
    | Concern                           | Rule                                                                                                                   |
    | --------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
    | Skeleton overlay                  | `getPrimarySkeletonBones(modelRoot)`, from the primary skinned mesh                                                    |
    | Joint gizmos                      | A fixed, uniform `SKELETON_JOINT_SPHERE_RADIUS` (0.012), `depthTest: false` overlay                                    |
    | Bone gizmo position               | `getBoneDisplayWorldPosition`; no AIGC display offset when `userData.vrm` or `vrmNormalized`                           |
    | `updateSkeletonDisplayCorrection` | Skipped for an uploaded VRM                                                                                            |
    | Trait or loot load                | `characterManager`, `vrmManager`, `load-utils`: the same scene-root forward fix and rebind, never a hips-only rotation |
    """

    details "Export path", ~S"""
    Entry: the Save panel, `VRMExporter.exportToVRM`, or
    `SceneManager.exportToVRM`.

    1. Rebind skinned meshes before the glTF parse, when `userData.vrm` or `vrmNormalized` is set.
    2. Yaw only if the model's world-forward has `z > 0.5`, the same rule as upload; never a blind
    `rotateY(π)` on an already-correct upload.
    3. Strip internal flags from the exported GLB: `vrmNormalized`, `preserveExportedOrientation`,
    `fromAigc`, and so on (`glbExportUtils.stripInternalExportUserData`).
    4. Restore the viewport quaternion after export, if a temporary yaw was applied.

    Round-trip test: export a multi-skin reference model, re-import it,
    and confirm the eyes and finger bones still align in skeleton mode.
    """

    details "Implementation map", ~S"""
    | Area                              | File                                                                |
    | --------------------------------- | ------------------------------------------------------------------- |
    | Upload normalize                  | `src/library/vrmLoader.js`, `processVRM` with `passthrough: true`   |
    | Forward fix                       | `src/library/modelOrientationUtils.js`, `applyVrm0SceneForwardFix`  |
    | Rebind and skeleton visualization | `src/library/rigBoneUtils.js`                                       |
    | Skip AIGC `processModel`          | `src/library/sceneManager.js`, `processModel`                       |
    | Trait or loot load                | `src/library/characterManager.js`, `vrmManager.js`, `load-utils.js` |
    | Export                            | `src/library/VRMExporter.js`, `glbExportUtils.js`                   |
    | The VRM-versus-AIGC contract      | RFD 1083                                                            |
    | Tests                             | `src/__tests__/rigBoneUtils.test.js`                                |
    """

    details "Retest checklist", ~S"""
    1. Hard refresh the dev tab (`Ctrl+Shift+R`).
    2. Upload a multi-skin VRM0 reference model.
    3. Grep the remote log for `[VRM] Multi-skin layout` and the scene-root rotation line.
    4. Solid mode: textures correct. Skeleton mode: eye bones on the eye mesh, finger joints on
    the finger mesh.
    5. Export the VRM, re-import it, confirm the same alignment.
    """

    drafted_by :ai
  end
end
