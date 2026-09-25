# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2150. `mix rfd.render` renders rfd/2150-rectgtn-on-openplc4-over-coap-oscore/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2150 do
  use RFD.DSL

  rfd 2150, "RECTGTN as FBD, on OpenPLC v4 and node-graph editors" do
    compact_head true

    state :prediscussion

    feature "compile RECTGTN plans to IEC 61131-3 **FBD**. Runtime
hosts for OpenPLC v4's compiled binary: PLC, ESP32, Godot Sandbox
(RISC-V). Node-graph converter targets from the same FBD network:
glTF Interactivity, VRChat Udon, UE 4/5 Blueprint, Resonite ProtoFlux.
Coordination is in-process linking (RFD 2154); CoAP+OSCORE (RFD 2151)
is parked until a deployment leaves Godot's networking."

    decision ~S"""
    Translate RECTGTN to **FBD** via RFD 2148's compact GRAFCET, emit
    PLCopen XML with an `<FBD>` body encoding the state machine as
    `SR_L` flip-flops per step and `AND` gates per transition. Compile
    with OpenPLC v4 to a shared library or RISC-V binary; a Godot game
    loads that binary through Godot Sandbox. Hand the same FBD network
    to a converter for a node-graph editor.

    `DETAILS.md` carries the full text of this RFD.
    """

    problem ~S"""
    Taskweft targets the BEAM. Constrained runtimes (PLC, ESP32, Godot
    Sandbox RISC-V VM) and node-graph editors (glTF Interactivity, Udon,
    Blueprint, ProtoFlux) cannot host BEAM. All those consumers speak
    the same shape; typed function blocks with dataflow wires, state
    persisted through named variables; which IEC 61131-3 calls **FBD**.
    """

    references ~S"""
    1. OpenPLC Runtime v4 (MIT), Godot Sandbox (`libriscv/godot-sandbox`)
    2. RFD 2148, 2144, 2146 (parked), 2149
    """

    details_title "RECTGTN as FBD, on OpenPLC v4 and node-graph editors"

    details "Language ranking, with the argument behind each row", ~S"""
    OpenPLC v4's toolchain (MATIEC-derived) supports the five IEC 61131-3
    languages. Two survive the workspace's blocklist as RECTGTN targets;
    the other three are blocklisted or deprecated.

    | rank | lang | verdict | why |
    |---|---|---|---|
    | 1 | **FBD** | the only target | State machine encoded as `SR_L` flip-flops (one per step) + `AND` gates (one per transition) + `MOVE` blocks (one per action). Every downstream consumer; OpenPLC v4, glTF Interactivity, VRChat Udon, UE Blueprint, Resonite ProtoFlux, Godot Sandbox loading OpenPLC's compiled binary; speaks this shape. RFD 2149's Lean analyser reads the compact GRAFCET *input* to the emitter, not the FBD output, so verification is unaffected. |
    |; | ~~SFC~~ | **blocklisted** | Every downstream target speaks FBD-shape; none speaks SFC-shape natively. Shipping SFC as a second output would be drift-shaped (SFC as "pretty FBD") and every consumer would re-encode it into flip-flops anyway. Full argument in `BLOCKLIST.md`. |
    |; | ~~ST~~ | **blocklisted** | Textual imperative subset adds a second parser the Lean analyser has to see through. FBD stays graph-shaped. `BLOCKLIST.md`. |
    |; | ~~LD~~ | **blocklisted** | Relay logic carries simple bool combinational + timers/counters; RECTGTN's ETNF tuple state does not survive the projection. `BLOCKLIST.md`. |
    |; | ~~IL~~ | deprecated | IEC 61131-3 Ed. 3 (2013) withdrew it. Never a target; needs no blocklist row. |

    The emitter refuses to produce ST, LD, or IL bodies and errors out
    naming the row above. A silent skip on a bad target reads exactly
    like a pass (CLAUDE.md rule 3); this is that rule applied here.
    """

    details "The translation pipeline, and where taskweft stops", ~S"""
        RECTGTN JSON-LD                           taskweft's HTN shape
          |
          | Taskweft.Grafcet.to_grafcet/1         RFD 2148
          v
        compact GRAFCET JSON-LD                   IEC 60848 SFC, RFD 2148 profile
          |                                       │
          |                                       └── verified by RFD 2149
          |                                           (reachability, concurrent pairs)
          | Taskweft.OpenPLC.PLCopen.emit/1
          v
        plcopen.xml                               ── taskweft's OUTPUT boundary ──
          |
          | openplc-cli compile                   OpenPLC Editor v4 (GPL-3.0), the
          | (invoked by the operator,             one tool in the ecosystem that
          | not by taskweft)                      accepts PLCopen XML and produces
          v                                       the runtime's expected shape
        program.zip
          |
          | REST upload                           OpenPLC Runtime v4 (MIT)
          v
        running program on the target

    **taskweft ships PLCopen XML.** The downstream compile step
    (`openplc-cli compile`, part of the OpenPLC Editor v4 distribution) is
    invoked by the operator, in their environment, against their target
    board. That step's GPL-3.0 licence attaches to the Editor itself, not
    to the XML we hand it and not to the compiled program the runtime
    loads (OpenPLC Runtime v4 is MIT, and its `strucpp` runtime library
    ships a GCC-style runtime exception explicitly permitting this).

    **Two gates precede the boundary.** RFD 2149's Lean analyser reads
    the compact GRAFCET (before emit) and refuses charts with unreachable
    steps or unintended concurrent pairs; RFD 2150 stage 1's emitter is
    gated by its own tests to produce only FBD inline bodies (ST and LD
    blocklisted, structurally, per the ~~struck~~ rows above). What
    crosses the boundary is *verified* PLCopen XML.

    **One gate follows the boundary, downstream.** `openplc-cli compile`
    fails on any XML the Editor's compiler cannot reduce; a failure there
    is a bug either in the emitter or in a downstream ecosystem change,
    and the operator surfaces it back to us on the XML with the same
    compact GRAFCET input, which reproduces deterministically.

    **What is not in scope here.** Running `openplc-cli` inside taskweft's
    build, or bundling the Editor with taskweft. Both would pull GPL-3.0
    into the taskweft build graph, which the workspace does not want.
    The Editor is a *tool* the operator holds, like `gcc` or `git`; the
    aggregation is a shell invocation, not a link edge.
    """

    details "PLCopen XML SFC skeleton, with FBD inline bodies", ~S"""
    The XML the emitter produces, for one SFC POU. Actions and guards are
    FBD networks (no ST), matching the blocklist row above.

        <pou name="rectgtn_plan" pouType="program">
          <interface>
            <localVars>
              <variable name="done_lake"><type><BOOL/></type>
                <initialValue><simpleValue value="FALSE"/></initialValue>
              </variable>
              ...
            </localVars>
          </interface>
          <body>
            <SFC>
              <step name="lake" localId="10" initialStep="true">
                <action qualifier="S">
                  <inline>
                    <FBD>
                      <inVariable localId="1"><expression>TRUE</expression></inVariable>
                      <outVariable localId="2"><expression>done_lake</expression>
                        <connectionPointIn><connection refLocalId="1"/></connectionPointIn>
                      </outVariable>
                    </FBD>
                  </inline>
                </action>
              </step>
              <transition localId="11">
                <connectionPointIn refLocalId="10"/>
                <connectionPointOut refLocalId="20"/>
                <condition>
                  <inline>
                    <FBD>
                      <inVariable localId="1"><expression>done_lake</expression></inVariable>
                    </FBD>
                  </inline>
                </condition>
              </transition>
              <step name="ingest" localId="20">...</step>
            </SFC>
          </body>
        </pou>

    A conjunction guard (`done_lake AND done_render`) inserts a chain of
    `<block typeName="AND">` between the input variables and the
    condition's output. A time-delayed transition (`t/X_i/PT1H`) inserts
    a `<block typeName="TON">` with its `PT` bound to `T#1h` and its `Q`
    carrying to the condition output. Every RECTGTN construct the emitter
    supports today has an FBD network; a construct that would require an
    ST body raises with a pointer at the ranking above.
    """

    details "CoAP + OSCORE resource model", ~S"""
    Constrained networks: UDP, small MTU, no session state. CoAP (RFC
    7252) is REST over UDP; OSCORE (RFC 8613) supplies end-to-end message
    security independent of the underlying transport, so an intermediary
    CoAP proxy in the shop-floor network cannot read or forge payloads.

    The runtime exposes four CoAP resources, each OSCORE-protected:

    | method | path | body | reply |
    |---|---|---|---|
    | PUT  | `/rectgtn/program` | PLCopen XML | 2.04 Changed on success |
    | POST | `/rectgtn/run`     | (empty)     | 2.05 Content, running program name |
    | GET  | `/rectgtn/state`   |             | 2.05 Content, CBOR-encoded variable snapshot |
    | POST | `/rectgtn/stop`    | (empty)     | 2.04 Changed |

    CBOR (RFC 8949) on state replies matches the workspace's existing
    wire encoding on `2-contract/bus`. Payloads that would exceed CoAP's
    block boundary use CoAP's Block-Wise transfer (RFC 7959); this is a
    transport-level concern the OpenPLC plugin handles, not something the
    program emitter reasons about.
    """

    details "The OpenPLC v4 plugin", ~S"""
    OpenPLC v4 has a plugin system for I/O drivers and transports. The
    CoAP plugin links against libcoap (BSD/MIT) and libcoap-oscore (or
    `libocore`; TBD depending on which permissive CoAP OSCORE library
    lands first), registers the four resources, and bridges CoAP requests
    into OpenPLC's internal program-management API. The plugin lives in
    its own repository, `taskweft-openplc-coap`, so an OpenPLC user who
    doesn't need the CoAP surface can build without it.
    """

    details "Elixir side", ~S"""
    `Taskweft.OpenPLC.CoAP`; a new module in taskweft that wraps a NIF
    over libcoap. The NIF's shape mirrors `weft_bus_nif.cpp`
    (request-response, reply carries a request-id, poll-until-match).
    OSCORE key material comes from a `Taskweft.OpenPLC.CoAP.Keyset`
    struct configured at start; a key-exchange step (EDHOC, RFC 9528) is
    the follow-on that lets the coordinator provision a fresh keyset per
    runtime rather than sharing a static one.
    """

    details "Translator scope for stage 1", ~S"""
    The stage-1 emitter, `Taskweft.OpenPLC.PLCopen`, covers:

    1. sequential chains of `Step`s linked by transitions
    2. AND-divergence + AND-convergence
    3. boolean internal variables (from `V` in the compact GRAFCET)
    4. `stored` actions setting an internal variable
    5. time-delayed transitions (`t/X_i/PT1H` → SFC's `TIME` receptivity)

    Constructs staged for later, matching RFD 2148's own staging:

    1. OR-divergence (needs a translation to SFC's simultaneous-divergence
      with mutually-exclusive receptivities)
    2. MacroStep and EnclosingStep
    3. ForcingOrder (SFC hierarchy jumps; supported by IEC 61131-3 but
      not every runtime)
    """

    details "Verification", ~S"""
    1. Round-trip: a compact GRAFCET fixture lowers to PLCopen XML, that
      XML validates against the PLCopen TC6 schema, and the compiled
      program runs on a headless OpenPLC v4 producing the same trace the
      Lean analyser predicted (reachable steps in the order the RECTGTN
      planner would have visited them).
    2. Analyser gate (RFD 2149): the compact GRAFCET passes the reachable
      + concurrent-pair check *before* it reaches the emitter; an
      unreachable step fails the load rather than compiling into dead
      code.
    3. CoAP+OSCORE: the coordinator publishes a program with a fresh key,
      runs it, reads state, stops it; a replayed message with an old
      sequence number is rejected by OSCORE at the runtime side.
    """

    details "What is deliberately not here", ~S"""
    1. A hard dependency on any specific OSCORE library. libcoap-oscore,
      `libocore`, and mbedTLS-OSCORE are all candidates; the RFD closes
      the pattern, not the choice.
    2. EDHOC key exchange (staged; static keys today).
    3. Compiled program versioning / rollback semantics on the runtime.
    """

    details "From the README, moved here on 2026-09-07", ""

    details "Decision", ~S"""
    Translate RECTGTN to **FBD** via RFD 2148's compact GRAFCET, emit
    PLCopen XML with an `<FBD>` body encoding the state machine as
    `SR_L` flip-flops per step and `AND` gates per transition. Compile
    with OpenPLC v4 to a shared library or RISC-V binary; a Godot game
    loads that binary through Godot Sandbox. Hand the same FBD network
    to a converter for a node-graph editor.

    Language ranking collapses to **FBD only**. **SFC is blocklisted**
    (new row in `CLAUDE.md`, argument in `BLOCKLIST.md`). ST and LD
    were already blocklisted; IL is deprecated.

    Coordination rides linking: Elixir NIF → LibGodot → Godot Sandbox
    → OpenPLC compiled `.riscv`. One address space. No wire.
    """

    details "Problem", ~S"""
    Taskweft targets the BEAM. Constrained runtimes (PLC, ESP32, Godot
    Sandbox RISC-V VM) and node-graph editors (glTF Interactivity, Udon,
    Blueprint, ProtoFlux) cannot host BEAM. All those consumers speak
    the same shape; typed function blocks with dataflow wires, state
    persisted through named variables; which IEC 61131-3 calls **FBD**.
    """

    details "References", ~S"""
    1. OpenPLC Runtime v4 (MIT), Godot Sandbox (`libriscv/godot-sandbox`)
    2. RFD 2148, 2144, 2146 (parked), 2149
    """

    drafted_by :ai
  end
end
