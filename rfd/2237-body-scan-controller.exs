# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2237. `mix rfd.render` renders rfd/2237-body-scan-controller/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2237 do
  use RFD.DSL

  rfd 2237, "The body reacts through a per-frame diagram scan" do
    state :discussion

    feature "a Function Block Diagram run once per frame between the gamepad, the mocap trackers and motion-bricks.cpp: inputs in, a motion command and a chain mask out, the planner generating the sequences, a Lean reference the guest is measured against"

    scope "`3-interactor/taskweft-fbd-compiler`, `3-interactor/taskweft-godot-sandbox`, `3-interactor/motion-bricks-cpp` as the actuator"

    decision ~S"""
    The body's reaction logic is a diagram with declared inputs and outputs,
    scanned once per frame (RFD 2154's tick), in RFD 2236's subset and forms:
    PLCopen XML, the text form, and a SafeGDScript guest that lifts back. A
    shared netlist orders and types the blocks; a variable read is last
    scan's value and a wire loop without one is refused. The reference scan
    is executable Lean, and the guest is differentially tested against it on
    every generated controller and trace. The taskweft planner generates the
    sequences; continuous logic is written in the text form. The actuator is
    motion-bricks.cpp's command; the chain mask is an output for the mask and
    unmask training. `DETAILS.md` carries the rest.
    """

    problem ~S"""
    Item 2 of the operator's rerank asks for a body that moves in reaction to
    mocap sensors and a gamepad, with spring-bone motion trained under a
    mask. The motion generator, the planner and the sandbox host exist, and
    nothing decided the motion command or the chain mask from an input. RFD
    2236's guest runs a plan once; a body needs the diagram every frame, and
    a per-frame guest tested by eye has not been measured.
    """

    references ~S"""
    - RFD 2236, the diagram forms, the compiler and the teacher this continues
    - RFD 2154 and RFD 1175, the per-frame tick in Godot Sandbox and motion-bricks generating the body's motion between decisions
    - RFD 2230 and RFD 2213, the ggml adapter and the VRM loading the outputs reach once they land
    - RFD 2229, interchangeable parts, which decides what each leg reuses
    """

    related ~S"""
    RFD 2235 (the door), RFD 2157 (the RISC-V emit and the theorem this stays short of), RFD 2206 (the portrait convention, a different surface: it removes the gamepad).
    """

    details_title "The body reacts through a per-frame diagram scan"

    details "Interchangeable parts", ~S"""
    | leg | the part that already exists | what changes |
    | --- | --- | --- |
    | the diagram, its forms, the compiler | `taskweft-fbd-compiler` (`Parser`, `Dsl`, `Xml`, `Lift`, `Sgd`), `fbd_text.gbnf` | input and output variables, REAL literals, `Netlist`, `Scan`, `Semantics`, `Gen` |
    | the block library | `Block` in `TaskweftFbdCompiler.lean` | semantics for the logic, edge, timer, bistable, select, arithmetic and comparison blocks; no new block |
    | the per-frame host | `taskweft_bridge.gd` (`_process`), `taskweft_host.gd` (`vmcall`) | `body_host.gd`: the guest attached as a script, `tick` each frame |
    | the inputs | Godot `Input` joypad, `XRServer` trackers | a named dictionary; a trace file when headless |
    | the actuator | `motion-bricks-cpp` C ABI and its demo server (`POST /api/session`, `POST /api/plan`) | the host posts the command; RFD 2230's adapter replaces the post |
    | the logic generator | `Planner.plan/2`, `Export.sgd/1`, `mix taskweft_acp.plan_sgd` | `avatar_reactions.ex`; the lift of `set` and `hold` steps |
    | the differential runner | Godot headless, the sandbox addon | `scan_runner.gd`, `scripts/diff_scan.sh` |
    """

    details "The netlist and the scan", ~S"""
    A controller declares `in`, `out` and `var` lines; PLCopen carries them as
    `inputVars`, `outputVars` and `localVars`. `Netlist.build` resolves each
    pin to a literal, a variable read or another block's pin, infers BOOL, INT
    and REAL (INT promotes to REAL in arithmetic, never the reverse; STRING is
    not a scan type), orders the blocks by Kahn over pin wires with localId
    ties, and refuses by name: an unwired or unknown pin, a type mismatch, an
    output written twice or declared as an input, a controller writing no
    output, and a combinational cycle, spelled out with the legal form (route
    the loop through a variable, which reads last scan's value).

    `Scan.emit` writes a SafeGDScript guest: `tick(inputs, dt)`, `reset()`,
    `state()`; block state in guest variables committed at the end of a scan;
    a fault (MUX index out of range, INT division by zero) returned as
    `_fault` with the state untouched; `EN` false yielding type defaults and
    `ENO` false. The netlist rides in the guest as a `const NET` string (a
    dictionary literal that size exhausts the sandbox's scoped variants while
    the script initialises), so an edited guest lifts back through `NET`;
    a guest whose tick body was edited instead is refused with the line.

    `Semantics.scan` is the reference, with the per-block definitions in its
    header: timers count seconds of `dt` with `min(et + dt, pt)` in the
    guest's operation order; R_TRIG and F_TRIG with memory initially FALSE;
    SR set-dominant, RS reset-dominant; INT division truncating toward zero
    and MOD with the dividend's sign, as GDScript does. `sim` runs a trace
    and prints one JSON line per tick; REAL values print through a fixed
    nine-decimal formatter. `gen-scan` enumerates 69 harness controllers
    (each block kind direct, at arity four, behind EN, in a feedback loop
    through a variable, and two chains) and 12 traces (six boolean patterns
    at 60 and 30 frames per second, the numbers cycling through edge values
    with a zero divisor and an out-of-range index), so the block set is
    covered rather than sampled. `compile_correct` as a theorem stays RFD
    2157's stage 3; the differential run is the gate now.

    The sandbox lesson: `Sandbox.program` set to a SafeGDScript resource
    publishes no functions (`vmcall` answers "Function not found"), while the
    same resource attached to a node as its script runs in its own sandbox
    with every declared function callable. `taskweft_host.gd` used the first
    route; `body_host.gd` and the runner use the second.
    """

    details "The planner generates the sequences", ~S"""
    `priv/domains/avatar_reactions.ex` carries the body's discrete state
    (`facing_set`, `waving`, `greeted`, `idle`) and actions whose exec kinds
    are `set` (an output and a literal) and `hold` (seconds). The planner
    turned `greet` into `face_stick, start_wave, hold_wave 2, stop_wave` on
    this desk; `plan_sgd` exports it as the step guest, and the compiler's
    lift turns `set` and `hold` steps into a scan controller: `trigger` rises
    through an R_TRIG, each `set` is a SEL that overrides the output's own
    last value while its stage is live, each `hold` is an SR armed by the
    stage before and reset by a TON whose input is the arm's value from the
    previous scan, and the next stage starts on the TON's rising edge. Every
    wait goes through a variable, so the netlist has no combinational loop.
    Continuous logic (stick deadzone, speed limit, tracker timeout) is
    written in the text form by hand now and by RFD 2236's teacher later.
    """

    details "The host", ~S"""
    `transport-taskweft-acp/priv/godot_project/body_host.gd`: `_process`
    builds the input dictionary from joypad 0 (`pad0_lx`, `pad0_ly`,
    `pad0_a`, ...) and from `XRServer` trackers (`mocap<i>_ok`, positions;
    an absent tracker reads as not ok, never as zeros), or from a recorded
    trace when headless; calls the guest's `tick`; prints one `tick` line
    with inputs and outputs per frame for the session log; and posts the
    motion command (`style` by index into the named styles, `move`,
    `facing`, `speed`, `seed`, `advance`) to motion-bricks.cpp's demo server.
    The chain mask is an output on the same line. Nothing else is computed
    in the host.
    """

    details "What was measured", ~S"""
    On this desk (Godot 4.5 stable, the sandbox addon's shipped binaries,
    Lean 4.30.0), the walk controller (`fixtures/scan/walk_ctl.fbd`: nine
    blocks, four inputs, five outputs, one feedback variable) round-trips
    text to XML to text byte for byte, lifts back from its guest to the same
    text, re-emits to the same guest, and simulates identically from all
    three forms. Its guest matched the Lean reference on all 24 ticks of the
    fixture trace, and the negative control, the same guest with the greet
    hold's `>=` turned into `>`, mismatched on tick 21, the tick the timer
    expires. The controls are refused by name: a combinational cycle (the
    loop is printed), an INT into a BOOL pin, an output declared as an input,
    a controller writing no output, a MUX index out of range at run time
    (a fault line, state untouched), a guest whose tick body was edited
    instead of its `NET`.

    `scripts/diff_scan.sh` ran the enumerated harness on the same desk: 69
    controllers by 12 traces, 828 pairs, every guest output equal to the
    reference on every tick, 72 pairs carrying a fault line on both sides
    (INT and REAL division by zero, a MUX index out of range), 0 mismatches.
    The first pass found one: REAL division by zero gave infinity in both,
    which the reference's JSON could not carry, so division by zero is a
    fault for REAL as for INT and a controller output is never infinite.
    The latency rows, 10,000 ticks each through the sandbox with the
    dictionary marshalling included:

    | controller             | blocks | p50 µs | p99 µs | max µs |
    | ---------------------- | ------ | ------ | ------ | ------ |
    | floor (one MOVE)       | 1      | 2      | 2      | 33     |
    | walk controller        | 9      | 5      | 7      | 80     |
    | chain_count harness    | 3      | 5      | 7      | 80     |

    Against a 16.7 ms frame the walk controller's p99 is 0.04 per cent, a
    credit card's thickness against the height of a door; the rails in the
    script (floor p99 under 200 µs, the walk controller under 1 ms) are
    there so a marshalling regression is a number.

    The planner's `greet` plan lifted into a seven-block controller whose
    guest matched the reference on 28 ticks: style 3 one tick after the
    trigger, style 0 on tick 21 when the two-second hold expired. The walk
    controller ran through `mix taskweft_acp.body` over its trace, 24 ticks
    and no fault, every tick an `acp/tick` event in session
    `acp_eea7cd92dfa237ba` of the desk's plain store.

    The controller corpus (`taskweft-fbd-teacher`, family `react`): five
    templates (walk from the stick, face the stick, tracker lost freezes the
    chains, a button plays a style then idles, a speed-limited run), 5,000
    rows in 534 seconds at 8 workers, 1,000 per template, 4,500 train and
    500 holdout with 100 of each template held out, three constructed traces
    per row scored by the reference scan, no nulls in any parquet, published
    as `chibifire/taskweft-fbd-react-train`. Two rows stopped earlier passes
    and both were findings: a hold of 0.8 s in 0.1 s frames expired one frame
    late (eight additions of 0.1 sum to 0.7999999999999999), so the traces
    tick at 0.125 s; and a sweep that never reached the speed cap let the
    halved-cap mutant match, so every sweep now visits the stick's corners.
    The scores over the 4,500 train rows:

    | candidate | parses | compiles | runs | effect | ticks | refused |
    | --------- | ------ | -------- | ---- | ------ | ----- | ------- |
    | rank1     | 1.00   | 1.00     | 1.00 | 1.00   | 36    | 0       |
    | rank3     | 1.00   | 1.00     | 1.00 | 0.00   | 36    | 0       |
    | rank5     | 1.00   | 0.00     | 0.00 | 0.00   | 0     | 4,500   |
    """

    drafted_by :ai
  end
end
