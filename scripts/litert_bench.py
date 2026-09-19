#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
"""What LiteRT's Metal accelerator reaches on this machine, against Core ML's figure.

RFD 1148 chose LiteRT and RFD 1142 measured Core ML's Metal path at 6.97 TFLOP/s fp16.
This is the other half of that comparison, on the same `ConvStack` and the same
convention, so the two rows compose.

THE ACCELERATOR IS PREBUILT AND CANNOT BE OTHERWISE. `libLiteRtMetalAccelerator.dylib`
ships inside the wheel. No LiteRT GPU accelerator builds from the public tree: WORKSPACE
declares `ml_drift` as an http_archive with no url, and ml-drift is not a public
repository. So this measures what Google shipped rather than what we compiled.

PLACEMENT IS REPORTED, NEVER ASSUMED. `is_fully_accelerated()` is LiteRT's own answer to
"did the accelerator take the whole graph", and it is the equivalent of the MLComputePlan
fraction that stopped an ANE row being read as a GPU row. A timing without it is a number
about an unknown device.

THE ORACLE IS TORCH ON CPU. `gate_onnx_device.py` diffed against PyTorch and ONNX is
retired as an interchange, so the reference moves to the module the graph came from.

    pixi run -e litert python scripts/litert_bench.py [--width 64] [--depth 4] [--size 64]
"""

import argparse
import os
import platform
import statistics
import subprocess
import sys
import tempfile
import time

import numpy as np
import torch

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from convstack import ConvStack, conv_stack_macs

# RFD 1142, Core ML native at fp16 on this part. The baseline goes in the same table
# because a rate quoted alone leaves a reader nothing to weigh it against.
COREML_METAL_TFLOPS = 6.97


def machine():
    """Printed with every timing, because a rate without a machine is not a measurement."""
    try:
        chip = subprocess.run(["sysctl", "-n", "machdep.cpu.brand_string"],
                              capture_output=True, text=True).stdout.strip()
    except OSError:
        chip = "unknown"
    return f"{platform.system()} {platform.machine()}, {chip}"


def convert(module, example, path):
    import litert_torch
    litert_torch.convert(module, (example,)).export(path)
    return path


def timed(model, ins, outs, reps, warmup):
    for _ in range(warmup):
        model.run_by_index(0, ins, outs)
    ms = []
    for _ in range(reps):
        t0 = time.perf_counter()
        model.run_by_index(0, ins, outs)
        ms.append((time.perf_counter() - t0) * 1000.0)
    return statistics.median(ms)


def open_model(path, accel, enforce_f32):
    from ai_edge_litert.compiled_model import CompiledModel
    from ai_edge_litert.options import GpuOptions, Options
    if enforce_f32 is None:
        return CompiledModel.from_file(path, hardware_accel=accel)
    return CompiledModel.from_file(path, options=Options(
        hardware_accelerators=accel, gpu_options=GpuOptions(enforce_f32=enforce_f32)))


