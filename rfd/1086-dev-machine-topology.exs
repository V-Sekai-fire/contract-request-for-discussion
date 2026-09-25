# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 1086. `mix rfd.render` renders rfd/1086-dev-machine-topology/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD1086 do
  use RFD.DSL

  rfd 1086, "Dev machine topology, and the two-machine sync rule" do
    state :published

    scope "an editor workstation, a CUDA-capable GPU host, `scripts/sync-*`"

    attest_in :none

    decision ~S"""
    One rule: one machine owns `src/` at a time. Normal development and
    headset testing run on the editor workstation, which also runs the
    Vite dev server (`https://<workstation-LAN-IP>:3000`); the headset
    always targets that LAN IP, never `localhost` on itself. The GPU
    host is reached over a VPN mesh (Tailscale), mostly headless, for
    SSH, `3DAIGC-API` inference, and builds. `scripts/sync-changes-to-dgx.ps1`
    and `sync-changes-to-pc.sh` push incrementally in one direction at a
    time; a `.sync-lock-dgx` file mid-sync means stop, not force.

    See `DETAILS.md` for the machine-role table, the log-reading fields,
    the file-ownership table, and the full sync command reference.
    """

    problem ~S"""
    Two machines, an editor workstation and a headless GPU host, each
    hold a copy of this repository, synced by `scp`, not by git.
    Reading `logs/remote-log.txt`, planning a headset test, or resolving
    a sync conflict all need to know which machine owns `src/` at any
    given moment. Nothing about this split needs one specific machine or
    headset; RFD 1119 gives the real requirement, a CUDA GPU and a
    WebXR browser. This RFD's own examples name a Windows Surface, an
    NVIDIA DGX Spark, and a Galaxy XR headset, this team's own reference
    pair and test device.
    """

    related ~S"""
    RFD 1119 gives the general hardware requirement this RFD's own
    Surface/DGX pair is one example of. RFD 1088 gives the HTTPS
    certificate setup this topology's headset access depends on. RFD
    1101 gives the two SSH host names this RFD also names.
    weftspun-3d-studio's own `thirdparty/m3/docs/DEV_MACHINE_TOPOLOGY.md`
    holds the same content, byte-identical, as of this writing.
    """

    details_title "Dev machine topology, and the two-machine sync rule"

    details "Machines and roles", ~S"""
    | Role            | Hardware                        | Typical access                                                                                          | Client IP in `remote-log`                                                   |
    | --------------- | ------------------------------- | ------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
    | Dev workstation | Windows Surface Laptop Studio 2 | Local editor, Chrome/Edge, `npm run dev`, webcam tests                                                  | `10.0.0.32` (example LAN IP, where Vite binds on the Surface)               |
    | Remote Linux    | NVIDIA DGX Spark                | Mostly headless; NVIDIA Sync (Tailscale) for SSH/remote editing as user `sifr`; occasional HDMI monitor | Not the browser that posts most `webcamDebug` or desktop `remote-log` lines |
    | XR headset      | Galaxy XR (Chrome WebXR)        | Opens `https://<dev-workstation-LAN-IP>:3000/...` on the LAN                                            | `10.0.0.224` (example)                                                      |

    Do not conflate the DGX Spark with "the PC" when reading a log. The
    Surface runs the Vite dev server and most desktop browser sessions;
    the DGX is for remote compute and SSH, unless a browser is opened on
    it explicitly.
    """

    details "Network flow, development", ~S"""
    ```
    [Surface]  npm run dev  ->  https://<Surface-LAN-IP>:3000/
        ^ POST /__remote_log, /__native_face_ingest
        |
    [Galaxy XR Chrome]  ?nativeFaceRelay=1&remoteLog=1  (AR/VR, relay, playback)
        ^ POST face JSON from a native face-relay app (same-origin ingest on the Surface)

    [DGX Spark]  SSH / API / builds, via NVIDIA Sync, not required for headset -> Surface LAN URL
    ```

    - Headset `localhost`: `https://localhost:3000` on the headset targets the headset itself, not
    the Surface. Always use the Surface's own LAN IP in a headset URL.
    - `3DAIGC-API` may run on the DGX or another host (`VITE_API_ENDPOINT`), a separate concern
    from where Vite serves the web app.
    - The NVIDIA XR AI stack runs on the DGX only (`/home/sifr/xr-ai`); RFD 1095 gives its own
    Media Hub access path.
    """

    details "Reading `logs/remote-log.txt`", ~S"""
    Each line includes the HTTP client that forwarded it:

    ```
    [REMOTE_LOG][::ffff:10.0.0.224][session=…][info] … (https://10.0.0.32:3000/?…)
    ```

    | Field                        | Meaning                                                                                                         |
    | ---------------------------- | --------------------------------------------------------------------------------------------------------------- |
    | `[::ffff:10.0.0.224]`        | Who sent the log (for example, Galaxy XR Chrome)                                                                |
    | `(https://10.0.0.32:3000/…)` | The dev-server origin the tab loaded from (Surface Vite)                                                        |
    | The query string on that URL | Which test mode was active (`nativeFaceRelay`, `nativeFacePlayback`, `webcamDebug`, `xrDebugInputs`, and so on) |

    Vite rotates the log at roughly 5 MB, to
    `logs/remote-log.<timestamp>.txt`; older XR and relay history often
    lives in an archive, not the current file.

    ### Query flags, by typical device

    | Flag                   | Usually exercised on                                                      |
    | ---------------------- | ------------------------------------------------------------------------- |
    | `webcamDebug=1`        | The Surface browser (`10.0.0.32`)                                         |
    | `nativeFaceRelay=1`    | The headset's Chrome (`10.0.0.224`); ingest handled by the Surface's Vite |
    | `nativeFacePlayback=…` | The headset, and sometimes the Surface, for AR replay                     |
    | `xrDebugInputs=1`      | The headset, during a WebXR session                                       |
    """

    details "DGX Spark access", ~S"""
    NVIDIA Sync is the primary way to reach the headless Spark; HDMI
    gives an optional local console, and does not change the log roles
    above unless a browser runs there directly. SSH has two hosts only:
    `DGX-Local` (LAN, `10.0.0.158`) and `DGX-Remote` (Tailscale, through
    NVIDIA Sync), both as user `sifr`. RFD 1101 gives the full naming
    rule.
    """

    details "Two editor entry points, one repository", ~S"""
    | Workspace                      | Typical path                                       | Editor connection           |
    | ------------------------------ | -------------------------------------------------- | --------------------------- |
    | Surface (local dev, Galaxy XR) | `C:\Users\alfao\Documents\GitHub\Weftspun3DStudio` | Local folder                |
    | DGX Spark (SSH agent)          | `/home/sifr/Weftspun3DStudio`                      | `DGX-Local` or `DGX-Remote` |

    | Role                         | Machine             | Typical commands                                                                       |
    | ---------------------------- | ------------------- | -------------------------------------------------------------------------------------- |
    | Web UI, WebXR, headset tests | Surface             | `npm run dev`, serving `https://<Surface-LAN-IP>:3000/`                                |
    | `3DAIGC-API` inference       | DGX Spark (`:7842`) | Via `VITE_API_ENDPOINT` or the dev proxy                                               |
    | Code edits                   | Surface             | Pushed to DGX with `sync-changes-to-dgx.ps1` (preferred) or the full `sync-to-dgx.ps1` |

    Avoiding a mixed-content block, HTTPS dev on the Surface plus Galaxy XR:

    ```env
    DEV_API_PROXY_TARGET=http://10.0.0.158:7842
    VITE_API_ENDPOINT=/__dev_dgx_proxy
    ```

    Vite forwards `https://<Surface>:3000/__dev_dgx_proxy/...` to the
    DGX API. In a DGX SSH session, `VITE_API_ENDPOINT` can point at
    `http://127.0.0.1:7842` when the API runs locally there.

    Auto-rigging (aligned with this project's own upstream): a viewport
    mesh upload plus a JSON `generate-rig` call.
    `src/library/taskManager.js`'s `executeAutoRigging` calls `POST
    /api/v1/file-upload/mesh`, then `POST
    /api/v1/auto-rigging/generate-rig`. `src/components/TaskAdvancedOptions.jsx`
    sets rig mode, skin weights, and output format (FBX or GLB).
    `src/library/aiModelsCatalog.js` names `unirig_auto_rig` and
    `skintokens_auto_rig`. Only `unirig_auto_rig` is enabled on the API
    today, unless `skintokens_auto_rig` is added to `config/models.yaml`
    on the DGX backend.
    """

    details "Sync without GitHub", ~S"""
    No cloud repository is required. Changed files copy over LAN or
    Tailscale only, `scp`-based, last write wins:

    | Route             | SSH host     | When                       |
    | ----------------- | ------------ | -------------------------- |
    | Same Wi-Fi        | `DGX-Local`  | The Spark at `10.0.0.158`  |
    | Away from the LAN | `DGX-Remote` | NVIDIA Sync plus Tailscale |
    """

    details "Surface/DGX sync cheat sheet", ~S"""
    The problem: both machines hold a copy of this repository. If both
    edit `src/` at the same time, one side's work can be silently
    overwritten by the other's `scp` push.

    The golden rule: one machine owns `src/` at a time.

    | Situation                                         | `src/` owner | What to run                                                                                                                                     |
    | ------------------------------------------------- | ------------ | ----------------------------------------------------------------------------------------------------------------------------------------------- |
    | Normal development plus Galaxy XR, on the Surface | Surface      | Push after edits (below); the DGX never uses `--include-src`.                                                                                   |
    | Explicitly coding on DGX Remote                   | DGX          | Lock, edit, `sync-changes-to-pc.sh --include-src --retry-until-complete`, then release the lock. The Surface does not push until that finishes. |

    ### Quick commands, Surface (PowerShell, repository root)

    ```powershell
    # After edits (preferred, git-changed Surface-owned files only)
    .\scripts\sync-changes-to-dgx.ps1 -RetryUntilComplete

    # Full resync (first clone, or large drift)
    .\scripts\sync-to-dgx.ps1 -RetryUntilComplete

    # Pull DGX-owned files only (README, Pitch Deck, package.json, branding docs)
    .\scripts\sync-from-dgx.ps1

    # Away from the home LAN
    .\scripts\sync-changes-to-dgx.ps1 -Remote -RetryUntilComplete
    ```

    Never pipe sync output through `Select-Object -First`; it can stall
    `scp`.

    ### Quick commands, DGX (bash, repository root)

    ```bash
    # After DGX-owned edits (preferred)
    bash scripts/sync-changes-to-pc.sh --retry-until-complete

    # Full DGX-owned push
    bash scripts/sync-to-pc.sh

    # Before editing src/ on DGX
    bash scripts/sync-lock-utils.sh lock "reason"

    # After editing src/ on DGX, push changed src/ only
    bash scripts/sync-changes-to-pc.sh --include-src --retry-until-complete
    bash scripts/sync-lock-utils.sh unlock
    ```

    ### If sync aborts on `.sync-lock-dgx`

    The DGX is mid-edit on `src/`. Stop. Wait for the DGX side to finish
    and release the lock, or confirm with the team which machine is
    canonical before using `-Force`.

    ### When both sides changed something

    ```powershell
    .\scripts\sync-from-dgx.ps1          # 1) DGX docs/branding -> Surface, never src/
    # 2) Resolve any src/ conflict by hand; never blind-push
    .\scripts\sync-changes-to-dgx.ps1 -RetryUntilComplete   # 3) only if the Surface's src/ is the
    truth
    ```

    ### Backup

    Sync scripts live in this repository's own `scripts/` directory.
    Git commits on the Surface are the real rollback; no separate copy
    of the sync scripts is needed.
    """

    details "Who owns what", ~S"""
    | File or folder                                                 | Source of truth              | Direction                         |
    | -------------------------------------------------------------- | ---------------------------- | --------------------------------- |
    | `MONETIZATION_ROADMAP.md`                                      | Surface                      | PC to DGX only, never pulled back |
    | `src/`, this project's own `scripts/` (not `sync-*.ps1`)       | Surface                      | PC to DGX only                    |
    | `Pitch Deck/`, `README.md`, `package.json`, branding doc pages | DGX (edited there)           | DGX to PC only                    |
    | `vite.config.js`, `index.html`, `public/`, `.env`              | Surface (runs `npm run dev`) | Manual, stays on the PC           |

    One canonical roadmap file only: `MONETIZATION_ROADMAP.md`. No
    `MONETIZATION_ROADMAP_BACKUP.md`, no dated variants, no HTML export,
    on the DGX; `bash scripts/prune-sync-duplicates.sh` runs after every
    PC push.

    From the Surface repository root (PowerShell), when both sides
    changed something:

    ```powershell
    # 1) Pull DGX doc/branding and sync-workflow scripts (never src or roadmaps)
    .\scripts\sync-from-dgx.ps1

    # 2) Push PC code and MONETIZATION_ROADMAP.md to DGX (auto-runs the DGX-side ensure step)
    #    Prefer incremental: .\scripts\sync-to-dgx.ps1 -Paths src/library
    .\scripts\sync-to-dgx.ps1
    ```

    ```powershell
    # Away from the home LAN
    .\scripts\sync-to-dgx.ps1 -Remote
    .\scripts\sync-from-dgx.ps1 -Remote

    # A single wrapper for either direction
    .\scripts\sync-dgx.ps1 -Direction to-dgx -Paths src/library
    .\scripts\sync-dgx.ps1 -Direction from-dgx
    ```

    On the DGX (optional; `sync-to-dgx.ps1` runs this automatically
    after each PC push):

    ```bash
    cd /home/sifr/Weftspun3DStudio
    bash scripts/ensure-dgx-sync-ready.sh
    ```

    Or push DGX-owned files to the Surface, when Surface SSH is enabled:

    ```bash
    bash scripts/sync-to-pc.sh
    ```

    Every sync uses `scp` and `ssh` only.

    **What syncs, PC to DGX:** `src/*`, this project's own `scripts/*`
    (excluding `sync-*.ps1`, `prune-sync-duplicates.sh`,
    `sync-to-pc.sh`, `ensure-dgx-sync-ready.sh`), and
    `MONETIZATION_ROADMAP.md`.

    **What syncs, DGX to PC:** `Pitch Deck/`, `README.md`,
    `package.json`, branding doc pages, plus the sync-workflow scripts
    themselves (`sync-*.ps1`, `prune-sync-duplicates.sh`) when those
    change on the DGX.

    **What never syncs DGX to PC:** `src/`, the rest of `scripts/`,
    `MONETIZATION_ROADMAP.md`.

    `-IncludeDocs`, on `to-dgx` only, also mirrors the full `docs/` tree
    from the PC; use it only after a broad PC-side docs edit, then run
    `prune-sync-duplicates.sh` on the DGX.

    **What sync never copies at all:** `vite.config.js`, `index.html`,
    `public/`, `.env`. Those stay on whichever machine runs `npm run
    dev`, usually the Surface.

    Browsing `https://10.0.0.32:3000` is the Surface's own `npm run dev`
    session; pushing files to the DGX does not change that browser
    session. DGX sync exists for the DGX-side remote editing agent and
    for sharing docs with the `3DAIGC-API` codebase, not for updating
    the Surface's own dev server.

    Avatar rig GLBs come from the `3DAIGC-API` export on the DGX
    (UniRig, then a Blender GLB step). Copying this project's docs to
    the DGX does not fix a broken rig; the API itself must implement RFD
    1083's contract. Re-opening an old, completed task still downloads
    the same GLB; a new avatar-from-image job is needed after an API
    fix.
    """

    details "Related docs", ~S"""
    RFD 1088 gives the HTTPS certificate setup, for Galaxy XR access.
    RFD 1105 gives webcam avatar control's `webcamDebug` and
    remote-logging flags. RFD 1082 gives the Android Studio AI brief,
    APK relay, and headset test steps. RFD 1096 gives the OpenXR
    face-tracking Chrome-versus-native paths.
    """

    drafted_by :ai
  end
end
