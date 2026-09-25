# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2167. `mix rfd.render` renders rfd/2167-maskscore-voice-reward-distillation/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2167 do
  use RFD.DSL

  rfd 2167, "Voice-clone reward-model distillation" do
    state :discussion

    flight_level :l1

    feature "distill the wavlm_cos + voxtral_wer scoring signal from
RFD 2164.3 into a fast reward model usable in RL fine-tuning of voice
models. Parallels EditScore for image edits."

    scope "`6-datasource/anny-render-corpus`"

    preamble ~S"""
    **Shelved 2026-09-02:** 2167.1/.2 need GPU time not budgeted; rented
    compute is blocklisted. Nothing on the Rung 1 queue depends on this.
    """

    decision ~S"""
    Train a small reward model that predicts our composite score from
    raw audio, then freeze it as the reward signal for RL fine-tuning.

      base       Gemma-4-12B QAT Q4_0 (Apache-2.0, already local)
      training   pairwise ranking on 150 rank pairs from RFD 2164
      input      (reference_audio, target_text, candidate_audio)
      output     scalar reward; ~50 ms per pair on MPS
      loss       Bradley-Terry on the 10-rank ladders

    Same Gemma serves image + voice reward roles (subsumes the parked
    Qwen3-VL -> Gemma swap).
    """

    problem ~S"""
    The 10-rank voice-clone ladder from RFD 2164.2 has a real gradient
    (measured: identity 0.92 -> pitch-shift 0.70 -> wrong subject 0.75 on
    wavlm_cos; canonical 0.07 WER -> wrong text 1.94), but the scoring
    path is too slow to serve as an RL reward. Voxtral inference takes
    5-10s per candidate on MPS; standard RL loops want ~10k rollouts per
    epoch, or >24 hours per epoch just for reward computation.
    """

    related ~S"""
    Spine: urn:oid:1.3.6.1.4.1.66606.1.1.1173 (MaskScore).
    Consumes: urn:oid:1.3.6.1.4.1.66606.1.2.2164.
    """

    drafted_by :ai
  end
end
