# SPDX-License-Identifier: Apache-2.0 OR MIT
# Runner: run the gates a project declares, over the change at hand.
#
# Dispatches to prek where a `.pre-commit-config.yaml` exists and to the pixi `gate`
# environment where one is declared. Adds no gate of its own. The measurements that
# argue for it, and the four controls, are in
# `logbook/logbook-local-gates-before-ci.md`.
#
# Usage:
#     elixir scripts/gate.exs [<path>] [--base REF]   # one project; default the cwd's
#     elixir scripts/gate.exs --all                   # every manifest project with a gate
#     elixir scripts/gate.exs --install               # install the prek hook where declared
#     elixir scripts/gate.exs --self-test
#
# Exit codes: 0 all gates passed, 1 a gate failed, 2 bad usage or an empty sweep.

defmodule Gate do
  @root Path.expand(Path.join(__DIR__, "../../.."))

  # Parsed from the manifest: `repo forall` visits zero projects here.
  def projects do
    manifest = Path.join(@root, ".repo/manifests/default.xml")

    if File.exists?(manifest) do
      {doc, _} = :xmerl_scan.file(String.to_charlist(manifest), quiet: true)

      :xmerl_xpath.string(~c"//project/@path", doc)
      |> Enum.map(fn {:xmlAttribute, _, _, _, _, _, _, _, value, _} -> List.to_string(value) end)
      |> Enum.filter(&File.dir?(Path.join(@root, &1)))
      |> Enum.uniq()
      |> Enum.sort()
    else
      []
    end
  end

  def mechanisms(abs) do
    prek = if File.exists?(Path.join(abs, ".pre-commit-config.yaml")), do: [:prek], else: []
    pixi = if pixi_gate_env?(abs), do: [:pixi_gate], else: []
    inc = if engine_tree?(abs), do: [:includes], else: []
    prek ++ inc ++ pixi
  end

  # An engine checkout, recognised by the roots an engine include is written against.
  def engine_tree?(abs) do
    Enum.all?(["core", "scene", "servers"], &File.dir?(Path.join(abs, &1)))
  end

  defp pixi_gate_env?(abs) do
    path = Path.join(abs, "pixi.toml")

    File.exists?(path) and
      path |> File.read!() |> String.contains?("\ngate = {")
  end

  def base_ref(abs, nil) do
    case System.cmd("git", ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"],
           cd: abs,
           stderr_to_stdout: true
         ) do
      {out, 0} -> String.trim(out)
      _ -> nil
    end
  end

  def base_ref(_abs, explicit), do: explicit

  def changed_files(abs, base) do
    args =
      case base do
        nil -> ["diff", "--name-only", "HEAD"]
        b -> ["diff", "--name-only", "#{b}...HEAD"]
      end

    case System.cmd("git", args, cd: abs, stderr_to_stdout: false) do
      {out, 0} ->
        out
        |> String.replace("\r", "")
        |> String.split("\n", trim: true)
        |> Enum.filter(&File.exists?(Path.join(abs, &1)))

      _ ->
        []
    end
  end

  # A --files list of thousands exceeds the Windows command line; prek takes a range.
  def run_prek(abs, base, files \\ nil) do
    args =
      cond do
        is_list(files) -> ["run", "--files" | files]
        is_binary(base) -> ["run", "--from-ref", base, "--to-ref", "HEAD"]
        true -> ["run", "--all-files"]
      end

    # Unpiped: a pipeline would report the last stage's status, not the gate's.
    case System.cmd("prek", args, cd: abs, stderr_to_stdout: true) do
      {out, 0} -> {:ok, out}
      {out, code} -> {:fail, "prek exited #{code}\n" <> failed_hooks(out)}
    end
  end

  defp failed_hooks(out) do
    out
    |> String.split("\n")
    |> Enum.filter(&(String.contains?(&1, "Failed") or String.contains?(&1, "hook id:") or
                       String.contains?(&1, "==>")))
    |> Enum.take(20)
    |> Enum.join("\n")
  end

  def run_pixi_gate(abs) do
    case System.cmd("pixi", ["run", "-e", "gate", "python", "scripts/check_anti_entropy.py"],
           cd: abs,
           stderr_to_stdout: true
         ) do
      {out, 0} -> {:ok, out}
      {out, code} -> {:fail, "pixi gate exited #{code}\n" <> tail(out)}
    end
  end

  defp tail(text, n \\ 25) do
    text |> String.split("\n") |> Enum.take(-n) |> Enum.join("\n")
  end

  # The dirty set wins: a range check cannot see uncommitted work.
  def gate(abs, base) do
    case dirty_files(abs) do
      [] -> run_for(abs, base_ref(abs, base), nil)
      files -> run_for(abs, nil, files)
    end
  end

  defp run_for(abs, ref, files) do
    mechanisms(abs)
    |> Enum.map(fn
      :prek -> {:prek, run_prek(abs, ref, files)}
      :includes -> {:includes, run_includes(abs, ref, files)}
      :pixi_gate -> {:pixi_gate, run_pixi_gate(abs)}
    end)
  end

  @engine_roots ~w(core scene servers editor main drivers platform)

  @doc """
  Every engine-rooted `#include "..."` in the changed sources resolves to a file.
  Catches the relocation class, where upstream moves a header and git reports the
  merge clean because nothing conflicted; it surfaces only at compile time.
  """
  def run_includes(abs, ref, files) do
    sources =
      (files || changed_files(abs, ref))
      |> Enum.filter(&(Path.extname(&1) in [".c", ".h", ".cpp", ".hpp", ".cc", ".hh", ".inc"]))
      |> Enum.reject(&String.contains?(&1, "thirdparty/"))

    broken =
      for f <- sources,
          abs_f = Path.join(abs, f),
          File.regular?(abs_f),
          inc <- engine_includes(abs_f),
          not File.regular?(Path.join(abs, inc)),
          do: "#{f} -> #{inc}"

    case Enum.uniq(broken) do
      [] -> {:ok, "#{length(sources)} source(s), every engine include resolves"}
      bad -> {:fail, "unresolved include(s):\n" <> Enum.join(Enum.take(bad, 20), "\n")}
    end
  end

  defp engine_includes(abs_f) do
    abs_f
    |> File.read!()
    |> String.split("\n")
    |> Enum.flat_map(fn line ->
      case Regex.run(~r/^\s*#include\s+"([^"]+)"/, line) do
        [_, inc] -> [inc]
        _ -> []
      end
    end)
    # Generated headers do not exist until SCons writes them, and a module-relative
    # include resolves through a CPPPATH this check cannot see. Both are excluded, so
    # the floor is: only engine-rooted, non-generated includes are checked.
    |> Enum.filter(&(hd(String.split(&1, "/")) in @engine_roots))
    |> Enum.reject(&String.ends_with?(&1, ".gen.h"))
  end

  def dirty_files(abs) do
    case System.cmd("git", ["status", "--porcelain", "-z"], cd: abs, stderr_to_stdout: false) do
      {out, 0} ->
        out
        |> String.split(<<0>>, trim: true)
        |> Enum.map(fn entry ->
          entry |> String.slice(3..-1//1) |> String.trim()
        end)
        |> Enum.filter(&(&1 != "" and File.regular?(Path.join(abs, &1))))
        |> Enum.uniq()

      _ ->
        []
    end
  end

  def install do
    targets = for p <- projects(), :prek in mechanisms(Path.join(@root, p)), do: p

    {ok, bad} =
      Enum.split_with(targets, fn p ->
        match?({_, 0}, System.cmd("prek", ["install"], cd: Path.join(@root, p), stderr_to_stdout: true))
      end)

    IO.puts("  installed the prek hook in #{length(ok)} of #{length(targets)} project(s)")
    Enum.each(bad, &IO.puts("  FAILED to install: #{&1}"))
    if bad == [], do: 0, else: 1
  end

  def self_test do
    results = [
      {"the enumerator visits more than zero projects", length(projects()) > 0},
      {"a planted always-failing hook is reported as a failure", planted(:fail) == :fail},
      {"a planted always-passing hook is reported as a pass", planted(:pass) == :ok},
      {"a defect that is only in the working tree is reported as a failure",
       uncommitted_control() == :fail},
      {"a planted unresolved engine include is reported as a failure",
       include_control(:broken) == :fail},
      {"a generated .gen.h include is not reported as unresolved",
       include_control(:generated) == :ok}
    ]

    Enum.each(results, fn {name, ok} ->
      IO.puts(if ok, do: "  ok     #{name}", else: "  FAIL   #{name}")
    end)

    if Enum.all?(results, &elem(&1, 1)), do: 0, else: 1
  end

  defp uncommitted_control do
    dir = Path.join(System.tmp_dir!(), "gate_dirty_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)

    File.write!(Path.join(dir, ".pre-commit-config.yaml"), """
    repos:
      - repo: local
        hooks:
          - id: no-defect
            name: the word 'defect' must not appear
            language: system
            entry: python -c "import sys;sys.exit(any('defect' in open(f).read() for f in sys.argv[1:]))"
            files: \\.txt$
    """)

    File.write!(Path.join(dir, "subject.txt"), "clean\n")
    env = [{"GIT_AUTHOR_NAME", "g"}, {"GIT_AUTHOR_EMAIL", "g@x"}, {"GIT_COMMITTER_NAME", "g"},
           {"GIT_COMMITTER_EMAIL", "g@x"}]
    System.cmd("git", ["init", "-q"], cd: dir, stderr_to_stdout: true)
    System.cmd("git", ["add", "-A"], cd: dir, stderr_to_stdout: true)
    System.cmd("git", ["commit", "-qm", "clean"], cd: dir, env: env, stderr_to_stdout: true)

    File.write!(Path.join(dir, "subject.txt"), "this line has a defect\n")

    result =
      if Enum.any?(gate(dir, nil), fn {_, r} -> match?({:fail, _}, r) end), do: :fail, else: :ok

    File.rm_rf!(dir)
    result
  end

  # A tree shaped like an engine checkout, with one source whose include either does not
  # resolve or is generated. The second direction matters as much as the first: a check
  # that flags every .gen.h is noise, and a noisy gate gets switched off.
  defp include_control(kind) do
    dir = Path.join(System.tmp_dir!(), "gate_inc_#{kind}_#{System.unique_integer([:positive])}")
    Enum.each(["core", "scene", "servers", "modules/m"], &File.mkdir_p!(Path.join(dir, &1)))
    File.write!(Path.join(dir, "servers/real.h"), "// present\n")

    include =
      case kind do
        :broken -> "servers/audio/effects/moved_away.h"
        :generated -> "core/object/gdvirtual.gen.h"
      end

    File.write!(Path.join(dir, "modules/m/a.cpp"), ~s(#include "#{include}"\n#include "servers/real.h"\n))

    result =
      case run_includes(dir, nil, ["modules/m/a.cpp"]) do
        {:ok, _} -> :ok
        {:fail, _} -> :fail
      end

    File.rm_rf!(dir)
    result
  end

  defp planted(kind) do
    dir = Path.join(System.tmp_dir!(), "gate_selftest_#{kind}_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)

    code = if kind == :fail, do: "1", else: "0"

    File.write!(Path.join(dir, ".pre-commit-config.yaml"), """
    repos:
      - repo: local
        hooks:
          - id: planted
            name: planted control
            language: system
            entry: python -c "import sys; sys.exit(#{code})"
            files: \\.txt$
    """)

    File.write!(Path.join(dir, "subject.txt"), "subject\n")
    System.cmd("git", ["init", "-q"], cd: dir, stderr_to_stdout: true)

    result =
      case run_prek(dir, nil, ["subject.txt"]) do
        {:ok, _} -> :ok
        {:fail, _} -> :fail
      end

    File.rm_rf!(dir)
    result
  end

  def report(label, results) do
    Enum.each(results, fn {mech, r} ->
      case r do
        {:ok, _} -> IO.puts("  ok     #{label}  (#{mech})")
        {:fail, why} -> IO.puts("  FAIL   #{label}  (#{mech})\n#{indent(why)}")
      end
    end)

    Enum.any?(results, fn {_, r} -> match?({:fail, _}, r) end)
  end

  defp indent(text), do: text |> String.split("\n") |> Enum.map(&("         " <> &1)) |> Enum.join("\n")
end

# --- entry point -----------------------------------------------------------------------

argv = System.argv()

{base, argv} =
  case Enum.find_index(argv, &(&1 == "--base")) do
    nil -> {nil, argv}
    i -> {Enum.at(argv, i + 1), List.delete_at(List.delete_at(argv, i), i)}
  end

root = Path.expand(Path.join(__DIR__, "../../.."))

code =
  cond do
    "--self-test" in argv ->
      Gate.self_test()

    "--install" in argv ->
      Gate.install()

    "--all" in argv ->
      all = Gate.projects()
      gated = Enum.filter(all, &(Gate.mechanisms(Path.join(root, &1)) != []))

      if all == [] do
        IO.puts("  FAIL   the enumerator visited zero projects; refusing to call that clean")
        2
      else
        failed =
          gated
          |> Enum.map(fn p -> Gate.report(p, Gate.gate(Path.join(root, p), base)) end)
          |> Enum.any?()

        IO.puts("\n  #{length(gated)} of #{length(all)} project(s) declare a gate; " <>
                  "#{length(all) - length(gated)} declare none and were not checked")

        if failed, do: 1, else: 0
      end

    true ->
      target =
        case Enum.find(argv, &(not String.starts_with?(&1, "--"))) do
          nil -> File.cwd!()
          p -> Path.expand(p)
        end

      case Gate.mechanisms(target) do
        [] ->
          IO.puts("  --     #{target} declares no local gate; nothing run (this is not a pass)")
          0

        _ ->
          if Gate.report(Path.relative_to(target, root), Gate.gate(target, base)), do: 1, else: 0
      end
  end

System.halt(code)
