# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 1061. `mix rfd.render` renders rfd/1061-glb-upload-prep-via-idtx-core/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD1061 do
  use RFD.DSL

  rfd 1061, "GLB upload prep moves to idtx_core, later" do
    state :discussion

    scope "`thirdparty/3d_studio/src/library/glbCompress.js`, `thirdparty/fabric-flow-adapters/`"

    attest_in :none

    decision ~S"""
    The upload-prep job belongs on `idtx_core`'s USD-native transport,
    not on a second bespoke GLB pipeline in JavaScript.
    `thirdparty/fabric-flow-adapters/flow/` already carries what that
    job needs, and this repository's browser compression does not.

    None of that is reachable from a browser today. See `DETAILS.md` for
    what `idtx_core` carries, the three steps to reach it, the interim
    stopgap in `glbCompress.js`, and a bug that stopgap's tests surfaced.
    """

    problem ~S"""
    `__tests__/prepareGlbForApiUpload.test.js` tested two functions,
    `computeApiUploadSimplifyRatio` and `prepareGlbForApiUpload`, that
    `glbCompress.js` never defined. `TaskManager.jsx`'s skintokens
    auto-rig path imports `prepareGlbForApiUpload` at line 1163 and
    awaits it, and the import threw since whenever that call site was
    written. RFD 1023 first recorded this gap, and it stayed open
    through RFD 1060's move.

    The mesh a browser uploads today is prepared by `compressGlbBuffer`
    in the same file, over `gltf-transform`: client-side Draco, Meshopt,
    and WebP. RFD 1053 makes OpenUSD the internal format, the way
    `.blend` is internal to Blender, and it names glTF only a
    transmission format, converted at the boundary. GLB, Draco, and WebP
    belong at that boundary. They do not belong as the mesh-prep
    pipeline itself, which is what `compressGlbBuffer` is today.
    """

    related ~S"""
    RFD 1023 first recorded the `prepareGlbForApiUpload` gap. RFD 1053
    selects OpenUSD as the internal format this RFD defends. RFD 1057
    tracks open work of this shape.
    """

    details_title "GLB upload prep moves to idtx_core, later"

    details_preamble ~S"""
    `thirdparty/fabric-stage-runtime/` and `thirdparty/fabric-flow-adapters/`
    are vendored as git subtrees, at `main` and `main-fabric`
    respectively.
    """

    details "What idtx_core carries that browser compression does not", ~S"""
    `thirdparty/fabric-flow-adapters/flow/` already carries three things
    this repository's browser compression lacks.

    - **Content-defined chunking**, casync-compatible, SHA-512/256 chunk
      IDs (`idtx_chunker.h`). Two uploads of the same mesh, or two
      revisions that share most of their geometry, share most of their
      chunks. Nothing here gets resent.
    - **USD-native mesh and VRM handling** (`idtx_import_usd.cpp`,
      `idtx_export_usd.cpp`, `idtx_vrm.cpp`), which composes with RFD
      1053's decision to make OpenUSD the internal format instead of
      round-tripping GLB at every stage.
    - **AES + zstd transport** (`idtx_aes.cpp`, `idtx_transport.cpp`)
      already built for exactly this shape of problem. The same
      chunker/transport pair backs `multiplayer-fabric-godot`'s asset
      streaming.
    """

    details "Why none of this is reachable yet", ~S"""
    `flow/adapters/` holds three hosts: `godot/` (GDExtension), `unity/`
    (P/Invoke), and `cli/`. It holds no fourth. Getting there needs:

    1. An Elixir NIF (or Rustler-style binding) linking `idtx_core`
       through the ports it already exposes
       (`flow/ports/include/idtx_core/`), built against the OpenUSD
       `fabric-stage-runtime` already ships as `{:stage_runtime, "~>
    0.1.0-dev"}`. RFD 1053 already commits `weftspun_studio` to
       linking that build.
    2. A `weftspun_studio` API route the browser uploads to, instead of
       whatever `image_to_textured_mesh`-style route it POSTs a GLB to
       today.
    3. The browser call site swapped from `compressGlbBuffer` /
       `prepareGlbForApiUpload` to that route.

    This RFD records the target and stops there. Building the NIF, the
    port, the adapter, and the route is its own multi-session scope. It
    is RFD 1057-style open work, not a task this RFD's Decision closes.
    """

    details "The interim stopgap, in `glbCompress.js` today", ~S"""
    This stopgap works in GLB, against RFD 1053's own rule that GLB
    stays a transmission format and never the working format. It exists
    only to unblock the failing test and the throwing import, until the
    NIF adapter lets this path move to USD-native handling instead.

    Two functions now exist, so the test the gap left red passes and
    `TaskManager.jsx`'s import resolves.

    `computeApiUploadSimplifyRatio(sourceVerts, sourceFaces, maxVertices, maxFaces, headroom =
    0.85)`
    gives the fraction of the _current_ mesh to keep, driven by whichever
    cap (verts or faces) needs the deeper cut. It returns `1` when both
    are already under cap.

    `prepareGlbForApiUpload(arrayBuffer, { maxVertices, maxFaces })`
    passes a buffer through unchanged when it fits. Otherwise it `weld`s,
    then loops `simplify` plus `dedup` plus `prune`, up to 5 passes.
    Each pass re-measures against the cap, since `simplify`'s ratio is
    relative to the current triangle count and not the source. It throws
    if a rigged mesh (joints, weights, or morph targets, per
    `documentNeedsSafeMode`) stays over the cap, since decimation skips a
    rig to protect it. `TaskManager.jsx`'s call site relies on that throw
    to drive its "too dense to auto-rig" warning.

    Both are `gltf-transform` over the same `getIO()` pipeline
    `compressGlbBuffer` already uses in this file. Nothing here is a
    step toward the `idtx_core` path. Replace this whole block, and do
    not extend it, once the NIF adapter exists.
    """

    details "A bug this surfaced, unrelated to either path", ~S"""
    `documentNeedsSafeMode` called `mesh.listTargets()`. Morph targets
    live on `Primitive` in the installed `@gltf-transform/core`, not on
    `Mesh`. `listTargets()` does not exist there, and every real call to
    this function threw `TypeError: mesh.listTargets is not a function`.
    `compressGlbBuffer` calls it unconditionally.

    This broke the main compression path too, on every document with at
    least one mesh, for as long as the check existed. No test exercised
    either function against a real document until this RFD's test run
    found it. Fixed: iterate primitives, and call `listTargets()` on
    each.
    """

    drafted_by :ai
  end
end
