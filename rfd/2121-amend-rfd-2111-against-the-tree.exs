# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2121. `mix rfd.render` renders rfd/2121-amend-rfd-2111-against-the-tree/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2121 do
  use RFD.DSL

  rfd 2121, "Amend rfd 2111 against the tree" do
    state :prediscussion

    decision ~S"""
    See `DETAILS.md` for the full argument.
    """

    problem ~S"""
    Every count below comes from the GitHub API or from a checkout on
    disk, on 2026-08-16, against `repo` manifest revision `main`. Each
    claim states the command that produces it, so a later reader can
    re-run it rather than trust the number.
    """

    related ~S"""
    See `DETAILS.md` for the full argument.
    """

    details_title "Amend rfd 2111 against the tree"

    details "How this was checked", ~S"""
    Every count below comes from the GitHub API or from a checkout on disk, on
    2026-08-16, against `repo` manifest revision `main`. Each claim states the
    command that produces it, so a later reader can re-run it rather than trust the
    number.

    The renames of RFD 2111 have landed. GitHub answers the old names with the new
    ones:

    ```sh
    gh api repos/v-sekai-multiplayer-fabric/fabric-authority-plane --jq .full_name
    # v-sekai-multiplayer-fabric/interactor-authority
    gh api repos/v-sekai-multiplayer-fabric/fabric-interactor --jq .full_name
    # v-sekai-multiplayer-fabric/contract-command
    gh api repos/v-sekai-multiplayer-fabric/fabric-service-meta --jq .full_name
    # v-sekai-multiplayer-fabric/fabric
    ```
    """

    details "The prefix survives in five live names", ~S"""
    ```sh
    gh api "orgs/v-sekai-multiplayer-fabric/repos?per_page=100" --paginate --jq '.[].name' | grep
    '^fabric-'
    ```

    Fifteen names carry the prefix. The bare `fabric` is the sixteenth match for
    `^fabric` and is the name RFD 2111 frees, so it is excluded here.

    | name                          | archived | fork | reaches the convention |
    | ----------------------------- | -------- | ---- | ---------------------- |
    | `fabric-ardy`                 | no       | yes  | no, upstream name      |
    | `fabric-casync-central`       | yes      | no   | no, archived           |
    | `fabric-container-verify`     | yes      | no   | no, archived           |
    | `fabric-game-observability`   | no       | no   | yes                    |
    | `fabric-godot-assembly`       | no       | no   | yes                    |
    | `fabric-godot-packaging`      | yes      | no   | no, archived           |
    | `fabric-harness`              | no       | no   | yes, deferred by 0111  |
    | `fabric-locomotion-generator` | no       | yes  | no, upstream name      |
    | `fabric-motion-diffusion`     | no       | yes  | no, upstream name      |
    | `fabric-platform-central`     | yes      | no   | no, archived           |
    | `fabric-quickstart`           | no       | no   | yes                    |
    | `fabric-scoop-central`        | yes      | no   | no, archived           |
    | `fabric-stage-runtime`        | no       | no   | yes                    |
    | `fabric-wholebody-control`    | no       | yes  | no, upstream name      |
    | `fabric-wt-harness`           | no       | no   | yes                    |

    Five archived and four forks leave six live and owned. RFD 2111 names
    `fabric-harness` and says it becomes `contract-bus` when that pass is taken,
    which leaves five the RFD does not mention at all.

    Two of the five sit in the `repo` manifest and check out on every `repo sync`:
    `fabric-godot-assembly` and `fabric-wt-harness`. A reader of the workspace root
    sees the retired prefix on the first listing.
    """

    details "`entities-godot` is the engine", ~S"""
    ```sh
    gh api repos/v-sekai-multiplayer-fabric/entities-godot/contents --jq '[.[].name]|join(" ")'
    ```

    ```
    .clang-format .clang-tidy .clangd .editorconfig .git-blame-ignore-revs
    .gitattributes .github .gitignore .mailmap .pre-commit-config.yaml AUTHORS.md
    CHANGELOG.md CONTRIBUTING.md COPYRIGHT.txt DONORS.md LICENSE.txt README.md
    SConstruct core doc drivers editor gles3_builders.py glsl_builders.py main
    methods.py misc modules platform platform_methods.py pyproject.toml scene
    scu_builders.py servers tests thirdparty version.py
    ```

    `SConstruct`, `editor/`, `drivers/`, `platform/`, `servers/`, `modules/`, and
    `thirdparty/` are the Godot engine tree, 1 708 369 KB of C++ by the API's own
    size field. The Netflix definition of an entity is a domain object that has no
    knowledge of where it is stored. An engine that renders, builds, and ships an
    editor holds many things, and a set of such domain objects is a small part of
    none of the directories above.

    RFD 2111 defends this name in one paragraph, and the paragraph argues a different
    point: that the `core/` directory inside the repository comes from upstream and
    must keep its name. That reasoning is sound and this RFD keeps it. It says
    nothing about whether `entities-` describes the repository.

    The test RFD 2111 applies elsewhere is whether a name asserts something false.
    `fabric-service-meta` was rejected as `service-meta` because "`service-meta` would
    assert the thing that is false". `contract-command` was chosen over
    `interactor-anything` because the latter "picks the side the git repository exists
    to avoid picking". `entities-godot` fails the same test and is the seventh name
    the shape does not decide.
    """

    details "`repositories/` puts the created collision in the tree", ~S"""
    RFD 2111 renames the RFD 2028 triad in three git repositories. Those three exist
    and hold the triad, which the API confirms:

    ```sh
    for r in loot combat progression; do
      gh api "repos/v-sekai-multiplayer-fabric/$r/contents" --jq '[.[]|select(.type=="dir").name]|join(" ")'
    done
    # loot:        .github adapters core ports
    # combat:      adapters core ports
    # progression: adapters core ports
    ```

    RFD 2111 states the resolution for the word it takes from Netflix: write "git
    repository" in full, and keep "repository" alone for the interface. It chooses
    that over keeping Cockburn's "port" on the ground that "a collision in prose costs
    less than a collision in code".

    A directory named `repositories/` sits in the tree of a git repository, which is
    the place the RFD ranks as the more expensive of the two. The plural reads as a
    collection of checkouts, which is the meaning the RFD spends the section pushing
    away. The singular `repository/` reads as the interface, matches `core/` and
    `ports/` in number, and costs nothing to adopt because the rename has not run yet.

    The other two renames in that triad stand. `core/` to `entities/` and `adapters/`
    to `datasources/` carry no collision.

    Three git repositories named `loot`, `combat`, and `progression` are also absent
    from the rename list and from the `repo` manifest, and their names state no type.
    Whether the type-first convention reaches them is a question this RFD raises and
    does not answer, because the answer decides three more names.
    """

    details "The gap is two READMEs rather than five", ~S"""
    RFD 2111 says the `lean-*-core` READMEs state a hexagon layout of `core/`,
    `ports/`, and `adapters/`, that those directories do not exist, and that each of
    those git repositories holds one Lean namespace directory. The checkout disagrees
    in two of the five.

    ```sh
    for d in entities-lean-*; do
      printf '%-28s ' "$d"
      find "$d" -type d -not -path '*/.git/*' -not -name .git | sed "s|^$d/||" | tr '\n' ' '
      echo
    done
    ```

    | git repository              | the directories it holds                           |
    | --------------------------- | -------------------------------------------------- |
    | `entities-lean-combat`      | `CombatCore`                                       |
    | `entities-lean-loot`        | `r128gpu` `r128test` `parity` `LootCore` `.github` |
    | `entities-lean-progression` | `ProgressionCore`                                  |
    | `entities-lean-rebac`       | `Rebac` `Rebac/core` `Rebac/ports` `.github`       |
    | `entities-lean-shared`      | `Shared` `.github`                                 |

    `entities-lean-rebac` holds `core/` and `ports/`, one namespace directory down,
    and both carry Lean sources: `Rebac/core/NoGod.lean`, `Rebac/core/ReBAC.lean`,
    and `Rebac/ports/AuthQuery.lean`. Its README says

    >, `core/`, dependency-free domain logic + proofs
    >, `ports/`, narrow driving (source) / driven (sink) contracts

    which describes what is there. The correction it needs is the prefix `Rebac/` on
    each path, and the removal of `adapters/`, which the repository does not have.

    `entities-lean-loot` holds three directories beside `LootCore`, so "one Lean
    namespace directory" describes three of the five rather than all of them.

    Three of the five carry no README at all, which is the larger half of this gap:

    ```sh
    for d in entities-lean-*; do printf '%-28s %s\n' "$d" "$(git -C "$d" ls-files | grep -ci
    readme)"; done
    # entities-lean-combat       0
    # entities-lean-loot         0
    # entities-lean-progression  0
    # entities-lean-rebac        2
    # entities-lean-shared       1
    ```

    So RFD 2111 describes five READMEs where two exist. `entities-lean-shared` is the
    one whose layout section is wholly false: it names the triad and the repository
    holds `Shared/Types.lean` and nothing else. `entities-lean-rebac` is the one that
    needs its paths qualified, in both its top-level README and the second one at
    `Rebac/README.md`, which names an `adapters/` that is absent.

    One README to correct and one to qualify. The count in that section, and the
    sentence "Those directories do not exist", are the two claims to amend. Whether
    `combat`, `loot`, and `progression` should gain a README is a separate question
    this RFD does not answer.
    """

    details "What this RFD leaves alone", ~S"""
    The conversion table, the retirement of plane, edge plane, domain, and store
    plane, the type-first name shape, the thirty renames, and the reasoning for
    "interactor" over the alternatives all hold. Every one of them was checked
    against the organisation and matches.

    The `domain` field on the wire in RFD 2091 is still unrenamed, and still needs
    its own RFD, as RFD 2111 says.
    """

    drafted_by :ai
  end
end
