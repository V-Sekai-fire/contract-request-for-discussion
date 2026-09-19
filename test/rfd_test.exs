# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT

defmodule RFDTest do
  use ExUnit.Case, async: true

  defp doc(overrides \\ []) do
    struct!(
      RFD.Doc,
      Keyword.merge(
        [
          serial: 2999,
          title: "a test RFD",
          state: :discussion,
          feature: "the feature",
          scope: "the scope",
          decision: "Do the thing.",
          problem: "The thing was not done.",
          references: ["RFD 1000"],
          related: "RFD 1000.",
          drafted_by: :ai
        ],
        overrides
      )
    )
  end

  test "a well-formed RFD renders README in RFD 1000's shape" do
    readme = RFD.Doc.readme(doc())

    assert String.starts_with?(
             readme,
             "# RFD 2999: a test RFD\n\n**State:** discussion\n**Feature:**"
           )

    assert readme =~ "\n## Decision\n\nDo the thing.\n\n## Problem\n"
    assert readme =~ "\n## References\n\n- RFD 1000\n\n## Related\n"
    assert String.ends_with?(readme, RFD.Doc.canary(:ai) <> "\n")
    assert length(String.split(readme, "\n")) <= RFD.Doc.readme_limit()
    assert RFD.Doc.problems(doc()) == []
  end

  test "details render to DETAILS.md and the README names it" do
    d = doc(details: [{"How it was checked", "Every number came from a run."}])
    assert RFD.Doc.details(d) =~ "# RFD 2999 details: a test RFD\n\n"
    assert RFD.Doc.details(d) =~ "## How it was checked\n\nEvery number came from a run."
    assert RFD.Doc.readme(d) =~ "`DETAILS.md` carries the rest of this RFD."
    assert RFD.Doc.details(doc()) == nil
  end

  # Negative controls: each must be refused, or the DSL certifies the defect.
  test "an unknown state is refused" do
    assert ["state :draft is not one of" <> _] = RFD.Doc.problems(doc(state: :draft))
  end

  test "a missing Decision is refused unless the state is moved" do
    assert ["a Decision is required" <> _] = RFD.Doc.problems(doc(decision: nil))
    assert RFD.Doc.problems(doc(decision: nil, state: :moved)) == []
  end

  test "a README over 40 lines is refused" do
    long = Enum.map_join(1..40, "\n", &"line #{&1}")
    assert ["README renders to " <> _] = RFD.Doc.problems(doc(problem: long))
  end

  test "an em-dash join, a pompous copula and an exact on a soft noun are named as tropes" do
    assert [_] = RFD.Doc.tropes(doc(decision: "Do the thing — it matters."))
    assert [_] = RFD.Doc.tropes(doc(problem: "This is what makes it work."))
    assert [_] = RFD.Doc.tropes(doc(related: "the exact moment it failed"))
    assert RFD.Doc.tropes(doc()) == []
  end

  test "front matter and a preamble render in place and the pointer is not doubled" do
    d =
      doc(
        front_matter: "---\nname: x\n---",
        preamble: "Shelved 2026-09-02: waiting.",
        related: "See `DETAILS.md`.",
        details: [{"More", "body"}]
      )

    r = RFD.Doc.readme(d)
    assert String.starts_with?(r, "---\nname: x\n---\n\n# RFD 2999: a test RFD\n\n**State:**")
    assert r =~ "**Scope:** the scope\n\nShelved 2026-09-02: waiting.\n\n## Decision\n"
    assert length(Regex.scan(~r/DETAILS\.md/, r)) == 1
  end

  test "validate! raises with every reason at once" do
    assert_raise ArgumentError, ~r/outside RFD 1000's shape.*state.*Decision/s, fn ->
      RFD.Doc.validate!(doc(state: :draft, decision: nil))
    end
  end

  test "the DSL compiles a source into the same struct and refuses a broken one at compile time" do
    code = """
    defmodule RFDTestGood do
      use RFD.DSL
      rfd 2998, "good" do
        state :discussion
        decision "Do it."
        drafted_by :human
      end
    end
    """

    [{mod, _}] = Code.compile_string(code)
    assert %RFD.Doc{serial: 2998, state: :discussion, drafted_by: :human} = mod.__rfd__()

    broken =
      String.replace(code, "state :discussion", "state :whatever")
      |> String.replace("RFDTestGood", "RFDTestBad")

    assert_raise ArgumentError, ~r/state :whatever/, fn -> Code.compile_string(broken) end
  end
end
