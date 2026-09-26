# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 1144. `mix rfd.render` renders rfd/1144-image-to-omnigen2/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD1144 do
  use RFD.DSL

  rfd 1144, "The image-to-OmniGen2 loop" do
    state :published

    feature "loop 2 of the four-loop plan"

    scope "`fourloops-plan.usda`"

    attest_in :none

    decision ~S"""
    Run loop 2 first among the four, and let it carry the measurements.

    **The hazard is a silent skip.** The edit instruction comes from a text
    input rather than from the filename. A filename that matches no key is
    skipped without a word, which produces a run that reports success and
    edits nothing.

    `DETAILS.md` holds what the first runs measured: what OmniGen2 costs at
    bf16 and at four bits, what EditScore costs, and what EditScore returns
    for an instruction the edit actually matched. `fourloops-plan.usda` and
    `fourloops-etnf.usda` both name that file as a source, so a quantity in
    either layer is checked against a measurement rather than against a
    recollection.
    """

    problem ~S"""
    Loop 2 is the smallest complete loop: OmniGen2 proposes an edited png,
    EditScore scores it, OmniGen2 repairs. One propose stage, one scorer,
    one repair arm, size M, and it runs second because the harness is the
    only thing it waits on.

    Being smallest makes it the one that measures the two components every
    other loop also uses, so its numbers are the plan's numbers.
    """

    related ~S"""
    RFD 1143, RFD 1145 and RFD 1146 are the other three loops. RFD 1128
    records four-bit tolerance for another model on the same card.
    """

    details_title "The image-to-OmniGen2 loop"

    details_preamble ~S"""
    Loop 2 exercises OmniGen2 and EditScore with nothing else in the way, so its
    numbers are the ones the plan layers check their quantities against. Both
    `fourloops-plan.usda` and `fourloops-etnf.usda` name this file as a source.

    Measured on the desk described in `logbook-fourloops-first-runs.md`, which holds
    the apparatus and the runs these are lifted from.
    """

    details "OmniGen2, and what four bits buys", ~S"""
    Same input, same seed, 1024 square, 30 steps:

    | precision | weights   | peak      | seconds |
    | --------- | --------- | --------- | ------: |
    | bf16      | 14.75 GiB | 17.14 GiB |     131 |
    | NF4       | 4.33 GiB  | 6.72 GiB  |     133 |

    Four bits bought memory and cost two seconds. Weights fall to 0.29 of bf16 and
    peak to 0.39, while the wall time moves from 131 to 133 seconds, which is inside
    the run-to-run spread and should be read as unchanged rather than as slower.

    That matters for a 24 GiB desk. At bf16 the peak of 17.14 GiB leaves 6.86 GiB for
    everything else in the process; at NF4 the peak of 6.72 GiB leaves 17.28. Loop 2
    fits either way and loop 4 does not, which is why the plan carries both rows
    rather than only the one it runs.

    CLAUDE.md's generated-synthetic condition 5 decides what may be done with the
    NF4 row: quantised weights produce no corpus data. So the four-bit form is a way
    to fit the loop on this desk, and never a way to make data with it. RFD 1128
    reaches the same place for a different model, and records that four bits bought
    no speed there either.
    """

    details "What EditScore costs and returns", ~S"""
    RFD 1147 holds it. Every loop scores with EditScore and only loops 2 and 3
    propose with OmniGen2, so the scorer's figures belong to the plan rather than to
    this loop. `editscoreMatchingOverall`, `editscoreNonsenseOverall`,
    `editscorePeakGib512` and `editscorePeakGib1024` all resolve there.
    """

    drafted_by :ai
  end
end
