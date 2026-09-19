# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT

defmodule Mix.Tasks.Rfd.Render do
  @shortdoc "Render rfd/NNNN-slug.exs into rfd/NNNN-slug/ and SERIALS*.exs into SERIALS*.usda"
  @moduledoc """
      mix rfd.render [--check] [NAME ...]

  NAME is `NNNN-slug`, `rfd/NNNN-slug.exs`, a directory or `SERIALS*.exs`; with none,
  every source is rendered. `--check` writes nothing and fails on drift.
  """
  use Mix.Task

  @impl true
  def run(args) do
    {opts, names, _} = OptionParser.parse(args, strict: [check: :boolean])

    sources =
      if names == [],
        do: RFD.Source.all() ++ RFD.Source.registers(),
        else: Enum.map(names, &RFD.Source.at/1)

    if sources == [], do: Mix.raise("no rfd/*.exs found")

    results = Enum.map(sources, &RFD.Source.render(&1, opts))
    bad = Enum.filter(results, &match?({:drift, _, _}, &1))

    for r <- results do
      case r do
        {:ok, name, files} -> Mix.shell().info("ok    #{name}: #{Enum.join(files, ", ")}")
        {:same, name} -> Mix.shell().info("same  #{name}")
        {:drift, name, files} -> Mix.shell().error("DRIFT #{name}: #{Enum.join(files, ", ")}")
      end
    end

    Mix.shell().info("rendered #{length(results)} source(s)")
    if bad != [], do: Mix.raise("#{length(bad)} rendered file(s) differ from their source")
  end
end

defmodule Mix.Tasks.Rfd.Check do
  @shortdoc "Compile every RFD and register source; one outside RFD 1000's shape fails here"
  @moduledoc false
  use Mix.Task

  @impl true
  def run(args) do
    {_, names, _} = OptionParser.parse(args, strict: [])

    sources =
      if names == [],
        do: RFD.Source.all() ++ RFD.Source.registers(),
        else: Enum.map(names, &RFD.Source.at/1)

    Code.compiler_options(ignore_module_conflict: true)

    bad =
      for path <- sources, reduce: [] do
        acc ->
          try do
            RFD.Source.load(path)
            acc
          rescue
            e ->
              Mix.shell().error("FAIL #{Path.basename(path)}: #{Exception.message(e)}")
              [path | acc]
          end
      end

    Mix.shell().info("#{length(sources) - length(bad)} of #{length(sources)} source(s) compile")
    if bad != [], do: Mix.raise("#{length(bad)} source(s) are outside RFD 1000's shape")
  end
end

defmodule Mix.Tasks.Rfd.Usda do
  @shortdoc "Print the .usda rendering of one register source to stdout"
  @moduledoc false
  use Mix.Task

  @impl true
  def run([path]) do
    Mix.shell().info(path |> RFD.Source.load() |> RFD.Register.usda())
  end

  def run(_), do: Mix.raise("usage: mix rfd.usda PATH")
end

defmodule Mix.Tasks.Rfd.Serials do
  @shortdoc "Hold every register against the tree, and against a base revision"
  @moduledoc """
      mix rfd.serials [--base REF]

  The registers against the sources on disk and, with `--base`, against a revision:
  no serial gone, none revived. A missing base register fails unless it is new here.
  """
  use Mix.Task

  @impl true
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [base: :string])
    registers = RFD.Source.registers()
    if registers == [], do: Mix.raise("no SERIALS*.exs at the repository root")

    problems =
      Enum.flat_map(registers, fn path ->
        r = RFD.Source.load(path)
        name = Path.basename(path)

        tree = Enum.map(RFD.Serials.tree_problems(r, RFD.Source.all()), &"#{name}: #{&1}")

        base =
          case opts[:base] do
            nil -> []
            ref -> Enum.map(base_problems(path, ref), &"#{name}: #{&1}")
          end

        {a, d} = RFD.Register.tables(r)
        Mix.shell().info("#{name}: #{map_size(a)} allocated, #{map_size(d)} deleted")
        tree ++ base
      end)

    for p <- problems, do: Mix.shell().error(p)
    Mix.shell().info("#{length(problems)} problem(s)")
    if problems != [], do: Mix.raise("the register and the tree disagree")
  end

  defp base_problems(path, ref) do
    rel = Path.relative_to(path, RFD.Source.repo_root())

    case System.cmd("git", ["show", "#{ref}:#{rel}"],
           cd: RFD.Source.repo_root(),
           stderr_to_stdout: true
         ) do
      {text, 0} ->
        RFD.Serials.base_problems(RFD.Source.load_string(text, rel), RFD.Source.load(path))

      _ ->
        case System.cmd("git", ["diff", "--name-status", "#{ref}...HEAD", "--", rel],
               cd: RFD.Source.repo_root()
             ) do
          {"A" <> _, 0} -> []
          _ -> ["no #{rel} at #{ref}, so nothing held the register in place"]
        end
    end
  end
end

