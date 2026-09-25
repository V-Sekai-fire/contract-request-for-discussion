# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 1131. `mix rfd.render` renders rfd/1131-operator-emulation-for-the-accelerator/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD1131 do
  use RFD.DSL

  rfd 1131, "Emulating the operators an edge compiler refuses" do
    state :discussion

    feature "running the whole keypoint graph on the accelerator, with no host cut"

    scope "`3-interactor/rf-detr-cpp`, `2-contract/lean-deform-exact`, `5-repository/hailo-model-zoo`"

    attest_in :none

    decision ~S"""
    Emulate them. One kernel does all four: bilinear interpolation is a tent that vanishes
    beyond one pixel, so at integer positions it is exactly a one-hot.

        out[i] = sum_k data[k] * tent(idx - k)      tent(t) = relu(1 - sqrt(t*t))

    The index moves out of the ADDRESS and into a MULTIPLIER. The addresses were the
    objection; the arithmetic never was.

    1. **Trace before rewriting.** Fold what is constant. All 85 `ScatterND` indices were
       predicted constant and measured data-dependent, which deleted the cheap route.
    2. **A parse is not a measurement.** It says the operators are expressible. Separate
       translation error from precision error, because they call for different fixes.
    3. **Every rewrite ships a control that must fail.** One that agrees with whatever it is
       handed proves nothing.
    4. **Report what was not measured.** No schedule, no cycle count, no device.

    Measured: four rewrites accepted for `hailo10h`, exact to float64 roundoff, 1,549 layers
    against the backbone's 336. Whether that beats the cut is unanswered — layers are not
    cycles, and saying so is the finding rather than a caveat.
    """

    problem ~S"""
    A dataflow accelerator refuses to compute an address from the data. That rules out
    `GridSample`, `ScatterND`, `GatherElements` and `TopK` — the whole indexing family the
    DETR decoder is built from. The accepted answer is to cut the graph and run the decoder
    on the host, which is what Hailo's own DETR does and what 50 of its 127 zoo configs do.
    A cut costs a USB round trip per frame and a host pipeline that has to exist.
    """

    related ~S"""
    RFD 1122 is the corpus this detector trains on. `weftspun/lean-deform-exact` proves the
    deformable rewrite. `DETAILS.md` carries the procedures and the traps.
    """

    details_title "Emulating the operators an edge compiler refuses"

    details_preamble ~S"""
    <!-- Moved here from `rf-detr-cpp/.claude/skills/hailo-dfc/SKILL.md`, which is deleted
    rather than left behind so the two cannot drift. A procedure only one tool can read is a
    procedure nobody reviews; an RFD is reviewed when written and `check-rfd-structure.py`
    gates it. -->

    The DFC wheel is `linux_x86_64` only and this workspace is Windows. Docker Desktop and WSL
    (Fedora) are both present, so the compiler runs in a container. Most of the difficulty is not
    the compiler.
    """

    details "The traps, in the order they bite", ~S"""
    **`MSYS_NO_PATHCONV=1` on every `docker -v` and every `wsl` call.** Git Bash rewrites
    anything that looks like a POSIX path. `wsl, cat /home/x` becomes
    `cat 'C:/Program Files/Git/home/x'`, and a `$VAR` inside a quoted `bash -lc` can arrive
    empty. That silently produced a systemd unit reading `-v /op_tests_deform:/w/deform`, Docker
    created four empty directories, and the emulation reported an empty table rather than an
    error. Export it once at the top of the command.

    It is not only paths, and the other two forms bit while this document was being moved
    into this RFD. `git show origin/main:file` becomes `origin\main;file`, the colon is
    rewritten too, so a recovery command fails as though the revision were missing. And
    Python is a third case: it wants `C:\...` and does nothing useful with `/c/...`, which
    is how the write that should have created this file failed while the `rm` beside it
    succeeded.

    **Verify the destination before removing the source.** This document was nearly lost
    moving it here: the write went to a Python that had been handed `/c/...` instead of `C:\...`
    and failed, while the `rm` on the next line ran anyway. It survived only because the commit
    that added it had already merged, which is luck rather than procedure. A move is a write and
    then a delete, in that order, with something between them that reads the destination back.

    **Prefer a script file to inline quoting through `wsl`.** Even with path conversion off,
    nested quotes through `wsl -d X, bash -lc '...'` are unreliable. Write the script to
    `/c/...`, then `wsl, bash /mnt/c/...`.

    **Mount paths are `/mnt/c/...` from WSL and `/c/...` from Git Bash.** Both reach the same
    Windows directory; the daemon is Windows-side either way.

    **The compiler writes into the directory it reads.** Its simplify-and-retry path emits
    `<name>.sim.onnx` beside the input, so a second run globs its own artefacts and reports 72
    operators where 48 were tested. Scan the manifest's list, not the directory, and clean
    `*.sim.onnx` and `*.har` after every run.
    """

    details "The four gates, in order", ~S"""
        scripts/gen_op_tests.py          one minimal ONNX graph per operator, self-verified
        deploy/hailo-dfc/scripts/gate_dfc_ops.py     parse each: accepted or refused
        deploy/hailo-dfc/scripts/measure_dfc_cost.py ONNX nodes against Hailo layers
        deploy/hailo-dfc/scripts/emulate_dfc.py      native and quantized against onnxruntime

    Build once: `docker build -t weftspun-hailo-dfc deploy/hailo-dfc` (the 522 MB wheel must sit
    beside the Dockerfile; it is gitignored).

    **A parse is not a measurement of correctness.** It says the operators are expressible. Only
    `emulate_dfc.py` answers whether translation preserved the function, and it separates
    translation error (native vs onnxruntime) from precision error (quantized vs native) because
    those call for different fixes.

    **A one-operator graph cannot tell "refused" from "absorbed".** Reshape-like operators are
    folded into their neighbours and emit no layer, which surfaces as
    `InvalidHNError: node name Y in end_node_names is missing in the HN`, identical to a real
    refusal. Sandwich the operator between convolutions, and record any that cannot be wrapped so
    their verdict is read with that caveat.
    """

    details "Long runs as a systemd unit", ~S"""
    WSL Fedora has systemd enabled, so a run that outlives a shell goes there:

        wsl -d FedoraLinux-44, systemctl --user restart hailo-emulate
        wsl -d FedoraLinux-44, journalctl --user -u hailo-emulate -f

    `Type=oneshot` with `RemainAfterExit=yes`, never `simple`: this is a measurement that ends,
    and `simple` reports success the moment docker starts.
    """

    details "Rewriting a refused operator", ~S"""
    Four have been done, `GridSample`, `ScatterND`, `GatherElements`, `TopK`, and one kernel
    does all of them. Bilinear interpolation is a tent that vanishes beyond one pixel, so at
    integer positions it is exactly a one-hot:

        tent(t)   = relu(1, sqrt(t*t))         |t| the long way: Abs is not in the operator set
        out[i]    = sum_k data[k] * tent(idx, k)

    That moves the index out of the ADDRESS and into a MULTIPLIER, which is the whole trick: the
    compiler refuses data-dependent addressing, not data-dependent arithmetic. Proved in
    `weftspun/lean-deform-exact`, six theorems, zero admitted goals.

    **Three shapes the compiler refuses, learned by hitting each.** Implicit rank-3 broadcasting
    (`operands could not be broadcast together with shapes (104,) (52,)`). `.expand`, which torch
    lowers to `Expand` plus `ConstantOfShape`/`Equal`/`Where` scaffolding. And `Reshape` used as a
    view (`UnsupportedShuffleLayerError`). When an index is a compile-time constant it never
    needed to be a tensor dimension: emit one small block per slot and `Concat`. More nodes, all
    of them measured passing.

    **Watch the numerics, not just the parse.** `max(a,b) = (a+b+|a-b|)/2` cancels
    catastrophically
    when operands differ in magnitude, a `-1e30` padding sentinel returned `0.0` instead of
    `3.0`, and the error is about `eps * max(|a|,|b|)` absolute, so at float32 a large sentinel
    alone costs ~1e-3. And an `eps` inside `sqrt(t*t + eps)` biases the weight by `sqrt(eps)` at
    the knot: `1e-12` cost a part per million and removing it improved agreement a millionfold.

    **Every rewrite ships a negative control that must fail.** An offset outside the clamp, a
    fractional index, a sentinel of the wrong magnitude, a tie-break ramp too large or too small.
    Without one, a rewrite that agrees with whatever it is handed proves nothing.
    """

    details "Reporting", ~S"""
    `num_windows` is a real compatibility switch, not a default to inherit:
    `RFDETRKeypointPreviewConfig.num_windows` is 2, which exports the 868-node graph the DFC
    refuses; at 1 it is 825 nodes and clears the operator set. Cost is 1.35x wall-clock.

    Pair every physical measurement with a household object, per the workspace rule, and state
    what was NOT measured, no schedule, no cycle count, no device, rather than letting a parse
    be read as a deployment.
    """

    drafted_by :ai
  end
end
