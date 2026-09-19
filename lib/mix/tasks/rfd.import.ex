# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT

defmodule Mix.Tasks.Rfd.Import do
  @shortdoc "Write rfd/NNNN-slug.exs from an RFD directory's README.md and DETAILS.md"
  @moduledoc """
      mix rfd.import [--force] [NAME ...]

  Reads `rfd/NNNN-slug/README.md` (and DETAILS.md when present), writes
  `rfd/NNNN-slug.exs`, renders that source in memory and reports every non-blank
  line of the originals the rendering does not carry. A source that exists is
  left alone unless `--force`. With no NAME every RFD directory is imported.
  Nothing is written into the directory; `mix rfd.render` does that.
  """
  use Mix.Task

  @impl true
  def run(args) do
    {opts, names, _} = OptionParser.parse(args, strict: [force: :boolean])
    Code.compiler_options(ignore_module_conflict: true)

    dirs =
      if names == [],
        do:
          RFD.Source.rfd_root()
          |> Path.join("[0-9][0-9][0-9][0-9]-*")
          |> Path.wildcard()
          |> Enum.filter(&File.dir?/1)
          |> Enum.sort(),
        else: Enum.map(names, &RFD.Source.dir_of(RFD.Source.at(&1)))

    results = Enum.map(dirs, &RFD.Import.import_dir(&1, opts))

    for {status, dir, msg} <- results, status not in [:ok, :skipped] do
      Mix.shell().info(
        "#{String.pad_trailing(to_string(status), 8)} #{Path.basename(dir)} #{msg}"
      )
    end

    counts = results |> Enum.map(&elem(&1, 0)) |> Enum.frequencies()

    Mix.shell().info(
      "imported #{counts[:ok] || 0}, lossy #{counts[:lossy] || 0}, failed #{counts[:failed] || 0}, skipped #{counts[:skipped] || 0}"
    )

    if (counts[:failed] || 0) > 0, do: Mix.raise("some RFDs could not be imported")
  end
end

