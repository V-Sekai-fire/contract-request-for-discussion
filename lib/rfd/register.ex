# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT

defmodule RFD.Register do
  @moduledoc """
  One site's serial register as data, and the `SERIALS*.usda` layer rendered from it.
  `SERIALS.exs` at the repository root is the reference source; README.md
  shows the block. A serial is appended once and never reused, so the compile refuses
  a serial listed twice, a serial from another site, and a retired row whose
  `recorded_in` names no serial in the register.
  """

  @enforce_keys [:name]
  defstruct name: nil, layer: %{}, thesis: nil, sections: [], rows: []

  @layer_keys [:arc, :site, :site_name, :category, :category_name, :pen, :rule]

  defmacro __using__(_) do
    quote do
      import RFD.Register, only: [register: 2]
    end
  end

  defmacro register(name, do: block) do
    quote do
      Module.register_attribute(__MODULE__, :reg_rows, accumulate: true)
      Module.register_attribute(__MODULE__, :reg_sections, accumulate: true)
      @reg_layer %{}
      @reg_thesis nil
      @reg_table nil
      import RFD.Register.Fields
      unquote(block)
      import RFD.Register.Fields, only: []

      @reg_doc RFD.Register.build(
                 unquote(name),
                 @reg_layer,
                 @reg_thesis,
                 @reg_sections,
                 @reg_rows
               )
      def __register__, do: @reg_doc

      use RFD.Corpus, kind: :serials, via: :__register__, entries: :rows
    end
  end

  @doc false
  def build(name, layer, thesis, sections, rows) do
    %__MODULE__{
      name: name,
      layer: layer,
      thesis: thesis,
      sections: Enum.reverse(sections),
      rows: Enum.reverse(rows)
    }
    |> validate!()
  end

  defmodule Fields do
    @moduledoc false
    defmacro layer(opts), do: quote(do: @reg_layer(Map.new(unquote(opts))))
    defmacro thesis(text), do: quote(do: @reg_thesis(unquote(text)))

    defmacro allocated(do: block), do: section(:allocated, nil, block)
    defmacro unused(note, do: block), do: section(:unused, note, block)
    defmacro deleted(do: block), do: section(:deleted, nil, block)
    defmacro deleted(note, do: block), do: section(:deleted, note, block)

    defmacro serial(serial, slug, opts \\ []) do
      quote do
        @reg_rows {RFD.Register.slug_table(@reg_table), unquote(serial), unquote(slug),
                   unquote(opts)}
      end
    end

    defmacro never_written(serial) do
      quote do
        @reg_rows {:never_written, unquote(serial), nil, []}
      end
    end

    defmacro retired(serial, opts) do
      quote do
        @reg_rows {:retired, unquote(serial), nil, unquote(opts)}
      end
    end

    defp section(kind, note, block) do
      quote do
        @reg_sections {unquote(kind), unquote(note)}
        @reg_table unquote(kind)
        unquote(block)
        @reg_table nil
      end
    end
  end

  @doc false
  def slug_table(:allocated), do: :allocated
  def slug_table(:deleted), do: :deleted

  def slug_table(other),
    do: raise(ArgumentError, "serial/3 does not belong in #{inspect(other)}")

  @doc "Every rule the register has to meet, as the list of reasons it does not."
  def problems(%__MODULE__{} = r) do
    serials = Enum.map(r.rows, &elem(&1, 1))

    dup =
      serials
      |> Enum.frequencies()
      |> Enum.filter(fn {_, n} -> n > 1 end)
      |> Enum.map(&elem(&1, 0))

    site = r.layer[:site]
    missing = for k <- @layer_keys, not Map.has_key?(r.layer, k), do: k

    []
    |> check(
      is_binary(r.name) and r.name =~ ~r/^[A-Za-z][A-Za-z0-9]*$/,
      "the site scope needs a prim-safe name"
    )
    |> check(missing == [], "layer is missing #{inspect(missing)}")
    |> check(
      is_integer(site) and site in 1..9,
      "layer site must be a digit; the serials begin with it"
    )
    |> check(is_binary(r.thesis), "a thesis sentence is required")
    |> check(dup == [], "serial listed twice: #{inspect(Enum.sort(dup))}")
    |> check(
      Enum.any?(r.rows, &(elem(&1, 0) == :allocated)),
      "no allocated serial, which is never correct here"
    )
    |> check(
      Enum.all?(serials, &(is_integer(&1) and &1 in 1000..9999)),
      "every serial is a four-digit integer"
    )
    |> Kernel.++(row_problems(r, site, MapSet.new(serials)))
    |> Enum.reverse()
  end

  defp row_problems(r, site, all) do
    for {table, serial, slug, opts} <- r.rows,
        problem <- row_problems(table, serial, slug, opts, site, all),
        do: problem
  end

  defp row_problems(table, serial, slug, opts, site, all) do
    unknown = Keyword.keys(opts) -- [:flight_level, :recorded_in]

    []
    |> check(
      not is_integer(serial) or div(serial, 1000) == site,
      "serial #{serial}: this site is #{site}, and that serial is not its own"
    )
    |> check(
      table not in [:allocated, :deleted] or (is_binary(slug) and slug =~ ~r/^[a-z0-9-]+$/),
      "serial #{serial}: slug #{inspect(slug)} is not a directory name"
    )
    |> check(
      table != :retired or
        (is_integer(opts[:recorded_in]) and MapSet.member?(all, opts[:recorded_in])),
      "serial #{serial}: recorded_in must name a serial in this register"
    )
    |> check(
      opts[:flight_level] in [nil, :l1, :l2, :l3],
      "serial #{serial}: flight_level must be :l1, :l2 or :l3"
    )
    |> check(unknown == [], "serial #{serial}: unknown row fields #{inspect(unknown)}")
  end

  defp check(acc, true, _), do: acc
  defp check(acc, false, msg), do: [msg | acc]

  def validate!(%__MODULE__{} = r) do
    case problems(r) do
      [] ->
        r

      ps ->
        raise ArgumentError,
              "register #{r.name} is outside RFD 1000's shape:\n  " <> Enum.join(ps, "\n  ")
    end
  end

  @doc "`{allocated, deleted}` as serial -> slug, the view `check-rfd-serials.py` reads."
  def tables(%__MODULE__{} = r) do
    a = for {:allocated, s, slug, _} <- r.rows, into: %{}, do: {s, slug}

    d =
      for {t, s, slug, opts} <- r.rows, t in [:deleted, :retired], into: %{} do
        {s, slug || opts[:recorded_in]}
      end

    {a, d}
  end

  @doc "The register as a `.usda` layer, the shape the Python gates and pen-66606.usda read."
  def usda(%__MODULE__{} = r) do
    l = r.layer
    {note_key, note} = l[:note] || {nil, nil}

    data =
      [
        {"arc", l[:arc]},
        note_key && {Atom.to_string(note_key), note},
        {"category", to_string(l[:category])},
        {"categoryName", l[:category_name]},
        {"pen", l[:pen]},
        {:list, "relationKindVocabulary", ["spine", "satellite"]},
        {"rule", l[:rule]},
        {"site", to_string(l[:site])},
        {"siteName", l[:site_name]}
      ]
      |> Enum.reject(&(&1 in [nil, false]))
      |> Enum.map_join("\n", fn
        {:list, k, vs} -> "        string[] #{k} = [#{Enum.map_join(vs, ", ", &q/1)}]"
        {k, v} -> "        string #{k} = #{q(v)}"
      end)

    header =
      [
        "#usda 1.0",
        "(",
        "    customLayerData = {",
        data,
        "    }",
        "    defaultPrim = \"Serials\"",
        "    metersPerUnit = 1",
        "    upAxis = \"Z\"",
        ")",
        ""
      ]
      |> Enum.join("\n")

    scopes =
      Enum.map(r.sections, fn
        {:allocated, _} -> scope("Allocated", nil, [relation(r, :allocated)])
        {:unused, note} -> scope("Unused", note, [relation(r, :never_written)])
        {:deleted, note} -> scope("Deleted", note, [relation(r, :retired), relation(r, :deleted)])
      end)

    site =
      [
        "    def Scope #{q(r.name)}",
        "    {",
        "        custom string thesis = #{q(r.thesis)}",
        ""
      ] ++
        (scopes |> Enum.intersperse([""]) |> List.flatten()) ++ ["    }"]

    header <> "\ndef Scope \"Serials\"\n{\n" <> Enum.join(site, "\n") <> "\n}\n"
  end

  defp scope(name, note, relations) do
    note_lines =
      if note, do: ["            custom string sectionNote = #{q(note)}", ""], else: []

    body = relations |> Enum.reject(&is_nil/1) |> Enum.intersperse([""]) |> List.flatten()
    ["        def Scope #{q(name)}", "        {"] ++ note_lines ++ body ++ ["        }"]
  end

  @relations %{
    allocated: {"Rfd", ["serial int16 PK", "slug string"], "spine"},
    deleted: {"Rfd", ["serial int16 PK", "slug string"], "spine"},
    retired: {"Retired", ["serial int16 PK", "recorded_in int16 FK"], "satellite"},
    never_written: {"NeverWritten", ["serial int16 PK"], "satellite"}
  }

  # The Retired satellite renders only when it carries a row; the spine relations always.
  defp relation(r, table) do
    rows = for {^table, s, slug, opts} <- r.rows, do: {s, slug, opts}
    {prim, columns, kind} = @relations[table]

    if rows == [] and table == :retired do
      nil
    else
      head = [
        "            def #{q(prim)}",
        "            {",
        "                custom string[] columns = [#{Enum.map_join(columns, ", ", &q/1)}]",
        "                custom uniform token kind = #{q(kind)}",
        "                custom string primaryKey = \"serial\"",
        ""
      ]

      body =
        Enum.flat_map(rows, fn {s, slug, opts} ->
          attrs =
            [
              slug && "                    custom string slug = #{q(slug)}",
              opts[:flight_level] &&
                "                    custom string flight_level = #{q(level(opts[:flight_level]))}",
              opts[:recorded_in] &&
                "                    custom int recorded_in = #{opts[:recorded_in]}"
            ]
            |> Enum.reject(&(&1 in [nil, false]))

          ["                def \"S#{s}\"", "                {"] ++ attrs ++ ["                }"]
        end)

      head ++ body ++ ["            }"]
    end
  end

  defp level(l), do: l |> Atom.to_string() |> String.upcase()

  defp q(s) when is_binary(s),
    do: "\"" <> String.replace(s, ~r/["\\]/, fn c -> "\\" <> c end) <> "\""
end
