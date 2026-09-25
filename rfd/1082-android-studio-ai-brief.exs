# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 1082. `mix rfd.render` renders rfd/1082-android-studio-ai-brief/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD1082 do
  use RFD.DSL

  rfd 1082, "A companion APK relays face weights past Chrome's own gap" do
    state :discussion

    scope "`native/android-xr-face-bridge/`, `com.weftspun.xrfacebridge`"

    attest_in :none

    decision ~S"""
    A companion APK, `com.weftspun.xrfacebridge`, runs native face
    tracking (Jetpack XR, with OpenXR's `XR_ANDROID_face_tracking` as a
    parallel path per RFD 1096), then POSTs face JSON to the dev PC over
    LAN while the user is inside Chrome WebXR. Chrome loads this
    project's own URL with `?nativeFaceRelay=1`, and applies the
    relayed weights through the same code path native WebView injection
    already uses. This is a development-time workflow; production would
    need real WebXR expressions, a hosted relay, or a native immersive
    host instead.

    See `DETAILS.md` for the end-to-end data flow, the implementation
    status table, the platform constraints, and the test steps.
    """

    problem ~S"""
    Chrome on Android XR does not grant WebXR's `expression-tracking`
    feature, so `XRFrame.expressions` never reaches the web app inside
    an immersive session, and a VRM avatar's face cannot follow the
    user's own face in AR or VR through Chrome alone. This gap is
    specific to Android XR's own Chrome build; a headset whose browser
    grants `expression-tracking` needs no bridge at all.
    """

    related ~S"""
    **Unresolved duplicate:** weftspun-3d-studio's own
    `thirdparty/m3/docs/ANDROID_STUDIO_AI_BRIEF.md` covers the same
    topic, with real content differences. Neither version is
    authoritative; that reconciliation is still open. RFD 1096 gives the
    OpenXR spec this bridge's native path implements. RFD 1105 gives the
    webcam-driven fallback this bridge complements. RFD 1119 gives the
    general hardware requirement this Android-only bridge is one
    enhancement on top of, not a dependency.
    """

    details_title "A companion APK relays face weights past Chrome's own gap"

    details "End-to-end data flow", ~S"""
    ```
    [Galaxy XR headset]
      Weftspun XR Face APK
        Jetpack XR Session + Face (BLEND_SHAPES)  --,
        OpenXR xrGetFaceStateANDROID (parallel)   --+
                                                    v
        FaceHttpRelay -> POST https://<PC_LAN_IP>:3000/__native_face_ingest
                                                    |
    [Dev PC] npm run dev (Vite)                     |
        relay plugin -> SSE /__native_face_sse      |
                                                    v
      Chrome WebXR (immersive AR/VR)
        ?nativeFaceRelay=1 -> nativeFaceBridge.js -> VRM morph targets
    ```

    WebView path, works with no relay: the APK loads this project's own
    URL in a `WebView`, and calls
    `evaluateJavascript("__characterStudioNativeFace.push(...)")`
    directly. `WebView` does not support `navigator.xr`, so AR/VR must
    run in Chrome instead.

    Chrome path, needs the relay: the user opens the app menu, "Open in
    Chrome for WebXR (+ face)." The APK must keep face tracking alive
    while Chrome is foreground, through picture-in-picture,
    `FaceKeeperActivity`, and a foreground service.
    """

    details "FaceKeeperActivity, black-screen guard", ~S"""
    `FaceKeeperActivity` is a transparent 1x1 activity. It keeps the
    Jetpack XR session host alive while Chrome runs WebXR. A missing
    guard below shows the user a black-screen flash on "Open in Chrome
    for WebXR (+ face)."

    `Theme.FaceKeeper`, in `themes.xml`, must keep every one of:
    `windowIsTranslucent` true, `windowBackground` and `colorBackground`
    transparent, `windowNoTitle` true, `windowContentOverlay` null,
    `backgroundDimEnabled` false, `windowDisablePreview` true (this is
    the one that stops the starting-window snapshot flash), and
    `windowAnimationStyle` null. `AndroidManifest.xml` must set this
    theme on `FaceKeeperActivity`.

    In `FaceKeeperActivity.kt`, `onCreate()` and `onResume()` must call
    `finish()` plus `overridePendingTransition(0, 0)` when
    `FaceHandoffState.isChromeHandoff()` is false.
    `FaceKeeperActivity` must never call `setChromeHandoff(true)` itself;
    only `MainActivity`, PiP, or the Chrome flow sets that. `FaceKeeper`'s
    own `acquire()` and `release()` must add
    `Intent.FLAG_ACTIVITY_NO_ANIMATION`, and the caller must call
    `overridePendingTransition(0, 0)` after `startActivity()`.

    `recordRelayPostSuccess()` fires only on a successful HTTP ingest in
    `FaceHttpRelay`, never on a handoff toggle. A cold launcher start
    (`ACTION_MAIN`, `CATEGORY_LAUNCHER`, no saved state) must call
    `clearChromeHandoff()`. `canRestoreHandoffSession(inPiP,
    pausingForChrome)` gates the keeper restore; it returns true only
    when a handoff is active and the app is in PiP or transitioning to
    Chrome.
    """

    details "What is already implemented", ~S"""
    | Area                                                                                     | Status              |
    | ---------------------------------------------------------------------------------------- | ------------------- |
    | Gradle app, WebView shell, dev HTTPS (debug SSL proceed)                                 | Done                |
    | `XrFaceTrackingEngine`, Jetpack `Session`, `Face.getUserFace`, roughly 30 Hz             | Done                |
    | `FaceHttpRelay`, an OkHttp POST to `/__native_face_ingest`                               | Done                |
    | `FaceBridgeForegroundService` plus notification                                          | Done                |
    | `FaceKeeper`/`FaceKeeperActivity`, a transparent 1x1 host during the Chrome handoff      | Done                |
    | `FaceHandoffState`, `SharedPreferences` for `chromeHandoff`, a 30-second stale threshold | Done                |
    | `FaceTrackingCoordinator`, Jetpack plus OpenXR, picks the freshest `lastPostAgeMs()`     | Done                |
    | OpenXR native (`libcs_openxr_face.so`, `OpenXrFaceEngine`, GLES/PBuffer Phase 1b)        | Scaffolded, partial |
    | Permissions: `FACE_TRACKING`, notifications, camera, audio for WebView                   | Done                |
    | Web side: `nativeFaceBridge.js`, `nativeFaceRelay.js`, a Vite plugin, tests              | Done                |

    ### Payload contract, the JSON POST body

    Preferred: WebXR-style keys, `{ "weights": { "jaw_drop": 0.6, ... },
    "t": <epochMs> }`. Or a dense array: `{ "openxrParameters": [68
    floats], "t": ... }`, in the Khronos
    `XrFaceParameterIndicesANDROID` order. The web side maps this
    through `src/library/openxrFaceParameterMap.js` into
    `applyExpressionWeightRecordToVRMS`, in
    `src/library/xrExpressionTrackingDriver.js`. RFD 1096 gives the full
    spec.
    """

    details "Status after a May 2026 rebuild (verify on device)", ~S"""
    | Mode                             | Behavior before the fix                             | Expected after                                                              |
    | -------------------------------- | --------------------------------------------------- | --------------------------------------------------------------------------- |
    | Flat Chrome or WebView           | Works: `nativeKeys` 25, 42                          | Unchanged                                                                   |
    | Chrome immersive AR (Full Space) | Relay stale, `nativeKeys=0`, Jetpack `not TRACKING` | The OpenXR PBuffer path plus `FaceKeeperActivity` host; Jetpack as fallback |

    ### Implemented that same pass

    1. Headless OpenXR (Phase 1b): `openxr_face_engine.cpp` prefers PBuffer EGL;
    `OpenXrFaceEngine.tryStartNative` needs no `TextureView` or `surfaceReady`.
    2. Chrome handoff: `FaceKeeperActivity.onResume` calls `setActivity`, `setSessionHost`,
    `ensureFacePipeline("keeper-onResume")`.
    3. Coordinator: `OpenXrFaceEngine.ensureFacePipeline` always runs; Jetpack also runs when
    `!OpenXrFaceEngine.isCollecting()` or `chromeHandoff`.
    4. Watchdog and recycle: `CHROME_HANDOFF_STALE_MS` is 10 seconds. A forced recycle happens
    when the relay stays quiet twice that threshold (roughly 20 seconds), even if the collector
    still ticks; `COLLECTOR_STUCK_CHROME_MS` is 20 seconds.
    5. Foreground service type: `dataSync|camera|microphone` (the microphone type gated to API
    34+); the manifest declares `FOREGROUND_SERVICE_MICROPHONE`.
    6. Handoff expiry: a restored handoff only applies if the last successful relay ingest was
    under 60 seconds ago. A cold launcher start clears the handoff; `FaceKeeperActivity` finishes
    if the handoff flag is false.

    ### Known gaps, not fully fixed

    | Issue                                                 | Detail                                                                                                                                                                                      |
    | ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
    | Web-versus-APK stale mismatch                         | The web side holds the last weights for 30 seconds while `xrPresenting`; the APK's own handoff staleness is 10 seconds, intentionally, trading UI stability against faster recovery.        |
    | Jetpack and OpenXR running in parallel during handoff | The coordinator can still start Jetpack while `chromeHandoff` is set, even when OpenXR is already collecting, which can compete for GLES on Galaxy XR; watch logcat for session failures.   |
    | The foreground-service `microphone` type              | Declared only for process priority; face tracking itself does not use the microphone. Add it only if the WebView/foreground path actually records audio, or a store policy may question it. |
    | A prior assistant summary's typo                      | It claimed "1.5x stale = 15s"; the code actually uses 2x `effectiveStaleMs()`, roughly 20 seconds, during handoff.                                                                          |
    | `OpenXrFaceEngine.kt`                                 | `setSurface` still only nudges the pipeline when `surfaceReady`; the headless path runs through `ensureFacePipeline` with no surface, which is correct.                                     |

    ### Success criteria, on a re-test after rebuild

    In Chrome AR: `nativeKeys > 25`, `relay=poll+sse/<500ms`, sustained
    while `xrPresenting=true` (live ingest, not a frozen cache). Logcat
    shows `ON-OpenXrFace` "OpenXR GLES face started" or "First OpenXR
    face push", or `ON-JetpackFace` "TRACKING" plus `ON-FaceHttpRelay`
    posts.
    """

    details "Key files to open first", ~S"""
    | File                                            | Role                                                                                           |
    | ----------------------------------------------- | ---------------------------------------------------------------------------------------------- |
    | `MainActivity.kt`                               | WebView, permissions, the Chrome-handoff menu item, picture-in-picture, FaceKeeper get/release |
    | `XrFaceTrackingEngine.kt`                       | The Jetpack face-collect loop, `FaceHttpRelay.post`, watchdog and recycle logic                |
    | `FaceKeeper.kt` / `FaceKeeperActivity.kt`       | The session host while Chrome runs in XR                                                       |
    | `FaceHandoffState.kt`                           | The persistent Chrome-handoff flag                                                             |
    | `FaceBridgeForegroundService.kt`                | The foreground service, keeper restart, reconfigure on a stale relay                           |
    | `FaceTrackingCoordinator.kt`                    | Starts and stops Jetpack plus OpenXR                                                           |
    | `FaceHttpRelay.kt`                              | The LAN POST to the dev server                                                                 |
    | `OpenXrFaceEngine.kt` plus `app/src/main/cpp/*` | OpenXR 1.0.x, `XR_ANDROID_face_tracking`, the GLES binding                                     |
    | `FaceBlendShapeMaps.kt`                         | The Jetpack-to-WebXR key mapping                                                               |
    | `AndroidXrBridgeInterface.kt`                   | The JS-facing `AndroidXRBridge.onBridgeReady()`                                                |

    Log tags: `ON-JetpackFace`, `ON-FaceKeeper`, `ON-FaceBridgeSvc`,
    `ON-FaceHttpRelay`, `ON-OpenXrNative`, `ON-XR-WebView`.
    """

    details "Platform constraints, do not violate", ~S"""
    1. WebView is not WebXR; never attempt immersive XR inside WebView. Chrome only, for AR or VR.
    2. The Galaxy XR OpenXR runtime accepts API 1.0.x only (1.1 is rejected: "Max supported
    version is 1.0.34").
    3. `android.permission.FACE_TRACKING` is required before `xrCreateFaceTrackerANDROID`.
    4. Chrome cannot share an OpenXR session with this APK; a headless, separate OpenXR instance
    is the intended Phase 1b approach.
    5. The dev URL comes from `local.properties`: `weftspun3dStudio.url=https://<PC_LAN_IP>:3000/`
    (the legacy alias `characterStudio.url` still works). The PC runs `npm run dev --host`, and
    the firewall allows TCP 3000.
    6. HTTPS: debug builds trust dev certificates for the relay POST; a release build must never
    blindly `proceed()` on an SSL error.
    """

    details "Follow-up tasks, if Full Space AR still fails", ~S"""
    1. Verify OpenXR actually posts in AR: check logcat's `ON-OpenXrFace` tag, or a remote-log
    `faceSrc=openxr` / payload `"source":"openxr"`.
    2. Reduce Jetpack/OpenXR contention: consider running Jetpack only when
    `!OpenXrFaceEngine.isCollecting()` during handoff (today, Jetpack always runs on handoff).
    3. Confirm the `FACE_TRACKING` runtime permission is granted before
    `xrCreateFaceTrackerANDROID` runs.
    4. If a future Google release documents face data reaching Chrome WebXR without a relay,
    prefer that path for production.

    Do not remove the HTTP relay without a Chrome replacement ready. Do
    not break WebView's `evaluateJavascript` path. Never commit a secret
    or a LAN IP into source.
    """

    details "How to test", ~S"""
    1. On the PC: `npm run dev`, then open `https://<PC_IP>:3000/?remoteLog=1&nativeFaceRelay=1`.
    2. Install the debug APK; grant face, notification, and camera permissions.
    3. Open the app, load the site, then the menu's "Open in Chrome for WebXR (+ face)".
    4. Keep the Weftspun XR Face app visible, or its picture-in-picture bubble, in Home Space.
    5. Enter AR in Chrome; watch the PC's `logs/remote-log.txt` for `[ON-NATIVE-FACE-DIAG]
    nativeKeys=… relay=… xrPresenting=…`.
    6. Use `adb logcat` with the tags above, or this repository's own
    `scripts/capture-apk-logcat.ps1`.
    """

    details "Related web repository paths", ~S"""
    | Path                              | Role                                                       |
    | --------------------------------- | ---------------------------------------------------------- |
    | `src/library/nativeFaceBridge.js` | Consumes native weights                                    |
    | `src/library/nativeFaceRelay.js`  | Chrome-side SSE/poll from the dev server                   |
    | `vite.config.js`                  | The `__native_face_ingest` and `__native_face_sse` plugins |
    | RFD 1096                          | Spec links, the payload contract                           |
    | RFD 1105                          | WebXR expression notes, remote logging                     |
    """

    details "One-sentence summary", ~S"""
    Keep Jetpack XR, and optionally OpenXR's `XR_ANDROID_face_tracking`,
    posting roughly 30 Hz of face blend shapes to a LAN HTTP relay while
    Chrome runs Full Space WebXR, because Chrome does not expose
    `expression-tracking` and WebView cannot run WebXR at all.
    """

    drafted_by :ai
  end
end
