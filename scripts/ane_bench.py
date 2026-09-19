# SPDX-License-Identifier: Apache-2.0 OR MIT
"""What the Apple Neural Engine can address, and what precision buys once it can.

WHY THIS EXISTS. `rfd1122-plan.usda`'s M2Pro scope ends in two booleans:

    custom bool neuralEngineReachableViaOnnx = 1
    custom bool neuralEngineUsefulForBackbone = 0

The second is backed by 1685.1 ms at 576 against the CPU's 476.4, measured through ONNX
Runtime's CoreML execution provider. That provider PARTITIONS a graph and falls back
per operator, and the run recorded no placement. So the number cannot distinguish "ran
on the Neural Engine and was slow" from "never reached the Neural Engine at all", and
those have opposite consequences. This script measures placement first and refuses to
report a latency without it.

THE QUESTION THIS ANSWERS FIRST, AND WHY PRECISION COMES SECOND. If the device can address
the whole 32 GiB of unified memory, then four bits against eight against sixteen is not
a fitting problem and there is nothing to trade -- the part computes in fp16 either way,
so fp16 is both what fits and the native width. Precision becomes a lever only if the
ceiling binds below what we deploy. `--ceiling` therefore runs before `--ladder`, at
fp16 AND at int4, because WHERE the two sweeps stop is what says which kind of limit it
is: the same parameter count means an address-space or graph limit that precision cannot
move, and int4 reaching further means a byte limit that it can.

METHOD FOR PLACEMENT. `MLComputePlan` reports, per operation, which device Core ML
prefers. Constants carry no device and are excluded from the denominator -- counting
them would let a graph of mostly weights look well-placed no matter where the arithmetic
went. The fraction reported is over real operations only, and the const count is printed
beside it rather than hidden.

METHOD FOR TIMING. Best-of and median over repetitions, after a warm-up that is
discarded, because the first prediction pays for lazy compilation and weight staging.
A coefficient of variation accompanies every median: on a fanless-adjacent part a tight
median with a wide spread is a thermal story, not a throughput one.

WHAT A NUMBER HERE DOES NOT MEAN. A synthetic convolution stack is a friendly shape.
It is an upper bound on what a real graph reaches, in the same way `gpu_tops.py`'s dense
GEMM is an upper bound for that device, and it should be read as one.

THE NEGATIVE CONTROL SHIPS WITH THE GATE. `--selftest` asserts that the detector reports
ZERO Neural Engine operations for a configuration known not to use it. A placement gate
that has never returned "no" certifies nothing, which is the defect this script exists
to correct in the first place.
"""

import argparse
import collections
import json
import os
import platform
import shutil
import statistics
import subprocess
import sys
import tempfile
import time

import numpy as np
import torch

from convstack import ConvStack, conv_stack_macs
import torch.nn as nn

import coremltools as ct
from coremltools.models.compute_plan import MLComputePlan

# The device names MLComputePlan returns, shortened for a table. Kept as a mapping
# rather than string-slicing the class name, because a rename upstream should break
# loudly here instead of silently producing a column nobody recognises.
# Which Core ML compute-unit set a run is confined to. Named here so a comparison
# between devices runs THE SAME GRAPH on each rather than comparing a convolution
# stack on one against a dense GEMM on another, which measures the two kernels'
# authors as much as the two devices.
UNIT_CHOICES = {
    "all": ct.ComputeUnit.ALL,
    "ane": ct.ComputeUnit.CPU_AND_NE,
    "gpu": ct.ComputeUnit.CPU_AND_GPU,
    "cpu": ct.ComputeUnit.CPU_ONLY,
}

DEVICE_SHORT = {
    "MLNeuralEngineComputeDevice": "ane",
    "MLGPUComputeDevice": "gpu",
    "MLCPUComputeDevice": "cpu",
}


def machine():
    """A timing without the machine is not a measurement -- `scripts/README.md`."""
    chip = subprocess.run(
        ["/usr/sbin/sysctl", "-n", "machdep.cpu.brand_string"],
        capture_output=True, text=True).stdout.strip()
    mem = int(subprocess.run(["/usr/sbin/sysctl", "-n", "hw.memsize"],
                             capture_output=True, text=True).stdout.strip())
    cores = ane_core_count()
    return (f"{chip}, {mem / 1024**3:.0f} GiB unified, {cores}-core ANE, "
            f"macOS {platform.mac_ver()[0]}, coremltools {ct.__version__}")


