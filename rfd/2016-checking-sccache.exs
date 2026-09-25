# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2016. `mix rfd.render` renders rfd/2016-checking-sccache/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2016 do
  use RFD.DSL

  rfd 2016, "Checking sccache" do
    state :committed

    decision ~S"""
    `sccache --show-stats` is how anyone confirms the cache is healthy, and
    `Cache errors 0` after a build is the confirmation that the bucket,
    region and credentials are all right. Nothing else proves it: a
    misconfigured sccache falls back to local disk and the build still
    succeeds, so "the build worked" is not evidence the cache worked.

    Native builds route through sccache against `chibifire-sccache`, and
    `scons` keeps its own cache alongside it. That pairing is settled; an
    install that forgets the `SCCACHE_*` environment is an installation
    defect rather than an open question.
    """

    problem ~S"""
    Native builds route compilation through sccache
    (https://github.com/mozilla/sccache) backed by a shared DigitalOcean
    Spaces bucket (`chibifire-sccache`, region `tor1`), so object files
    are cached across machines and CI (see
    `rfd/2017-compiling-godot-engine/index.md`). The failure mode is
    silent: if the `SCCACHE_*` environment is missing, the credentials are
    wrong, or the region/endpoint is off, sccache quietly falls back to a
    local disk cache — or records read/write errors — while the build
    """

    related ~S"""
    - RFD 2017 compiles the engine through this cache.
    """

    details_title "Checking sccache"

    details "Context and Problem Statement", ~S"""
    Native builds route compilation through sccache
    (https://github.com/mozilla/sccache) backed by a shared DigitalOcean
    Spaces bucket (`chibifire-sccache`, region `tor1`), so object files are
    cached across machines and CI (see
    `rfd/2017-compiling-godot-engine/index.md`). The failure mode is
    silent: if the `SCCACHE_*` environment is missing, the credentials are
    wrong, or the region/endpoint is off, sccache quietly falls back to a
    local disk cache, or records read/write errors, while the build still
    succeeds. The shared-cache benefit is lost with no obvious signal. How
    does someone confirm sccache is actually using the remote bucket and is
    healthy?
    """

    details "Decision Drivers", ~S"""
    - A misconfigured cache degrades silently (local disk, or errored
      requests) without failing the build, so "the build worked" is not
      evidence the cache worked.
    - The check should be one command, not a ritual or a log dive.
    - Credentials are scoped to the `do-tor1` AWS profile, not global
      environment variables, so the check must not require exporting
      secrets.
    - It should read the same on Windows (PowerShell) and WSL/Linux.
    """

    details "Considered Options", ~S"""
    - Infer from build times (implicit, unreliable, no backend visibility).
    - Enable `SCCACHE_LOG=debug` and read the per-request log every build.
    - Read `sccache --show-stats` and check the backend and error counters.
    """

    details "Windows PowerShell wrapper", ~S"""
    Aliases cannot carry logic, hence a function plus a `Set-Alias` shim:

    ```powershell
    function sccheck {
        sccache --show-stats |
            Select-String -Pattern 'Compile requests|Cache hits|Cache misses|Cache .*errors|Cache location'
    }
    Set-Alias scc sccheck
    ```

    The bash equivalent is `sccache --show-stats` filtered with `grep`. To
    measure a single build, reset first:
    `sccache --zero-stats; <build>; sccache --show-stats`.
    """

    details "Consequences", ~S"""
    - Good: one command shows the backend and health; no secrets needed,
      since stats read the running server's own counters.
    - Good: works identically across shells; the PowerShell `sccheck`/`scc`
      shortcut makes it a reflex.
    - Bad: the counters are per-server-session, they reset when the
      sccache server restarts or on `--zero-stats`, so they are not
      lifetime bucket totals.
    - Bad: `--show-stats` alone does not prove S3 connectivity; only a
      compile (or a full build) exercises read/write. `Cache errors = 0`
      after a build is the real confirmation that auth and the endpoint are
      correct.
    """

    details "Confirmation", ~S"""
    Running `sccheck` reported `Cache location  s3, name: chibifire-sccache,
    prefix: /godot/`, `Cache errors 0`, and hits accumulating during a Godot
    rebuild, so the remote backend, region, and `do-tor1` credentials are
    all working.
    """

    details "More Information", ~S"""
    - The non-secret `SCCACHE_*` variables (`SCCACHE_BUCKET`,
      `SCCACHE_ENDPOINT`, `SCCACHE_REGION`, `SCCACHE_S3_USE_SSL`,
      `SCCACHE_S3_KEY_PREFIX`) are set globally; credentials live in the
      `do-tor1` profile (`~/.aws/credentials`) and are applied only for the
      duration of a build, so the real AWS CLI is never shadowed.
    - Per-project key prefixes keep objects from colliding in the one
      bucket (e.g. `godot` vs `idtx-flow`).
    - To debug a non-zero error count, set `SCCACHE_LOG=debug` and
      `SCCACHE_ERROR_LOG` in the sccache service launcher and reinstall the
      service so the supervised server picks them up
      (`decisions/20260606-windows-background-services-nssm.md`).
    """

    drafted_by :ai
  end
end