defmodule RFD.Import do
  @moduledoc "README.md + DETAILS.md -> an rfd/NNNN-slug.exs source, with a preservation check."

  @canary_ai "This RFD was drafted by an AI and read by a human before it shipped."
  @canary_human "This RFD was drafted by a human without AI help."
  @spine %{
    "Decision" => :decision,
    "Problem" => :problem,
    "References" => :references,
    "Related" => :related
  }

  def import_dir(dir, opts) do
    readme = Path.join(dir, "README.md")
    source = dir <> ".exs"

    cond do
      not File.exists?(readme) ->
        {:failed, dir, "no README.md"}

      File.exists?(source) and !opts[:force] ->
        {:skipped, dir, "source exists"}

      true ->
        try do
          doc = parse(dir)
          File.write!(source, emit(doc, dir))
          rendered = RFD.Source.load(source)
          missing = lost_lines(dir, rendered)

          if missing == [] do
            {:ok, dir, ""}
          else
            {:lossy, dir,
             "#{length(missing)} line(s) not in the render, e.g. #{inspect(hd(missing))}"}
          end
        rescue
          e ->
            {:failed, dir,
             Exception.message(e) |> String.split("\n") |> Enum.take(2) |> Enum.join(" ")}
        end
    end
  end

  @doc "Every non-blank line of the originals that the rendering does not carry."
  def lost_lines(dir, doc) do
    rendered = [RFD.Doc.readme(doc), RFD.Doc.details(doc) || ""] |> Enum.join("\n")
    have = rendered |> String.split("\n") |> Enum.map(&String.trim/1) |> MapSet.new()

    for name <- ["README.md", "DETAILS.md"],
        path = Path.join(dir, name),
        File.exists?(path),
        line <- File.read!(path) |> String.split("\n"),
        t = String.trim(line),
        t != "",
        not MapSet.member?(have, t),
        do: "#{name}: #{t}"
  end

  # -- parsing ------------------------------------------------------------------

  def parse(dir) do
    readme = File.read!(Path.join(dir, "README.md"))
    {front_matter, body} = split_front_matter(readme)
    {head, sections} = split_sections(body)
    [title_line | rest] = String.split(head, "\n")

    %{"serial" => serial, "title" => title} =
      Regex.named_captures(~r/^# RFD (?<serial>\d{4}): (?<title>.*)$/, title_line) ||
        raise(ArgumentError, "README title is not `# RFD NNNN: title`: #{inspect(title_line)}")

    meta = metadata(rest)
    details_path = Path.join(dir, "DETAILS.md")
    details_text = if File.exists?(details_path), do: File.read!(details_path), else: nil
    {dtitle, dpre, dsecs} = if details_text, do: parse_details(details_text), else: {nil, nil, []}

    has_details = dpre != nil or dsecs != []

    attest_in =
      cond do
        canary?(readme) -> :readme
        details_text && canary?(details_text) && has_details -> :details
        # A DETAILS.md holding nothing but the sentence goes; the README carries it.
        details_text && canary?(details_text) -> :readme
        true -> :none
      end

    compact_head = match?([first | _] when first != "", rest)

    order =
      for {h, _} <- sections do
        case Map.fetch(@spine, h) do
          {:ok, key} -> key
          :error -> {:section, h}
        end
      end

    by = Map.new(sections)

    %{
      serial: String.to_integer(serial),
      title: title,
      front_matter: front_matter,
      compact_head: compact_head,
      preamble: readme_preamble(rest),
      state: meta |> Map.fetch!("State") |> String.split() |> hd() |> String.to_atom(),
      feature: meta["Feature"],
      scope: meta["Scope"],
      flight_level: flight_level(String.to_integer(serial), dir),
      decision: strip_canary(by["Decision"]),
      problem: strip_canary(by["Problem"]),
      references: strip_canary(by["References"]),
      related: strip_canary(by["Related"]),
      sections: for({h, b} <- sections, not Map.has_key?(@spine, h), do: {h, strip_canary(b)}),
      order: order,
      attest_in: attest_in,
      details_pointer: not has_details or String.contains?(readme, "DETAILS.md"),
      details_title: dtitle,
      details_preamble: dpre,
      details: dsecs,
      drafted_by: drafted_by([readme, details_text || ""])
    }
  end

  defp parse_details(text) do
    {head, sections} = split_sections(text)
    lines = String.split(head, "\n")

    {title, body_lines} =
      case lines do
        ["# RFD " <> rest | tail] -> {String.replace(rest, ~r/^\d{4} details: /, ""), tail}
        _ -> {nil, lines}
      end

    preamble = body_lines |> Enum.join("\n") |> strip_canary() |> blank_to_nil()
    {title, preamble, Enum.map(sections, fn {h, b} -> {h, strip_canary(b)} end)}
  end

  # A leading `---` ... `---` block travels verbatim.
  defp split_front_matter("---\n" <> rest) do
    case String.split(rest, "\n---\n", parts: 2) do
      [fm, body] -> {"---\n" <> fm <> "\n---", String.trim_leading(body, "\n")}
      _ -> {nil, "---\n" <> rest}
    end
  end

  defp split_front_matter(text), do: {nil, text}

  @doc "Head text and [{heading, body}] for level-2 headings outside fenced code."
  def split_sections(text) do
    {chunks, cur, _} =
      text
      |> String.split("\n")
      |> Enum.reduce({[], [], false}, fn line, {chunks, cur, fence} ->
        fence =
          if String.starts_with?(String.trim_leading(line), "```"), do: not fence, else: fence

        if not fence and String.starts_with?(line, "## ") and cur != [],
          do: {[Enum.reverse(cur) | chunks], [line], fence},
          else: {chunks, [line | cur], fence}
      end)

    [head | rest] = Enum.reverse([Enum.reverse(cur) | chunks])

    sections =
      for ["## " <> heading | body] <- rest do
        {String.trim(heading), body |> Enum.join("\n") |> trim_blank_edges()}
      end

    head_text = Enum.join(head, "\n")

    if String.starts_with?(head_text, "## "),
      do:
        {"",
         [
           {head_text
            |> String.split("\n")
            |> hd()
            |> String.replace_prefix("## ", "")
            |> String.trim(), ""}
           | sections
         ]},
      else: {head_text, sections}
  end

  # Leading indentation stays (a code block may open a section); blank edges go.
  defp trim_blank_edges(text) do
    text |> String.replace(~r/\A(\s*\n)+/, "") |> String.trim_trailing()
  end

  defp metadata(lines) do
    Enum.reduce(lines, {%{}, nil}, fn line, {acc, current} ->
      case Regex.run(~r/^\*\*(State|Feature|Scope):\*\*\s*(.*)$/, line) do
        [_, key, value] ->
          {Map.put(acc, key, value), key}

        nil ->
          if current && String.trim(line) != "" && not String.starts_with?(line, "**"),
            do: {Map.update!(acc, current, &(&1 <> "\n" <> line)), current},
            else: {acc, nil}
      end
    end)
    |> elem(0)
  end

  # Prose between the metadata block (which ends at the first blank line) and the sections.
  defp readme_preamble(lines) do
    lines
    |> Enum.drop_while(&(String.trim(&1) == ""))
    |> Enum.drop_while(&(String.trim(&1) != ""))
    |> Enum.reject(&Regex.match?(~r/^\*\*(State|Feature|Scope):\*\*/, &1))
    |> Enum.join("\n")
    |> strip_canary()
    |> blank_to_nil()
  end

  # The sentence counts only as a line of its own; prose that quotes it is prose.
  defp canary_lines(text),
    do:
      text
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.filter(&(&1 in [@canary_ai, @canary_human]))

  defp canary?(text), do: canary_lines(text) != []

  defp drafted_by(texts) do
    lines = Enum.flat_map(texts, &canary_lines/1)

    cond do
      @canary_ai in lines -> :ai
      @canary_human in lines -> :human
      true -> :ai
    end
  end

  defp strip_canary(nil), do: nil

  defp strip_canary(text) do
    text
    |> String.split("\n")
    |> Enum.reject(&(String.trim(&1) in [@canary_ai, @canary_human]))
    |> Enum.join("\n")
    |> trim_blank_edges()
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(s), do: s

  defp flight_level(serial, dir) do
    root = dir |> Path.dirname() |> Path.dirname()

    Path.wildcard(Path.join(root, "SERIALS*.usda"))
    |> Enum.find_value(fn f ->
      case Regex.run(~r/def "S#{serial}"\s*\{[^}]*?flight_level = "(L[123])"/s, File.read!(f)) do
        [_, level] -> level |> String.downcase() |> String.to_atom()
        nil -> nil
      end
    end)
  end

  # -- emitting -------------------------------------------------------------------

  def emit(doc, dir) do
    slug = Path.basename(dir)

    head =
      [
        doc.front_matter && {"front_matter", heredoc(doc.front_matter)},
        doc.compact_head && {"compact_head", "true"},
        {"state", inspect(doc.state)},
        doc.flight_level && {"flight_level", inspect(doc.flight_level)},
        doc.feature && {"feature", str(doc.feature)},
        doc.scope && {"scope", str(doc.scope)},
        doc.preamble && {"preamble", heredoc(doc.preamble)},
        doc.attest_in != :readme && {"attest_in", inspect(doc.attest_in)},
        doc.details_pointer == false && {"details_pointer", "false"}
      ]
      |> Enum.reject(&(&1 in [nil, false]))
      |> Enum.map(fn {k, v} -> "    #{k} #{v}" end)

    body =
      for key <- doc.order, item = body_item(doc, key), item != nil, do: item

    details =
      [
        doc.details_title && "    details_title #{str(doc.details_title)}",
        doc.details_preamble && "    details_preamble #{heredoc(doc.details_preamble)}"
      ]
      |> Enum.reject(&(&1 in [nil, false]))
      |> Kernel.++(for {h, b} <- doc.details, do: "    details #{str(h)}, #{heredoc(b)}")

    fields =
      Enum.join(head ++ body ++ details ++ ["    drafted_by #{inspect(doc.drafted_by)}"], "\n\n")

    """
    # Copyright (c) 2026 K. S. Ernest (iFire) Lee
    # SPDX-License-Identifier: MIT
    #
    # RFD #{doc.serial}. `mix rfd.render` renders rfd/#{slug}/README.md and
    # DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
    defmodule RFD#{doc.serial} do
      use RFD.DSL

      rfd #{doc.serial}, #{str(doc.title)} do
    #{fields}
      end
    end
    """
  end

  defp body_item(doc, :decision), do: doc.decision && "    decision #{heredoc(doc.decision)}"
  defp body_item(doc, :problem), do: doc.problem && "    problem #{heredoc(doc.problem)}"

  defp body_item(doc, :references),
    do: doc.references && "    references #{heredoc(doc.references)}"

  defp body_item(doc, :related), do: doc.related && "    related #{heredoc(doc.related)}"

  defp body_item(doc, {:section, h}) do
    case List.keyfind(doc.sections, h, 0) do
      {_, b} -> "    section #{str(h)}, #{heredoc(b)}"
      nil -> nil
    end
  end

  defp str(s), do: inspect(s)

  # ~S heredocs carry prose verbatim: no escapes, no interpolation. An empty body is
  # a one-line empty string, since a heredoc needs at least one line.
  defp heredoc(""), do: "\"\""

  defp heredoc(text) do
    body =
      text |> String.trim_trailing() |> String.split("\n") |> Enum.map_join("\n", &("    " <> &1))

    "~S\"\"\"\n#{body}\n    \"\"\""
  end
end