def ane_core_count():
    """Read the core count off the device rather than off a spec sheet (rule 6)."""
    from coremltools.models.compute_device import MLComputeDevice, MLNeuralEngineComputeDevice
    for d in MLComputeDevice.get_all_compute_devices():
        if isinstance(d, MLNeuralEngineComputeDevice):
            return d.total_core_count
    return 0


def ane_power_state():
    """The sudo-free corroboration: H11ANEIn's power state, 0 idle against MaxPowerState 1.

    This is a second opinion on MLComputePlan, not a replacement for it. It says the
    block powered up during the window, not which operations ran there, and another
    process on the machine can raise it. Treated as corroboration only, and reported
    beside the plan rather than instead of it.
    """
    out = subprocess.run(["/usr/sbin/ioreg", "-c", "H11ANEIn", "-r"],
                         capture_output=True, text=True).stdout
    for line in out.splitlines():
        if "DevicePowerState" in line:
            for tok in line.split('"DevicePowerState"='):
                digits = "".join(c for c in tok[:4] if c.isdigit())
                if digits:
                    return int(digits)
    return -1


def rss_bytes():
    """Current resident size of this process, for the load-expansion question.

    NOT the whole story and said so where it is used: weights staged into an
    ANE-managed allocation need not appear in this process's RSS. The number bounds
    what the host pays and does not bound what the device does.
    """
    out = subprocess.run(["/bin/ps", "-o", "rss=", "-p", str(os.getpid())],
                         capture_output=True, text=True).stdout.strip()
    return int(out) * 1024 if out else -1


def dir_bytes(path):
    total = 0
    for root, _, files in os.walk(path):
        for f in files:
            total += os.path.getsize(os.path.join(root, f))
    return total


def convert(module, example, precision, deployment=None):
    """Trace, convert, and compress to the named precision.

    fp16 is the baseline and the ANE's native compute width. int8 and the two int4
    forms are WEIGHT compression: coremltools writes narrow weights and Core ML decides
    when to widen them. Which of those it does on this part is exactly what `--footprint`
    measures, and it gets measured here.
    """
    deployment = deployment or ct.target.macOS15
    traced = torch.jit.trace(module.eval(), example)
    mlmodel = ct.convert(
        traced,
        inputs=[ct.TensorType(name="x", shape=example.shape)],
        convert_to="mlprogram",
        compute_precision=ct.precision.FLOAT32 if precision == "fp32" else ct.precision.FLOAT16,
        minimum_deployment_target=deployment,
    )
    if precision in ("fp16", "fp32"):
        return mlmodel

    from coremltools.optimize.coreml import (
        OptimizationConfig, OpPalettizerConfig, OpLinearQuantizerConfig,
        palettize_weights, linear_quantize_weights)

    if precision == "int8":
        cfg = OptimizationConfig(global_config=OpLinearQuantizerConfig(
            mode="linear_symmetric", dtype="int8", granularity="per_channel"))
        return linear_quantize_weights(mlmodel, config=cfg)
    if precision == "int4":
        cfg = OptimizationConfig(global_config=OpPalettizerConfig(
            mode="kmeans", nbits=4, granularity="per_tensor"))
        return palettize_weights(mlmodel, config=cfg)
    if precision == "int4-group":
        cfg = OptimizationConfig(global_config=OpPalettizerConfig(
            mode="kmeans", nbits=4, granularity="per_grouped_channel", group_size=32))
        return palettize_weights(mlmodel, config=cfg)
    if precision == "int4-linear":
        cfg = OptimizationConfig(global_config=OpLinearQuantizerConfig(
            mode="linear_symmetric", dtype="int4", granularity="per_block", block_size=32))
        return linear_quantize_weights(mlmodel, config=cfg)
    raise ValueError(f"unknown precision {precision!r}")


