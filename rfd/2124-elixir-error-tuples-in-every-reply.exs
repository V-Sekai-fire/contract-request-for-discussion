# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2124. `mix rfd.render` renders rfd/2124-elixir-error-tuples-in-every-reply/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2124 do
  use RFD.DSL

  rfd 2124, "Elixir error tuples in every reply" do
    state :moved

    decision ~S"""
    See `DETAILS.md` for the full argument.
    """

    problem ~S"""
    ETF was written first. The decision moved to CBOR after both were
    shown to reach the same term, so this records what each cost rather
    than an argument from taste.
    """

    related ~S"""
    See `DETAILS.md` for the full argument.
    """

    details_title "Elixir error tuples in every reply"

    details "Both encodings were built and measured", ~S"""
    ETF was written first. The decision moved to CBOR after both were shown to reach the same term,
    so this records what each cost rather than an argument from taste.

    |                          | ETF                        | CBOR, tag 39                           |
    | ------------------------ | -------------------------- | -------------------------------------- |
    | bytes for the same reply | 60                         | 53                                     |
    | decoder on the BEAM      | `:erlang.binary_to_term/2` | `Weft.Reply.decode!/1`, about 60 lines |
    | atom safety              | `[:safe]`                  | `String.to_existing_atom/1`            |
    | writer in C++            | a hand-rolled term encoder | the existing CBOR writer plus one tag  |
    | readers off the BEAM     | an ETF reader in each      | the CBOR library each already has      |
    | encodings in the tree    | two                        | one                                    |

    Both decoded to `{:error, {:res_below_minimum, %{got: 512, minimum: 1280}}}` on OTP 29. The
    term is identical; only the cost of getting there differs.
    """

    details "The ETF subset that was written", ~S"""
    The writer emits eight tags. Nothing else is needed for `:ok`, `{:ok, map}` and
    `{:error, reason}`, and a smaller writer is a smaller thing to get wrong.

    | tag                   | number | use                                         |
    | --------------------- | ------ | ------------------------------------------- |
    | `VERSION_MAGIC`       | 131    | the first byte of every term                |
    | `SMALL_ATOM_UTF8_EXT` | 119    | an atom under 256 bytes                     |
    | `ATOM_UTF8_EXT`       | 118    | a longer atom                               |
    | `SMALL_INTEGER_EXT`   | 97     | 0 to 255                                    |
    | `INTEGER_EXT`         | 98     | a signed 32-bit integer                     |
    | `BINARY_EXT`          | 109    | an Elixir binary, which is what a string is |
    | `SMALL_TUPLE_EXT`     | 104    | a tuple with fewer than 256 elements        |
    | `MAP_EXT`             | 116    | a map                                       |

    A reply that needs a larger integer, a float, a list or a reference is refused by the writer
    rather than encoded. The refusal is the check: a reply shape nobody agreed on does not reach a
    caller in a form that decodes.
    """

    details "The test against a real virtual machine", ~S"""
    Run on Erlang/OTP 29, 2026-08-17. The bytes came from the Python writer and went to `elixir`
    with no intermediate step.

        decoded: {:error, {:res_below_minimum, %{got: 512, minimum: 1280}}}
        MATCHED {:error, {:res_below_minimum, %{got: 512, minimum: 1280}}}
        is_tuple: true  elem0_is_atom: true

    The term is a tuple, its first element is an atom, and it matches the clause a caller writes.
    """

    details "What `[:safe]` does, measured rather than assumed", ~S"""
    The first run above decoded under `[:safe]` although `:res_below_minimum` is not an atom any
    release ships. That looked like evidence that `[:safe]` permits new atoms. It is evidence of nothing of the sort: the atom already existed. The test
    script names the atom in its own `case` clause, so compiling the script created the atom before
    the decode ran.

    A second test used an atom that no module names:

        safe REFUSED it (ArgumentError) => :safe blocks novel atoms
        atom_count before=18541 after=18914
        without :safe: {:error, :zz_never_seen_atom_9f3a2b}

    So `[:safe]` refuses an atom the virtual machine does not have, and a decode without it creates
    one. Both halves are necessary to the decision: `[:safe]` is what stops a reply from growing the
    atom table, and the caller's own clauses are what make the reasons it expects decodable.

    This is recorded because the first reading was wrong and the wrong reading was the comfortable
    one. A claim about a safety option that nobody runs is a claim that stays wrong.
    """

    details "Where each writer applies", ~S"""
    Two boundaries, and they are not the same boundary. Confusing them is how a project ends up
    with an ETF writer inside a NIF, or Fine linked into a process with no virtual machine.

    | boundary                         | who writes the term         | why                                                       |
    | -------------------------------- | --------------------------- | --------------------------------------------------------- |
    | the BEAM calls into C++          | Fine                        | there is an `ErlNifEnv`, and the term never becomes bytes |
    | a worker replies over the bus    | the ETF writer              | there is no virtual machine in the process                |
    | a worker replies to a RunPod job | the ETF writer, then base64 | the queue carries JSON                                    |

    The ETF writer's subset is above. It is small because the second and third rows carry replies
    and nothing else; a NIF that passes a resource, a reference or a port is the first row, and
    that is Fine's.
    """

    details "The gate, and what it found", ~S"""
    `mix check nifs`, over 39 children: green. `interactor-ward` and `datasource-queen` carry
    `thirdparty/taskweft/fine.hpp`, and no first-party source calls `enif_make_*` or `enif_get_*`.

    The controls inject a finding, which proves the report and not the scan. The scan was proved
    separately by writing a real NIF file into a real project in the manifest:

        FAIL  interactor-see-through-cpp handles Erlang terms in src/nif_probe.cpp and shows no Fine
        FAIL  interactor-see-through-cpp/src/nif_probe.cpp calls enif_make_/enif_get_ directly

    The file was then removed and the gate went green again.

    One defect was found in the harness while registering it. A concern named in `@concerns` but
    absent from `@order` is filtered out of every run, so `mix check nifs` executed no checks and
    printed `0 failing check(s)`. A pass over an empty set reads exactly like a pass, which is the
    failure `check.ex`'s own documentation warns about.
    """

    drafted_by :ai
  end
end
