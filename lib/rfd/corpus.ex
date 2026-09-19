# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT

defmodule RFD.Corpus do
  @moduledoc """
  Every RFD, register, logbook entry and agreement document, loaded once and held in
  `:persistent_term` for the site and the MCP server. `mix rfd.pack` writes the same
  term to `priv/corpus.bin` so a release boots without compiling the sources.

  Also the mixin contract that register-like corpora implement — `SERIALS.exs`,
  `SERIALS-vsekai-fabric.exs`, `ESCAPES.exs` — so `RFD.Corpora` can answer questions
  across all of them without a caller picking a single file. A single module
  because splitting the aggregate loader and the register contract into two
  modules once already produced the outage this file exists to prevent: the
  loader gone and every `RFD.Corpus.entries/0` call in the router still there.

  Mixed in with `use RFD.Corpus, kind: :serials, via: :__register__, entries: :rows`
  which injects `__corpus__/0` and declares the behaviour.
  """

  defmodule Entry do
    @moduledoc false
    defstruct [:serial, :slug, :title, :state, :feature, :scope, :flight_level, :readme, :details]
  end

  @type entry :: map()
  @type t :: %{kind: atom(), name: String.t(), entries: [entry()]}

  @callback __corpus__() :: t()

  defmacro __using__(opts) do
    kind = Keyword.fetch!(opts, :kind)
    via = Keyword.fetch!(opts, :via)
    entries = Keyword.fetch!(opts, :entries)

    quote do
      @behaviour RFD.Corpus

      @impl RFD.Corpus
      def __corpus__ do
        doc = apply(__MODULE__, unquote(via), [])

        %{
          kind: unquote(kind),
          name: Map.get(doc, :name) || to_string(__MODULE__),
          entries: Map.fetch!(doc, unquote(entries))
        }
      end
    end
  end

  @key {__MODULE__, :corpus}

  def load do
    corpus =
      case packed_path() do
        {:ok, path} -> path |> File.read!() |> :erlang.binary_to_term()
        :error -> build(root())
      end

    :persistent_term.put(@key, corpus)
    corpus
  end

  def root, do: System.get_env("RFD_ROOT") || RFD.Source.repo_root()

  defp packed_path do
    path = Application.app_dir(:rfd, "priv/corpus.bin")
    if File.exists?(path), do: {:ok, path}, else: :error
  end

  @doc "Build the corpus from the sources under `root`."
  def build(root) do
    Code.compiler_options(ignore_module_conflict: true)

    entries =
      for path <- Path.wildcard(Path.join(root, "rfd/[0-9][0-9][0-9][0-9]-*.exs")),
          doc = RFD.Source.load(path) do
        %Entry{
          serial: doc.serial,
          slug: path |> Path.basename(".exs") |> String.slice(5..-1//1),
          title: doc.title,
          state: doc.state,
          feature: doc.feature,
          scope: doc.scope,
          flight_level: doc.flight_level,
          readme: RFD.Doc.readme(doc),
          details: RFD.Doc.details(doc)
        }
      end

    registers =
      for path <- Path.wildcard(Path.join(root, "SERIALS*.exs")),
          do: {Path.basename(path, ".exs"), RFD.Source.load(path)}

    logbook =
      for path <- Path.wildcard(Path.join(root, "logbook/*.md")) |> Enum.sort(),
          do: {Path.basename(path, ".md"), File.read!(path)}

    %{
      entries: Enum.sort_by(entries, & &1.serial, :desc),
      registers: registers,
      logbook: logbook,
      documents: documents(root)
    }
  end

  def get, do: :persistent_term.get(@key, nil) || load()

  def entries, do: get().entries
  def registers, do: get().registers
  def logbook, do: get().logbook
  def document(name), do: get().documents[name]

  def entry(serial) when is_integer(serial), do: Enum.find(entries(), &(&1.serial == serial))

  def entry(name) when is_binary(name) do
    case Integer.parse(name) do
      {serial, _} -> entry(serial)
      :error -> nil
    end
  end

  def logbook_entry(name), do: List.keyfind(logbook(), name, 0)

  def by_level(level), do: Enum.filter(entries(), &(&1.flight_level == level))

  @doc "Entries whose prose contains `query`, case-insensitively, with the matching lines."
  def search(query) when is_binary(query) do
    q = String.downcase(query)

    for e <- entries(),
        text = e.readme <> "\n" <> (e.details || ""),
        lines = matching_lines(text, q),
        lines != [] do
      {e, Enum.take(lines, 5)}
    end
  end

  defp matching_lines(text, q) do
    for l <- String.split(text, "\n"), String.contains?(String.downcase(l), q), do: l
  end

  @doc "The next unused serial: max plus one on the site still allocating."
  def next_serial do
    registers()
    |> Enum.map(fn {_, r} -> r end)
    |> Enum.reject(&match?({:decommissioned, _}, &1.layer[:note]))
    |> Enum.flat_map(fn r -> Enum.map(r.rows, &elem(&1, 1)) end)
    |> Enum.max(fn -> 2000 end)
    |> Kernel.+(1)
  end

  defp documents(root) do
    for name <- ~w(CLAUDE.md BLOCKLIST.md PITFALLS.md KEYPOINTS.md),
        File.exists?(Path.join(root, name)),
        into: %{},
        do: {name, File.read!(Path.join(root, name))}
  end
end