def placement(mlpackage_path, compute_units=ct.ComputeUnit.ALL):
    """Per-operation device assignment, with constants excluded from the denominator.

    Returns (counts, const_count, total_real). `MLComputePlan` needs a COMPILED model:
    handed an .mlpackage it aborts the process with an ios_base failure rather than
    raising, which is why the compile step is here and not left to a caller.
    """
    loaded = ct.models.MLModel(mlpackage_path, compute_units=compute_units)
    compiled = loaded.get_compiled_model_path()
    plan = MLComputePlan.load_from_path(compiled, compute_units=compute_units)

    counts = collections.Counter()
    unreported = collections.Counter()
    consts = 0
    program = plan.model_structure.program
    if program is None:
        raise RuntimeError("model has no mlprogram structure; nothing to place")
    for op in program.functions["main"].block.operations:
        if op.operator_name == "const":
            consts += 1
            continue
        usage = plan.get_compute_device_usage_for_mlprogram_operation(op)
        if usage is None:
            # Named rather than pooled. An anonymous "unreported" bucket in the
            # denominator silently deflates the ANE fraction, and the reader cannot
            # tell a weight-decompression op -- which is expected to carry no device
            # -- from arithmetic that failed to place.
            unreported[op.operator_name] += 1
            counts["unreported"] += 1
            continue
        name = type(usage.preferred_compute_device).__name__
        counts[DEVICE_SHORT.get(name, name)] += 1
    return counts, consts, sum(counts.values()), unreported


def ane_fraction(counts, total):
    return (counts.get("ane", 0) / total) if total else 0.0


def bench(mlmodel, example, reps=30, warmup=5):
    """Median and best of `reps`, after discarding `warmup`.

    The warm-up is discarded rather than averaged in because the first prediction pays
    for lazy compilation and weight staging, which is a one-time cost being reported as
    a steady-state one if it is left in.
    """
    x = example.numpy().astype(np.float32)
    feed = {"x": x}
    for _ in range(warmup):
        mlmodel.predict(feed)
    samples = []
    p_before = ane_power_state()
    powered = p_before > 0
    for _ in range(reps):
        t = time.perf_counter()
        mlmodel.predict(feed)
        samples.append((time.perf_counter() - t) * 1e3)
        if ane_power_state() > 0:
            powered = True
    mean = statistics.fmean(samples)
    return {
        "ms_med": round(statistics.median(samples), 3),
        "ms_min": round(min(samples), 3),
        "cv": round(statistics.pstdev(samples) / mean, 4) if mean else 0.0,
        "reps": reps,
        "ane_powered": powered,
    }


def save_tmp(mlmodel, tmpdir, tag):
    path = os.path.join(tmpdir, f"{tag}.mlpackage")
    mlmodel.save(path)
    return path




def cmd_tops(args):
    """Achieved throughput on the Neural Engine, against its published peak.

    THE CONVENTION IS `gpu_tops.py`'S. A fused multiply-add counts as two operations, so
    FLOPs = 2 * MACs, because that is what a derived peak assumes and mixing the two makes a
    device look twice as good or twice as bad as it is.

    WHY THIS MATTERS BEYOND THIS MACHINE. The UGen300 comparison needs a ratio of achieved to
    peak that was measured on a real neural accelerator rather than assumed. The logbook's
    standing convention divides by 40 TOPS INT4 at an ASSUMED 30% and says plainly to treat
    that as a ranking and not a budget. This measures the assumption on the one NPU that is
    here, so the Hailo prediction carries a number somebody observed.

    A CONVOLUTION STACK IS A FRIENDLY SHAPE, so this is an upper bound on what a real graph
    reaches, exactly as the dense GEMM is for the GPU.
    """
    print(f"machine: {machine()}")
    print(f"compute units: {args.units}   precision: {args.precision}")
    print(f"peak cited: {args.peak_tops} TOPS")
    print()
    header = (f"{'width':>6} {'depth':>6} {'size':>5} {'GMAC/inf':>10} {'ms med':>9} "
              f"{'TFLOP/s':>9} {'of peak':>8} {'on-dev':>7}  placement")
    print(header)
    print("-" * len(header))

    best = 0.0
    rows = []
    for width in args.widths:
        tmp = tempfile.mkdtemp(prefix="ane_tops_")
        example = torch.rand(1, 3, args.size, args.size)
        model = ConvStack(width=width, depth=args.depth)
        macs = conv_stack_macs(width, args.depth, args.size)
        try:
            units = UNIT_CHOICES[args.units]
            pkg = save_tmp(convert(model, example, args.precision), tmp, f"t{width}")
            counts, consts, total, _ = placement(pkg, units)
            # The fraction that matters is the fraction on the device being CLAIMED.
            # Gating a GPU run on its ANE fraction would reject every row.
            want = {"all": "ane", "ane": "ane", "gpu": "gpu", "cpu": "cpu"}[args.units]
            frac = (counts.get(want, 0) / total) if total else 0.0
            loaded = ct.models.MLModel(pkg, compute_units=units)
            timing = bench(loaded, example, reps=args.reps)
            tflops = (2 * macs) / (timing["ms_med"] / 1e3) / 1e12
            # A rate is only the DEVICE's rate if the work ran on the device. A row that
            # slipped to the GPU is reported and excluded from the best, rather than
            # quietly raising or lowering the headline number.
            if frac >= 0.99:
                best = max(best, tflops)
            rows.append({"width": width, "gmac": macs / 1e9, "ms": timing["ms_med"],
                         "tflops": tflops, "frac": frac, "units": args.units,
                         "placement": dict(counts)})
            print(f"{width:>6} {args.depth:>6} {args.size:>5} {macs / 1e9:>10.2f} "
                  f"{timing['ms_med']:>9.3f} {tflops:>9.3f} "
                  f"{tflops / args.peak_tops:>8.3f} {frac:>7.3f}  {dict(counts)}")
        except Exception as exc:
            print(f"{width:>6} {args.depth:>6} {args.size:>5} {macs / 1e9:>10.2f} "
                  f"{'-':>9} {'-':>9} {'-':>8} {type(exc).__name__}: {str(exc)[:40]}")
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    print()
    print(f"best fully-on-{args.units} rate: {best:.3f} TFLOP/s "
          f"= {best / args.peak_tops:.1%} of the {args.peak_tops} TOPS cited peak")
    print("Read as an upper bound: a 3x3 stride-1 stack is the friendliest shape this part sees.")
    if args.json:
        with open(args.json, "w") as fh:
            json.dump({"machine": machine(), "peak_tops": args.peak_tops,
                       "best_tflops": best, "rows": rows}, fh, indent=2)
        print(f"wrote {args.json}")
    return 0


