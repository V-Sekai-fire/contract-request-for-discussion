# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2154. `mix rfd.render` renders rfd/2154-openplc4-to-godot-sandbox/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2154 do
  use RFD.DSL

  rfd 2154, "OpenPLC v4 into Godot Sandbox, from Elixir" do
    state :prediscussion

    feature "compile RECTGTN → FBD → OpenPLC v4 → RISC-V shared
object, load into Godot through Godot Sandbox (`libriscv`), embed
that Godot from Elixir via the `lib_godot_connector` NIF"

    scope "taskweft compile chain, new `taskweft-godot-sandbox`
project (Elixir + Godot scene + Godot Sandbox addon)"

    decision ~S"""
    Reuse three MIT pieces:

    1. **OpenPLC v4** compiles FBD XML to a RISC-V shared object.
    2. **Godot Sandbox** (`libriscv/godot-sandbox`) ticks it per frame.
    3. **`lib_godot_connector`** is the Elixir NIF over LibGodot.

    Flow: `RECTGTN → to_grafcet → PLCopen.emit → openplc-cli compile
    --target riscv64 → Godot scene loads plan.riscv via Godot Sandbox →
    BEAM embeds that Godot via lib_godot_connector`.

    `DETAILS.md` carries the Godot scene shape, the Sandbox addon config,
    the frame-tick contract, and verification.
    """

    problem ~S"""
    RFD 2150 names Godot Sandbox as one runtime host for OpenPLC v4's
    compiled binary. The compile lives in OpenPLC v4's toolchain (MIT
    runtime, GCC-style runtime exception on the compiler). The load-
    and-execute lives in a Godot process. Elixir owns the coordinator.
    This RFD is the wire.
    """

    references ~S"""
    1. lib_godot_connector: https://hex.pm/packages/lib_godot_connector
    2. Godot Sandbox: https://github.com/libriscv/godot-sandbox (MIT)
    3. RFD 2148, 2144, 2145
    """

    details_title "OpenPLC v4 into Godot Sandbox, from Elixir"

    details "The three pieces and how they connect", ~S"""
    **Compile step**; `openplc-cli compile` (via OpenPLC Editor v4,
    GPL-3.0 as a tool, GCC-style runtime exception on its output). Takes
    PLCopen FBD XML in, produces a shared object out. For Godot Sandbox
    consumption the target is RISC-V:

        openplc-cli compile --target riscv64 --format shared plan.plcopen.xml

    The output is `plan.riscv` (technically a `libplan.so` compiled for
    RV64GC). OpenPLC v4's `Makefile.strucpp` already builds `.so` on the
    host; a RISC-V cross-compile substitutes `riscv64-unknown-linux-gnu-g++`
    for `g++` and passes `-march=rv64gc`. Cross-toolchain installation is
    outside taskweft (a developer concern), like `riscv-gnu-toolchain`.

    **Load step**; Godot Sandbox (`libriscv/godot-sandbox`, MIT). It is
    a Godot addon that adds a `Sandbox` node type. Each `Sandbox` node
    holds a `libriscv` VM instance, loads a `.riscv` shared object at
    `_ready`, and calls a Godot-side entry function every frame (Godot's
    `_process(delta)` calls the sandbox's exported `on_tick`). The
    Sandbox scene tree looks like:

        Node2D (root)
          Sandbox
            program = res://plans/plan.riscv
            entry_symbol = "on_tick"

    `on_tick` inside the compiled program is one call to OpenPLC's
    `strucpp_run_task(0)`, which ticks the FBD network exactly one scan.
    State (SR flip-flop values, `done_*` variables) persists inside the
    Sandbox instance between frames, matching how a PLC scans forever.

    **Embed step**; `lib_godot_connector` (MIT, Hex `lib_godot_connector
    4.5.1`, `Ughuuu/libgodot`). It is an Elixir NIF over LibGodot that
    spawns/embeds a Godot process. From the BEAM:

        {:ok, godot} = LibGodot.create("../../priv/libgodot.dylib", [
          "--headless", "--main-scene", "res://sandbox_host.tscn"
        ])
        :ok = LibGodot.start(godot)
        :ok = LibGodot.wait(godot, timeout: 5000)

    The scene the connector loads (`sandbox_host.tscn`) contains one
    `Sandbox` node whose `program` property is the compiled `.riscv`
    file. Elixir sends inputs and reads outputs through Godot's
    `set` / `call` on nodes, exposed by the connector as
    `LibGodot.call(godot, "/root/Node2D/Sandbox", "get_var", ["done_oracle"])`.
    """

    details "The taskweft-godot-sandbox project layout", ~S"""
        3-interactor/taskweft-godot-sandbox/
          mix.exs                         Elixir project, deps :lib_godot_connector
          lib/
            taskweft_godot_sandbox.ex     public facade (start, tick, get_var)
            sandbox_host.ex               GenServer over LibGodot
          priv/
            sandbox_host.tscn             Godot scene with one Sandbox node
            plans/                        compiled .riscv artifacts land here
          test/
            sandbox_host_test.exs         smoke test: compile fixture, load,
                                          tick, observe done_oracle -> true

    Boot order:

    1. `mix taskweft.grafcet.lower` produces HTN JSON (already exists).
    2. `mix openplc.emit` (new) produces PLCopen FBD XML.
    3. `mix openplc.compile --target riscv64` (new) invokes the operator's
       installed openplc-cli to produce `plan.riscv`.
    4. `TaskweftGodotSandbox.start(plan: "priv/plans/plan.riscv")` embeds
       Godot, loads the scene, runs.
    """

    details "Frame-tick contract", ~S"""
    Godot's `_process(delta)` fires at whatever the frame budget allows
    (60 Hz default headless). Each frame:

    1. Godot Sandbox calls `on_tick(delta)` inside the RISC-V program.
    2. Inside the program, `strucpp_run_task(0)` runs one scan of the FBD.
    3. SR flip-flops update their `.Q`; `done_*` variables reflect the new
      state.
    4. BEAM optionally reads state via `LibGodot.call(...)`.

    **One scan per frame** matches an IEC 61131-3 scan cycle exactly.
    If the operator needs slower ticks (a plan whose steps take seconds),
    the Sandbox node can be wrapped in a Godot `Timer` firing at 1 Hz
    and calling the sandbox from the timer's timeout signal.
    """

    details "Verification", ~S"""
    1. `weftspun-build.grafcet.jsonld` (RFD 2148 fixture) compiles to
      `plan.riscv`. `mix test` under `taskweft-godot-sandbox` starts a
      headless Godot via `lib_godot_connector`, ticks 100 frames, asserts
      `done_oracle` becomes `TRUE` and each upstream `done_*` also does.
    2. The Sandbox addon's own tests (upstream) prove the RISC-V VM does
      not escape its sandbox. We inherit that guarantee for free.
    3. RFD 2149's Lean analyser passes on the compact GRAFCET input
      before the emit, so an unreachable step in the source is caught
      before it becomes a step_*_Q that never rises inside the sandbox.
    """

    details "Licensing map", ~S"""
    | piece | licence | reason it is safe |
    |---|---|---|
    | OpenPLC Runtime v4 | MIT | first-party |
    | OpenPLC Editor / STruC++ | GPL-3.0 (with runtime exception) | invoked as a build tool, output is unencumbered |
    | Godot Sandbox addon | MIT | linked at Godot's addon layer |
    | Godot engine | MIT | linked as `libgodot` |
    | `lib_godot_connector` | MIT | Elixir NIF |
    | RISC-V cross-toolchain | GPL-3.0 (with runtime exception) | invoked as a build tool |

    Every piece the taskweft codebase links against or ships is MIT.
    Every GPL piece is invoked as a tool (aggregation), and the compiled
    output the runtime loads carries no GPL obligation.
    """

    details "What is deliberately not here", ~S"""
    1. The RISC-V cross-toolchain installation. That is a developer-
      environment concern.
    2. A `--target x86_64` alternative. Godot Sandbox is RISC-V-only; a
      native-code path would use a different addon and a different RFD.
    3. Live editing of the plan while the sandbox runs. Reloading the
      `.riscv` at runtime is possible (Godot Sandbox supports it), but
      the RFD leaves it as "restart the scene" for stage 1.
    4. Any glTF / VRChat / Blueprint / ProtoFlux integration; those are
      RFD 2153's job.
    """

    drafted_by :ai
  end
end
