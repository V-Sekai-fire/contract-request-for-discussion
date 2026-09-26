# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2238. `mix rfd.render` renders rfd/2238-g1-sim-to-real-environment/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2238 do
  use RFD.DSL

  rfd 2238,
      "Sim-to-real for the body on the G1 rig: the environment, the ROM envelope and the smoke run" do
    state :discussion

    feature "the microduck formula (mjlab on MuJoCo Warp, PPO through rsl-rl, 50 Hz control, ONNX with the normaliser baked in) stood up on the Unitree G1 rig inside WSL2 on the desk's own 4090, with the Appendix E.3 joint envelope as one artefact and a throwaway smoke run proving train, roll-out and export end to end"

    scope "`3-interactor/motion-bricks-cpp/mujoco` (`pixi.toml`, `rom_envelope.py`, `mjlab_motionbricks/`), the WSL2 host on this desk, RFD 1138's source list"

    decision ~S"""
    The training environment is the `pixi.toml` already pinned in `mujoco/`,
    installed for linux-64 inside WSL2 because mjlab declares itself Linux
    or macOS only; the undeclared `uv` venv the benchmarks used is retired.
    The eight-joint E.3 envelope is written to disk once, wrist included,
    from the measured calibration, with a gate and a negative control, and
    the reward, the clearance metric and the gate read that file. A task
    family in the microduck layout registers a flat velocity task on
    mjlab's own G1 at 50 Hz with the ROM terms added. A smoke run validates
    the pipeline and is thrown away: no policy ships or publishes before
    the obs_dim, `K_max` and ROM rulings. `DETAILS.md` carries the rest.
    """

    problem ~S"""
    The operator asked whether the body was being trained sim-to-real in the
    microduck methodology and, told it was not, said "do it". Nothing had
    trained: the stack was pinned but never installed, the E.3 calibration
    lived in one script, and no environment, PPO loop or export existed. The
    three rulings that gate a shipped policy are still open, so the first
    moves are the ones that do not depend on them.
    """

    references ~S"""
    - RFD 2237, the per-frame controller that decides the motion command this body will follow
    - RFD 1138, where a range of motion comes from: Appendix E.3 is a fourth source it has not weighed
    - RFD 2229, interchangeable parts, which decides what each leg reuses
    - Pollen's `microduck_rl`, the public reference for the formula
    """

    related ~S"""
    RFD 1175 (motion-bricks between decisions), RFD 2230 (the ggml adapter the trained policy would reach the avatar through), the #174 open questions recorded in memory.
    """

    details_title "Sim-to-real for the body on the G1 rig: the environment, the ROM envelope and the smoke run"

    details "Interchangeable parts", ~S"""
    | leg | the part that already exists | what changes |
    | --- | --- | --- |
    | the environment declaration | `mujoco/pixi.toml` (mjlab 1.6.0, mujoco 3.11.0, warp-lang 1.17.0, rsl-rl-lib 5.4.2, torch 2.11.0 cu128) | installed for linux-64 in WSL2; `pyarrow`, `datasets` and the editable task package added |
    | the rig | `mujoco/g1.xml` (menagerie, BSD-3-Clause) and mjlab's `asset_zoo/robots/unitree_g1` | mjlab's G1 config reused; `CITATION.cff` beside our copy |
    | the joint envelope | `rom_calibrate.py`, `rom_map.py` | `rom_envelope.py` and `data/g1_rom_envelope.parquet` |
    | the task template | mjlab `tasks/velocity/config/g1` (`env_cfgs.py`, `rl_cfg.py`), `VelocityOnPolicyRunner` | `mjlab_motionbricks/`: the task at 50 Hz with `rom_penalty` and `rom_clearance` |
    | the runner and export | mjlab `scripts/train.py`, `scripts/play.py`, `MjlabOnPolicyRunner.export_policy_to_onnx`, `exporter_utils` | thin entries that register the task, pick the GPU by name and assert the graph's shape |
    | the GPU selection | `bench_silhouette.py`'s select-by-name | `gpu.py`: bus order plus the name from `nvidia-smi` |
    """

    details "The host and the envelope", ~S"""
    mjlab's `pyproject.toml` requires Linux x86_64 or macOS arm64. The desk is
    Windows 11 with WSL2 Ubuntu 26.04 beside it, both owned GPUs visible
    there and the workspace mounted, so `pixi` (0.80.0) is installed in the
    distro with detached environments on the WSL filesystem and the same
    `pixi.toml` is installed for linux-64. Torch enumerates the 4090 first
    while `nvidia-smi` lists it second; `gpu.py` sets the bus order and reads
    the index from `nvidia-smi` by name, so "the 4090" is a name, never an
    index.

    `rom_envelope.py` writes one row per gate joint (knee, elbow, shoulder
    pitch, wrist yaw, both sides) with the E.3 row, the measured neutral and
    flexion sign, the envelope in qpos degrees intersected with `jnt_range`,
    and which of E.3 or the MJCF binds. The wrist's flexion sign is measured
    as well: the right wrist's yaw axis is the left's mirrored across the
    sagittal plane, and the sign follows the axis. `--check` refuses a bound
    outside `jnt_range`, a neutral outside its range, an E.3 row outside the
    pinned eight, and a sign under which ten degrees of flexion leaves the
    envelope; `--self-test` plants a swapped sign and an out-of-range bound
    and both must be refused; `--refetch` reads the sixteen E.3 rows from
    `chibifire/starforged-std-3001-appendix-e` and refuses when they differ
    from the pinned ones. RFD 1138 weighs three ROM sources and not this
    one; the artefact is the fourth candidate, with the civilian reference
    named in the dataset's `source` column.
    """

    details "The task family", ~S"""
    `mjlab_motionbricks/` follows the microduck layout: `robot/g1_constants.py`
    (mjlab's G1 config, the 29 actuated joints in MJCF order, the gate),
    `tasks/mdp.py` (`rom_penalty`, radians outside the permissive envelope
    summed over the gate joints, weight -0.5; `rom_clearance`, the fraction
    of gate joints inside the conservative envelope, logged as a metric),
    `tasks/env_cfg.py` (`Mjlab-Velocity-Flat-MotionBricks-G1`: mjlab's flat G1
    velocity task with a 5 ms physics step and decimation 4, so 50 Hz, the
    two terms added and everything else inherited), `rl_cfg.py` (mjlab's G1
    PPO config, TensorBoard, no upload), `train_cli.py`, `play_cli.py`,
    `export.py` (through the runner, never a hand conversion; the graph
    asserted `[1, obs_dim] -> [1, 29]`; a manifest with every version and
    SHA and `published: false`), `env_check.py` and `smoke.py`.

    The observation is mjlab's actor group as it stands: joint positions and
    velocities, projected gravity, base linear and angular velocity, last
    action, the twist command. Its dimension is measured from the built
    environment and recorded below as the candidate to freeze against; no
    cloth slots (`K_max` = 0), no mocap or gamepad slots, because those
    change the shape and wait for the rulings.
    """

    details "The roll-out corpus", ~S"""
    What a PPO trainer leaves behind, done as data rather than as microduck's
    `--save-csv` debug dump: `RolloutRecorder` (an mjlab `RecorderTerm`)
    writes one row per environment per control step (the actor observation,
    the action, joint positions and velocities, root pose and body-frame
    velocities, projected gravity, the twist command, the reward, the ROM
    clearance, the reset flags; the terminal transition from
    `record_pre_reset`) into ZStandard parquet shards, with an `episodes`
    satellite (seed, sweep, length, how it ended) and a `run` table (the
    checkpoint's sha256, the task, the measured obs_dim, the versions, the
    envelope's sha256, the git sha). `rollout_corpus.py` rolls the policy over
    seven command sweeps (stand, slow walk, walk, run, lateral, turn, mixed)
    and eight seeds, whole seeds held out: seeds 0 to 5 train, 6 test, 7
    evaluation, so the evaluation split is not the training distribution
    reshuffled. The `run` table records that the rows are generated synthetic
    data sampled from a learned policy, the conditioning, and that nothing is
    evaluated on them (CLAUDE.md's four conditions). The first corpus rolls
    the smoke checkpoint, which is not a gait; the same command regenerates
    it from a real checkpoint when the rulings land.
    """

    details "What was measured", ~S"""
    On this desk, in WSL2 Ubuntu 26.04, pixi 0.80.0, mjlab 1.6.0, mujoco and
    mujoco-warp 3.11.0, warp 1.17.0, rsl-rl 5.4.2, torch 2.11.0 cu128, the
    4090 selected by name:

    `rom_envelope.py` wrote the eight-joint envelope (sha256 `08205882...`)
    with E.3 binding on every joint: knee [+13.8, +143.8], elbow [-54.2,
    +75.8], shoulder pitch [-145.3, +4.7], wrist yaw [-50.0, +55.0], both
    sides; the self-test refused the planted swapped sign and the planted
    out-of-range bound; `--check` passes.

    The environment built and stepped: actor observation 99, critic 111,
    action 29, 50 Hz, `rom_penalty` among the fifteen active reward terms and
    `rom_clearance` among the two metrics, 414 environment steps per second
    at 16 environments including the kernel compile.

    The smoke run: 300 iterations at 1024 environments in 341 s (about 21,600
    environment steps per second, 24 steps per environment per iteration),
    checkpoint `model_299.pt`; the roll-out of 1,000 steps over 64
    environments read ROM clearance 0.7986 (denominator 1,000 frames × 64
    environments × 8 gate joints) and mean reward 0.054 per step; the
    envelope shifted by 30 degrees read 0.7562, below the 0.9 rail, so the
    metric moves with the envelope; the export produced `[1, 99] -> [1, 29]`
    with the normaliser in the graph (`bench/smoke_export_manifest.json`,
    `bench/smoke_record.json`). Neither number is a gait's: a smoke policy at
    300 iterations sits below the clearance rail itself, which is why the
    shifted control's margin is small, and why the run is thrown away.

    Two defects the first pass caught: the roll-out called the clearance
    metric with an unresolved joint selection (29 against 8), fixed by
    resolving the gate's regexes when the manager has not; and the
    recorder's shards were named by seed alone, so sweeps overwrote each
    other, fixed by naming them by sweep too.

    The roll-out corpus, from the smoke checkpoint over 8 seeds and 7 sweeps
    at 64 environments and 500 steps each, enumerated by `census_rollouts.py`
    (nulls 0; the planted seed leak and the planted obs-width mismatch both
    refused):

    | split | seeds | shards | frames | episodes | ROM clearance | reward/step | terminal |
    | --- | --- | --- | --- | --- | --- | --- | --- |
    | train | 0 to 5 | 42 | 1,344,000 | 20,809 | 0.8017 | 0.0673 | 0.0135 |
    | test | 6 | 7 | 224,000 | 3,480 | 0.8029 | 0.0675 | 0.0136 |
    | evaluation | 7 | 7 | 224,000 | 3,451 | 0.8020 | 0.0677 | 0.0135 |

    Nearly every episode ends by termination (18,157 of 20,809 in train):
    the smoke policy falls, which is what a policy at 300 iterations does,
    and the corpus records that faithfully. It is published privately as
    `chibifire/motionbricks-g1-rollouts` (1.8 GB, 113 parquets) with the
    run table naming the checkpoint, because no G1 policy publishes before
    the three rulings; the public dataset waits for a real checkpoint.
    """

    drafted_by :ai
  end
end
