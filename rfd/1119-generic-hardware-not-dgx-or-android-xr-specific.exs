# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 1119. `mix rfd.render` renders rfd/1119-generic-hardware-not-dgx-or-android-xr-specific/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD1119 do
  use RFD.DSL

  rfd 1119, "Target hardware stays generic" do
    state :discussion

    scope "the backend GPU host, the XR headset target"

    attest_in :none

    decision ~S"""
    The backend (`3DAIGC-API`) runs on any machine with a CUDA GPU. The
    DGX Spark is this project's own reference machine, not a
    requirement; RFD 1027's memory budget, not a DGX-specific spec,
    decides whether a GPU fits the loaded models.

    The client runs in any WebXR-capable browser, on any headset that
    supports it. Quest 3 and Apple Vision Pro reach the dev URL the same
    way Galaxy XR does, through `enableVR()` or `enableAR()`, per RFD 1010. Android XR's own
    native face-tracking bridge (RFD 1082, RFD 1096) stays Android-specific, since it calls an
    Android-only OpenXR
    extension. That path is a Galaxy-XR enhancement, not a requirement
    for XR elsewhere. A headset without it still gets VR, AR, floor
    anchoring, and the WebXR-native `expression-tracking` feature where
    the browser grants it.

    See `DETAILS.md` for the affected RFDs.
    """

    problem ~S"""
    Several RFDs name one specific machine, the DGX Spark, and one
    specific headset line, Android XR (Galaxy XR), as if the project
    needed that exact hardware. Neither dependency is real. The backend
    needs a CUDA GPU with enough VRAM for the loaded models. The client
    needs a WebXR-capable browser. A reader who owns a 4090 desktop, a
    Quest 3, or an Apple Vision Pro should not read those RFDs as
    requirements they fail to meet.
    """

    related ~S"""
    RFD 1027 gives the GPU memory budget that replaces "runs on a DGX
    Spark" as the real constraint. RFD 1010 gives the WebXR session
    modes every supported headset shares. RFD 1082 and RFD 1096 give the
    Android-specific enhancement this decision does not remove.
    """

    details_title "Target hardware stays generic"

    details_preamble ~S"""
    35 RFDs name DGX Spark, Android XR, or Galaxy XR. Each falls into
    one of three groups.
    """

    details "Group A: built around that one machine or headset", ~S"""
    Rewriting these replaces the specific name with the general
    requirement, keeping the specific name as one example.

    | RFD  | What it assumes                                                               | Status                                                    |
    | ---- | ----------------------------------------------------------------------------- | --------------------------------------------------------- |
    | 0086 | Dev machine topology names the DGX Spark and a Surface PC as the two machines | Generalized this session                                  |
    | 0095 | "A voice XR path... on the DGX Spark"                                         | Generalized this session                                  |
    | 0099 | Scripts cheatsheet, 77 DGX-path references, a real runbook for one deployment | Pointer note added; full rewrite still open               |
    | 0090 | Galaxy XR named in the title; state is abandoned                              | Deferred; abandoned RFDs are not this decision's priority |
    """

    details "Group B: Android-specific by real technical necessity, not choice", ~S"""
    These do not generalize away. The feature itself is an Android-only
    OS or OpenXR extension. The fix is to state that boundary clearly,
    not to pretend the feature runs elsewhere.

    | RFD  | The real boundary                                                                                                          | Status                 |
    | ---- | -------------------------------------------------------------------------------------------------------------------------- | ---------------------- |
    | 0082 | The companion APK is an Android app; native face relay needs Android                                                       | Clarified this session |
    | 0096 | `XR_ANDROID_face_tracking` is an Android OpenXR extension by name                                                          | Clarified this session |
    | 0108 | Floor-anchor code path is headset-agnostic already; `Galaxy XR AR` in one heading names the test device, not a requirement | Open                   |
    | 0105 | Webcam driver defers to the Android native bridge only when present                                                        | Open                   |
    """

    details "Group C: one incidental mention", ~S"""
    A path example, a log sample, or a related-RFD pointer names DGX or
    Galaxy XR once, with no structural dependency. Lower priority; a
    pass can fix wording without changing any decision.

    0009, 0013, 0018, 0019, 0027, 0030, 0034, 0036, 0040, 0052, 0060,
    0083, 0084, 0085, 0088, 0089, 0091, 0092, 0093, 0094, 0098, 0100,
    0101, 0102, 0107, 0110, 0111.

    RFD 1027 was already GPU-agnostic; the DGX Spark line in its own
    Problem section is a corrected historical artifact, kept as
    context, not a live dependency. Gained one line this session naming
    the RTX 4090 as a real, supported 24 GB tier.
    """

    drafted_by :ai
  end
end
