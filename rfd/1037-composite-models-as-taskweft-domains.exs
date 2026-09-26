# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 1037. `mix rfd.render` renders rfd/1037-composite-models-as-taskweft-domains/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD1037 do
  use RFD.DSL

  rfd 1037, "Composite models as taskweft domains" do
    state :discussion

    feature "model packaging"

    attest_in :none

    decision ~S"""
    Model each composite as a taskweft domain and a paired problem.
    taskweft is an HTN planner at github.com/V-Sekai-fire/interactor-taskweft, and it
    serves `plan` and `validate` over MCP at
    https://taskweft-mcp.fly.dev/mcp.

    Write the domain in the Elixir DSL. The `plan` tool takes `format` of
    `dsl` by default, and JSON-LD is the fallback. Each file is real
    Elixir, thus `Code.string_to_quoted/1` checks it with no planner.

    The model image then calls the plan, and it runs one action per step. The
    order lives in the domain, and not in the Python.

    See `DETAILS.md` for the domain shape and the type rules. It also
    covers why the solved plan is a checked-in file, why replanning is
    the payoff, and the table of all five composites.
    """

    problem ~S"""
    Five catalog entries name one task and run several networks.
    `seethrough_layer_decomposition` runs nine. A Python script that calls
    them in order hides the order, the guards, and the failure points.

    A script also cannot replan. When a stage fails, the caller repeats
    the whole job.
    """

    related ~S"""
    RFD 1036 gives the model image convention. RFD 1030 lists the See-Through
    components. RFD 1006 records the layer decomposition design.
    """

    details_title "Composite models as taskweft domains"

    details "The shape", ~S"""
    A domain is a module with `use Taskweft.DSL` and module attributes.

    | Attribute    | Holds                                          |
    | ------------ | ---------------------------------------------- |
    | `@name`      | The domain name.                               |
    | `@variables` | A map of `name => %{type:, init:}`. The state. |
    | `@actions`   | Primitives. `params`, `bind`, and `body`.      |
    | `@methods`   | Compound tasks. `params` and `alternatives`.   |
    | `@todo_list` | The goal. A call, a `goal`, or a `multigoal`.  |

    A body step is `%{eval: %{…}}` for a guard, or
    `%{pointer_set: "/p", value: v}` for an effect. A guard reads state
    with `%{pointer_get: "/p"}`.

    A problem is a second module. It sets `@source` to the domain name,
    it overrides the `@variables` keys it cares about, and it carries its
    own `@todo_list`.
    """

    details "Type rules that catch a writer out", ~S"""
    `type` is mandatory on each variable, and the vocabulary comes from
    glTF Interactivity. There is no `:string` type. A stage name, a file
    handle, and a format are each `:ref`, which is an opaque value
    compared for equality.

    There is no `:enum` type either. A named class is capability data, and
    it belongs in the top-level `capabilities` key.
    """

    details "The solved plan is a file", ~S"""
    Call `plan` once, and write the result to `plan.ex` beside the domain.
    The model image then reads that file, and a cold start needs no planner
    and no network.

    Write it in the same DSL, and not as JSON. One language across the
    domain, the problem, and the plan means one formatter and one parse
    check.

    Regenerate `plan.ex` when the domain changes, and never edit it by
    hand. A hand-edited plan can hold a step order the guards forbid,
    which is the failure this whole RFD exists to stop.

    **RETRACTED, 2026-08-25: a plan may be written by hand.** The paragraph
    above stays as written because it names a real hazard. The rule it drew
    from that hazard is withdrawn.

    What the rule cost was measured the first time it was applied. A domain
    for the CineForm delivery, RFD 1137, was written and checked with
    `Code.string_to_quoted/1`, and then no plan could be produced, because
    the planner serves over MCP at a host this desk was not going to reach
    mid-task. The domain sat unusable beside a skill that told a reader to
    run it. A rule that turns a reachable deliverable into an unreachable
    one costs more than the defect it prevents.

    So a hand-written `plan.ex` is permitted until a pattern appears across
    enough domains to encode generically. What does not change is the
    checking: the plan is real Elixir and must parse, the domain's guards
    still hold at run time, and a hand-written plan that violates one fails
    there rather than passing quietly. Say in the file which way it was
    made, and regenerate from the planner once it is reachable.
    """

    details "Replanning is the payoff", ~S"""
    `plan` takes `plan_json` and `fail_step`. A caller that loses a stage
    replans from that step, and it keeps the work before it.

    That is the reason a composite is a domain. A script cannot do it.
    """

    details "The five composites", ~S"""
    | Model id                       | Networks | RFD  |
    | ------------------------------ | -------: | ---- |
    | seethrough_layer_decomposition |        9 | 0044 |
    | weftspun_image_to_world        |        2 | 0049 |
    | lingbot_map_environment_scan   |        2 | 0050 |
    | voxhammer_text_mesh_editing    |        2 | 0047 |
    | voxhammer_image_mesh_editing   |        2 | 0048 |

    Each domain lives with its model, and not here. RFD 1000 keeps one
    source per design. The See-Through pair in
    `0044-seethrough-layer-decomposition/` is the worked example,
    because it is the largest of the five.
    """

    details "A decision model is an action, not a runtime", ~S"""
    A decision model answers one typed question: EditScore rates an edit
    against its instruction, and MaskScore is EditScore retrained to rate a
    matte, so one architecture answers both. In a domain it is an action's
    body or a `validate` guard, and the planner orders it among the other
    steps and replans when it fails.

    It runs on the loop's own stack, a godot-sandbox guest on ggml-rd and
    compute-rd, with no model server to reach. That is the difference from a
    standalone runtime that serves decision models over a socket: the typed
    question, the plan that asks it, and the model that answers it sit in the
    process the host already loads.
    """

    drafted_by :ai
  end
end
