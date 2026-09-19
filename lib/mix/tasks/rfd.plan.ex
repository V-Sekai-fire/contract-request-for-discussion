# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT

defmodule Mix.Tasks.Rfd.Plan do
  @shortdoc "Render every apparatus plan .exs to its sibling .usda"
  @moduledoc """
  `mix rfd.plan` writes `<name>.usda` beside each `<name>.exs` plan source.

      mix rfd.plan               # every plan source
      mix rfd.plan PATH...       # only these
      mix rfd.plan --check       # render to memory and fail on any drift

  `--check` is what a gate runs: it re-renders and compares against the file on disk
  without writing, so a hand-edited layer or a stale artifact fails a command.
  """
  use Mix.Task

  @roots ["apparatus", "."]

  @impl true
  def run(argv) do
    Mix.Task.run("app.start")
    {opts, paths} = OptionParser.parse!(argv, strict: [check: :boolean])
    sources = if paths == [], do: discover(), else: paths

    if sources == [] do
      Mix.raise("no plan source found; a plan source is an .exs whose module uses RFD.Plan")
    end

    results = Enum.map(sources, &render(&1, opts[:check] == true))
    bad = Enum.count(results, &(&1 == :drift))

    Mix.shell().info("#{length(results)} plan(s), #{bad} out of date")
    if bad > 0, do: Mix.raise("a rendered layer disagrees with its source; run `mix rfd.plan`")
  end

  defp discover do
    @roots
    |> Enum.flat_map(&Path.wildcard(Path.join([&1, "**", "*.exs"])))
    |> Enum.reject(&String.contains?(&1, ["deps/", "_build/", "test/"]))
    |> Enum.filter(&(File.read!(&1) =~ "use RFD.Plan"))
    |> Enum.uniq()
  end

  defp render(source, check?) do
    out = Path.rootname(source) <> ".usda"
    text = source |> load() |> RFD.Plan.usda()

    cond do
      check? and not File.exists?(out) ->
        Mix.shell().info("  FAIL #{out}: never rendered")
        :drift

      check? ->
        if normalise(File.read!(out)) == normalise(text) do
          Mix.shell().info("  ok   #{out}")
          :same
        else
          Mix.shell().info("  FAIL #{out}: disagrees with #{Path.basename(source)}")
          :drift
        end

      true ->
        File.write!(out, text)
        Mix.shell().info("  ok   #{out}")
        :written
    end
  end

  # Line endings are the checkout's business, not the layer's.
  defp normalise(s), do: String.replace(s, "\r\n", "\n")

  defp load(source) do
    [{mod, _} | _] = Code.compile_file(source)
    mod.__plan__()
  end
end
