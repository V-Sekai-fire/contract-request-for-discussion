# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2015. `mix rfd.render` renders rfd/2015-bounded-llm-steering-queue/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2015 do
  use RFD.DSL

  rfd 2015, "Bounded llm steering queue" do
    state :prediscussion

    decision ~S"""
    See `DETAILS.md` for the full argument.
    """

    problem ~S"""
    We steer an LLM by appending tasks to a queue as we go — this manuals
    session is the canonical example, with dozens of incremental requests.
    An unbounded queue overflows two scarce resources: the operator's
    personal context (you lose track of what is pending versus done) and
    the model's context window. How do we keep steering open-ended without
    overflowing either?
    """

    related ~S"""
    See `DETAILS.md` for the full argument.
    """

    details_title "Bounded llm steering queue"

    details "Context and Problem Statement", ~S"""
    We steer an LLM by appending tasks to a queue as we go, this manuals
    session is the canonical example, with dozens of incremental requests.
    An unbounded queue overflows two scarce resources: the operator's
    personal context (you lose track of what is pending versus done) and the
    model's context window. How do we keep steering open-ended without
    overflowing either?
    """

    details "Decision Drivers", ~S"""
    - Keep adding tasks freely as ideas arrive.
    - Bound what is held in volatile conversation context.
    - Never lose the record of what was decided or done.
    """

    details "Considered Options", ~S"""
    - Unbounded queue held in the conversation (status quo).
    - A hard task cap that drops tasks past a limit.
    - Externalize the queue, bound work in progress, and compact finished
      work.
    """

    details "Consequences", ~S"""
    - Good: the backlog and the record live in durable docs, not working
      memory, so the operator's attention and the model's context window
      both stay bounded.
    - Good: each finished item is findable later in the manuals.
    - Bad: it takes discipline to externalize and compact instead of holding
      everything in the conversation.
    """

    details "Confirmation", ~S"""
    At any time the conversation holds roughly one active task; completed
    work is found in the manuals (decisions and changelog) rather than the
    transcript; and the number of open PRs stays small.
    """

    details "More Information", ~S"""
    The one-concern-per-PR rule is the work-in-progress bound; the changelog and MADR practice is
    the compaction step.
    """

    drafted_by :ai
  end
end
