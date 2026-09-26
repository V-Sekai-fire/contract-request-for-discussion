# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 1036. `mix rfd.render` renders rfd/1036-packaging-convention/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD1036 do
  use RFD.DSL

  rfd 1036, "Model packaging convention" do
    state :committed

    feature "model packaging"

    attest_in :none

    decision ~S"""
    Package each model as a plain Docker image that serves HTTP.

    No Cog. Cog wraps a `Predictor` class and builds an image around it,
    and that image expects Replicate's own runtime. The local worker
    starts a container and maps a port, and nothing more.

    Each model gets a standalone repo, and each repo holds a `Dockerfile`,
    a `server.py`, and a `test_input.json`. The RFD stays here.

    Name the repo for its model, and never for a package format. A
    format is a decision this RFD already changed once. A folder name
    that carries one goes stale on the next change.

    See `DETAILS.md` for target, rules, the two-stage Dockerfile, files,
    composites, and unconverted folders.

    Committed 2026-09-02: the convention has been in force for months;
    CLAUDE.md closes compute (local desktop GPU only; RunPod/Vast.ai
    blocklisted). Earlier rental-target framing retracted in DETAILS.md.
    """

    problem ~S"""
    The DGX API ran each model through its own adapter, each with its
    own weight loader, CUDA pin, and output writer. There is no DGX now.
    This RFD first selected Cog; `DETAILS.md` records why it was withdrawn.
    """

    related ~S"""
    RFD 1016 lists the models. RFD 1026 gives the memory. RFD 1027 the
    GPU tier. RFD 1037 the composite convention. RFD 1053 the asset
    format. RFD 1028 gates the license.
    """

    details_title "Model packaging convention"

    details "Retracted: Replicate Cog as the package format", ~S"""
    This RFD first selected Replicate Cog. Cog is a good package format,
    and it targets one host. RFD 1055 now runs the worker on this box's
    own 4090 first, plain Docker, no rental. vast.ai stays priced for
    later, the same plain-Docker shape once this box is not enough.

    The rule that replaced it is in the README, and the reason Cog does
    not fit either host is beside it. This entry stays so a reader who
    finds a Cog reference elsewhere knows which way the decision went.
    """

    details "The target", ~S"""
    The local desktop GPU is the only compute (CLAUDE.md hard
    constraint). Rented GPU providers are blocklisted (RunPod, Vast.ai
    rows). The convention still targets a 24 GB card so an image built
    here runs unchanged if the operator later stands up a peer machine
    with equivalent hardware; RFD 1027 records that every model in the
    catalog reaches a 24 GB card.

    An earlier draft named "RTX 4090 with 24 GB, at about 0.35 to 0.37
    US dollars per hour on demand, and 0.13 interruptible" as the target
    and Vast.ai as a future host. Retracted: no budget for
    per-hour/per-invocation billing this cycle.
    """

    details "The rules", ~S"""
    - One model per image. An image that holds two cannot scale one
      without the other.
    - Load the weights at start, and not per request. Whether the host
      is this box or a rented instance, a load per request buys nothing
      and costs every response.
    - Serve `/health` and `/predict`. Neither this box's own worker nor
      vast.ai runs a health probe of its own, thus a caller polls
      `/health` until the instance is ready.
    - Download the weights at build time. A cold start that pulls 24 GB is
      a cold start that times out.
    - Pin every version, and pin the upstream commit. A moved tag changes
      the output with no build change to show for it.
    - Return 400 for a bad request, and not 500. A 500 sends a caller to
      retry a request that can never work.
    - Return a USD layer beside the transmission file. RFD 1053 gives that
      rule.
    - Name the license. RFD 1028 gates what ships.
    """

    details "Two stages in one Dockerfile", ~S"""
    The `contract` stage carries the server and `usd-core`, and no model.
    It builds in seconds on any machine, and `WEFTSPUN_STUB=1` makes
    `/predict` answer with the real shape and no GPU.

    The `worker` stage is the real image. It carries CUDA, the upstream
    source, and the weights.

    That split is what makes the contract testable. RFD 1040 records a run
    of it in Docker on a machine with no NVIDIA device.
    """

    details "Files in each folder", ~S"""
    | File            | Holds                                       |
    | --------------- | ------------------------------------------- |
    | README.md       | The RFD. Why this model, and what it costs. |
    | Dockerfile      | Both stages, the CUDA version, the weights. |
    | server.py       | `/health`, `/predict`, and the type schema. |
    | test_input.json | One request body, for the contract stage.   |
    | domain.ex       | A composite model only. See RFD 1037.       |
    | problem.ex      | A composite model only. See RFD 1037.       |
    | plan.ex         | The solved plan. The planner writes it.     |
    """

    details "What a composite model does", ~S"""
    Five models in the catalog run more than one network. RFD 1037 models
    each one as a taskweft domain, and not as a Python script. The server
    then calls the plan, and each step is one action.
    """

    details "The other folders are not converted yet", ~S"""
    RFD 1040 is the worked example. It carries a `Dockerfile`, a
    `server.py`, and a `test_input.json`, and RFD 1040 records a run of
    the contract stage in Docker.

    Fourteen model folders still carry a `cog.yaml` and a `predict.py`.
    This folder carries a fifteenth `cog.yaml`, the template the other
    fourteen copied. They describe the same models, and they name a
    package format this RFD no longer selects.

    The folder names no longer carry that format. Each folder is now
    named for its model alone.

    Convert one when the model is next worked on, and not in a sweep. A
    folder converted without a build produces a `server.py` that nobody
    ran, which is what the Cog files already are.
    """

    drafted_by :ai
  end
end
