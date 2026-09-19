# Logbook: what the Neural Engine reaches, and what it holds

RETRACTED THE SAME DAY: "the Neural Engine has no total-size ceiling". It has one, at
exactly 2 GiB. The claim came from stopping a sweep at 1.7 GiB and from reading a shape
control too broadly: the control disproved a 1.5 GiB total limit, and it was written up
as showing no total limit existed. Continuing the sweep with small tensors and more
depth finds the wall at 2^31 bytes. The per-tensor cap near 224 MiB stands unchanged.

Question: the plan is sequenced around an 8 GiB, 40 TOPS INT4 USB part. Can the Mac already
in the room run the same work, and at what precision.

Apparatus: `scripts/ane_bench.py`, subcommands `selftest`, `ceiling`, `tops`, `ladder`,
`footprint`. One machine: Apple M2 Pro, 32 GiB unified, 16-core ANE (`ane,t8020`, arch `h14g`,
`ANEVersion` 128.1), macOS 26.5.2, coremltools 9.0, torch 2.11.0 CPU. Environment is
`pixi.toml`'s `ane` feature, which is new: this repository's gates had a `requirements.txt`
and no environment to install it into.

Every Hailo figure below is DERIVED from `rfd1122-plan.usda` and none was observed. No
UGen300 is attached to this machine. RFD 1130 exists to replace those rows with measurements
and this entry does not do that.

## The measurement that had to come first

`logbook-edge-npu-and-the-anny-forward.md` records CoreML at 1685.1 ms against the CPU's
476.4 at 576, 0.28x, outside the port's 4.2e-03 bound, and concludes the Neural Engine is
"REACHABLE ... and not useful for this model". That run went through ONNX Runtime's CoreML
provider, which partitions and falls back per operator, and it logged no placement.

So the figure is consistent with two opposite worlds: the device ran the graph slowly, or the
graph never reached the device. `MLComputePlan` distinguishes them per operation, and the
first thing built here was the control that proves the distinction is being read:

    positive (ComputeUnit.ALL)      ane=8/8   {'ane': 8}   consts=28
    negative (ComputeUnit.CPU_ONLY) ane=0/8   {'cpu': 8}   consts=28

Two costs paid to get there. `MLComputePlan` requires a COMPILED model and does not raise
when handed an `.mlpackage` — it aborts the process from libc++. And constants carry no
device, so leaving them in the denominator lets a graph of mostly weights look well placed
wherever the arithmetic went.

## 13.583 TFLOP/s, 86.0% of the cited peak

Convolution stacks, 3x3 stride-1, FLOPs counted as `2 * MACs` — `gpu_tops.py`'s convention,
so these compose with the GPU rows already in the plan.

    width   GMAC/inf   ms med    TFLOP/s   of 15.8 peak   ANE fraction
    128       16.97      6.484     5.234   0.331          1.000
    256       67.76     15.339     8.835   0.559          1.000
    512      270.81     45.887    11.803   0.747          1.000
    768      609.15     89.694    13.583   0.860          1.000
    1024    1082.78    168.062    12.886   0.816          1.000
    1536    2435.93    371.910    13.100   0.829          1.000
    2048    4330.23   1319.102     6.565   0.416          1.000

A 3x3 stride-1 stack is the friendliest shape this part sees, so 86% is an upper bound and
not a promise, exactly as `gpu_tops.py` says of its own GEMM figure.

The last row is the one to keep. At width 2048 the rate halves while placement stays at
1.000 — the work is on the device and running at half speed, with 72 MiB per weight tensor,
well inside the cap below. Throughput degrades before placement does, so a placement check
falls short of a health check.

## The ceiling is per-tensor, and a width sweep alone gets it wrong

Growing width at depth 8 put the cliff between 1543.7 MiB and 1599.3 MiB of fp16 weights,
16/16 operations dropping to 1/16. Read alone that says the device holds about 1.5 GiB. The device holds no
such ceiling: the limit is per-tensor. Holding parameters near constant and changing shape moves the cliff:

    depth  width   params        pkg MiB   ANE fraction
    8      3584    809,392,640   1543.7    1.000
    8      3648    838,554,816   1599.3    0.062
    32     1704    810,263,928   1545.3    1.000
    32     1800    904,123,800   1724.3    1.000

A larger model passed where a smaller one failed. The control is a two-layer graph, small in
total and large in one tensor:

    depth  width   one weight   total MiB   ANE fraction
    2      3584    220.5 MiB    220.7       1.000
    2      3648    228.4 MiB    228.6       0.250
    2      4096    288.0 MiB    288.2       0.250

Same boundary at a seventh of the total. The limit is a single weight tensor between 220.5
and 228.4 MiB. 224 MiB sits inside that bracket and is a guess at a round number, not a
measurement: the sweep resolution is one width step.

Bryngelson's _Apple Neural Engine_ (arXiv 2606.22283) documents a per-axis extent cap of
16384; these weights are `[3648, 3648, 3, 3]` and are nowhere near it. Searching found the
reason it goes undocumented — Apple does not publish the internal buffer limits.

## And a second ceiling, at exactly 2 GiB

Small tensors, growing depth, so the per-tensor cap stays far away at 55.6 MiB each:

    depth  width   weights MiB   ops   ANE fraction
    36     1800    1946.8         72   1.000
    37     1800    2002.4         74   1.000
    38     1800    2058.0         76   0.000
    40     1800    2169.3         80   0.000
    64     1800    3504.1        128   0.000

