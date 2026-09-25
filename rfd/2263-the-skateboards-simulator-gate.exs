# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2263. `mix rfd.render` renders rfd/2263-the-skateboards-simulator-gate/README.md
# and DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2263 do
  use RFD.DSL

  rfd 2263, "the Skateboard's simulator gate" do
    state :discussion

    flight_level :l1

    feature "The pen draws a scripted outfit through a simulated OpenXR
hand and curvenet closes it, repeatably, on a desk and in CI"

    scope "transport-meshing-pen's tools/gate_replay.gd,
tools/replay_oxrsys.py and CI workflows; the dress-on ELFs it carries"

    decision ~S"""
    OXRSys is the OpenXR runtime, and tools/replay_oxrsys.py is its hand:
    tracking packets at 90 Hz, a calibration hold, then each stroke with
    the trigger held, thumbstick clicks for boundary mode and the menu
    button to finish. tools/gate_replay.gd runs the pen scene, writes the
    replay plan in the runtime's frame, and passes when strokes made
    equal strokes planned, with 2 cycles and 2 openings. On Linux it
    passes under a software rasterizer in a virtual X server.
    """

    problem ~S"""
    The Skateboard (RFD 2262) asks whether a drawn outfit comes back as a
    garment that fits. A person in a headset is the real test, but slow
    and unrepeatable; the simulator is the test that runs on every change.
    """

    related ~S"""
    - RFD 2262 (make it with the pen), whose Skateboard this gates.
    - RFD 2234 (dress-on pipeline), the stages the strokes run through.
    - RFD 2255 and 2256, the Bao tunnel and the in-guest transport.
    """

    drafted_by :ai

    details_title "the Skateboard's simulator gate"

    details "State by platform", ~S"""
    | Platform | State |
    | --- | --- |
    | Linux | passes: strokes 6 of 6, 2 cycles, 2 openings, lavapipe under Xvfb |
    | Windows | parked: needs a D3D12 app binding on OXRSys's Windows backend, for WARP |
    | macOS | parked: the gate writes its plan, then the engine aborts before a stroke is drawn |

    Holds are counted in engine frames (the gate sends its frame number
    over UDP), because a software rasterizer runs the engine at 5 to 7
    frames a second.
    """

    details "Saved strokes", ~S"""
    A person's strokes save as OpenUSD: one linear `BasisCurves` prim
    per stroke under `/Creation`, Y up, metres, in the Body frame, the
    boundary mark a per-curve primvar authored only where drawn. usd.elf
    reads and writes them in the guest; Gate S round-trips them against
    the host's OpenUSD. CASSIE's `dress.curves` converts once to the
    same layout, from the train split of a group-wise 60/20/20 split
    whose test set is withheld. Replaying a saved `.usda` through this
    gate is the next step; its expected cycles come from CASSIE's own
    algorithm.
    """

    details "What may still break", ~S"""
    - The runtime's button bits map to OpenXR paths the pen's action
      map may not expect; the symptom is the wrong number of openings.
    - The reference space may be rotated as well as offset; the
      calibration removes only a translation.
    - Headless engine runs have no rendering device; non-VR runs need
      the XR mode off; redirected stdout is buffered, so results go to
      a file; a quit-after flag never fires with XR on, so the gate
      quits on a wall clock.
    """
  end
end