def cmd_selftest(args):
    """Positive and NEGATIVE control for the placement detector.

    Rule 2: a check that passes on known-broken input is decoration. The negative
    control here is a CPU_ONLY compute unit, which cannot reach the Neural Engine by
    construction. If the detector still reports ANE operations for it, every other
    number this script prints is worthless, and the exit status says so.
    """
    tmp = tempfile.mkdtemp(prefix="ane_selftest_")
    example = torch.rand(1, 3, 64, 64)
    model = ConvStack(width=64, depth=4)
    pkg = save_tmp(convert(model, example, "fp16"), tmp, "control")

    pos_counts, pos_consts, pos_total, _ = placement(pkg, ct.ComputeUnit.ALL)
    neg_counts, neg_consts, neg_total, _ = placement(pkg, ct.ComputeUnit.CPU_ONLY)

    pos_ane = pos_counts.get("ane", 0)
    neg_ane = neg_counts.get("ane", 0)

    print(f"machine: {machine()}")
    print()
    print(f"  positive (ComputeUnit.ALL)      ane={pos_ane}/{pos_total} "
          f"{dict(pos_counts)} consts={pos_consts}")
    print(f"  negative (ComputeUnit.CPU_ONLY) ane={neg_ane}/{neg_total} "
          f"{dict(neg_counts)} consts={neg_consts}")
    print()

    problems = []
    if pos_ane == 0:
        problems.append("positive control placed NOTHING on the ANE -- the detector "
                        "cannot show a hit, so it cannot show a miss either")
    if neg_ane != 0:
        problems.append(f"negative control placed {neg_ane} operations on the ANE under "
                        "CPU_ONLY, which is impossible -- the detector is not reading "
                        "placement")
    shutil.rmtree(tmp, ignore_errors=True)

    if problems:
        for p in problems:
            print(f"FAIL: {p}")
        return 1
    print("PASS: the detector reports ANE for a graph that uses it and zero for one "
          "that cannot.")
    return 0