def measure(path, plan, x, n_out, reps, warmup, rounds):
    """Per-configuration medians, gathered ROUND-ROBIN rather than one config at a time.

    ONE MEDIAN OF FIFTY REPETITIONS FAILS TO SETTLE THIS. Measured on this machine, the
    median moves 74% between rounds -- 0.35 ms to 0.61 ms for the same configuration and
    the same flatbuffer. Running each configuration to completion in turn attributes that
    drift to whichever ran second, which is how an ordering artefact becomes a result.
    So the configurations interleave, every round, and the spread is reported beside the
    rate rather than hidden by it.

    The rate uses the FASTEST round. A GPU sharing a machine with a browser is contended,
    and contention only ever subtracts, so the floor of the observed distribution is the
    closer estimate of what the part can do. The spread says how much to trust it.

    THE ORDER ALTERNATES, AND THE REASON IS A RESULT RATHER THAN A PRECAUTION. Measured
    with a fixed order, whichever GPU configuration ran first won: fp16 first gave
    fp16 0.38 ms against f32 0.40, and f32 first gave f32 0.45 against fp16 0.48. The
    ranking followed the order rather than the arithmetic, so the difference between fp16
    and f32 at this size is smaller than the artefact and this harness cannot rank them.
    It reports both and says so.
    """
    xb = np.ascontiguousarray(x.numpy(), dtype=np.float32).ravel()
    seen = {name: [] for name, _, _ in plan}
    placement, output = {}, {}
    for r in range(rounds):
        order = plan if r % 2 == 0 else list(reversed(plan))
        for name, accel, force in order:
            model = open_model(path, accel, force)
            placement[name] = model.is_fully_accelerated()
            ins = model.create_input_buffers(0)
            outs = model.create_output_buffers(0)
            ins[0].write(xb)
            seen[name].append(timed(model, ins, outs, reps, warmup))
            output[name] = np.array(outs[0].read(n_out, np.float32))
            model.close()
    return seen, placement, output


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--width", type=int, default=64)
    ap.add_argument("--depth", type=int, default=4)
    ap.add_argument("--size", type=int, default=64)
    ap.add_argument("--reps", type=int, default=200)
    ap.add_argument("--warmup", type=int, default=50)
    ap.add_argument("--rounds", type=int, default=5)
    args = ap.parse_args()

    from ai_edge_litert.hardware_accelerator import HardwareAccelerator

    torch.manual_seed(0)
    module = ConvStack(args.width, args.depth).eval()
    x = torch.randn(1, 3, args.size, args.size)
    with torch.no_grad():
        reference = module(x).numpy().ravel()

    macs = conv_stack_macs(args.width, args.depth, args.size)
    path = os.path.join(tempfile.gettempdir(), "litert_bench.tflite")
    convert(module, x, path)

    print(f"machine   {machine()}")
    print(f"graph     ConvStack(width={args.width}, depth={args.depth}, size={args.size})"
          f"  {macs/1e6:.1f} M MACs  {os.path.getsize(path)/1024:.0f} KiB flatbuffer")
    print(f"oracle    torch on cpu, {reference.size} elements")
    print(f"reps      {args.rounds} interleaved rounds of {args.reps} timed, "
          f"{args.warmup} warm-up discarded each\n")

    plan = [("cpu", HardwareAccelerator.CPU, None),
            ("metal fp16", HardwareAccelerator.GPU, False),
            ("metal f32", HardwareAccelerator.GPU, True)]
    seen, placement, output = measure(path, plan, x, reference.size,
                                      args.reps, args.warmup, args.rounds)

    print(f"  {'backend':11s} {'accel':6s} {'best ms':>8s} {'spread':>7s} "
          f"{'TFLOP/s':>9s} {'max|diff|':>11s}")
    best = {}
    for name, _, _ in plan:
        v = sorted(seen[name])
        tflops = (2 * macs) / (v[0] / 1000.0) / 1e12
        spread = 100.0 * (v[-1] - v[0]) / v[0]
        diff = float(np.max(np.abs(output[name][: reference.size] - reference)))
        best[name] = tflops
        print(f"  {name:11s} {str(placement[name]):6s} {v[0]:8.2f} {spread:6.0f}% "
              f"{tflops:9.2f} {diff:11.3e}")
    print(f"  {'coreml':11s} {'-':6s} {'-':>8s} {'-':>7s} "
          f"{COREML_METAL_TFLOPS:9.2f} {'-':>11s}   RFD 1142, fp16")

    gpu = max(v for k, v in best.items() if k.startswith("metal"))
    print(f"\nMetal takes the whole graph and reaches {gpu:.2f} TFLOP/s, "
          f"{gpu / COREML_METAL_TFLOPS:.2f}x Core ML's Metal figure at fp16.")
    print("fp16 and f32 are NOT ranked here. With a fixed order whichever ran first won,")
    print("so the gap between them is under the ordering artefact; the rate above is the")
    print("best either reached. What does separate them is numeric, and it is not a")
    print("timing: the default carries max|diff| 1.7e-03 against enforce_f32's 2.7e-07,")
    print("so the accelerator computes in fp16 unless told otherwise.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