2^31 bytes is 2,147,483,648, and the passing and failing rows bracket it at 2,099,520,000
and 2,157,840,000. Bytes rather than operation count: depth 32 at width 2020 carries
2171.5 MiB in 64 operations and fails, while depth 36 at width 1800 carries 1946.8 MiB in
72 operations and passes. It fails wholesale — placement goes to 0.000 and the whole graph
moves to the GPU together.

## The same graph on Metal

    width   GMAC/inf   ms med    TFLOP/s   placement
    512      270.81     80.472     6.731   {'gpu': 16}
    768      609.15    174.665     6.975   {'gpu': 16}
    1024    1082.78    311.664     6.948   {'gpu': 16}
    1536    2435.93    719.915     6.767   {'gpu': 16}

6.98 against the Neural Engine's 13.58 on the same stack, 1.95x, and corroborating
`gpu_tops.py`'s 6.20 fp16 from dense GEMM by a different route. The GPU ran the 3504.1 MiB
stack the Neural Engine refused, so above 2 GiB this machine still executes at half rate.

## The comparison, at one precision

RETRACTED, AND THE RETRACTION IS THE POINT. This section first tabled "memory: 32 GiB
unified" against the device's 8 GiB and concluded the Mac had "four times the memory".
That is backwards. The quantity that decides placement is what the ENGINE accepts, and
the Neural Engine accepts 2 GiB. Against the UGen300's 8 GiB the Mac's Neural Engine has
a QUARTER of the memory, not four times it. The error came from reading a machine's
unified pool as an accelerator's working set, and it survived a full draft.

Compared at one precision, fp16, because both parts choose their precision and a
comparison across two of them measures the choice rather than the hardware.

|                  | M2 Pro ANE        | M2 Pro Metal          | Hailo-10H / UGen300     |
| ---------------- | ----------------- | --------------------- | ----------------------- |
| fp16 rate        | 13.58 TFLOP/s     | 6.98 TFLOP/s          | ~10 TOPS, halved        |
| of cited peak    | 0.86 of 15.8      | 1.03 of the 6.8 fp32  | not measured, no device |
| weights it holds | 2 GiB, measured   | >= 8176.2 MiB         | 8 GiB nominal           |
| per-tensor cap   | ~224 MiB measured | none found            | unknown                 |
| host bandwidth   | ~200 GB/s         | ~200 GB/s             | USB 3.1 Gen2, ~1.2 GB/s |
| device half, 576 | 121.6 ms, FAILS   | 62.0 ms, inside bound | not measured            |
| power            | UNMEASURED, sudo  | UNMEASURED            | 2.5 W typical           |

On the synthetic stack the Neural Engine is the faster engine, 13.58 against 6.98. On the
graph we ship it loses at 121.6 ms against 62.0 and misses the port's bound by ten times.
A benchmark shape chosen for an accelerator flatters it, and reporting only the synthetic
row would have said something the measurement does not.

RFD 1128's premise still makes the memory axis concrete, corrected: Pixal3D is 24.045 GB
in bf16 and about 6 GB at four bits. Neither fits the Neural Engine's 2 GiB at any
precision this part computes in. Metal holds 8176.2 MiB, so the fp16 route on this machine
runs through the GPU, and CLAUDE.md now blocklists the Neural Engine as an execution
target on that basis.

## What stays open, and waits on hardware

The UGen300 side. Its fp16 rate is halved from the 20 TOPS INT8 row rather than measured,
the part is not attached to this machine, and RFD 1130 exists to replace those rows once it
arrives. Every Hailo figure above predicts rather than reports.

Metal's ceiling above 8176.2 MiB. The sweep stopped at the device's 8 GiB because that is
the quantity under comparison, not because Metal refused.

Power on both Mac engines. `powermetrics --samplers ane_power` needs sudo and stayed unrun.

An `int4-linear` row, which would close the four-bit question cheaply.

## Four bits, briefly, and why the ladder was dropped

Core ML does store four-bit weights: 126.0 MiB against fp16's 504.1 at 264M parameters, a
clean quarter. The graph gains eight `ios18.constexpr_lut_to_dense` operations carrying no
device, and the sixteen arithmetic operations stay where they were. The int4 and int8-int8
fast paths arrived with A17 Pro and M4; this is an M2. Four bits buys disk and adds
decompression.

Whether it buys capacity depends on which engine is being fitted. Against the Neural
Engine's 2 GiB a quarter is meaningful; against Metal's 8176.2 MiB nothing needed
shrinking. The Neural Engine is blocklisted, so the route that remains fits at fp16
without quantising, and it stays the 8 GiB device that makes four bits compulsory.

An `int4-linear` row would close the question cheaply and was not run; `int4` k-means
clusters single-threaded and hung a sweep at 838M parameters before it was killed.

Two apparatus faults worth recording because both presented as agreement rather than as
error. A console filter removed two FAILED int4 rows, leaving six that agreed with each
other. And `scikit-learn >= 1.4` installed 1.9.0, which coremltools 9.0 refuses with
"Disabling scikit-learn conversion API" — a warning, after which palettization fails exactly
as if the package were absent. The pin now carries both ends.
