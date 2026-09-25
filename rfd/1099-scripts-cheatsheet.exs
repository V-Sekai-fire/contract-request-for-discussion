# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 1099. `mix rfd.render` renders rfd/1099-scripts-cheatsheet/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD1099 do
  use RFD.DSL

  rfd 1099, "One cheat sheet, every operator command, machine plus folder plus command" do
    state :published

    scope "every operator script under `scripts/`, on both the Surface and the DGX"

    attest_in :none

    decision ~S"""
    One file, kept in sync both ways: DGX edits push to the Surface with
    `bash scripts/sync-changes-to-pc.sh --retry-until-complete`, which
    also mirrors to the Surface desktop automatically when this file
    itself changed. Every entry states machine, folder, command, and
    what the command does, in that order. A dedicated section 21 names
    every deprecated command and its replacement, so an old note does
    not silently resurface. Section 22 states the same four-part format
    as the rule agents themselves must follow when giving a command.
    Secrets never appear here: API keys and tokens live only in `.env`
    or local MCP config.

    See `DETAILS.md` for the full inventory, all 22 sections, from repo
    paths and SSH through the spatial fabric, the Sneeze engine, and
    deprecated commands.
    """

    problem ~S"""
    Two machines, two roles, and roughly twenty separate operational
    areas (sync, the dev server, the DGX API, model smoke tests, XR
    logging, the spatial fabric, and more) each carry their own start,
    stop, and verify commands. An agent or a developer needs one place
    naming which machine, which folder, and which exact command, not a
    memory of which of a dozen scripts is current.
    """

    related ~S"""
    RFD 1086 gives the Surface/DGX topology this cheat sheet's sync
    commands depend on. RFD 1095 and RFD 1100 give the XR voice stack
    and the spatial fabric this sheet's own section 19 also covers. RFD
    1119 gives the general hardware rule; this sheet documents one
    team's own reference deployment against that rule, not a
    requirement for running the project elsewhere.
    """

    details_title "One cheat sheet, every operator command, machine plus folder plus command"

    details "1. Repo roots and key paths", ~S"""
    | What                                  | DGX Spark                                | Surface PC                                         |
    | ------------------------------------- | ---------------------------------------- | -------------------------------------------------- |
    | This project (frontend)               | `/home/sifr/Weftspun3DStudio`            | `C:\Users\alfao\Documents\GitHub\Weftspun3DStudio` |
    | `3DAIGC-API` (backend)                | `/home/sifr/3DAIGC-API`                  | API runs on the DGX only                           |
    | MSF Map Service (RP1/Scene Assembler) | `/home/sifr/MSF_Map_Svc`                 | DGX only                                           |
    | Sneeze (the OMB engine library)       | `/home/sifr/Sneeze`                      | DGX only, a native build                           |
    | RP1/MSF secrets, gitignored           | `~/.config/rp1-spatial-fabric/rp1.env`   | copy the template from `rp1.env.example`           |
    | Memory Bank                           | `.../memory-bank/`                       | `...\memory-bank\`                                 |
    | SessionMem team folder                | `.../.sessionmem-team/Weftspun3DStudio/` | `...\.sessionmem-team\Weftspun3DStudio\`           |
    | SessionMem local database             | `~/.sessionmem/memories.db`              | `C:\Users\alfao\.sessionmem\memories.db`           |
    | MCP config (repository)               | `.../.mcp.json`                          | `...\.mcp.json`                                    |
    | Graphify output                       | `.../graphify-out/`                      | `...\graphify-out\`                                |
    | Remote debug log                      |,                                        | `...\logs\remote-log.txt`                          |

    Typical LAN IPs: the Surface at `10.0.0.32`, the DGX at
    `10.0.0.158`; the API URL from the Surface is
    `http://10.0.0.158:7842` (or Vite's own `/__dev_dgx_proxy`).

    Public fabric, over Tailscale: tailnet Serve by default,
    `https://dgx-spark.tail6121eb.ts.net/`, tailnet members only.
    Funnel (real internet access) is opt-in:
    `bash …/setup-dgx-public-routing.sh funnel`. The MSF JSON lives at
    `…/fabric/sample.msf`; the Scene Assembler needs the host root
    opened, never a raw `.msf` file in the browser. Close public access
    with `tailscale funnel reset && tailscale serve reset`.
    """

    details "2. SSH between machines", ~S"""
    Surface to DGX, from PowerShell or an editor terminal: `ssh
    DGX-Local` at home, `ssh DGX-Remote` away (over Tailscale); an
    editor's own Remote-SSH connects to host `dgx-spark.local`, folder
    `/home/sifr`. The SSH alias reference is
    `scripts/dgx-device-map.ps1` on the Surface (display names against
    `DGX-Local`/`DGX-Remote`/the LAN address `10.0.0.158`).

    DGX to Surface, from a DGX terminal: `ssh Surface-PC-Tailscale`.
    """

    details "3. Sync files, DGX to Surface and back", ~S"""
    These copy files over SSH (`scp`); they are not a git push or pull.

    Push DGX-owned files to the Surface, from the DGX, in
    `/home/sifr/Weftspun3DStudio`:

    ```bash
    bash scripts/sync-changes-to-pc.sh --retry-until-complete   # after edits, preferred
    bash scripts/sync-changes-to-pc.sh                          # changes only, one pass
    bash scripts/sync-to-pc.sh                                  # full sync, every DGX-owned path
    bash scripts/sync-changes-to-pc.sh --include-src --retry-until-complete   # only when the DGX
    owned those src/ edits
    bash scripts/sync-changes-to-pc.sh --include-agent-context --retry-until-complete
    bash scripts/sync-cheatsheet-to-desktop.sh   # Desktop mirror, after a cheatsheet edit; also
    runs automatically when this file is part of the incremental sync
    ```

    `sync-changes-to-pc.sh` reads `git status`, touching only changed
    DGX-owned files; `--retry-until-complete` retries a failed `scp` up
    to eight rounds. This is the DGX-side mirror of the Surface's own
    `sync-changes-to-dgx.ps1`.

    Push Surface-owned files to the DGX, from the Surface (PowerShell),
    in `C:\Users\alfao\Documents\GitHub\Weftspun3DStudio`:

    ```powershell
    .\scripts\sync-changes-to-dgx.ps1 -RetryUntilComplete   # after edits, preferred
    .\scripts\sync-changes-to-dgx.ps1                        # changes only, one pass
    .\scripts\sync-to-dgx.ps1 -RetryUntilComplete             # full sync, every top-level src dir
    .\scripts\sync-to-dgx.ps1 -IncludeDocs                    # include docs/ too
    .\scripts\sync-changes-to-dgx.ps1 -Remote -RetryUntilComplete   # away from home
    ```

    `sync-changes-to-dgx.ps1` reads `git status` too, touching only
    changed Surface-owned files; `-RetryUntilComplete` retries the same
    way, up to eight rounds.

    Pull DGX docs and scripts to the Surface, with no Surface `src/`
    push, from the Surface, same folder:

    ```powershell
    .\scripts\sync-from-dgx.ps1
    .\scripts\sync-from-dgx.ps1 -Remote   # away from home
    ```

    Copy `remote-log.txt` from the Surface to the DGX, manually, from
    the Surface (PowerShell), same folder:

    ```powershell
    scp logs\remote-log.txt sifr@DGX-Local:/home/sifr/Weftspun3DStudio/logs/
    ```
    """

    details "4. Frontend development, on the Surface", ~S"""
    Start the Vite dev server, from the Surface (PowerShell), same
    folder: `npm run dev`; stop with `Ctrl+C` in that terminal. Port
    3000 runs on the Surface, never on the DGX.

    Kill whatever holds port 3000, from the Surface (PowerShell):

    ```powershell
    $pid = (Get-NetTCPConnection -LocalPort 3000 -State Listen).OwningProcess; Stop-Process -Id
    $pid -Force
    ```

    Debug URLs (replace the IP if it differs):

    | URL                                                     | Purpose                           |
    | ------------------------------------------------------- | --------------------------------- |
    | `https://10.0.0.32:3000/?nativeFaceRelay=1&remoteLog=1` | Native face relay plus remote log |
    | `https://10.0.0.32:3000/?webcamDebug=1&remoteLog=1`     | Webcam debug                      |
    | `https://10.0.0.32:3000/?xrDebugInputs=1&remoteLog=1`   | XR input debug                    |

    Append `&v=2` to bust the headset's own cache after a deploy.

    Animation playback QA, on the Surface, with Vite running on port
    3000:

    | Task                                           | Command                                                                                          |
    | ---------------------------------------------- | ------------------------------------------------------------------------------------------------ |
    | A canned Mixamo smoke test (VRM hips move)     | `npm run test:anim-smoke`                                                                        |
    | A bone audit, Walking plus Kimodo (Playwright) | `npm run test:bone-audit`                                                                        |
    | A Kimodo job for that audit                    | `set MOTION_JOB_ID=JOB_UUID&& npm run test:bone-audit`                                           |
    | Animation regression unit tests                | `npm run test:anim-regression`                                                                   |
    | A manual browser hook                          | Open `https://10.0.0.32:3000/?animSmoke=1`, then in DevTools: `await __csAnimSmoke.auditBones()` |

    Optional environment variable: `ANIM_SMOKE_URL=https://10.0.0.32:3000`
    (the default LAN HTTPS origin).

    From the DGX, over SSH to the Surface, running in the repository:

    ```bash
    ssh Surface-PC-Tailscale "cd C:/Users/alfao/Documents/GitHub/Weftspun3DStudio && npm run
    test:anim-smoke"
    ssh Surface-PC-Tailscale "cd C:/Users/alfao/Documents/GitHub/Weftspun3DStudio && set
    MOTION_JOB_ID=90cc20fe-da7d-4175-8601-f40e1819515e&& npm run test:bone-audit"
    ```

    A named reference rig, "Eagle Knight" (a SkinTokens GLB): job
    `79a9f3d5-10e3-4ba0-9b7f-593aa6191455`, `skintokens_tokenrig_cli`,
    skeleton bones `bone_0` through `bone_51`. Never apply the VRM0
    quaternion-axis fix to a SkinTokens rig; it reverses the limbs. The
    VRM canned test and the Kimodo test both stay locked through `npm
    run test:anim-regression` (`vrmPlaybackLock.test.js`).
    """

    details "4a. DGX after a reboot, one command", ~S"""
    Run on the DGX after every reboot, or whenever the Surface reports
    the API, MSF, or XR unreachable:

    | Profile                       | Folder                     | Command                                                                               |
    | ----------------------------- | -------------------------- | ------------------------------------------------------------------------------------- |
    | Default (API plus MSF)        | `cd /home/sifr/3DAIGC-API` | `bash scripts/start-dgx-after-reboot.sh`                                              |
    | Plus the XR voice hub         | same                       | `bash scripts/start-dgx-after-reboot.sh --with-xr`                                    |
    | Plus Tailscale public routing | same                       | `bash scripts/start-dgx-after-reboot.sh --with-routing`, or `… --with-routing funnel` |
    | API only                      | same                       | `bash scripts/start-dgx-after-reboot.sh --api-only`                                   |
    | Skip the job drain            | same                       | `bash scripts/start-dgx-after-reboot.sh --force`                                      |
    | Verify the stack              | same                       | `bash scripts/verify-spark-dev-stack.sh`, or `… --with-xr`                            |

    What the default profile starts:

    | Service                         | Port | Script layer                                     |
    | ------------------------------- | ---- | ------------------------------------------------ |
    | Redis (`3daigc-redis`)          | 6379 | `restart_services.sh`, through `ensure_redis.sh` |
    | `3DAIGC-API` plus its scheduler | 7842 | `restart_services.sh`                            |
    | MySQL (`msf-mysql`)             | 3306 | `MSF_Map_Svc/scripts/ensure-msf-mysql.sh`        |
    | MSF Map Service                 | 8443 | `MSF_Map_Svc/scripts/run-msf-map-svc.sh`         |

    On the Surface, each development session, not the DGX: `cd
    Weftspun3DStudio`, then `npm run dev`, plus `npm run
    dev:spark-proxies` when using the MSF Scene Assembler or Galaxy XR
    voice.

    Aliases: `start-dgx-after-reboot.sh` calls
    `ensure-spark-dev-services.sh`. MSF helpers:
    `ensure-msf-mysql.sh`, `verify-fabric-url.sh`.
    """

    details "5. `3DAIGC-API`, start and restart, on the DGX", ~S"""
    Repository path: `cd /home/sifr/3DAIGC-API`, never
    `~/github/3DAIGC-API`.

    Preferred, multi-worker plus scheduler, in the background: use
    `stop_services.sh` and `restart_services.sh`, which avoid a
    duplicate scheduler. `restart_services.sh` auto-starts Redis and
    checks the scheduler's own source files before it launches.

    Confirm Redis and scheduler continuity, before a start or restart,
    from `/home/sifr/3DAIGC-API`:

    ```bash
    bash scripts/ensure_redis.sh                  # start 3daigc-redis if it is down (docker)
    bash scripts/check_scheduler_continuity.sh    # fails if core/scheduler/*.py is missing
    bash scripts/verify_api_stack.sh              # redis + continuity + health + pids
    bash scripts/verify_api_stack.sh --smoke-kimodo   # plus a short text-to-motion job
    ```

    This prevents "scheduler up but workers crash" (a missing
    `job_queue.py`) and "API up but no jobs" (Redis exited).
    `ensure_redis.sh` and `check_scheduler_continuity.sh` both run
    automatically inside `start_services_detached.sh`.

    Stop the API and scheduler cleanly, from the same folder:

    ```bash
    bash scripts/stop_services.sh           # graceful; drains in-flight jobs, up to 5 minutes
    bash scripts/stop_services.sh --force     # an immediate kill, no drain
    ```

    This stops the scheduler (its GPU workers), uvicorn, and any
    orphaned model subprocess.

    Restart, background, the production default, from the same folder:

    ```bash
    bash scripts/restart_services.sh          # stop (drain) + start (redis + continuity checks)
    bash scripts/restart_services.sh --force  # skip the drain
    sleep 3
    bash scripts/verify_api_stack.sh
    ```

    This leaves one scheduler plus one uvicorn
    (`main_multiworker`, 4 workers) on port 7842.

    Start detached, the first time after a stop, from the same folder:

    ```bash
    source scripts/env_local_gpu.sh
    bash scripts/start_services_detached.sh   # ensure_redis + continuity checks are built in
    ```

    This refuses to start if the scheduler or API is already running;
    run `stop_services.sh` first.

    Logs: `logs/api.log`, `logs/scheduler.log`. PIDs: `run/api.pid`,
    `run/scheduler.pid`. Optional worker idle-unload, a scheduler
    environment variable: `P3D_WORKER_IDLE_SEC=900` (15 minutes by
    default), `P3D_WORKER_EVICT_SEC=30`.

    Sync the spatial-fabric environment into the API's own `.env`, from
    the same folder: `bash scripts/sync-spatial-fabric-env.sh`, which
    copies `~/.config/rp1-spatial-fabric/rp1.env`'s variables into
    `3DAIGC-API/.env`; restart the API afterward.

    First-time or clean start, foreground, single worker, from the same
    folder:

    ```bash
    source scripts/env_local_gpu.sh
    ./scripts/run_local_venv.sh
    ```

    This runs a single-worker API on port 7842, with the terminal
    staying attached; `run_server.sh` calls `ensure_redis.sh` first.

    Restart, foreground, single-worker development, from the same
    folder:

    ```bash
    source scripts/env_local_gpu.sh
    pkill -f 'uvicorn api.main_singleworker:app' 2>/dev/null || true
    sleep 2
    fuser -k 7842/tcp 2>/dev/null || true
    sleep 1
    ./scripts/run_local_venv.sh
    ```

    A config-only change, `models.yaml` for instance, needs only a stop
    and start; no model rebuild is needed.

    One-time API maintenance scripts, on the DGX:

    | Task                                                          | Command                                                                                                 |
    | ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
    | Confirm the detached start sources `.env` (the MSF variables) | `/home/sifr/3DAIGC-API/venv/bin/python /home/sifr/Weftspun3DStudio/scripts/dgx-api-source-env-patch.py` |
    | Add the `POST /spatial-fabric/publish-glb` route, if missing  | `/home/sifr/3DAIGC-API/venv/bin/python /home/sifr/Weftspun3DStudio/scripts/dgx-api-add-publish-glb.py`  |

    Restart the API after either patch.

    Restart, background, single worker, legacy, from the same folder:

    ```bash
    source scripts/env_local_gpu.sh
    pkill -f 'uvicorn api.main_singleworker:app' 2>/dev/null || true
    sleep 2
    fuser -k 7842/tcp 2>/dev/null || true
    sleep 1
    mkdir -p logs
    nohup ./scripts/run_local_venv.sh >> logs/api.log 2>&1 &
    sleep 2
    curl -s http://127.0.0.1:7842/api/v1/system/health
    ```

    Multi-worker, foreground, an attached terminal, from the same
    folder:

    ```bash
    bash scripts/stop_services.sh
    source scripts/env_local_gpu.sh
    bash scripts/run_server.sh
    ```

    This runs the scheduler and uvicorn in one terminal; `Ctrl+C` stops
    both.

    A different port: `P3D_PORT=7843 ./scripts/run_local_venv.sh`.

    Free port 7842 by hand: `ss -tlnp | grep 7842` (or `lsof -i :7842`),
    then `kill <PID>`.
    """

    details "6. `3DAIGC-API`, logs and health, on the DGX", ~S"""
    Live logs, best while a job runs, from `/home/sifr/3DAIGC-API`:
    `tail -f logs/api.log logs/scheduler.log`.

    Health checks:

    ```bash
    curl -s http://127.0.0.1:7842/api/v1/system/health | python3 -m json.tool
    curl -s http://127.0.0.1:7842/api/v1/system/models | python3 -m json.tool
    curl -s http://127.0.0.1:7842/api/v1/spatial-fabric/config | python3 -m json.tool
    ```

    `uptime` in the health response is seconds since the API worker
    started, not an epoch timestamp.

    From the Surface, not the DGX:

    ```bash
    curl -s http://10.0.0.158:7842/api/v1/system/health | python3 -m json.tool
    ```

    Add `-H "Authorization: Bearer YOUR_API_KEY"` if API-key auth is
    enabled (the key lives in `.env`).
    """

    details "7. `3DAIGC-API`, job-queue monitoring", ~S"""
    All on the DGX, in `/home/sifr/3DAIGC-API`, unless noted:

    | Task                     | Command                                                                                                     |
    | ------------------------ | ----------------------------------------------------------------------------------------------------------- |
    | A queue snapshot         | `curl -s http://127.0.0.1:7842/api/v1/system/jobs/queue/stats \| python3 -m json.tool`                      |
    | An auto-refreshing queue | `watch -n 2 'curl -s http://127.0.0.1:7842/api/v1/system/jobs/queue/stats \| python3 -m json.tool'`         |
    | Recent jobs              | `curl -s "http://127.0.0.1:7842/api/v1/system/jobs/history?limit=20" \| python3 -m json.tool`               |
    | Failed jobs only         | `curl -s "http://127.0.0.1:7842/api/v1/system/jobs/history?limit=20&status=failed" \| python3 -m json.tool` |
    | One job's detail         | `curl -s http://127.0.0.1:7842/api/v1/system/jobs/JOB_ID \| python3 -m json.tool`                           |

    Quick pick: `tail -f logs/api.log logs/scheduler.log` for live
    inference, plus `watch` on the queue stats. `tail -f` and `watch`
    both stop showing new output after `restart_services.sh` runs;
    restart the monitor after every API restart.

    Redis versus SQLite: live job status and download use Redis only
    (roughly a 24-hour TTL on a completed result); `data/job_queue.db`
    is a legacy archive, and `NOT_IN_SQLITE` is the normal answer for an
    old world job.

    Rehydrate an expired Image-to-World job, on the DGX, when the API
    answers 404 for a job or manifest but the files still exist under
    `outputs/worlds/<job_id>/`:

    ```bash
    /home/sifr/3DAIGC-API/venv/bin/python
    /home/sifr/Weftspun3DStudio/scripts/dgx-rehydrate-world-job.py JOB_ID
    ```

    This re-registers the completed job in Redis, from the on-disk
    `world.manifest.json` and `environment.ply`. Verify with:

    ```bash
    curl -sS -o /dev/null -w '%{http_code}\n'
    'http://127.0.0.1:7842/api/v1/system/jobs/JOB_ID/download?asset=manifest'
    ```

    Expect `200`. Use `3DAIGC-API`'s own venv Python; the system
    `python3` may lack the `redis` module.

    Query a job in the SQLite archive, on the DGX:

    ```bash
    /home/sifr/3DAIGC-API/venv/bin/python
    /home/sifr/Weftspun3DStudio/scripts/dgx-query-job-sqlite.py JOB_ID
    ```

    This prints `(job_id, status, feature)`, or `NOT_IN_SQLITE`; it is
    diagnostic only, and does not fix an API 404. Omit `JOB_ID` to list
    the first five rows in `jobs`.
    """

    details "7a. Krea 2 text-to-image, on the DGX", ~S"""
    Local Krea 2 Turbo, through diffusers' own `Krea2Pipeline`, no Krea
    cloud API. In this project: Task Manager, "Text to Image," model
    `krea2_turbo_text_to_image`, then on the completed row, "Use for
    Image to 3D," into "Image to 3D"
    (`trellis2_image_to_textured_mesh`).

    | Task                                            | Where          | Folder                     | Command                                                                                                                                                                                                                         |
    | ----------------------------------------------- | -------------- | -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
    | Install dependencies (plus optional weights)    | DGX            | `cd /home/sifr/3DAIGC-API` | `bash scripts/setup_krea2.sh`                                                                                                                                                                                                   |
    | Dependencies only, weights already on disk      | DGX            | same                       | `bash scripts/setup_krea2.sh --deps-only`                                                                                                                                                                                       |
    | A post-pip guard                                | DGX            | same                       | `bash scripts/post_pip_guard.sh`                                                                                                                                                                                                |
    | Restart the API after a setup or adapter change | DGX            | same                       | `bash scripts/restart_services.sh`                                                                                                                                                                                              |
    | Pipeline-lock verify, frontend                  | DGX or Surface | `cd Weftspun3DStudio`      | `bash scripts/verify_krea2_text_to_3d_pipeline.sh`                                                                                                                                                                              |
    | Pipeline-lock verify, backend                   | DGX            | `cd /home/sifr/3DAIGC-API` | `./venv/bin/python scripts/verify_hf_conditioning.py`                                                                                                                                                                           |
    | Confirm the model is listed                     | DGX            | any                        | `curl -s http://127.0.0.1:7842/api/v1/system/models \| python3 -c "import json,sys; print(json.load(sys.stdin)['available_models'].get('text_to_image'))"`                                                                      |
    | A smoke job, a quick 512-squared image          | DGX            | `cd /home/sifr/3DAIGC-API` | `curl -s -X POST http://127.0.0.1:7842/api/v1/image-generation/text-to-image -H 'Content-Type: application/json' -d '{"prompt":"a red cube on white","model_preference":"krea2_turbo_text_to_image","width":512,"height":512}'` |

    Weights: `pretrained/krea/Krea-2-Turbo`, roughly 57 GB. VRAM:
    roughly 32 GB reserved per worker (`config/models.yaml`).

    Environment: `TEXT_ENCODER_DEVICE=cpu` in `.env`, optional headroom;
    the adapter honors it for the Qwen3-VL text encoder.

    Two real pitfalls, fixed in the adapter in June 2026: the Krea
    checkpoint uses `rope_parameters` (a transformers 5.x export), and
    the adapter maps that to `rope_scaling` for the pinned transformers
    4.57.3; `Krea2Pipeline` requires the pinned diffusers git checkout
    (`setup_krea2.sh`), not PyPI's own 0.32 or 0.38 release alone.

    Multiview mesh, part of the same flow: `trellis_image_to_textured_mesh`
    plus `trellis2_image_to_textured_mesh` (2 to 8 photos), through Task
    Manager's own "Image to 3D" multi-upload and checkbox; the API's own
    `reference_image_file_ids` field on
    `/mesh-generation/image-to-textured-mesh`.

    A studio canvas (Phase 1) exists too: this project's own `/studio`
    route, a Graph plus Kanban view over the locked Krea-to-TRELLIS.2
    template; run the pipeline through Task Manager. "Open mesh in
    viewport" uses `/?loadMesh=…`.
    """

    details "7b. Kimodo text-to-motion, on the DGX", ~S"""
    NVIDIA Kimodo's SOMA skeleton produces `studio_motion.json` for VRM
    playback. In this project: the animation bar's own
    `KimodoMotionPromptBar`.

    | Task                                        | Where | Folder                     | Command                                                                |
    | ------------------------------------------- | ----- | -------------------------- | ---------------------------------------------------------------------- |
    | Set up the Kimodo venv and its dependencies | DGX   | `cd /home/sifr/3DAIGC-API` | `bash scripts/setup_kimodo.sh`                                         |
    | Prefetch the Llama and Kimodo weights       | DGX   | same                       | `bash scripts/prefetch_kimodo_deps.sh`                                 |
    | Restart, then verify the stack              | DGX   | same                       | `bash scripts/restart_services.sh && bash scripts/verify_api_stack.sh` |
    | A full smoke test, a real motion job        | DGX   | same                       | `bash scripts/verify_api_stack.sh --smoke-kimodo`                      |
    | A drift check, an isolated venv             | DGX   | same                       | `bash scripts/check_kimodo_venv_drift.sh`                              |

    Environment: `TEXT_ENCODER_DEVICE=cpu` in `.env`;
    `worker_load_timeout_sec: 3600` on `kimodo_text_to_motion` in
    `config/models.yaml`.

    A normal, expected log line with no sidecar running: "Text encoder
    service is unreachable, falling back to local LLM2Vec encoder."

    A real pitfall: "Worker process exited before model load" usually
    means Redis is down (`3daigc-redis` exited), or the scheduler's own
    `.py` files were deleted, not a Kimodo weights problem. Run
    `check_scheduler_continuity.sh` and `ensure_redis.sh` before
    suspecting the Llama cache.

    Frontend: `npm run test:bone-audit`, with `MOTION_JOB_ID=…` set (see
    section 4).
    """

    details "8. Model smoke tests, on the DGX", ~S"""
    From `/home/sifr/3DAIGC-API`, after `source scripts/env_local_gpu.sh`:

    ```bash
    # UV unwrap (fast, CPU)
    python scripts/verify_model.py adapters.xatlas_adapter XatlasUVUnwrappingAdapter \
      '{"mesh_path": "assets/example_uv/igea.obj", "output_format": "obj"}'

    # Retopology (needs the Instant Meshes binary)
    python scripts/verify_model.py adapters.instant_meshes_adapter InstantMeshesRetopologyAdapter
    \
      '{"mesh_path": "assets/example_retopo/001.obj", "target_vertex_count": 2000}'

    # Segmentation (heavy GPU)
    python scripts/verify_model.py adapters.p3sam_adapter P3SAMSegmentationAdapter \
      '{"mesh_path": "assets/example_mesh/typical_creature_dragon.obj"}'
    ```

    Download model weights:

    ```bash
    cd /home/sifr/3DAIGC-API
    ./scripts/download_models.sh --list                    # see the names
    ./scripts/download_models.sh -m triposplat              # never a bare "triposplat" argument
    ./scripts/download_models.sh -m unirig,triposplat       # more than one
    ```
    """

    details "9. Avatar pipeline smoke test, on the DGX", ~S"""
    1. Place a master rig: `cp /path/to/your/master.vrm
    /home/sifr/3DAIGC-API/assets/example_autorig/template.vrm`.
    2. Download weights if needed: `cd /home/sifr/3DAIGC-API && ./scripts/download_models.sh -m
    triposplat`.
    3. Restart the API (section 5).
    4. In this project, on the Surface: either "Avatar from Image," upload a photo, and start; or
    "Image to 3D," load a mesh, then "Auto Rigging," rig mode "Template VRM."
    """

    details "10. SessionMem and Memory Bank", ~S"""
    | Tool                          | When                              | Where   | Command                                                                                          |
    | ----------------------------- | --------------------------------- | ------- | ------------------------------------------------------------------------------------------------ |
    | SessionMem sync               | After a coding session            | DGX     | `cd /home/sifr/Weftspun3DStudio`, then `bash scripts/sync-sessionmem-team.sh`                    |
    | SessionMem sync               | After a coding session            | Surface | `cd C:\Users\alfao\Documents\GitHub\Weftspun3DStudio`, then `.\scripts\sync-sessionmem-team.ps1` |
    | Memory Bank                   | At the start of a task            |,       | An agent reads `memory-bank/*.md` automatically                                                  |
    | Memory Bank                   | After a big change                | Chat    | Say "update memory bank"                                                                         |
    | Agent context, to the Surface | After a DGX agent session         | DGX     | `bash scripts/sync-to-pc.sh --include-agent-context`                                             |
    | Agent context, from the DGX   | At the start of a Surface session | Surface | `.\scripts\sync-from-dgx.ps1 -IncludeAgentContext`                                               |
    | PLAN or ACT                   | Planning versus coding            | Chat    | `PLAN` for planning only, `ACT` to implement                                                     |

    A one-time SessionMem ID migration, already done: `python3
    scripts/migrate-sessionmem-project-id.py` on the DGX, or
    `.\scripts\migrate-sessionmem-project-id.ps1` on the Surface.
    """

    details "11. Graphify, the code map", ~S"""
    Refresh on the DGX (frontend plus API): `cd
    /home/sifr/Weftspun3DStudio`, then `bash
    scripts/refresh-graphify-dgx.sh`. Refresh on the Surface (frontend):
    `cd C:\Users\alfao\Documents\GitHub\Weftspun3DStudio`, then
    `.\scripts\refresh-graphify-surface.ps1`. Query, on either machine,
    in the repository: `graphify query "how does taskManager connect to
    API"`.

    Graphify is AST-only, no API key needed. Output lands in
    `graphify-out/`, gitignored.
    """

    details "12. Galaxy XR and remote logging, on the Surface", ~S"""
    Tail the browser's own remote log, from PowerShell, in the project
    root: `Get-Content .\logs\remote-log.txt -Wait -Tail 30`.

    Filter to face-relay lines:

    ```powershell
    Get-Content .\logs\remote-log.txt -Wait -Tail 50 | Select-String "REMOTE_LOG|native-face-relay|ON-NATIVE-FACE|nativeFaceRelay|\[XR\]\[expression\]|nativeFaceBridge|WebcamAvatarDriver"
    ```

    Capture Galaxy XR APK logcat: `.\scripts\capture-apk-logcat.ps1`,
    writing `logs\apk-logcat.txt`. An older note names
    `capture-nativeFaceRelay-logcat.ps1`; use `capture-apk-logcat.ps1`
    instead.

    Other XR scripts, all from the project root on the Surface:
    `.\scripts\reconnect-galaxy-xr-debug.ps1` reconnects wireless or USB
    ADB to the headset; `.\scripts\start-dev-with-xr.bat` is a combined
    dev-plus-XR helper.
    """

    details "13. IWSDK and Playwright, on the Surface", ~S"""
    From `C:\Users\alfao\Documents\GitHub\Weftspun3DStudio`:

    | Task                                                             | Command                        |
    | ---------------------------------------------------------------- | ------------------------------ |
    | A one-time Chromium install                                      | `npm run playwright:install`   |
    | Refresh the MCP adapters                                         | `npm run iwsdk:adapter-sync`   |
    | Development, reliable on Windows                                 | `npm run dev:runtime`          |
    | Development, the IWSDK wrapper (can fail on some Windows shells) | `npm run dev`                  |
    | An XR smoke test, no headset                                     | `npm run iwsdk:xr-smoke`       |
    | Development status                                               | `npx iwsdk dev status`         |
    | A browser screenshot                                             | `npx iwsdk browser screenshot` |
    | Inspect MCP                                                      | `npx iwsdk mcp inspect`        |

    A Playwright MCP token belongs in the local `.env` or MCP config,
    never in this document.
    """

    details "14. Sunshine remote desktop, on the DGX", ~S"""
    | Task                           | Command                                                                                       |
    | ------------------------------ | --------------------------------------------------------------------------------------------- |
    | Script location                | `/home/sifr/start-sunshine.sh`                                                                |
    | Run it                         | `cd /home/sifr && ./start-sunshine.sh`                                                        |
    | A manual start                 | `DISPLAY=:0 XAUTHORITY=/run/user/1000/gdm/Xauthority flatpak run dev.lizardbyte.app.Sunshine` |
    | After a lock or an HDMI change | `systemctl --user restart sunshine`, then `systemctl --user status sunshine`                  |
    | Auto-start on login            | `systemctl --user enable sunshine`                                                            |
    | Re-enable keyring auto-unlock  | `~/disable-keyring-auto-unlock.sh`                                                            |
    """

    details "15. ComfyUI, on the DGX", ~S"""
    From `cd /home/sifr/ComfyUI`:

    ```bash
    source .venv/bin/activate
    python main.py
    ```

    URL, once running: `http://localhost:8188`.
    """

    details "16. NVIDIA Sync, on the Surface", ~S"""
    From PowerShell, in the project root: `.\scripts\restart-nvidia-sync.ps1`.
    """

    details "17. Port reference, on the DGX", ~S"""
    | Port  | Service                           | Notes                                                                        |
    | ----- | --------------------------------- | ---------------------------------------------------------------------------- |
    | 7842  | `3DAIGC-API` (uvicorn)            | The main API; the Surface reaches it over the LAN, or through the Vite proxy |
    | 8088  | The XR Spark hub (`xr_media_hub`) | The voice UI on the DGX; the Surface's own iframe uses the `:8443` proxy     |
    | 8260  | `3daigc-mcp-http`                 | The XR voice path into `3DAIGC-API`'s own MCP                                |
    | 8443  | The MSF Map Service, HTTPS        | The Scene Assembler, on the DGX; the Surface uses the `:8453` proxy          |
    | 8453  | The MSF proxy                     | Surface only; `npm run msf-proxy` forwards to the DGX's own `:8443`          |
    | 6379  | Redis (`3daigc-redis`)            | The job queue; required for the API                                          |
    | 3306  | MySQL (`msf-mysql`)               | The MSF map database, in Docker, localhost only                              |
    | 22    | SSH                               | An editor's Remote-SSH, sync scripts, `scp`                                  |
    | 3000  | Vite                              | Surface only, never on the DGX                                               |
    | 8188  | ComfyUI                           | Only while ComfyUI is running                                                |
    | 11434 | Ollama                            | A local LLM API                                                              |
    | 8080  | An OpenShell cluster              | Separate from `3DAIGC`                                                       |
    """

    details "18. Other services, optional", ~S"""
    OpenClaw/Nemoclaw, if installed: `nemoclaw sparkyai connect` enters
    the sandbox; `openclaw tui` opens the interactive UI, `/exit` leaves
    it, `exit` returns to the host shell; `openclaw agent --agent main
    -m "hello" --session-id test` runs one-shot; `nemoclaw sparkyai
    gateway-token --quiet` prints a gateway token, never committed.

    Git, run by the user only; an agent never pushes: on the DGX, `cd
    /home/sifr/3DAIGC-API`, then `git add … && git commit -m "…" && git
    push origin main`; on the Surface, `cd
    C:\Users\alfao\Documents\GitHub\3DAIGC`, then `git pull` or `git
    push origin main` if using a relay.

    Windows accessibility: the Narrator panel opens with `Win + Ctrl +
    Enter`.
    """

    details "19. RP1/MSF spatial fabric and XR voice, DGX plus Surface", ~S"""
    Config: `~/.config/rp1-spatial-fabric/rp1.env`
    (`RP1_COMPANY_ID`, `MSF_EDIT_KEY`, `MSF_BROWSER_PUBLIC_URL`,
    `XR_BROWSER_PUBLIC_URL`, and more).

    One-time setup, on the DGX, run after a fresh install or when the XR
    hub keeps dying:

    | Task                                        | Folder                     | Command                                    |
    | ------------------------------------------- | -------------------------- | ------------------------------------------ |
    | An XR hub auto-restart, a systemd user unit | `cd /home/sifr/3DAIGC-API` | `bash scripts/install-xr-stack-systemd.sh` |
    | Keep systemd running after logout           | any                        | `sudo loginctl enable-linger sifr`         |

    Check the XR service: `systemctl --user status
    xr-ai-3daigc-stack.service`; logs: `tail -40
    /home/sifr/3DAIGC-API/logs/xr-ai-stack.log`.

    Routine, on the DGX, after a reboot or a "Spark hub unreachable"
    report:

    | Task                                                   | Folder                     | Command                                                    |
    | ------------------------------------------------------ | -------------------------- | ---------------------------------------------------------- |
    | One command, preferred                                 | `cd /home/sifr/3DAIGC-API` | `bash scripts/start-dgx-after-reboot.sh`                   |
    | Plus XR voice                                          | same                       | `bash scripts/start-dgx-after-reboot.sh --with-xr`         |
    | Verify                                                 | same                       | `bash scripts/verify-spark-dev-stack.sh`, or `… --with-xr` |
    | Start or repair MSF `:8443` plus XR `:8088`, low-level | same                       | `bash scripts/ensure-spark-dev-services.sh`                |

    When only `rp1.env`'s URLs change: sync MSF and XR URLs into both
    the API's and this project's own `.env`, from
    `cd /home/sifr/3DAIGC-API`: `bash scripts/sync-dev-topology-env.sh`.

    MSF and Scene Assembler, on the DGX, from `cd
    /home/sifr/MSF_Map_Svc` unless noted:

    | Task                                                                  | Command                                                                              |
    | --------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
    | Apply the env into MSF's own settings                                 | `bash scripts/configure-from-env.sh`                                                 |
    | Start MSF plus the Scene Assembler                                    | `bash scripts/run-msf-map-svc.sh`                                                    |
    | Confirm MySQL only                                                    | `bash scripts/ensure-msf-mysql.sh`                                                   |
    | Verify the local plus public fabric URL                               | `bash scripts/verify-fabric-url.sh`                                                  |
    | Tailscale routing, default is Serve, tailnet only                     | `bash scripts/setup-dgx-public-routing.sh`, or `… serve`                             |
    | Tailscale Funnel, real internet, for an RP1 meetup                    | `bash scripts/setup-dgx-public-routing.sh funnel`                                    |
    | A simpler MSF-only expose, an alternate script                        | `bash scripts/setup-tailscale-exposure.sh` (default Serve; pass `funnel` for public) |
    | Close both Tailscale Serve and Funnel                                 | `tailscale funnel reset && tailscale serve reset`                                    |
    | Seed a GLB into the map database                                      | `bash scripts/seed-map-object.sh [path/to/model.glb] [object-name.glb]`              |
    | Sync MSF variables into `3DAIGC-API`, from `cd /home/sifr/3DAIGC-API` | `bash scripts/sync-spatial-fabric-env.sh`                                            |
    | Set the Scene Assembler login key                                     | `bash scripts/set-msf-edit-key.sh 'your-key'`                                        |

    Surface, each development session, not the DGX, from `cd
    Weftspun3DStudio`:

    | Task                                       | Command                      |
    | ------------------------------------------ | ---------------------------- |
    | Both proxies (MSF `:8453` plus XR `:8443`) | `npm run dev:spark-proxies`  |
    | Verify the proxies reach the DGX           | `npm run verify:dev-proxies` |

    Scene Assembler login: open the host root, never a raw `.msf` file.
    Two fields: the Fabric URL must match the host the Scene Assembler
    itself opened on (the Surface or Galaxy XR:
    `https://10.0.0.32:8453/fabric/`, with `npm run msf-proxy` running;
    Tailscale: `https://dgx-spark.tail6121eb.ts.net/fabric/`; the Scene
    Assembler auto-fills `window.location.origin + '/fabric/'`, and that
    value should be used directly, never mixing the Tailscale fabric URL
    with the Surface host or the reverse). The Key field takes only
    `MSF_EDIT_KEY`'s own value from `rp1.env`, never the `dev.rp1.com`
    password, and never `MSF_DB_PASSWORD`.

    Set a key: `bash
    /home/sifr/MSF_Map_Svc/scripts/set-msf-edit-key.sh 'your-key-here'`.

    Agent default, after any MSF or XR URL or service change: run
    `ensure-spark-dev-services.sh`, then `verify-spark-dev-stack.sh`, on
    the DGX. Never edit a `.env` URL directly unless `rp1.env` itself
    changed.

    World Library RP1 publishes only the GLB props from a world's own
    manifest; a splat-only Image-to-World job (`prop_count: 0`) cannot
    publish through it. Use Task Manager's own "Publish RP1" on a mesh
    job (image-to-3d, auto-rig) instead.
    """

    details "20. Sneeze engine, on the DGX", ~S"""
    The native OMB browser engine (`MetaversalCorp/Sneeze`), a static
    library only; not required for a Scene Assembler publish today.

    | Task                                       | Folder                 | Command                                                          |
    | ------------------------------------------ | ---------------------- | ---------------------------------------------------------------- |
    | Install build prerequisites, one sudo pass | `cd /home/sifr/Sneeze` | `bash scripts/install-prereqs-dgx.sh`                            |
    | Pull, rebuild, and smoke-test              | same                   | `bash scripts/build-dgx-spark.sh`                                |
    | An incremental, Sneeze-only rebuild        | same                   | `bash scripts/build-linux.sh`                                    |
    | Full dependencies plus Sneeze, first time  | same                   | `bash scripts/build-linux.sh --all`                              |
    | Force a scrub and rebuild                  | same                   | `bash scripts/build-linux.sh --rebuild`                          |
    | Manual smoke tests                         | same                   | `builds/linux-arm64/install/release/bin/SneezeTest --wasm --net` |

    Artifact: `builds/linux-arm64/install/release/lib/libSneeze.a`. More
    detail: `Sneeze/docs/guides/dgx-spark.md`.
    """

    details "20b. Weftspun Host, on the DGX, the OMB fabric viewer", ~S"""
    A minimal native browser shell (SDL plus Sneeze), this project's own
    viewer, not a third-party one. Opens an MSF fabric URL in 3D. Docs
    and examples: `MetaversalCorp/SneezeDoc`, cloned at
    `/home/sifr/SneezeDoc` (an embedding guide, plus a stool example).

    | Task                                        | Folder                       | Command                                                                        |
    | ------------------------------------------- | ---------------------------- | ------------------------------------------------------------------------------ |
    | Build (needs the Sneeze dependencies)       | `cd /home/sifr/WeftspunHost` | `bash scripts/build-dgx.sh`                                                    |
    | Run the SneezeDoc stool example, from a CDN | same                         | `bash scripts/run-dgx.sh --url https://cdn.rp1.com/sneeze/examples/stool.json` |
    | Run against the local MSF                   | same                         | `bash scripts/run-dgx.sh --url https://127.0.0.1:8443/fabric/sample.msf`       |
    | Update the SneezeDoc wiki clone             | `cd /home/sifr/SneezeDoc`    | `git pull --ff-only`                                                           |

    Prerequisite, for the local MSF path: `bash
    /home/sifr/3DAIGC-API/scripts/start-dgx-after-reboot.sh`. Sneeze
    dependencies: `cd /home/sifr/Sneeze && bash
    scripts/build-dgx-spark.sh` (or `--only sneeze-sdk` /
    `fastgltf`, if only those pieces are missing).

    Binary: `WeftspunHost/install/release/bin/weftspun-host`. Keys: F5
    reloads, Ctrl+Alt+F5 resets, Escape quits.
    """

    details "21. Deprecated, do not use", ~S"""
    | Old command or path                                       | Use instead                                                                                 |
    | --------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
    | `C:\Users\alfao\Documents\GitHub\CharacterStudio`         | `...\Weftspun3DStudio`                                                                      |
    | `cd ~/Weftspun3DStudio/CharacterStudio`                   | `cd /home/sifr/Weftspun3DStudio`                                                            |
    | `cd ~/github/3DAIGC-API`                                  | `cd /home/sifr/3DAIGC-API`                                                                  |
    | `bash start-api-in-container.sh`                          | `./scripts/run_local_venv.sh` (a venv, not the Docker API)                                  |
    | `docker exec 3daigc-api pkill …`                          | `pkill -f 'uvicorn api.main_singleworker:app'`                                              |
    | `./scripts/download_models.sh triposplat`                 | `./scripts/download_models.sh -m triposplat`                                                |
    | `sync-from-dgx.ps1 -IncludeDocs`                          | `-IncludeDocs` belongs on `sync-to-dgx.ps1`, not `sync-from`                                |
    | `capture-nativeFaceRelay-logcat.ps1`                      | `.\scripts\capture-apk-logcat.ps1`                                                          |
    | A SessionMem folder named `CharacterStudio/`              | `.sessionmem-team/Weftspun3DStudio/`                                                        |
    | A manual `pkill` of only the scheduler or API             | `bash scripts/stop_services.sh`, then `start_services_detached.sh` or `restart_services.sh` |
    | A manual `docker start 3daigc-redis` before every restart | `bash scripts/restart_services.sh` (calls `ensure_redis.sh` automatically)                  |
    | `builds/.../bin/WasmTest` / `NetTest`                     | `SneezeTest --wasm --net`, the unified test runner                                          |
    | Restarting the API without stopping the scheduler first   | `bash scripts/restart_services.sh` (always stops the scheduler first)                       |
    """

    details "22. The agent-facing rule", ~S"""
    When an agent gives a command, it states, in order: the machine
    (DGX or Surface), the folder (the full path to `cd` into first), the
    command (a copy-paste block), and the purpose (one line). An agent
    runs a command itself when it can; this file is the canonical
    inventory, and adding a workflow script means updating it.

    Also kept in sync, on the Surface desktop: `C:\Users\alfao\Desktop\DGX\DGX
    Terminal Commands.md` and the matching `.txt` file. After an edit to
    this cheat sheet on the DGX: `bash scripts/sync-changes-to-pc.sh
    --retry-until-complete` pushes the repository copy, and runs
    `sync-cheatsheet-to-desktop.sh` automatically.
    """

    drafted_by :ai
  end
end
