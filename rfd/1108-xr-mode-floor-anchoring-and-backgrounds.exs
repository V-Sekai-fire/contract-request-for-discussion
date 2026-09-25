# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 1108. `mix rfd.render` renders rfd/1108-xr-mode-floor-anchoring-and-backgrounds/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD1108 do
  use RFD.DSL

  rfd 1108, "Floor-anchor in both AR and VR, opaque sky only in VR" do
    state :committed

    scope "`src/library/sceneManager.js`, `enableVR()`, `initialize()`"

    attest_in :none

    decision ~S"""
    One unified `renderer.xr.setSession` override in `enableVR()`
    handles both session types. Reference spaces request in this order:
    `bounded-floor` (Galaxy XR's own boundary-calibrated floor level),
    `local-floor`, `local`, `viewer`; `bounded-floor` needs no manual
    floor-height code, since WebXR itself gives a floor-aligned origin.
    On entering either mode, an XR wrapper group holding only model
    content gets `x=0`, `z=-0.5`, and `y` set to the negative of the
    model's own bounding-box bottom, aligning that bottom to Y=0.
    AR keeps `scene.background = null` and a zero clear alpha, never
    letting a sky texture loader re-apply itself; VR keeps an opaque
    clear alpha and a mesh-based sky, since some runtimes handle
    `scene.background` alone unreliably. A background snapshot, captured
    before any session starts, restores exactly on AR exit.

    See `DETAILS.md` for the exact wrapper math, the snapshot fields,
    wrapper re-centering (including the long-press software recenter
    gesture), and the troubleshooting checklist.
    """

    problem ~S"""
    AR needs a transparent renderer so the camera feed shows through;
    VR needs an opaque sky. Both need the same model bottom-aligned to
    the physical or virtual floor, at the same wrapper position. A
    texture loader re-applying a stored sky to `scene.background` during
    AR, or a runtime reporting `floorAlignmentY: 1` instead of near
    zero, are the two regressions this area kept reintroducing.
    """

    related ~S"""
    **Unresolved duplicate:** weftspun-3d-studio's own
    `thirdparty/m3/docs/XR_MODE_FLOOR_ANCHORING_AND_BACKGROUNDS.md`
    covers the same topic, with real differences; neither is
    authoritative. RFD 1090 gives the IWSDK lab this file's own XR path runs beside.
    """

    details_title "Floor-anchor in both AR and VR, opaque sky only in VR"

    details "Current correct behavior, by mode", ~S"""
    VR mode uses a virtual sky background (the app's own sky image),
    opaque, no pass-through; scene content stays floor-anchored through
    a floor-aligned reference space.

    AR mode uses video pass-through, the physical world visible; the
    renderer must be transparent and `scene.background` must be null so
    the camera feed shows through. Scene content stays floor-anchored
    the same way VR's does.

    Positioning, in both modes: X is always 0 for the XR scene wrapper
    (centered); Z is -0.5 (content sits slightly in front of the user);
    Y computes from the model's own bounding box, so its bottom aligns
    with floor level (Y=0) in a floor-aligned space.
    """

    details "Implementation location", ~S"""
    Primary file: `src/library/sceneManager.js`. `initialize()` creates
    the renderer with `alpha: true`, required for AR transparency.
    `enableVR()` installs one unified `renderer.xr.setSession` override
    that handles both VR and AR sessions.
    """

    details "Reference space priority", ~S"""
    Requested in this order: `bounded-floor` (preferred on Android XR
    and Galaxy XR), `local-floor`, `local`, `viewer`.

    On Galaxy XR, `bounded-floor` uses the device's own boundaries
    floor-level calibration (Settings, XR, Boundaries, Adjust Floor
    Level); inside `bounded-floor`, Y=0 corresponds to the physical
    floor level the user configured. No manual "floor height" code is
    needed at all; WebXR itself provides a floor-aligned origin.
    """

    details "Floor anchoring, model bottom to Y=0", ~S"""
    On entering either VR or AR:

    1. Create an XR wrapper group (`VRSceneWrapper` or `ARSceneWrapper`) holding only model
    content, never lights, cameras, or helpers.
    2. Compute the model's bounding box and its bottom: `modelBottomY = boundingBox.min.y`.
    3. Compute the floor alignment: `floorAlignmentY = -modelBottomY`.
    4. Set the wrapper's position: `x = 0`, `y = floorAlignmentY`, `z = -0.5`.

    This aligns the model's bottom to Y=0 in the chosen reference space,
    the physical floor when that space is floor-aligned.
    """

    details "AR pass-through, keeping the physical background visible", ~S"""
    AR must keep the scene transparent: `scene.background = null`,
    `renderer.setClearColor(0x000000, 0)`, and
    `renderer.domElement.style.background = 'transparent'`.

    A sky texture can still load and stay stored for VR's own later use,
    but AR must never re-apply it to `scene.background`. In AR,
    `scene.environment` may optionally hold a texture for lighting,
    while `scene.background` stays null.

    ### Background snapshot and restore

    To return the viewer to the exact same sky orientation after
    exiting AR, the app captures a full snapshot of the background state
    before any XR session starts: for a texture, `{ textureRef, mapping,
    colorSpace, flipY, needsUpdate }`; for a color, a cloned
    `THREE.Color` instance; for null, `{ type: 'null', value: null }`.

    On AR exit (`handleXRSessionEnd('ar')`), the snapshot restores
    exactly as captured, including every texture property, so the sky
    never appears flipped or misoriented afterward. The snapshot is
    captured inside the unified `setSession` override, before any
    XR-specific background change happens, stored in
    `this.preXRBackgroundSnapshot`, and cleared once restored.
    """

    details "VR background, the sky in immersive VR", ~S"""
    Some WebXR immersive VR runtimes handle `scene.background` alone
    unreliably. The reliable approach: keep an opaque clear alpha
    (`renderer.getClearAlpha() === 1`), and use a mesh-based sky (a
    large sphere or skybox mesh) mapped with the sky texture, rendered
    behind everything else.
    """

    details "Wrapper centering, X = 0", ~S"""
    The XR wrapper's X must stay centered: whenever its position is set,
    `x=0`. In AR, the wrapper is anchored, and restored to `x=0` if it
    drifts; in VR, the render loop enforces
    `VRSceneWrapper.position.x === 0` as a safety guard.

    ### Auto-centering on session start

    On XR session start, the app auto-centers the reference space once,
    on the first XR frame, so the viewer starts at X=0 relative to the
    app's own world grid. This avoids a common issue on some runtimes:
    starting a few grid squares left or right of center.

    ### Software recenter, a long-press gesture

    A software-based recenter, through a long-press gesture on an XR
    input source (a controller or headset touchpad), is a fallback for
    when platform-level recenter (a Home button) does not affect the
    app.

    Implementation: hold-tracking uses a `WeakMap` keyed by the stable
    `XRSpace` object (`inputSource.targetRaySpace`), not the
    `XRInputSource` object reference itself, so tracking survives even
    when `session.inputSources` yields a different object instance than
    `event.inputSource`. The long-press threshold is 900ms. Supported
    inputs: `selectstart`/`selectend` events (for a headset or
    controller with no gamepad API), and a gamepad button long-press
    (through its `pressed` or `touched` state), with button indices
    chosen heuristically from the input source's own profile and
    handedness. A 1.5-second cooldown between triggers prevents a repeat
    while the button stays held.

    Platform recenter support: the app also listens for the XR reference
    space's own `reset` event, fired by a platform-level recenter (a
    Home button, for instance). On reset, the auto-center flag clears,
    so the next XR frame re-runs auto-centering and returns the view to
    X=0.

    ### XR input diagnostics

    Enable diagnostic logging with the `?xrDebugInputs=1` query
    parameter. Throttled to once per second, it logs input-source
    profiles and handedness, the gamepad's own button count, and which
    button indices currently read `pressed` or `touched`. This helps
    identify which buttons or events a given headset or controller
    actually exposes for a recenter gesture.
    """

    details "Troubleshooting checklist", ~S"""
    AR shows the sky, not the physical world: confirm
    `scene.background === null`, `renderer.getClearAlpha() === 0`, and
    that the canvas's own CSS background is transparent. If AR still
    shows a sky, a texture loader may be re-setting `scene.background`,
    or the renderer may have been created with `alpha:false` (it must be
    `alpha:true` at creation time).

    VR shows a black background: confirm
    `renderer.getClearAlpha() === 1`, confirm a sky mesh exists (for a
    mesh-based sky), and confirm the texture has actually loaded
    (`texture.image.complete === true`).
    """

    drafted_by :ai
  end
end