def cmd_ceiling(args):
    """Grow the graph until placement fails, at each precision named.

    Reports WHERE each sweep stops and why. Rule 5: this is a fixed enumerated sweep,
    not a sample, so the steps are listed rather than estimated -- and the step size is
    printed so a reader knows the resolution of the answer.
    """
    print(f"machine: {machine()}")
    print(f"precisions: {', '.join(args.precisions)}   units: {args.units}   "
          f"input: 1x3x{args.size}x{args.size}")
    print(f"widths: {args.widths}   depth: {args.depth}")
    print()
    header = f"{'precision':<12} {'width':>6} {'params':>13} {'pkg MiB':>9} {'ane frac':>9} {'placement':<28} outcome"
    print(header)
    print("-" * len(header))

    results = []
    for precision in args.precisions:
        for width in args.widths:
            tmp = tempfile.mkdtemp(prefix="ane_ceiling_")
            example = torch.rand(1, 3, args.size, args.size)
            model = ConvStack(width=width, depth=args.depth)
            params = sum(p.numel() for p in model.parameters())
            row = {"precision": precision, "width": width, "params": params}
            try:
                mlmodel = convert(model, example, precision)
                pkg = save_tmp(mlmodel, tmp, f"{precision}_{width}")
                size_mib = dir_bytes(pkg) / 1024**2
                units = UNIT_CHOICES[args.units]
                counts, consts, total, unrep = placement(pkg, units)
                # The fraction that matters is the fraction on the device being CLAIMED.
                # An ANE-centric outcome column reads a full-GPU row as a failure, which
                # is wrong when the GPU is the device under test.
                want = {"all": "ane", "ane": "ane", "gpu": "gpu", "cpu": "cpu"}[args.units]
                frac = (counts.get(want, 0) / total) if total else 0.0
                row.update(pkg_mib=round(size_mib, 1), ane_frac=round(frac, 3),
                           placement=dict(counts), unreported=dict(unrep),
                           outcome="ok" if frac >= 0.99 else f"OFF-{want.upper()}")
                print(f"{precision:<12} {width:>6} {params:>13,} {size_mib:>9.1f} "
                      f"{frac:>9.3f} {str(dict(counts)):<28} {row['outcome']}")
            except Exception as exc:
                msg = f"{type(exc).__name__}: {str(exc)[:60]}"
                row.update(outcome="FAILED", error=msg)
                print(f"{precision:<12} {width:>6} {params:>13,} {'-':>9} {'-':>9} "
                      f"{'-':<28} {msg}")
            finally:
                shutil.rmtree(tmp, ignore_errors=True)
            results.append(row)

    if args.json:
        with open(args.json, "w") as fh:
            json.dump({"machine": machine(), "rows": results}, fh, indent=2)
        print(f"\nwrote {args.json}")
    return 0


def cmd_ladder(args):
    """Latency, size and placement per precision, on one graph and one input.

    Every row carries its own placement. A latency row whose ANE fraction is 0 is a
    CPU or GPU number wearing an ANE label, and that is the confusion this whole script
    exists to prevent -- so the column sits in the table rather than in a footnote.
    """
    print(f"machine: {machine()}")
    print(f"graph: ConvStack(width={args.width}, depth={args.depth})  "
          f"input 1x3x{args.size}x{args.size}  reps={args.reps}")
    print()
    header = (f"{'precision':<13} {'pkg MiB':>9} {'ms med':>9} {'ms min':>9} {'cv':>7} "
              f"{'ane frac':>9} {'powered':>8}  placement")
    print(header)
    print("-" * len(header))

    rows = []
    for precision in args.precisions:
        tmp = tempfile.mkdtemp(prefix="ane_ladder_")
        example = torch.rand(1, 3, args.size, args.size)
        model = ConvStack(width=args.width, depth=args.depth)
        try:
            mlmodel = convert(model, example, precision)
            pkg = save_tmp(mlmodel, tmp, precision)
            size_mib = dir_bytes(pkg) / 1024**2
            counts, consts, total, unrep = placement(pkg)
            frac = ane_fraction(counts, total)
            loaded = ct.models.MLModel(pkg, compute_units=ct.ComputeUnit.ALL)
            timing = bench(loaded, example, reps=args.reps)
            row = {"precision": precision, "pkg_mib": round(size_mib, 1),
                   "ane_frac": round(frac, 3), "placement": dict(counts),
                   "unreported": dict(unrep), **timing}
            rows.append(row)
            print(f"{precision:<13} {size_mib:>9.1f} {timing['ms_med']:>9.3f} "
                  f"{timing['ms_min']:>9.3f} {timing['cv']:>7.4f} {frac:>9.3f} "
                  f"{str(timing['ane_powered']):>8}  {dict(counts)}")
        except Exception as exc:
            print(f"{precision:<13} {'-':>9} {'-':>9} {'-':>9} {'-':>7} {'-':>9} "
                  f"{'-':>8}  {type(exc).__name__}: {str(exc)[:50]}")
            rows.append({"precision": precision, "error": f"{type(exc).__name__}: {exc}"})
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    if args.json:
        with open(args.json, "w") as fh:
            json.dump({"machine": machine(), "rows": rows}, fh, indent=2)
        print(f"\nwrote {args.json}")
    return 0


