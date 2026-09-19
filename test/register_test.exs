# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT

defmodule RegisterTest do
  use ExUnit.Case, async: true

  @layer %{
    arc: "1.3.6.1.4.1.66606.1.9",
    site: 9,
    site_name: "test",
    category: 1,
    category_name: "documents",
    pen: "1.3.6.1.4.1.66606",
    rule: "rfd/9000-conventions/DETAILS.md"
  }

  defp reg(rows, overrides \\ []) do
    struct!(
      RFD.Register,
      Keyword.merge(
        [
          name: "Test",
          layer: @layer,
          thesis: "Every serial this site has allocated.",
          sections: [{:allocated, nil}, {:deleted, "A deleted serial keeps its row."}],
          rows: rows
        ],
        overrides
      )
    )
  end

  @good [
    {:allocated, 9000, "conventions", []},
    {:allocated, 9001, "a-slug", [flight_level: :l2]},
    {:retired, 9002, nil, [recorded_in: 9000]},
    {:deleted, 9003, "gone", []}
  ]

  test "a well-formed register renders the layer the Python gate reads" do
    assert RFD.Register.problems(reg(@good)) == []
    usda = RFD.Register.usda(reg(@good))

    assert String.starts_with?(
             usda,
             "#usda 1.0\n(\n    customLayerData = {\n        string arc = "
           )

    assert usda =~ "def Scope \"Test\"\n    {\n        custom string thesis = "
    assert usda =~ "def Scope \"Allocated\"\n        {\n            def \"Rfd\"\n"

    assert usda =~
             "def \"S9001\"\n                {\n                    custom string slug = \"a-slug\"\n                    custom string flight_level = \"L2\"\n"

    assert usda =~ "def \"Retired\"\n" and usda =~ "custom int recorded_in = 9000"
    assert usda =~ "custom string sectionNote = \"A deleted serial keeps its row.\""

    assert {%{9000 => "conventions", 9001 => "a-slug"}, %{9002 => 9000, 9003 => "gone"}} =
             RFD.Register.tables(reg(@good))
  end

  test "the Retired satellite is omitted when empty and the note is escaped" do
    usda =
      RFD.Register.usda(
        reg(Enum.reject(@good, &(elem(&1, 0) == :retired)),
          sections: [{:allocated, nil}, {:deleted, "say \"why\""}]
        )
      )

    refute usda =~ "Retired"
    assert usda =~ "sectionNote = \"say \\\"why\\\"\""
  end

  # Negative controls: each must be refused, or the register certifies the defect.
  test "a serial listed twice is refused" do
    assert ["serial listed twice: [9001]"] =
             RFD.Register.problems(reg(@good ++ [{:deleted, 9001, "again", []}]))
  end

  test "a serial from another site is refused" do
    assert ["serial 8001: this site is 9" <> _] =
             RFD.Register.problems(reg(@good ++ [{:allocated, 8001, "foreign", []}]))
  end

  test "a retired row naming no serial, a bad slug and a bad flight level are refused" do
    assert [_] = RFD.Register.problems(reg(@good ++ [{:retired, 9004, nil, [recorded_in: 9999]}]))
    assert [_] = RFD.Register.problems(reg(@good ++ [{:allocated, 9004, "Not A Slug", []}]))

    assert [_] =
             RFD.Register.problems(reg(@good ++ [{:allocated, 9004, "ok", [flight_level: :l4]}]))
  end

  test "an empty register and a layer missing its arc are refused" do
    assert ["no allocated serial" <> _] = RFD.Register.problems(reg([]))

    assert ["layer is missing [:arc]"] =
             RFD.Register.problems(reg(@good, layer: Map.delete(@layer, :arc)))
  end

  test "the tree check names a source with no row, a slug mismatch and a deleted serial with a source" do
    sources = [
      "rfd/9000-conventions.exs",
      "rfd/9001-other-slug.exs",
      "rfd/9003-gone.exs",
      "rfd/9005-new.exs"
    ]

    problems = RFD.Serials.tree_problems(reg(@good), sources)

    assert Enum.any?(
             problems,
             &(&1 =~ "9001: the register says a-slug, the source says other-slug")
           )

    assert Enum.any?(problems, &(&1 =~ "9005-new: the source has no allocated row"))
    assert Enum.any?(problems, &(&1 =~ "serial 9003 is listed as deleted and has a source"))

    assert RFD.Serials.tree_problems(reg(@good), [
             "rfd/9000-conventions.exs",
             "rfd/9001-a-slug.exs"
           ]) == []
  end

  test "the base check refuses a renumbering and a revived serial, and passes an append or a retitle" do
    was = reg(@good)
    assert [] = RFD.Serials.base_problems(was, reg(@good ++ [{:allocated, 9004, "later", []}]))

    assert [] =
             RFD.Serials.base_problems(
               was,
               reg(List.replace_at(@good, 1, {:allocated, 9001, "a-better-slug", []}))
             )

    assert ["serial 9001 was in the register and is gone from it"] =
             RFD.Serials.base_problems(was, reg(List.delete_at(@good, 1)))

    assert ["serial 9003 was deleted and is allocated again"] =
             RFD.Serials.base_problems(
               was,
               reg(List.replace_at(@good, 3, {:allocated, 9003, "back", []}))
             )
  end

  test "the DSL builds the same struct and refuses a serial/3 outside a slug table" do
    code = """
    defmodule RegisterTestGood do
      use RFD.Register
      register "Good" do
        layer arc: "a", site: 9, site_name: "t", category: 1, category_name: "d", pen: "p", rule: "r"
        thesis "t"
        allocated do
          serial 9000, "conventions"
        end
        unused "note" do
          never_written 9001
        end
      end
    end
    """

    [{mod, _}] = Code.compile_string(code)

    assert %RFD.Register{
             name: "Good",
             rows: [{:allocated, 9000, "conventions", []}, {:never_written, 9001, nil, []}]
           } = mod.__register__()

    bad =
      code
      |> String.replace("never_written 9001", "serial 9001, \"x\"")
      |> String.replace("RegisterTestGood", "RegisterTestBad")

    assert_raise ArgumentError, ~r/serial\/3 does not belong in :unused/, fn ->
      Code.compile_string(bad)
    end
  end
end
