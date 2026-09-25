# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2017. `mix rfd.render` renders rfd/2017-compiling-godot-engine/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2017 do
  use RFD.DSL

  rfd 2017, "Compiling godot engine" do
    state :prediscussion

    decision ~S"""
    See `DETAILS.md` for the full argument.
    """

    problem ~S"""
    Developers build the V-Sekai multiplayer-fabric Godot engine on two
    hosts from one workstation: **Windows (PowerShell + MinGW)** and **WSL
    / Linux (`linuxbsd`)**. Without a shared, persistent compiler cache,
    each host rebuilds from scratch and cache hits are lost whenever a
    checkout is moved or renamed.
    """

    related ~S"""
    See `DETAILS.md` for the full argument.
    """

    details_title "Compiling godot engine"

    details "Context", ~S"""
    Developers build the V-Sekai multiplayer-fabric Godot engine on two
    hosts from one workstation: **Windows (PowerShell + MinGW)** and **WSL /
    Linux (`linuxbsd`)**. Without a shared, persistent compiler cache, each
    host rebuilds from scratch and cache hits are lost whenever a checkout is
    moved or renamed.
    """

    details "Prerequisites", ~S"""
    | Tool     | Windows                       | WSL (Ubuntu 24.04)             |
    | -------- | ----------------------------- | ------------------------------ |
    | Python 3 | `scoop install python`        | system `python3`               |
    | SCons    | `python -m pip install scons` | `python3 -m pip install scons` |
    | Compiler | MinGW-w64 (`use_mingw=yes`)   | `build-essential` (gcc/g++)    |
    | sccache  | `scoop install sccache`       | `brew install sccache`         |
    | Git      | `scoop install git`           | system `git`                   |

    Verify `sccache --version` resolves in each shell. The verified setup
    uses sccache 0.15.0.
    """

    details "Storage backend", ~S"""
    sccache picks its backend from environment variables. Two options:

    - To share the cache across hosts (recommended), use an S3-compatible
      bucket: set the `SCCACHE_BUCKET` / `SCCACHE_ENDPOINT` / `SCCACHE_REGION`
      coordinates and point `AWS_PROFILE` at a profile in
      `~/.aws/credentials`. sccache keys include the compiler, target
      triple, and flags, so Windows/MinGW and Linux objects coexist in one
      bucket without colliding. A `SCCACHE_S3_KEY_PREFIX` namespaces these
      objects so they never collide with other projects sharing the bucket.
    - For a single host, use a local directory instead: set `SCCACHE_DIR`
      and `SCCACHE_CACHE_SIZE`, and sccache uses local disk with no S3
      config needed.

    Secrets policy: only the bucket name, endpoint, region, and key prefix —
    none of which are secrets, appear in committed config. The access key
    and secret are never committed to any repo, dotfile, or build log. They
    live in one of two places depending on where the build runs:

    - Locally: `~/.aws/credentials` under a named profile (`AWS_PROFILE`).
    - CI: GitHub Actions secret variables, injected at runtime via the
      `${{ secrets.* }}` context. Storing the keys there is fine, they are
      encrypted and never land in the repo. What is not fine is pasting a
      literal key into a workflow YAML, a script, or this manual.
    """

    details "CI: GitHub Actions", ~S"""
    In a workflow, read the credentials from secret variables into the
    sccache S3 environment for the build step. Only the secret names appear
    in the committed YAML, the values are stored in the repo/org Actions
    secrets:

    ```yaml
    env:
      SCCACHE_BUCKET: <your-sccache-bucket> # non-secret coordinates
      SCCACHE_ENDPOINT: <region>.example-object-store.com
      SCCACHE_REGION: <region>
      SCCACHE_S3_KEY_PREFIX: godot
      AWS_ACCESS_KEY_ID: ${{ secrets.SCCACHE_AWS_ACCESS_KEY_ID }} # from Actions secrets
      AWS_SECRET_ACCESS_KEY: ${{ secrets.SCCACHE_AWS_SECRET_ACCESS_KEY }}
    ```

    sccache reads `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` directly, so
    CI needs no `~/.aws/credentials` file or `AWS_PROFILE`.

    `SCCACHE_BASEDIRS` (the equivalent of ccache's `CCACHE_BASEDIR`) strips a
    leading absolute prefix before hashing so hits survive a moved/renamed
    checkout. Point it at `GODOT_SRC`. Paths must be absolute; separate
    multiple dirs with `;` on Windows and `:` elsewhere (longest matching
    prefix wins). The server reads it at startup, so it lives in the
    per-instance sccache service launcher; changing it means updating that
    launcher and reinstalling the service
    (`decisions/20260606-windows-background-services-nssm.md`).
    """

    details "Windows: PowerShell profile", ~S"""
    Set `GODOT_SRC` and the S3 coordinates to your values, then add to
    `Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`. The
    function sets the sccache env only for the duration of the build and
    restores it afterwards, so the interactive session and the real AWS CLI
    are never shadowed:

    ```powershell
    if (-not $env:GODOT_SRC) { $env:GODOT_SRC = "$env:USERPROFILE\godot" }
    function gscons {
        $envset = [ordered]@{
            SCCACHE_BUCKET        = '<your-sccache-bucket>'
            SCCACHE_ENDPOINT      = '<region>.example-object-store.com'
            SCCACHE_REGION        = '<region>'
            SCCACHE_S3_USE_SSL    = 'true'
            SCCACHE_S3_KEY_PREFIX = 'godot'
            SCCACHE_BASEDIRS      = $env:GODOT_SRC
            AWS_PROFILE           = '<your-s3-profile>'   # keys live in ~/.aws/credentials, never committed
        }
        $saved = @{}
        foreach ($k in $envset.Keys) { $saved[$k] = [Environment]::GetEnvironmentVariable($k, 'Process'); Set-Item "env:$k" $envset[$k] }
        try {
            python -m SCons platform=windows use_mingw=yes compiledb=yes target=editor precision=double `
                c_compiler_launcher=sccache cpp_compiler_launcher=sccache -j16 @args
        } finally {
            foreach ($k in $envset.Keys) { if ($null -eq $saved[$k]) { Remove-Item "env:$k" -ErrorAction SilentlyContinue } else { Set-Item "env:$k" $saved[$k] } }
        }
    }
    ```
    """

    details "WSL / Linux: `~/.bashrc`", ~S"""
    ```bash
    # Godot V-Sekai linuxbsd build. sccache is the only object cache; S3 backend shares it across
    hosts.
    export GODOT_SRC="${GODOT_SRC:-$HOME/godot}"                 # engine checkout
    export SCCACHE_BUCKET="${SCCACHE_BUCKET:-<your-sccache-bucket>}"
    export SCCACHE_ENDPOINT="${SCCACHE_ENDPOINT:-<region>.example-object-store.com}"
    export SCCACHE_REGION="${SCCACHE_REGION:-<region>}"
    export SCCACHE_S3_USE_SSL="${SCCACHE_S3_USE_SSL:-true}"
    export SCCACHE_S3_KEY_PREFIX="${SCCACHE_S3_KEY_PREFIX:-godot}"
    export AWS_PROFILE="${AWS_PROFILE:-<your-s3-profile>}"       # keys in ~/.aws/credentials,
    never committed
    # Strip the checkout root from compile paths so cache hits survive a moved/renamed build dir.
    export SCCACHE_BASEDIRS="${SCCACHE_BASEDIRS:-$GODOT_SRC}"
    gscons() {
        python3 -m SCons compiledb=yes target=editor precision=double \
            c_compiler_launcher=sccache cpp_compiler_launcher=sccache \
            debug_symbols=yes tests=yes -j$(nproc) "$@"
    }
    ```

    Open a fresh shell (or `source ~/.bashrc` / `. $PROFILE`) so `gscons` is
    defined.
    """

    details "Building", ~S"""
    From your engine checkout (`$GODOT_SRC`):

    ```sh
    gscons                      # full editor build
    gscons verbose=yes          # extra args pass straight through to SCons
    ```

    Output binary:

    - Windows: `bin\godot.windows.editor.double.x86_64.exe`
    - WSL: `bin/godot.linuxbsd.editor.double.x86_64`

    The two functions differ only where the platform requires it: Windows
    pins `platform=windows use_mingw=yes` and `-j16`; WSL infers
    `platform=linuxbsd`, uses `-j$(nproc)`, and adds
    `debug_symbols=yes tests=yes`. Both share
    `compiledb=yes target=editor precision=double` and the sccache
    launchers, and neither enables a SCons `CacheDir`.
    """

    details "Verifying and maintaining the cache", ~S"""
    ```sh
    sccache --show-stats        # "Compile requests" / "Cache hits" climb across builds
    sccache --stop-server       # apply changed SCCACHE_* / AWS_PROFILE env vars
    sccache --zero-stats        # reset counters
    ```

    A clean first build is mostly misses; a second build of the same tree
    shows a high hit rate and finishes substantially faster. With the S3
    backend, a build on the other host hits the same objects once they are
    uploaded.
    """

    details "Consequences", ~S"""
    - There is one object cache, not two: sccache is the sole cache; the
      SCons `CacheDir` is deliberately not enabled, so the same objects are
      never stored twice.
    - One S3 bucket serves both hosts; management is a single location, and
      a checkout can move or be renamed without losing hits
      (`SCCACHE_BASEDIRS`).
    - No secrets live in the repo; bucket coordinates are non-secret config.
      Access keys live in `~/.aws/credentials` locally and in GitHub Actions
      secret variables in CI, never in committed files or build logs.
    - The engine `SConstruct` recognises only `cache_path` and `cache_limit`
      for the SCons cache. We intentionally pass neither. `scons_cache=` is
      not valid and is silently ignored.
    - Common failures: no hits between builds -> server started before the
      env vars, run `sccache --stop-server`; no hits after relocating a
      checkout -> set `SCCACHE_BASEDIRS` to the checkout root; S3 auth
      errors -> wrong/expired `AWS_PROFILE` or missing `~/.aws/credentials`
      entry.
    """

    details "Further reading", ~S"""
    - sccache S3 storage (`SCCACHE_BUCKET`, `SCCACHE_ENDPOINT`, `SCCACHE_S3_KEY_PREFIX`):
    https://github.com/mozilla/sccache/blob/main/docs/S3.md
    - sccache configuration (`SCCACHE_BASEDIRS`):
    https://github.com/mozilla/sccache/blob/main/docs/Configuration.md
    - Godot `SConstruct`: https://github.com/godotengine/godot/blob/master/SConstruct
    """

    drafted_by :ai
  end
end
