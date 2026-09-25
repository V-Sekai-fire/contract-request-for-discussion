# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 1084. `mix rfd.render` renders rfd/1084-avatar-pipeline/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD1084 do
  use RFD.DSL

  rfd 1084, "The avatar pipeline, image to downloaded VRM" do
    state :published

    scope "`src/library/avatarPipelineCatalog.js`, `taskManager.js`, `avatarPipelineExport.js`"

    attest_in :none

    decision ~S"""
    State the chain once: a photo goes to `3DAIGC-API`'s mesh-generation
    task, then its template auto-rigging task (`rig_mode: template`),
    landing a rigged GLB in the viewport. `exportAvatarPipelineVrm()`
    then builds a `.vrm` blob client-side and triggers a browser
    download; nothing uploads unless the user mints or saves elsewhere.
    Rig alignment is validated against RFD 1083's contract, checked with
    a `[API-Contract] PASS` log line, and the client applies no
    rig-repair heuristic of its own for `fromAigc` loads — a backward or
    floating rig means re-running after pulling the latest API, not a
    client-side patch.

    See `DETAILS.md` for the task-type table, the blend-shape source
    table, and the key files.
    """

    problem ~S"""
    "Avatar from Image" chains two API jobs (mesh generation, then
    template rigging) and a client-side export step. Nothing stated the
    chain in one place, so "does VRM export upload anywhere" and "why
    does the rig look backward" were open questions each time someone
    hit them.
    """

    related ~S"""
    RFD 1083 gives the rig contract this pipeline validates against.
    RFD 1104 gives the separate, user-uploaded-VRM path this pipeline
    does not use.
    """

    details_title "The avatar pipeline, image to downloaded VRM"

    details "Quick path", ~S"""
    1. Connect to `3DAIGC-API` (DGX).
    2. Task: "Avatar from Image" (mesh plus template VRM).
    3. Upload a photo, wait for the mesh and the template rig.
    4. The viewport loads the rigged GLB.
    5. Optional: "Download VRM after pipeline" saves `*.vrm` through the browser.
    """

    details "What \"VRM export from rigged GLB\" means", ~S"""
    The API returns a rigged GLB. This project's own `VRMExporter` (the
    Save panel, or a post-pipeline hook) builds a `.vrm` blob and
    triggers a browser download. Nothing uploads unless the user mints
    or saves it elsewhere.

    ```
    Photo -> API (TRELLIS) -> GLB
          -> API (template rig) -> rigged GLB
          -> load in viewport
          -> exportAvatarPipelineVrm() -> user downloads avatar.vrm
    ```

    Template expression names can embed in VRM metadata directly. Mesh
    morphs need a wrap step instead (see the API's own
    `MESH_WRAP_ROADMAP.md`).
    """

    details "Task types", ~S"""
    | Task                             | API                                    | Viewport                          |
    | -------------------------------- | -------------------------------------- | --------------------------------- |
    | Image to 3D                      | mesh-generation                        | GLB mesh                          |
    | Auto rigging, template VRM       | auto-rigging, `rig_mode: template`     | Rigged GLB                        |
    | Avatar from image                | mesh plus template rig chain           | Rigged GLB, optional VRM download |
    | Image to Gaussian splat          | splat-generation                       | Spark `SplatMesh`                 |
    | Avatar from image, splat checked | the above, plus TripoSplat in parallel | Body GLB plus splat preview       |
    """

    details "Rig alignment and the contract", ~S"""
    The API's export validates against RFD 1083's contract. After a new
    avatar-from-image job, grep the remote log for `[API-Contract]
    PASS`.

    A backward rig, or one floating at the hips, means re-running after
    pulling the latest API, not a client-side fix. The Blender script
    aligns on Z-up (Blender's own vertical axis after a glTF import),
    not glTF's Y-up. Feet align to the mesh ground, the skeleton is no
    longer inverted (head up, feet down), and this project skips its own
    auto-180°-reorient and rig-repair heuristics for `fromAigc` loads.
    The client validates pre-process and post-viewport-layout only, no
    client-side rig hack.
    """

    details "Blend shape sources", ~S"""
    | Source              | Expressions                                                   |
    | ------------------- | ------------------------------------------------------------- |
    | `template.vrm`      | 124+ morphs, standard blendshape style, on the template's own topology |
    | A rigged AIGC mesh  | Skeleton only, until a wrap step runs                         |
    | Arc2Avatar (future) | FLAME, on head splats                                         |
    | TripoSplat          | Preview only, not a rigged VRM                                |

    XR face tracking needs a wrap or a head-stitch step, tracked in the
    API's own docs.
    """

    details "Uploaded VRM, a separate path", ~S"""
    A user-uploaded `.vrm` file takes a separate path from a rigged GLB
    this pipeline produces. RFD 1104 gives that path (scene-root
    transforms, multi-skin rebind, skeleton visualization, the
    export round-trip).
    """

    details "VRM drag-drop metadata", ~S"""
    `CombinedImport` plus `vrmTemplateMetadata.js`: dragging a `.vrm`
    parses its extensions (`VRM` or `VRMC_vrm`), stores presets in
    `sessionStorage`, and optionally pairs it with a splat preview URL
    (`attachSplatPreviewMetadata`).
    """

    details "Key files", ~S"""
    | File                                   | Role                                                |
    | -------------------------------------- | --------------------------------------------------- |
    | `src/library/avatarPipelineCatalog.js` | Template id, rig modes                              |
    | `src/library/taskManager.js`           | `executeAvatarFromImage`, the template rig API call |
    | `src/library/avatarPipelineExport.js`  | The post-pipeline VRM download                      |
    | `src/library/vrmTemplateMetadata.js`   | VRM file parsing, splat pairing                     |
    | `src/library/sparkSplatManager.js`     | Spark.js splats                                     |
    | `src/components/TaskManager.jsx`       | The UI tasks, the export checkbox                   |
    """

    details "Tests", ~S"""
    ```bash
    node node_modules/vitest/vitest.mjs run src/__tests__/avatarPipelineCatalog.test.js
    src/__tests__/taskManagerTemplateRig.test.js
    ```
    """

    drafted_by :ai
  end
end
