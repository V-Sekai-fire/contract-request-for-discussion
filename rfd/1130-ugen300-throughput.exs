# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 1130. `mix rfd.render` renders rfd/1130-ugen300-throughput/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD1130 do
  use RFD.DSL

  rfd 1130, "What the UGen300 actually delivers" do
    state :discussion

    feature "edge throughput measurement"

    scope "`3-interactor/rf-detr-cpp`"

    attest_in :none

    decision ~S"""
    Measure the device, once the two questions before it have answers.
    RFD 1128 asks whether four bits are survivable and RFD 1129 asks
    whether the operators compile. Throughput measured on a model that
    fails either is a number about nothing.

    Report three quantities rather than one rate: time to first output,
    which includes transfer; steady-state rate once transfer amortises;
    and transferred bytes per inference, which separates a resident model
    from a streaming one and predicts other hardware.

    Compare against the 3090 on the same input, saying plainly that it is
    a workstation card against a USB stick. The point is not which wins,
    but what the accelerator costs and buys.

    See `DETAILS.md` for the rig and the confounds. `SKILL.md` gives the
    procedure.
    """

    problem ~S"""
    The ASUS UGen300 is a Hailo-10H behind USB 3.1 Gen2. Two numbers are
    published and neither is the one that matters: the accelerator's
    compute, and the bus at 10 Gbps, about 1.2 GB/s.

    What a pipeline gets is neither, because a USB accelerator pays for
    every crossing. Resident weights cost nothing per frame and streaming
    weights cost everything, and which happens depends on whether the
    model fits 8 GB after quantisation. No measurement here has said.
    """

    related ~S"""
    RFD 1128 and RFD 1129 come first. RFD 1122 is the goal, and its
    detector is what ships to this device.
    """

    details_title "What the UGen300 actually delivers"

    details "The device", ~S"""
    ASUS UGen300: Hailo-10H, 8 GB LPDDR4, USB 3.1 Gen2 at 10 Gbps.
    Frameworks accepted are Keras, TensorFlow, TensorFlow Lite, PyTorch
    and ONNX, which in practice means a graph the Dataflow Compiler maps.

    8 GB is the number that decides everything else. At bf16 the Pixal3D
    checkpoints are 24.045 GB and nothing fits. At four bits they are
    about 6 GB and the weights can stay resident, which turns the bus from
    a per-inference cost into a one-off.
    """

    details "The three quantities", ~S"""
    | quantity                  | why it is not the others                     |
    | ------------------------- | -------------------------------------------- |
    | time to first output      | includes transfer, and is what a user feels   |
    | steady-state rate         | excludes it, and is what a batch job gets     |
    | transferred bytes         | predicts behaviour on a different bus         |

    A single "frames per second" hides which of the three it came from,
    and the three diverge by more than an order of magnitude on a USB
    device.
    """

    details "First measurements, 2026-08-29", ~S"""
    `efficientnet_lite0.hef`, single context, DFC 5.3.0, on the UGen300 over USB. Apparatus:
    `hailortcli benchmark` and `hailortcli run2 --measure-latency --measure-overall-latency`
    for the rates, and `hailo/rung3_shim.py` for the controlled input.

        steady-state rate         ~1168 FPS   (1177.4 / 1174.0 / 1153.9, spread 2%)
        HW latency, NN core          2.27 ms
        overall latency              3.95 ms
        transferred bytes         150,528 in, 1,000 out per inference
        chip temperature           38.7, 41.7 C

    **The third quantity is the answer to the question this RFD was written to ask.** Overall
    minus hardware is **1.68 ms of USB crossing per inference**, 43% of end-to-end latency. It
    amortises under pipelining, 1168 FPS is 0.86 ms per frame against 3.95 ms for a lone
    frame, so the bus is a latency cost and not a throughput cost at this model size. A
    resident model pays it once per frame for the activations, not per weight.

    At 1168 FPS the input traffic alone is 1168 x 150,528 = **176 MB/s**, against the bus's
    ~1.2 GB/s. So this model leaves the bus 85% idle, and the "streaming weights cost
    everything" case has not been reached at 4.7 MB of HEF.
    """

    details "THE FIRST PORT WAS STARVING THE DEVICE, AND EVERY EARLIER NUMBER WOULD HAVE BEEN WRONG",
            ~S"""
            On the port it was first plugged into, `hailortcli` warned:

                [HailoRT] [warning] USB-C source electrical current advertised: 1.5A.
                The module may run in reduced-performance mode.

            Moving it to a USB4 dock re-enumerated it from `usb/001:001` to `usb/001:009` and the
            warning stopped. Every figure above was taken after the move.

            **The evidence is the absence of the firmware's own flag, not a power reading**, and
            the
            distinction is worth keeping. Neither direct route works: `measure-power` fails with
            `HAILO_OPEN_FILE_FAILURE(13)`, and `monitor`, whose help promises "on H10, presents
            performance and health stats", reports it "is not supported on Windows". So
            temperature is
            the only proxy available, and **this RFD should not promise a power figure it cannot
            take.**

            **The comparison that would have priced the limit is gone.** No throughput was taken
            at
            1.5A before the move, so the cost of the power limit is unmeasured and only
            recoverable by
            plugging back in on purpose.

            **Backfilled 2026-08-29: throughput at 1.5A now exists, and it is the same.** A frame
            ladder
            of raw uint8 transport, a 1x1 convolution, so the compute is negligible, leaving the
            number as
            the link, was run at pipeline depth 4 across three different ports, each advertising
            1.5A:

                frame    in MB   out MB   ms/frame   frames/s   MB/s
                512p      1.05     0.26      4.83       207       272
                720p      3.69     0.92     15.75        63       293
                1080p     8.29     2.07     33.59        29       302
                4K       33.18     8.29    144.80         7       286

            The link plateaus at ~285-300 MB/s and holds there across a 32x range of frame sizes,
            and
            across `usb/004:013`, `usb/001:001` and `usb/004:001` the 4K figure reproduced to
            within
            0.07%. So the 1.5A ports do not differ from each other, and the ~176 MB/s this RFD
            measured
            for the keypoint model sits comfortably under that ceiling, which is why that model
            never
            felt the limit. **The power question is still open**: every port reached on this desk
            advertised 1.5A, so a run at 3.0A remains untaken and the plateau is a 1.5A number
            until one
            is. What is now closed is the within-1.5A comparison the paragraph above called
            unrecoverable.

            **Two software knobs that did not move it.** `HAILO_POWER_MODE_ULTRA_PERFORMANCE` and
            `VDevice::dma_map` on the caller's frame buffer were each measured at 4K, depth 4,
            against a
            baseline: 145.8 ms, ultra 146.2 ms, DMA-mapped 144.1 ms, both 146.7 ms, all within
            1.5%,
            which is noise. The bounce copy DMA mapping removes is a 33 MB `memcpy` at 25.7 GB/s,
            1.29 ms,
            0.9% of a frame's 145 ms. At this link speed the copy is not the cost, so zero-copy
            transport
            buys under one percent and its value here is multi-process topology, not throughput.

            **Pipelining is where the bus idle time converts to rate.** Queueing frames through
            `run_async` instead of one synchronous call climbed 724 -> 2094 FPS on a 16 KB block,
            2.89x,
            and flattened exactly at the device's own reported async queue depth of 32. That
            isolates
            ~0.9 ms of the 1.38 ms single-shot latency as USB round trip, the same crossing this
            RFD
            priced at 1.68 ms for the larger keypoint frame.
            """

    details "The controlled-input path needed a shim, and the flat C API does not work on H10",
            ~S"""
            `hailortcli` generates its own random inputs and dumps no outputs, so it cannot answer
            whether a host-side change reaches the device. HailoRT's flat C API is exported and
            binds
            cleanly, all 17 declarations in `hailo/hailort.sigs` resolve against `libhailort.dll`
            --
            and the Hailo-10H **rejects it**:

                hailo_init_configure_params_by_vdevice -> HAILO_NOT_IMPLEMENTED(7)
                [HailoRT] [error] Did you try calling create_configure_params on H10?
                                  If so, use InferModel instead

            `InferModel` returns `Expected<std::shared_ptr<InferModel>>`, which ctypes cannot
            call, and
            the DLL exports no `extern "C"` entry points for it, 245 mangled C++ symbols and no
            flat
            ones. `hailo_platform`, Hailo's Python bindings, are not on PyPI and are not shipped
            with
            the HailoRT 5.3.2 Windows install: `lib/` holds `libhailort.lib` and cmake files only.

            So `hailort_shim.cpp` wraps `InferModel` in six `extern "C"` functions, declared in
            `hailort_shim.sigs` and bound by `sigs_ctypes.py`, the same declarative-ABI convention
            this workspace uses for `iceoryx2.sigs` and `openvr_api.sigs`. 178 KB, built with
            clang++
            against `libhailort.lib`.

            With it, on `efficientnet_lite0`:

                different inputs   -> different outputs, so the device computes on what is sent
                same input twice   -> bit-identical, deterministic
                undersized buffer  -> refused, status 2
            """

    details "A host-side change reaches the device, which is what a scoring loop needs", ~S"""
    Three HEFs of one architecture, compiled from authored ONNX:

        variant   kernels sha         conv1 out_scale   device output
        base      58710ab3776b8531        6.44e-05      mean 85.989
        weights   1c35cff027a49580        6.72e-05      mean 79.814
        scale     f8830de2b0930035        1.79e-04      mean 84.769

    **base against weights: 7,946 of 8,192 output bytes differ**, and a rerun of base is
    bit-identical. So author -> DFC -> HEF -> silicon -> a score the host can read is closed,
    and an on-device evaluation loop has a foundation.

    **The scale row is confounded and is recorded rather than used.** `force_range_out` moved
    conv1's scale 2.8x as asked, but the kernel hash changed too: the optimiser re-derives
    weight quantisation, bias correction and its distillation pass against the new range. So
    forcing a range is not a scale-only perturbation, which matters to anything built on QZO --
    see `logbook-dfc-emulation-contexts-disagree.md`.

    Compile cost, for anything that recompiles per generation: **optimize 12.9-15.9 s, compile
    4.5-5.0 s** for a two-conv graph, and **8.7 s** to compile a 131k-parameter stack.
    """

    details "Confounds worth naming before they are discovered", ~S"""
    **Thermal.** A USB stick has a small thermal budget. A rate measured
    over ten seconds and a rate measured over ten minutes are different
    numbers, and the second is the one that matters.

    **Host contention.** USB 3.1 Gen2 is shared. A measurement taken while
    the same controller carries anything else is not a measurement of the
    device.

    **Cold caches.** The first inference includes compilation, allocation
    and transfer. Report it separately rather than averaging it away.
    """

    details "What the comparison is for", ~S"""
    The 3090 will win on rate and lose on power, and neither fact is
    interesting on its own. The comparison exists so somebody can decide
    where a stage runs, which needs the cost of moving data to it stated
    beside the rate.
    """

    details "What is not measured here", ~S"""
    Accuracy. RFD 1128 owns that, and mixing the two produces a table
    where a fast wrong answer looks good.
    """

    drafted_by :ai
  end
end