def cmd_footprint(args):
    """Does a narrow model widen when it loads?

    The mechanism behind the ceiling answer. If a 4-bit package expands to fp16 at
    load, four bits buys disk and neither memory nor bandwidth, and precision cannot
    move a ceiling expressed in bytes.

    THE CAVEAT IS PART OF THE RESULT: process RSS need not include weights staged into
    an ANE-managed allocation, so a flat RSS falls short of proving nothing widened. The
    on-disk column and the RSS column are both reported and neither is called the
    answer on its own.
    """
    print(f"machine: {machine()}")
    print(f"graph: ConvStack(width={args.width}, depth={args.depth})")
    print()
    header = f"{'precision':<13} {'pkg MiB':>9} {'RSS delta MiB':>14} {'ratio to fp16 pkg':>18}"
    print(header)
    print("-" * len(header))

    base_pkg = None
    for precision in args.precisions:
        tmp = tempfile.mkdtemp(prefix="ane_fp_")
        example = torch.rand(1, 3, args.size, args.size)
        model = ConvStack(width=args.width, depth=args.depth)
        try:
            pkg = save_tmp(convert(model, example, precision), tmp, precision)
            size_mib = dir_bytes(pkg) / 1024**2
            if base_pkg is None:
                base_pkg = size_mib
            before = rss_bytes()
            loaded = ct.models.MLModel(pkg, compute_units=ct.ComputeUnit.ALL)
            loaded.predict({"x": example.numpy().astype(np.float32)})
            after = rss_bytes()
            delta = (after - before) / 1024**2
            print(f"{precision:<13} {size_mib:>9.1f} {delta:>14.1f} "
                  f"{size_mib / base_pkg:>18.3f}")
            del loaded
        except Exception as exc:
            print(f"{precision:<13} {'-':>9} {'-':>14} {type(exc).__name__}: {str(exc)[:40]}")
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = ap.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("selftest", help="positive and negative control for placement")
    s.set_defaults(func=cmd_selftest)

    c = sub.add_parser("ceiling", help="grow the graph until placement fails")
    c.add_argument("--precisions", nargs="+", default=["fp16", "int4"])
    c.add_argument("--widths", nargs="+", type=int,
                   default=[64, 128, 256, 512, 768, 1024, 1536, 2048])
    c.add_argument("--depth", type=int, default=8)
    c.add_argument("--size", type=int, default=64)
    c.add_argument("--json")
    c.add_argument("--units", choices=sorted(UNIT_CHOICES), default="all")
    c.set_defaults(func=cmd_ceiling)

    l = sub.add_parser("ladder", help="latency and size per precision")
    l.add_argument("--precisions", nargs="+",
                   default=["fp16", "int8", "int4", "int4-group", "int4-linear"])
    l.add_argument("--width", type=int, default=256)
    l.add_argument("--depth", type=int, default=8)
    l.add_argument("--size", type=int, default=64)
    l.add_argument("--reps", type=int, default=30)
    l.add_argument("--json")
    l.set_defaults(func=cmd_ladder)

    f = sub.add_parser("footprint", help="does a narrow model widen at load")
    f.add_argument("--precisions", nargs="+", default=["fp16", "int8", "int4"])
    f.add_argument("--width", type=int, default=512)
    f.add_argument("--depth", type=int, default=8)
    f.add_argument("--size", type=int, default=64)
    f.set_defaults(func=cmd_footprint)

    t = sub.add_parser("tops", help="achieved throughput against the cited peak")
    t.add_argument("--widths", nargs="+", type=int, default=[128, 256, 512, 768])
    t.add_argument("--depth", type=int, default=8)
    t.add_argument("--size", type=int, default=128)
    t.add_argument("--reps", type=int, default=20)
    t.add_argument("--precision", default="fp16")
    t.add_argument("--peak-tops", type=float, default=15.8)
    t.add_argument("--units", choices=sorted(UNIT_CHOICES), default="all")
    t.add_argument("--json")
    t.set_defaults(func=cmd_tops)

    args = ap.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
