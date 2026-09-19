# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT

defmodule RFD.Doc do
  @moduledoc """
  One RFD as data, the shape RFD 1000 gives it, and the two renderings of it.

  The README rendering is what `scripts/check-rfd-structure.py` and the site
  read: CommonMark, `# RFD NNNN: title`, the metadata lines State / Feature /
  Scope in that order, then the spine Decision, Problem, References, Related,
  then the attestation sentence.
  """

  @states ~w(abandoned committed discussion ideation moved prediscussion published)a
  @no_decision_states [:moved]
  @readme_limit 40
  @canary %{
    ai: "This RFD was drafted by an AI and read by a human before it shipped.",
    human: "This RFD was drafted by a human without AI help."
  }
  @tropes [
    {~r/(?<=\S) [-—][-—]? /u, "an em-dash join"},
    {~r/\b(is|are)\s+what\s+(makes|proves|shows|says)\b/i, "a pompous copula"},
    {~r/\bthe exact (window|moment|shape|line|point|reason|failure)\b/i,
     "an `exact` on a soft noun"}
  ]
  @spine_rank %{decision: 0, problem: 1, references: 2, related: 3}

  @enforce_keys [:serial, :title]
  defstruct serial: nil,
            title: nil,
            front_matter: nil,
            compact_head: false,
            preamble: nil,
            state: :discussion,
            feature: nil,
            scope: nil,
            flight_level: nil,
            decision: nil,
            problem: nil,
            references: [],
            related: nil,
            sections: [],
            order: [],
            attest_in: :readme,
            details_pointer: true,
            details_title: nil,
            details_preamble: nil,
            details: [],
            drafted_by: :ai

  @type t :: %__MODULE__{}

  def states, do: @states
  def readme_limit, do: @readme_limit
  def canary(kind), do: Map.fetch!(@canary, kind)

  @doc "Every rule the README rendering has to meet, as a list of reasons it does not."
  def problems(%__MODULE__{} = d) do
    []
    |> check(
      is_integer(d.serial) and d.serial in 1000..9999,
      "serial must be a four-digit integer"
    )
    |> check(
      is_binary(d.title) and String.trim(d.title) != "",
      "title must be a non-empty string"
    )
    |> check(d.state in @states, "state #{inspect(d.state)} is not one of #{inspect(@states)}")
    |> check(
      d.decision != nil or d.state in @no_decision_states,
      "a Decision is required unless the state is one of #{inspect(@no_decision_states)}"
    )
    |> check(d.drafted_by in [:ai, :human], "drafted_by must be :ai or :human")
    |> check(d.flight_level in [nil, :l1, :l2, :l3], "flight_level must be :l1, :l2, :l3 or nil")
    |> check(
      d.attest_in in [:readme, :details, :none],
      "attest_in must be :readme, :details or :none"
    )
    |> check(
      d.attest_in != :details or d.details != [] or d.details_preamble != nil,
      "attest_in :details needs a DETAILS.md to carry the sentence"
    )
    |> check(
      Enum.all?(d.details, &match?({h, b} when is_binary(h) and is_binary(b), &1)),
      "each details entry is {heading, body}"
    )
    |> check(
      Enum.all?(d.sections, &match?({h, b} when is_binary(h) and is_binary(b), &1)),
      "each section entry is {heading, body}"
    )
    |> check(
      Enum.all?(d.sections, fn {h, _} -> h not in ~w(Decision Problem References Related) end),
      "a spine section goes in its own field, not in section/2"
    )
    |> check(spine_in_order?(d.order), "the spine runs Decision, Problem, References, Related")
    |> Kernel.++(length_problems(d))
    |> Enum.reverse()
  end

  @doc """
  The trope tells `scripts/check_tropes.py` counts. That gate holds density where it
  is rather than forbidding a tell, so these are warnings at compile time, not errors.
  """
  def tropes(%__MODULE__{} = d) do
    prose =
      [d.preamble, d.decision, d.problem, d.related, d.details_preamble] ++
        Enum.map(d.details ++ d.sections, &elem(&1, 1))

    for text <- prose, is_binary(text), {re, name} <- @tropes, Regex.match?(re, text) do
      "prose carries #{name}: #{inspect(Regex.run(re, text) |> hd() |> String.trim())}"
    end
  end

  def validate!(%__MODULE__{} = d) do
    problems = if System.get_env("RFD_LENIENT"), do: [], else: problems(d)

    case problems do
      [] ->
        for t <- tropes(d), do: IO.warn("RFD #{d.serial}: #{t}", [])
        d

      ps ->
        raise ArgumentError,
              "RFD #{d.serial} is outside RFD 1000's shape:\n  " <> Enum.join(ps, "\n  ")
    end
  end

  defp spine_in_order?(order) do
    ranks = for k <- order, r = @spine_rank[k], do: r
    ranks == Enum.sort(ranks)
  end

  defp check(acc, true, _msg), do: acc
  defp check(acc, false, msg), do: [msg | acc]

  defp length_problems(d) do
    if d.decision == nil and d.state not in @no_decision_states do
      []
    else
      n = d |> readme() |> String.trim_trailing("\n") |> String.split("\n") |> length()

      if n > @readme_limit,
        do: ["README renders to #{n} lines; RFD 1000 allows #{@readme_limit}"],
        else: []
    end
  end

  @doc "The README as the gates and the site read it."
  def readme(%__MODULE__{} = d) do
    meta =
      [
        "**State:** #{d.state}",
        d.feature && "**Feature:** #{d.feature}",
        d.scope && "**Scope:** #{d.scope}"
      ]
      |> Enum.reject(&is_nil/1)

    refs =
      case d.references do
        [] -> nil
        text when is_binary(text) -> text
        list -> Enum.map_join(list, "\n", &("- " <> &1))
      end

    spine = [
      {:decision, d.decision && section("Decision", d.decision <> details_pointer(d))},
      {:problem, d.problem && section("Problem", d.problem)},
      {:references, refs && section("References", refs)},
      {:related, d.related && section("Related", d.related)}
    ]

    extras = for {h, b} <- d.sections, do: {{:section, h}, section(h, b)}
    all = spine ++ extras
    # Declaration order when the source gave one; otherwise the spine, then the extras.
    keys = if d.order == [], do: Enum.map(all, &elem(&1, 0)), else: d.order

    sections =
      keys
      |> Enum.map(&List.keyfind(all, &1, 0))
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&elem(&1, 1))
      |> Enum.reject(&(&1 in [nil, false]))

    title_block =
      "# RFD #{d.serial}: #{d.title}" <>
        if(d.compact_head, do: "\n", else: "\n\n") <> Enum.join(meta, "\n")

    head =
      [
        d.front_matter && String.trim_trailing(d.front_matter),
        title_block,
        d.preamble && String.trim_trailing(d.preamble)
      ]
      |> Enum.reject(&(&1 in [nil, false]))
      |> Enum.join("\n\n")

    tail = if d.attest_in == :readme, do: ["", canary(d.drafted_by)], else: []

    ([head] ++ Enum.flat_map(sections, &["", &1]) ++ tail)
    |> Enum.join("\n")
    |> Kernel.<>("\n")
  end

  @doc "DETAILS.md, or nil when the RFD has no details."
  def details(%__MODULE__{details: [], details_preamble: nil}), do: nil

  def details(%__MODULE__{} = d) do
    parts =
      [
        "# RFD #{d.serial} details: #{d.details_title || d.title}",
        d.attest_in != :none && canary(d.drafted_by),
        d.details_preamble && String.trim_trailing(d.details_preamble)
      ] ++ Enum.map(d.details, fn {h, b} -> section(h, b) end)

    Enum.map_join(Enum.reject(parts, &(&1 in [nil, false])), "\n\n", & &1) <> "\n"
  end

  @doc "The register row fragment for SERIALS-*.usda, for a human to paste or a tool to insert."
  def register_row(%__MODULE__{} = d, slug) do
    level =
      if d.flight_level,
        do:
          "\n    custom string flight_level = \"#{d.flight_level |> Atom.to_string() |> String.upcase()}\"",
        else: ""

    "def \"S#{d.serial}\"\n{\n    custom string slug = \"#{slug}\"#{level}\n}\n"
  end

  defp section(heading, body), do: "## #{heading}\n\n#{String.trim_trailing(body)}"

  defp details_pointer(%{details: [], details_preamble: nil}), do: ""
  defp details_pointer(%{details_pointer: false}), do: ""

  defp details_pointer(d) do
    prose =
      [d.preamble, d.decision, d.problem, d.related, List.wrap(d.references)] ++
        Enum.map(d.sections, &elem(&1, 1))

    prose = List.flatten(prose)

    if Enum.any?(prose, &(is_binary(&1) and String.contains?(&1, "DETAILS.md"))),
      do: "",
      else: "\n\n`DETAILS.md` carries the rest of this RFD."
  end
end
