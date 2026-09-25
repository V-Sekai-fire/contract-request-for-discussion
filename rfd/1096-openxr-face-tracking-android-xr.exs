# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 1096. `mix rfd.render` renders rfd/1096-openxr-face-tracking-android-xr/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD1096 do
  use RFD.DSL

  rfd 1096, "OpenXR face tracking, native and web, on Android XR" do
    state :discussion

    scope "`src/library/xrExpressionTrackingDriver.js`, `openxrFaceParameterMap.js`, `native/android-xr-face-bridge/`"

    attest_in :none

    decision ~S"""
    Prefer the Khronos online man pages over any bundled PDF; the PDFs
    in this repository's own `OpenXR/` folder are raster, non-searchable
    scans, useful for diagrams, not for exact API names, and may lag the
    live registry version. `xrCreateFaceTrackerANDROID` and
    `xrGetFaceStateANDROID` fill `XrFaceStateANDROID`'s 68-parameter
    `XrFaceParameterIndicesANDROID` array; the web driver
    (`xrExpressionTrackingDriver.js`) reads either the browser's own
    `XRFrame.expressions`, or a native bridge's relayed weights,
    whichever is fresher, with native weights overriding WebXR's own
    values for that frame when both are present. `XR_ANDROID_face_tracking`
    is Android-only by name; a Quest 3 or Vision Pro session runs the
    `XRFrame.expressions` path alone, through the same driver, with no
    native bridge involved. See `DETAILS.md` for every canonical
    reference link, the payload contract in both its shapes, and the
    mapping-fidelity caveats.
    """

    problem ~S"""
    Two separate paths can drive a VRM's face on Android XR: a browser's
    own draft WebXR `expression-tracking` feature, and native OpenXR's
    `XR_ANDROID_face_tracking`. Neither this project's code nor its
    prior notes named the canonical API references, the exact payload
    shape between the two, or which one wins when both are active.
    """

    related ~S"""
    **Unresolved duplicate:** weftspun-3d-studio's own
    `thirdparty/m3/docs/OPENXR_FACE_TRACKING_ANDROID_XR.md` covers the
    same topic, with real content differences; not yet reconciled. RFD
    1082 gives the companion APK implementing the native side. RFD 1105
    gives the WebXR-only fallback, and RFD 1119 the general hardware
    requirement. The app's own `docs/FACE_EXPRESSION_TUNING_REFERENCE.md`
    holds the numeric tuning baseline, not restated here, per RFD 1000.
    """

    details_title "OpenXR face tracking, native and web, on Android XR"

    details "Local spec copies, and why they are second choice", ~S"""
    `OpenXR/` at the repository root holds PDFs for offline reading,
    including `OpenXR/XR_ANDROID_face_tracking.pdf`,
    `OpenXR/1.0/Wayback/XR_ANDROID_face_tracking OpenXR extension.pdf`,
    and `OpenXR/Open XR 1.1.54 Spec.pdf`. Do not assume a PDF is newer
    than the web registry: Khronos's own man pages track the live
    OpenXR 1.1.x spec (for example, showing Version 1.1.59 while a
    bundled PDF says 1.1.54). In this environment the PDFs are raster,
    not searchable; use the Khronos HTML man pages below for exact API
    names, structs, and enum order, and keep the PDFs only for diagrams.
    """

    details "Canonical online references, preferred for implementation", ~S"""
    Extension: `XR_ANDROID_face_tracking`, instance extension 459,
    revision 1, not ratified, OpenXR 1.0+, at the Khronos registry's own
    man page.

    Core calls and structs: `xrCreateFaceTrackerANDROID`;
    `xrGetFaceStateANDROID` (returns blend weights at a time, filling
    `XrFaceStateANDROID`); `XrFaceTrackerCreateInfoANDROID`;
    `XrFaceStateGetInfoANDROID`; `XrFaceParameterIndicesANDROID` (68
    scalar parameters, indices 0 through 67, then `MAX_ENUM`).

    Android: the "Android XR for OpenXR" extensions hub at
    `developer.android.com`; exact deep-link URLs to a specific
    extension article can move, start from the hub if one 404s.

    Web string keys, for the bridge: the WebXR Expression Tracking
    draft (`index.bs`), whose string keys `inferVRMMorphTargets` reuses
    directly.

    Android permission: `xrCreateFaceTrackerANDROID` requires
    `android.permission.FACE_TRACKING`, a dangerous permission; declare
    it in the manifest and request it at runtime.
    """

    details "Jetpack XR / ARCore face, the Google stack", ~S"""
    Google documents ARCore face tracking for Jetpack XR with
    `FaceTrackingMode.BLEND_SHAPES`, the same style of 68 blend shapes
    as the OpenXR tables above. This project's own wrapper APK
    implements that path in
    `native/android-xr-face-bridge/XrFaceTrackingEngine.kt` (a
    foreground service plus an HTTP relay for Chrome WebXR), forwarding
    weights into `nativeFaceBridge.js`; no raw OpenXR C code is needed
    for that route.
    """

    details "The native OpenXR runtime loop (C API), optional", ~S"""
    1. Enable `XR_ANDROID_face_tracking` on the `XrInstance` or session, per the loader's own
    setup.
    2. `xrCreateFaceTrackerANDROID` returns an `XrFaceTrackerANDROID`.
    3. Each frame, or at 30 or 60 Hz: `xrGetFaceStateANDROID` with `XrFaceStateGetInfoANDROID`,
    filling `XrFaceStateANDROID`.
    4. Read the `parameters` float buffer, capacity `XR_ANDROID_FACE_PARAMETER_COUNT` (68, per the
    current enum). `isValid`, `sampleTime`, and `regionConfidences` are optional extras.
    5. Either map indices to WebXR key names in Kotlin or Java, or send the dense array as
    `openxrParameters` in the JS bridge payload.

    Older drafts or slide decks sometimes name different functions;
    trust the Khronos man pages linked above over any of them.
    """

    details "Web versus native, side by side", ~S"""
    | Path          | Where it runs                       | Feature                                    | Data shape                                           | Implementation                                                                                                                                      |
    | ------------- | ----------------------------------- | ------------------------------------------ | ---------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
    | WebXR         | A Chrome immersive session          | The optional `expression-tracking` feature | `XRFrame.expressions`                                | `src/library/xrExpressionTrackingDriver.js`, `applyXRFrameExpressionsToVRMS`                                                                        |
    | Native bridge | The Android XR host, through OpenXR | `XR_ANDROID_face_tracking`                 | Serialized weights, or an `openxrParameters[]` array | The native app calls `window.__weftspun3dStudioNativeFace.push()`, into `src/library/nativeFaceBridge.js`, into `applyExpressionWeightRecordToVRMS` |

    The index-to-key mapping lives in
    `src/library/openxrFaceParameterMap.js`
    (`OPENXR_ANDROID_FACE_PARAMETER_WEBXR_KEYS`,
    `openxrFloatParametersToWebXRRecord`).

    When both paths are inactive, the avatar's face stays neutral in XR
    (the webcam driver, RFD 1105, is deliberately off during WebXR).
    Precedence: if `getNativeFaceWeightsIfFresh` returns data, it
    overrides WebXR's own `expressions` for that frame, in
    `sceneManager.js`.

    ### Dev relay: Chrome WebXR plus the APK's face data (Galaxy XR)

    When the browser does not grant `expression-tracking`, the Weftspun
    XR Face APK plus the Vite dev relay stand in:

    | Step | Component                                                                                                                                                                                                                       |
    | ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
    | 1    | `npm run dev` on the PC enables `POST /__native_face_ingest` and `GET /__native_face_sse`.                                                                                                                                      |
    | 2    | The APK's Jetpack path, or OpenXR's `XR_ANDROID_face_tracking`, POSTs to that ingest endpoint at roughly 30 Hz. OpenXR uses PBuffer GLES, so ingest continues during Chrome's Full Space when `FaceKeeperActivity` is the host. |
    | 3    | Chrome opens the app with `?nativeFaceRelay=1`; `nativeFaceRelay.js`'s `EventSource` feeds `nativeFaceBridge`.                                                                                                                  |
    | 4    | The XR frame loop uses the native weights, the same as the WebView path. The web side caches for 30 seconds while `xrPresenting`; the APK's own handoff staleness is 10 seconds.                                                |

    RFD 1082 gives the full APK design this relay depends on.
    """

    details "Payload contract, native to web", ~S"""
    Call from Android after obtaining face parameters, in one of two shapes.

    ### Option A: a WebXR-shaped object, preferred for debugging

    The same string keys as the WebXR draft's `XRExpression` enum (for
    example, `jaw_drop`, `eyes_closed_left`); see `index.bs`, and the
    `XRE_KEYS` list in `xrExpressionTrackingDriver.js`.

    ```json
    { "jaw_drop": 0.6, "eyes_closed_left": 0.1, "eyes_closed_right": 0.1 }
    ```

    ```json
    { "weights": { "jaw_drop": 0.6 }, "t": 1735689600000 }
    ```

    ### Option B: a dense OpenXR `parameters` array

    Compact JSON for `xrGetFaceStateANDROID`'s own output: 68 floats, in
    `XrFaceParameterIndicesANDROID` order. The web layer maps this to
    the same keys Option A uses; named keys present in the same payload
    override array slots, for per-shape fixes.

    ```json
    { "openxrParameters": [0, 0, ..., 0.85], "t": 1735689600000 }
    ```

    `jaw_drop` sits at index 24 in the current Khronos enum.

    From Kotlin or Java, through a WebView:

    ```java
    webView.evaluateJavascript(
      "window.__weftspun3dStudioNativeFace.push(" + json + ");",
      null
    );
    ```
    """

    details "Native project scaffold", ~S"""
    A Gradle WebView app lives under `native/android-xr-face-bridge/`:
    Jetpack XR's `XrFaceTrackingEngine` (activity-visible), OpenXR's
    `libcs_openxr_face.so` plus `OpenXrFaceEngine` (a parallel path,
    `openxrParameters` JSON), and `FaceTrackingCoordinator`, which
    starts both and lets the foreground-service watchdog use whichever
    relay age is freshest.
    """

    details "Mapping fidelity", ~S"""
    `inferVRMMorphTargets` (`xrExpressionTrackingDriver.js`) is
    heuristic. OpenXR indices 63 through 67 are tongue shapes in the
    current Khronos enum, mapped to `tongue_out`, `tongue_left`,
    `tongue_right`, `tongue_up`, and `tongue_down` in
    `openxrFaceParameterMap.js` for forward compatibility; mouth
    heuristics may ignore them until an explicit tongue drive is added.

    Once native data is live, compare the runtime weights against the
    Khronos enum table, and adjust the mapping, or add a normalizer in
    the native layer, if a vendor orders parameters differently (which
    should not happen when the spec's own indices are used directly).
    """

    drafted_by :ai
  end
end
