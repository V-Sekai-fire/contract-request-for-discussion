# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 1043. `mix rfd.render` renders rfd/1043-qwen-image-edit/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD1043 do
  use RFD.DSL

  rfd 1043, "Model image for qwen_q4_k_m_image_edit" do
    state :discussion

    feature "model packaging"

    attest_in :none

    decision ~S"""
    Ship Q4_K_M only. Never build a bf16 variant of this model image.

    At 0.55 bytes per parameter it needs 14.85 GB, and not 54.0 GB. That
    one choice saves 39.15 GB, which RFD 1027 records as the largest
    single saving in the catalog.

    See `DETAILS.md` for the model's memory and license, the `predict()`
    interface, and the open question on quantization quality.
    """

    problem ~S"""
    Qwen image edit is the largest model in the catalog at 27.0 B
    parameters. In bf16 it needs 54.0 GB, which is 46 percent of the whole
    catalog on its own.

    The model id already names the format. It ships Q4_K_M, and the
    catalog entry records that choice in its name.
    """

    related ~S"""
    RFD 1027 selects the format and records the saving. RFD 1026 gives
    the row. RFD 1028 clears Apache 2.0.
    """

    details_title "Model image for qwen_q4_k_m_image_edit"

    details "The model", ~S"""
    | Property   | Value                     |
    | ---------- | ------------------------- |
    | Parameters | 27.0 B, published         |
    | bf16       | 54.0 GB, never built      |
    | Q4_K_M     | 14.85 GB, the ship format |
    | License    | Apache 2.0                |

    The count covers the edit backbone and the vision language encoder
    that reads the instruction. The encoder is not optional, because the
    instruction is text while the edit is spatial.
    """

    details "The interface", ~S"""
    | Input       | Type  | Default |
    | ----------- | ----- | ------- |
    | image       | Path  | none    |
    | instruction | str   | none    |
    | strength    | float | 0.8     |
    | steps       | int   | 20      |
    | seed        | int   | -1      |

    `instruction` is a sentence, and not a tag list. "Make the jacket red"
    works. "jacket, red" does not, because the encoder reads language.
    """

    details "The quality question stays open", ~S"""
    No measurement compares Q4_K_M against bf16 for this model. The saving
    is certain, and the quality cost is not.

    Measure before the catalog depends on it. Run 20 edits in each format,
    and compare them by eye. RFD 1027 permits both formats, thus a bf16
    build stays legal if the measurement demands it.
    """

    drafted_by :ai
  end
end
