# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT

defmodule RFD.DSL do
  @moduledoc """
  Author an RFD as Elixir. The block builds an `RFD.Doc`, validates it against
  RFD 1000 while the file compiles, and exposes it as `__rfd__/0`.

      defmodule RFD2232 do
        use RFD.DSL

        rfd 2232, "RFD authoring as an Elixir DSL" do
          state :discussion
          flight_level :l2
          feature "one source file per RFD, the README and DETAILS rendered from it"
          scope "the Mix project at the root, every rfd/NNNN-slug.exs"

          decision \"\"\"
          ...
          \"\"\"

          problem \"\"\"
          ...
          \"\"\"

          references ["RFD 1000", "RFD 2177"]
          related "RFD 1000 (the shape), RFD 2177 (the register tag)."
          details "How the renderer is checked", \"\"\"
          ...
          \"\"\"
          drafted_by :ai
        end
      end

  Sections render in the order they are declared; the spine must still run
  Decision, Problem, References, Related. A file that breaks the shape does not
  compile; the error names the rule.
  """

  defmacro __using__(_opts) do
    quote do
      import RFD.DSL, only: [rfd: 3]
    end
  end

  defmacro rfd(serial, title, do: block) do
    quote do
      Module.register_attribute(__MODULE__, :rfd_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :rfd_details, accumulate: true)
      Module.register_attribute(__MODULE__, :rfd_sections, accumulate: true)
      Module.register_attribute(__MODULE__, :rfd_order, accumulate: true)
      import RFD.DSL.Fields
      unquote(block)
      import RFD.DSL.Fields, only: []

      @rfd_doc RFD.DSL.build(
                 unquote(serial),
                 unquote(title),
                 @rfd_fields,
                 @rfd_details,
                 @rfd_sections,
                 @rfd_order
               )
      def __rfd__, do: @rfd_doc
    end
  end

  @doc false
  def build(serial, title, fields, details, sections \\ [], order \\ []) do
    fields =
      Enum.reverse(fields) ++ [sections: Enum.reverse(sections), order: Enum.reverse(order)]

    dup =
      fields
      |> Enum.map(&elem(&1, 0))
      |> Enum.frequencies()
      |> Enum.filter(fn {_, n} -> n > 1 end)

    if dup != [],
      do:
        raise(
          ArgumentError,
          "RFD #{serial}: field given twice: #{inspect(Enum.map(dup, &elem(&1, 0)))}"
        )

    struct!(RFD.Doc, [serial: serial, title: title, details: Enum.reverse(details)] ++ fields)
    |> RFD.Doc.validate!()
  end

  defmodule Fields do
    @moduledoc false
    defmacro state(v), do: field(:state, v)
    defmacro feature(v), do: field(:feature, v)
    defmacro scope(v), do: field(:scope, v)
    defmacro flight_level(v), do: field(:flight_level, v)
    defmacro decision(v), do: ordered(:decision, v)
    defmacro problem(v), do: ordered(:problem, v)
    defmacro references(v), do: ordered(:references, v)
    defmacro related(v), do: ordered(:related, v)
    defmacro drafted_by(v), do: field(:drafted_by, v)
    defmacro attest_in(v), do: field(:attest_in, v)
    defmacro details_pointer(v), do: field(:details_pointer, v)
    defmacro details_title(v), do: field(:details_title, v)
    defmacro details_preamble(v), do: field(:details_preamble, v)
    defmacro preamble(v), do: field(:preamble, v)
    defmacro front_matter(v), do: field(:front_matter, v)
    defmacro compact_head(v), do: field(:compact_head, v)

    defmacro details(heading, body) do
      quote do
        @rfd_details {unquote(heading), unquote(body)}
      end
    end

    # A README section outside the spine (RFD 1000 allows them), in declaration order.
    defmacro section(heading, body) do
      quote do
        @rfd_sections {unquote(heading), unquote(body)}
        @rfd_order {:section, unquote(heading)}
      end
    end

    defp ordered(name, v) do
      quote do
        @rfd_fields {unquote(name), unquote(v)}
        @rfd_order unquote(name)
      end
    end

    defp field(name, v) do
      quote do
        @rfd_fields {unquote(name), unquote(v)}
      end
    end
  end
end
