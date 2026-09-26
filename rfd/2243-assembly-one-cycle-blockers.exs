# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2243. `mix rfd.render` renders rfd/2243-assembly-one-cycle-blockers/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2243 do
  use RFD.DSL

  rfd 2243, "one assembly cycle already completes; the blockers are on the replacement" do
    compact_head true

    state :discussion

    feature "the enumeration of what blocks one `gitassembly` cycle
from completing, parked as a record. The measured answer inverts the
question: a git-assembler cycle completes unattended today. What
remains blocked is the Elixir reimplementation, and separately the
correctness of a tree that a completing cycle does not check."

    scope "`4-entities/entities-assembly` (`gitassembly`,
`update_godot_v_sekai.exs`, `lib/assembler/`), the
`V-Sekai-fire/egit` fork, and `entities-godot`'s
`.github/CODEOWNERS` as assembled"

    decision ~S"""
    Operator, 2026-09-10, answering "which cycle should the blockers
    be enumerated for": *"please park as a rfd"*, and, for the bar
    the Elixir replacement has to clear, *"Byte-identical tree vs
    git-assembler"*.

    So this RFD parks the enumeration rather than opening work. Each
    fix lands as its own change with its own control.

    `DETAILS.md` carries the measurements.
    """

    related ~S"""
    - RFD 2242 (ggml consumers as native Godot modules), whose six
      module branches are 6 of the 31 merged in the cycle measured
      here. `feat/module-ggml` through `feat/module-skin-tokens`
      form a strict linear stack, so their large file overlaps are
      stack redundancy rather than contention.
    - The archived-org sweep, which retired
      `v-sekai-multiplayer-fabric` off redirects. Seven CODEOWNERS
      lines in the assembled tree still name a team in that org,
      so the sweep did not reach the assembled output.
    - `thirdparty/git-assembler`, GPLv3, the implementation being
      replaced. The repository is MIT and our modification
      (`dac60d5`) inherits GPLv3.
    """

    details_title "one assembly cycle already completes; the blockers are on the replacement"

    details "What was measured", ~S"""
    Four cycles ran on 2026-09-10. The last produced
    `main/fabric-0.1.0` at `af5dc1898d`, tagged
    `v2026.09.10.1818-main-fabric-0.1.0`.

        first-parent merges, all authored 09-10 11:18      31
        declared refs in `gitassembly` present in result    32 of 32
        non-merge commits touching `.github/CODEOWNERS`      0
        conflict-marker lines in CODEOWNERS / .gitignore     0 / 0
        wall clock for the merge phase                    ~10 s

    Zero non-merge commits touching CODEOWNERS is the load-bearing
    number. It is what rules out a hand resolution having been
    folded in, which is the way a cycle usually appears to have
    completed when it did not.

    Both claims are re-runnable:

        git log --first-parent --merges --format=%h af5dc1898d | head -31
        git show af5dc1898d:.github/CODEOWNERS | grep -E '^/' \
          | awk '{print $1}' | sort | uniq -d
    """

    details "The prediction that disagreed, and why it was wrong", ~S"""
    Before the run was checked, a full 325-pair sweep of
    `git merge-tree <mergebase> <a> <b>` over the 26
    non-stack-redundant branches predicted 69 conflicting pairs: 66
    on `.github/CODEOWNERS` across 12 branches that each append a
    block at the identical EOF anchor, and 3 on `.gitignore`. It
    forecast the first stop at merge 7 and roughly 13 to 17
    stoppages overall.

    The executed run stopped zero times. The forecast is recorded
    here rather than dropped, because the gap between the two is
    the useful part.

    Three ways the sweep measured something other than the cycle:

    1. It merges each pair against the *common* base. The cycle
       merges each branch against the *accumulated* target, which
       already carries the earlier blocks.
    2. The three-arg form does no rename detection, so a
       rename colliding with another branch's edit is invisible to
       it in the other direction too.
    3. Pairwise conflict is an upper bound. It says nothing about
       how an earlier resolution absorbs a later one.

    This is rule 1 of How Work Is Verified. The pairwise sweep was
    the readable proxy; the sequential run was the quantity.
    """

    details "What a completing cycle still gets wrong", ~S"""
    The twelve CODEOWNERS blocks merged into a clean union with no
    markers. Clean is not the same as correct.

    Five paths are owned twice in the assembled file:

        /modules/http3/
        /modules/lasso/
        /modules/open_telemetry/
        /modules/speech/
        /modules/sqlite/

    CODEOWNERS is last-match-wins, so a duplicate silently hands
    ownership to whichever copy the merge happened to place second.
    Nothing in the pipeline reads this file back, so the defect
    survives a green cycle intact.

    Seven lines still name
    `@v-sekai-multiplayer-fabric/multiplayer-fabric`, a team in the
    archived org.

    The bar the operator set for the Elixir replacement is a
    byte-identical tree against git-assembler. Both defects above
    would be reproduced byte-for-byte by an implementation that
    clears that bar, which is what the bar is for: it measures
    parity, not correctness, and the two are separate questions.
    """

    details "Blockers that remain, all on the replacement path", ~S"""
    `lib/assembler/config.ex` and `lib/assembler/graph.ex` are
    written and at oracle parity with git-assembler on the real
    31-dep config, 7 synthetic configs, and 9 invalid configs.
    Unwritten: `git.ex`, `state.ex`, `node_update.ex`, `cli.ex`,
    `workflow.ex`.

    The larger blocker is `egit`, the Apache-2.0 libgit2 NIF the
    replacement sits on. An audit found 22 defects. By severity:

    - `git_merge.hpp:31-45`. Fast-forward moves the branch ref with
      no `git_checkout_tree`, so index and worktree keep the old
      tree, and it returns `{ok, fast_forward}`. Silent history
      corruption.
    - `git_branch.hpp:138-139`. A `git_branch_create` failure has no
      `return` and falls through to `ATOM_OK`. Every failure
      reports success.
    - `git_branch.hpp:112-125`. `overwrite` is read inside the tuple
      branch, so a bare atom raises badarg. With the defect above,
      a branch can never be repointed.
    - `git_checkout.hpp:52-56`. The return of
      `git_annotated_commit_from_ref` is discarded and `GIT_OK`
      returned regardless, which NULL-dereferences at `:172`. A NIF
      crash takes the BEAM down, unlike today's subprocess
      boundary.
    - `git_status.hpp:168-179`. `GIT_STATUS_CONFLICTED` is in
      neither mask, so a conflicted repository returns `#{}` and is
      indistinguishable from a clean one.
    - Not exported at all: current branch and HEAD, repository
      state (merge, rebase or bisect in progress), `reset/3`, and
      any worktree support whatsoever. `git_worktree` appears
      nowhere in the NIF. That last one blocks the full-parity
      worktree decision outright.

    Already fixed on `V-Sekai-fire/egit`, each with a control that
    fails without it: merge commits recording only HEAD as a parent,
    the `operation->exec` null-deref in rebase, and the missing
    `rebase_commit` export.
    """

    details "Two decisions recorded so they are not reopened", ~S"""
    **Fork-point needs no reflog.** `needs_rebase` only needs the
    boolean `tip(base) != fork_point`, which reduces to:

        needs_rebase(dst, base) == not is_ancestor(tip(base), dst)

    When `tip` is an ancestor of `dst`, git can return only `tip` or
    NULL; when it is not, git can return only some `fp` unequal to
    `tip`, or NULL. It never returns a different definite answer, so
    the ancestry test cannot flip the boolean. It loses git's
    occasional NULL, and the one risky direction is a spurious
    rebase, which is wasteful rather than wrong.

    **rerere is not implemented.** It is unset locally, in the work
    clone and globally, with an empty `rr-cache`, so
    `--rerere-autoupdate` and its conflict retry are already no-ops
    here. On conflict the replacement reports the conflicted paths
    and stops, which is what happens today. The failure message has
    to say rerere was not replayed, otherwise enabling it later
    silently does nothing.
    """

    details "Verification", ~S"""
    1. `python scripts/check-rfd-structure.py`. Reads its state
       list and README line limit out of RFD 1000, so a wrong state
       atom or an over-long head fails here rather than in review.
    2. `python scripts/check_rfd_canary.py`, then the negative
       control: the same check against a copy with `drafted_by :ai`
       removed has to fail. A canary that has never rejected a
       stripped file has not been shown to reject one.
    3. `python scripts/check_anti_entropy.py`, for the serial
       register against what is on disk. Read what it reports
       rather than its last line.
    4. `python scripts/check_tropes.py --base origin/main` and
       `python scripts/check_commit_style.py --base origin/main`.
    5. The two commands under "What was measured". Re-running them
       is how a reader checks this document instead of trusting it.
    """

    drafted_by :ai
  end
end
