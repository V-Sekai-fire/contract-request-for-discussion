# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT

defmodule RFD.MCP.Server do
  @moduledoc "The corpus as MCP tools: public, read-only, the same data the site renders."

  use ExMCP.Server.Handler
  use ExMCP.Server.DSL, name: "rfd"

  alias RFD.Corpus

  tool "list_rfds",
       "Every RFD's serial, slug, title, state, flight level and scope, newest first." do
    param(:state, :string,
      description:
        "Only this state: discussion, committed, published, abandoned, moved, ideation, prediscussion."
    )

    param(:flight_level, :string, description: "Only this flight level: l1, l2 or l3.")

    handle(fn args, _state ->
      entries =
        Corpus.entries()
        |> filter(args["state"], & &1.state)
        |> filter(args["flight_level"], & &1.flight_level)
        |> Enum.map(&summary/1)

      {:ok, json(entries)}
    end)
  end

  tool "get_rfd", "One RFD's README and DETAILS as Markdown, by serial." do
    param(:serial, :integer, required: true, description: "The four-digit serial, e.g. 2232.")

    handle(fn args, _state ->
      case Corpus.entry(args["serial"]) do
        nil -> {:ok, error("no RFD #{inspect(args["serial"])}")}
        e -> {:ok, text(e.readme <> if(e.details, do: "\n\n---\n\n" <> e.details, else: ""))}
      end
    end)
  end

  tool "search_rfds", "The RFDs whose prose contains a phrase, with the matching lines." do
    param(:query, :string, required: true, description: "A phrase; matched case-insensitively.")

    handle(fn args, _state ->
      hits =
        for {e, lines} <- Corpus.search(args["query"] || ""),
            do: Map.put(summary(e), :lines, lines)

      {:ok, json(hits)}
    end)
  end

  tool "get_register",
       "Both serial registers: allocated and deleted serials per site, and the next unused serial." do
    handle(fn _args, _state ->
      sites =
        for {file, r} <- Corpus.registers() do
          {a, d} = RFD.Register.tables(r)

          %{
            file: file <> ".exs",
            site: r.layer[:site],
            site_name: r.layer[:site_name],
            arc: r.layer[:arc],
            allocated: Enum.sort(a) |> Enum.map(fn {s, slug} -> %{serial: s, slug: slug} end),
            deleted:
              Enum.sort(d) |> Enum.map(fn {s, v} -> %{serial: s, slug_or_recorded_in: v} end)
          }
        end

      {:ok, json(%{next_serial: Corpus.next_serial(), sites: sites})}
    end)
  end

  tool "list_logbook", "The logbook entries by name." do
    handle(fn _args, _state ->
      {:ok, json(for {name, md} <- Corpus.logbook(), do: %{name: name, title: heading(md)})}
    end)
  end

  tool "get_logbook_entry", "One logbook entry as Markdown." do
    param(:name, :string, required: true, description: "The entry's file name without .md.")

    handle(fn args, _state ->
      case Corpus.logbook_entry(args["name"] || "") do
        nil -> {:ok, error("no logbook entry #{inspect(args["name"])}")}
        {_, md} -> {:ok, text(md)}
      end
    end)
  end

  tool "get_agreements", "The working agreements (CLAUDE.md) or the blocklist (BLOCKLIST.md)." do
    param(:document, :string,
      description: "CLAUDE.md (default), BLOCKLIST.md, PITFALLS.md or KEYPOINTS.md."
    )

    handle(fn args, _state ->
      name = args["document"] || "CLAUDE.md"

      case Corpus.document(name) do
        nil -> {:ok, error("no document #{inspect(name)}")}
        md -> {:ok, text(md)}
      end
    end)
  end

  defp filter(entries, nil, _), do: entries
  defp filter(entries, "", _), do: entries

  defp filter(entries, value, get) do
    Enum.filter(entries, &(get.(&1) != nil and Atom.to_string(get.(&1)) == value))
  end

  defp summary(e) do
    %{
      serial: e.serial,
      slug: e.slug,
      title: e.title,
      state: e.state,
      flight_level: e.flight_level,
      scope: e.scope
    }
  end

  defp heading(md) do
    md
    |> String.split("\n")
    |> Enum.find("", &String.starts_with?(&1, "# "))
    |> String.trim_leading("# ")
  end

  defp text(s), do: %{content: [%{type: "text", text: s}]}
  defp json(term), do: text(Jason.encode!(term, pretty: true))
  defp error(msg), do: %{content: [%{type: "text", text: msg}], isError: true}
end
