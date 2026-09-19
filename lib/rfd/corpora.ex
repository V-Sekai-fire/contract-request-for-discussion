# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT

defmodule RFD.Corpora do
  @moduledoc """
  The facade over every register-like corpus in the repository.

  There is deliberately no way to ask this about a single corpus. Questions are
  answered across all of them, because the alternative — pick a file, grep it —
  is what produced `grep 2235 SERIALS.exs -> 0 hits` and the conclusion that no
  register named the serial. It sat in `SERIALS-vsekai-fabric.exs`.

  Discovery is by pattern over the repository root, and `load!/1` fails when it
  finds none: an empty corpus set answering "not found" is the same silent pass
  in a different costume.
  """

  @patterns ["SERIALS*.exs", "ESCAPES*.exs"]

  @doc "Every corpus file on disk. Raises when the set is empty."
  def files(root \\ ".") do
    case Enum.flat_map(@patterns, &Path.wildcard(Path.join(root, &1))) do
      [] -> raise "no corpus files under #{root} matching #{Enum.join(@patterns, ", ")}"
      found -> Enum.sort(found)
    end
  end

  @doc "Load every corpus, compiling each file once. Raises when any fails to load."
  def load!(root \\ ".") do
    for path <- files(root) do
      case Code.compile_file(path) do
        [{mod, _} | _] ->
          unless function_exported?(mod, :__corpus__, 0) do
            raise "#{path} defines #{inspect(mod)}, which does not implement RFD.Corpus"
          end

          Map.put(mod.__corpus__(), :path, path)

        [] ->
          raise "#{path} defined no module"
      end
    end
  end

  @doc """
  Which corpora mention a term, searched across all of them.

  Returns `{term, [%{path:, kind:, name:}]}`. An empty list means every corpus
  was searched and none matched — a claim `grep one-file` cannot make.
  """
  def mentions(term, root \\ ".") do
    needle = to_string(term)

    hits =
      for path <- files(root), File.read!(path) =~ needle do
        %{path: path, kind: kind_of(path), name: Path.basename(path, ".exs")}
      end

    {needle, hits}
  end

  @doc "True when some corpus names the term. The whole point is that it cannot be asked of one file."
  def names?(term, root \\ ".") do
    {_, hits} = mentions(term, root)
    hits != []
  end

  @doc "Entries across every corpus of a kind."
  def entries(kind, root \\ ".") do
    load!(root) |> Enum.filter(&(&1.kind == kind)) |> Enum.flat_map(& &1.entries)
  end

  defp kind_of(path) do
    case Path.basename(path) do
      "ESCAPES" <> _ -> :escapes
      "SERIALS" <> _ -> :serials
      _ -> :unknown
    end
  end
end
