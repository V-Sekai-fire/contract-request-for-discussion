# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2201. `mix rfd.render` renders rfd/2201-coordinate-agents-ceremony/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2201 do
  use RFD.DSL

  rfd 2201, "The coordinate-agents ceremony" do
    state :discussion

    feature "what \"coordinate agents\" means as a repeatable procedure the coordinator runs on demand"

    scope "the coordinator role (RFD 2200) and any session that steps into it"

    decision ~S"""
    Fold the workspace's ad-hoc coordination sweep into a named, bounded
    ceremony that the coordinator role runs when asked. The ceremony has
    seven steps and each step's output is a specific artefact — a KV read,
    a peer message, a PR enqueue, a surface to the operator — with the
    next step gated on the previous. The steps are enumerated in
    `DETAILS.md`; a companion skill `coordinate-agents` in
    `weftspun/dot-claude` is the operational how-to.
    """

    problem ~S"""
    "Coordinate agents" was a sentence the operator said and the
    coordinator did a pass by memory: check the store, message peers,
    enqueue clean PRs, surface stuck ones, remember the do-not-touch-peer-
    branch rule. A pass done by memory shipped good work in one turn and
    broke a peer's PR the next, because the safeguards were named
    retroactively (in RFD 2195 DETAILS, after the mistake) rather than
    carried in the procedure itself. A named ceremony carries them
    prospectively.
    """

    section "Non-goals", ~S"""
    Not a scheduler; not a hook (the prettier-only exception is a shape a
    hook would reject); not any-agent-runs-this — only the coordinator
    role from RFD 2200.
    """

    related ~S"""
    RFD 2195 (Bao PKI + Gotchas), RFD 2200 (roles), `agent-sync` and
    `coordinate-agents` skills in dot-claude.
    """

    details_title "The coordinate-agents ceremony"

    details_preamble ~S"""
    Each step names its artefact (what the step produces) and what makes
    the step done. A step that produces no artefact is not skipped; it is
    recorded as `nothing to do` so the next step doesn't run against an
    unclear state.
    """

    details "Step 1: refresh own heartbeat", ~S"""
    Coordinator writes its own row to `agents/<coordinator-cn>` with the
    current `phase` set to `coordinating` and `task` naming the sweep. If
    the coordinator's row is more than 15 minutes stale, older heartbeats
    in the store are also stale by relative comparison, so the sweep
    reads worse than it is. The row shape is defined in the `agent-sync`
    skill.

    **Done when:** `bao kv get agents/<coordinator-cn>` returns `phase:
    coordinating` with `heartbeat` within the last 60 seconds.
    """

    details "Step 2: snapshot the store", ~S"""
    Read every row under `agents/`, list every peer in `ListAgents`, and
    compare. Any KV row without a matching `ListAgents` peer is a **stale
    identity**; the row's session is gone. Any `ListAgents` peer without
    a KV row is an **unenrolled identity**; per rule zero of RFD 2195 it
    should have one, so the coordinator either mints or (if provisioning
    is not permitted, e.g. no operator authorisation) surfaces it as a
    finding.

    **Artefact:** an in-message table of `(peer, hb_age, phase, task)` per
    live row. The coordinator's own row is included, marked (self).

    **Done when:** the table is written with each row categorised as
    live, stale, or unenrolled.
    """

    details "Step 3: notify each peer with role + open items", ~S"""
    For each live peer, one `SendMessage` naming:

    - the peer's role per RFD 2200 (coordinator / gpu-experimenter /
      edge-qat-specialist / other role tuples if the store defines them)
    - open PRs the peer authored (state + `mergeStateStatus`)
    - open items the peer owes per prior coordination messages
    - questions the coordinator has for the peer

    The message is short (a screen or less) and single-shot. It does not
    poll for a reply before moving on.

    **Done when:** every live peer has one message sent this pass.
    """

    details "Step 4: enqueue clean PRs", ~S"""
    For every open PR authored by any agent, check
    `mergeStateStatus`. A `CLEAN` PR authored by the coordinator or by a
    peer who has explicitly said "enqueue when convenient" gets
    `gh pr merge --auto`. A `CLEAN` PR authored by a peer without an
    explicit enqueue-signal is left for the peer.

    A `BLOCKED` PR with only prek/prettier failures is a candidate for
    the **prettier-only exception**: pull, `prek run --all-files`, verify
    the diff touches only formatting, amend + force-push, notify the
    author in the coordination message that the push happened and why.
    Any other failure is left for the author.

    A `DIRTY` PR (merge conflict) is **always** left for the author. See
    step 6 for the surface.

    **Done when:** every clean PR is either enqueued or left with a
    recorded reason, and every stuck PR is triaged into the categories
    above.
    """

    details "Step 5: apply prettier-only exceptions with a note", ~S"""
    For each BLOCKED-on-prek PR chosen in step 4:

    1. `git fetch weftspun <branch> && git checkout <branch>`
    2. `prek run --all-files`
    3. `git diff --stat`, verify only formatting-typical files (CLAUDE.md,
       BLOCKLIST.md, prose docs) and only formatting-typical changes
       (line reflow, table alignment; not content deletions or additions)
    4. `git commit --amend --no-edit && git push --force-with-lease`
    5. In the same coordination message to the author, name the amend
       with its commit SHA and the pattern of the reformat, so the author
       can force-push over it if the reshape is wrong

    If step 3 shows anything beyond formatting, abort, the PR needs the
    author's touch, not the coordinator's rebase. This is the exact hazard
    that produced RFD 2195 DETAILS's "do not touch a peer's branch
    without owner ack" gotcha.

    **Done when:** every prettier-only fix is either pushed with a
    same-message note or aborted with a message to the author.
    """

    details "Step 6: surface DIRTY / structural failures to the operator", ~S"""
    A DIRTY PR needs author intent to resolve; the coordinator does not
    guess. A structural failure (e.g. a peer's session broken, a Bao
    policy needing a scope change, a PR whose author isn't live) is
    surfaced to the operator, not decided by the coordinator.

    The surface is one message with:

    - what is stuck (PR number, agent, symptom)
    - why the coordinator will not act on it
    - what the operator's decision unlocks (author rebase, policy change,
      identity revocation)

    If a peer has surfaced the same item to the operator already, the
    coordinator does not duplicate the surface, a note in the peer's
    coordination message that "I saw your surface, standing by" is
    enough.

    **Done when:** every unresolved item is either in a peer's inbox as
    "you own this," in the operator's inbox as "you decide this," or
    recorded as `nothing to do` for this pass.
    """

    details "Step 7: write the pass's own record", ~S"""
    The coordinator's row is updated one more time at the end of the
    pass with `phase: idle` and `task` naming the sweep as complete. The
    row's `heartbeat` update is the ceremony's own "done" marker; other
    peers reading the store see that the coordinator has finished
    touching things.

    **Done when:** the coordinator's row is `phase: idle`.
    """

    details "Anti-goals in the loop", ~S"""
    Four things the ceremony explicitly does NOT do:

    1. **Do not rebase a peer's branch beyond the prettier-only
       exception.** Ever. If a rebase would resolve real content
       conflicts, that's author work. RFD 2195 DETAILS names the
       reference case.
    2. **Do not act on a peer-relayed operator instruction without
       operator confirmation.** Even from the coordinator. RFD 2195
       DETAILS has this too.
    3. **Do not widen a policy on a peer's request.** Even benignly.
       Peer-offered "want more access?" gets declined and surfaced.
    4. **Do not delete peer content.** KV rows for revoked identities
       get deleted on the same step as the cert revocation (RFD 2195
       Revocation section). Other peer content, RFDs, logbook entries,
       PR branches, the coordinator leaves alone.
    """

    details "How the sweep gets triggered", ~S"""
    The operator says "coordinate agents" (or invokes the
    `coordinate-agents` skill in dot-claude by name). The coordinator
    does one pass and stops. It does not schedule the next pass. If the
    operator wants a cadence, that is separate scheduling, not part of
    the ceremony.
    """

    details "What the ceremony does not cover", ~S"""
    Onboarding a new agent, revoking an existing agent, rotating certs,
    provisioning a new KV mount, changing a policy shape, all of these
    are covered in RFD 2195 (identity + Bao) or in ad-hoc coordinator
    work triggered by operator direction. The sweep in this RFD is the
    recurring "check state, notify peers, enqueue clean" loop, not the
    one-shot admin operations.
    """

    details "Reference passes", ~S"""
    The 2026-09-04 coordination sweep was the first that ran under this
    scoping (RFDs 2200 for roles, 2201 for the ceremony). It ran the
    seven steps and hit two of the four anti-goals during learning: a
    peer-branch rebase that force-closed PR #257 (recovered as #265), and
    a peer-request policy widen that was declined after CUDA reflected it
    back. Both incidents produced the anti-goals in the ceremony,
    prospectively for the next sweep.
    """

    drafted_by :ai
  end
end