defmodule RFD.Serials do
  @moduledoc "The register held against the tree and against its own previous revision."

  @doc "Reasons the register and the `rfd/*.exs` sources disagree."
  def tree_problems(%RFD.Register{} = r, sources) do
    {allocated, deleted} = RFD.Register.tables(r)
    site = r.layer[:site]

    on_disk =
      for path <- sources,
          name = path |> Path.basename() |> String.replace_suffix(".exs", ""),
          serial = String.to_integer(String.slice(name, 0, 4)),
          div(serial, 1000) == site,
          into: %{},
          do: {serial, String.slice(name, 5..-1//1)}

    dirs =
      for {serial, slug} <- Enum.sort(on_disk) do
        cond do
          not Map.has_key?(allocated, serial) ->
            "#{serial}-#{slug}: the source has no allocated row"

          allocated[serial] != slug ->
            "#{serial}: the register says #{allocated[serial]}, the source says #{slug}"

          true ->
            nil
        end
      end

    rows =
      for {serial, _} <- Enum.sort(allocated), not Map.has_key?(on_disk, serial) do
        "serial #{serial} is allocated and has no source"
      end

    gone =
      for {serial, _} <- Enum.sort(deleted), Map.has_key?(on_disk, serial) do
        "serial #{serial} is listed as deleted and has a source"
      end

    Enum.reject(dirs, &is_nil/1) ++ rows ++ gone
  end

  @doc "A serial the previous revision recorded is still recorded, and never revived."
  def base_problems(%RFD.Register{} = was, %RFD.Register{} = now) do
    {was_a, was_d} = RFD.Register.tables(was)
    {now_a, now_d} = RFD.Register.tables(now)
    present = Map.keys(now_a) ++ Map.keys(now_d)

    gone =
      for s <- Enum.sort(Map.keys(was_a) ++ Map.keys(was_d)), s not in present do
        "serial #{s} was in the register and is gone from it"
      end

    revived =
      for s <- Enum.sort(Map.keys(was_d)), Map.has_key?(now_a, s) do
        "serial #{s} was deleted and is allocated again"
      end

    gone ++ revived
  end
end

defmodule RFD.Source do
  @moduledoc "Locate, compile and render the RFD and register sources."

  def repo_root, do: File.cwd!()
  def rfd_root, do: Path.join(repo_root(), "rfd")

  def all do
    rfd_root() |> Path.join("[0-9][0-9][0-9][0-9]-*.exs") |> Path.wildcard() |> Enum.sort()
  end

  def registers do
    repo_root() |> Path.join("SERIALS*.exs") |> Path.wildcard() |> Enum.sort()
  end

  @doc "Resolve `NNNN-slug`, `rfd/NNNN-slug.exs`, a directory, or `SERIALS*.exs` to a source path."
  def at(name) do
    base = name |> Path.basename() |> String.replace_suffix(".exs", "")

    if String.starts_with?(base, "SERIALS"),
      do: Path.join(repo_root(), base <> ".exs"),
      else: Path.join(rfd_root(), base <> ".exs")
  end

  def register?(path), do: path |> Path.basename() |> String.starts_with?("SERIALS")

  @doc "The directory an RFD rendering goes to."
  def dir_of(path), do: String.replace_suffix(path, ".exs", "")

  @doc "Compile one source and return its document; the compile itself validates it."
  def load(path) do
    Code.compiler_options(ignore_module_conflict: true)
    path |> Code.compile_file() |> Enum.map(&elem(&1, 0)) |> pick(path)
  end

  @doc "Compile source text (a base revision read from git) the same way."
  def load_string(text, name) do
    Code.compiler_options(ignore_module_conflict: true)
    text |> Code.compile_string(name) |> Enum.map(&elem(&1, 0)) |> pick(name)
  end

  defp pick(mods, path) do
    docs =
      Enum.flat_map(mods, fn m ->
        cond do
          function_exported?(m, :__rfd__, 0) -> [m.__rfd__()]
          function_exported?(m, :__register__, 0) -> [m.__register__()]
          true -> []
        end
      end)

    case docs do
      [doc] -> doc
      [] -> raise ArgumentError, "#{path} defines no module that uses RFD.DSL or RFD.Register"
      many -> raise ArgumentError, "#{path} defines #{length(many)} documents; one per file"
    end
  end

  def render(path, opts) do
    if register?(path), do: render_register(path, opts), else: render_rfd(path, opts)
  end

  defp render_register(path, opts) do
    name = Path.basename(path, ".exs")
    out = String.replace_suffix(path, ".exs", ".usda")
    body = path |> load() |> RFD.Register.usda()
    write(name, Path.dirname(path), [{Path.basename(out), body}], opts)
  end

  defp render_rfd(path, opts) do
    dir = dir_of(path)
    name = Path.basename(dir)
    doc = load(path)

    if Integer.to_string(doc.serial) != String.slice(name, 0, 4) do
      raise ArgumentError, "#{path}: serial #{doc.serial} does not match the file name #{name}"
    end

    wanted =
      [{"README.md", RFD.Doc.readme(doc)}, {"DETAILS.md", RFD.Doc.details(doc)}]
      |> Enum.reject(fn {_, body} -> is_nil(body) end)

    write(name, dir, wanted, opts)
  end

  defp write(name, dir, wanted, opts) do
    differing = for {n, body} <- wanted, File.read(Path.join(dir, n)) != {:ok, body}, do: n

    cond do
      differing == [] ->
        {:same, name}

      opts[:check] ->
        {:drift, name, differing}

      true ->
        File.mkdir_p!(dir)
        for {n, body} <- wanted, n in differing, do: File.write!(Path.join(dir, n), body)
        {:ok, name, differing}
    end
  end
end
