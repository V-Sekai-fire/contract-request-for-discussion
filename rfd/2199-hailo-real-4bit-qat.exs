# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2199. `mix rfd.render` renders rfd/2199-hailo-real-4bit-qat/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2199 do
  use RFD.DSL

  rfd 2199, "Real 4-bit QAT with Hailo as target hardware" do
    state :discussion

    feature "real QAT loop producing int4 weights, compiled and deployed on Hailo, filling the PR #256/#257 gap"

    scope "int4 only, end-to-end training loop to Hailo HEF"

    preamble ~S"""
    Parked 2026-09-04 for two reasons the same day. First: Hailo USB firmware stuck in bootloader
    from a partial update; operator parked rather than requiring admin recovery. Second: the
    ViT-base BN backbone accuracy delta measured 4.57% under the on-device pipeline — too large to
    ship — and the vendor fork the measurement ran under cannot be published, so the on-device QAT
    path at this backbone is not viable. Un-park requires firmware recovery, a resolved BN
    measurement on a publishable backbone, and a named use case. See `[[hailo-ugen300-shelved]]`
    and `logbook-rfd-2199-vit-base-bn-pick-provenance.md`.
    """

    decision ~S"""
    Build real 4-bit QAT infrastructure with Hailo as the deployment target. Int4 only. Int8 QAT
    is not the fallback. If Hailo hardware or the DFC toolchain does not support int4 weights,
    this RFD terminates with that finding and the operator picks the next target (different NPU
    vendor, GPU-only int4 QAT via Torchao, or wait for the field).

    Model choice deferred to the first spike. **First spike:** verify Hailo int4 support.
    **Loop:** fake-quant forward, STE backward, single quantized ckpt (Torchao
    `Int4WeightOnlyQuantizer` or custom STE). **Model priority:** small mtmd first; workspace
    target after.
    """

    problem ~S"""
    PR #256 blocks bnb NF4 + post-quantization fine-tuning. PR #257 blocks PTQ. The compliant
    shape has no framework support for our generative models; the only real-QAT FOSS today is
    Gemma 4 QAT (language-only). This RFD closes that gap.
    """

    related ~S"""
    RFD 2186, RFD 2198, PR #256, PR #257, `[[hailo-ugen300-shelved]]`.
    """

    drafted_by :ai
  end
end
