# SPDX-License-Identifier: Apache-2.0 OR MIT
# Rejects a taskweft domain or problem that is not valid Elixir.
#
# RFD 1037 records that a RECTGTN domain is Elixir DSL source, and the
# `plan` tool takes it as a string with format "dsl". A file that does
# not parse fails at the planner, which is far from the edit that
# broke it. This check names the failure at commit time.
#
# The prek hook passes the changed files. With no arguments it checks
# every domain and problem in this repository.
#
# Moved here from weftspun-3d-studio's own scripts/ when decisions/
# itself moved to this repository; only the wildcard (decisions/**/*.ex
# -> */*.ex) changed.

files =
  case System.argv() do
    [] -> Path.wildcard("*/*.ex")
    given -> given
  end

failures =
  Enum.reduce(files, [], fn file, acc ->
    case Code.string_to_quoted(File.read!(file)) do
      {:ok, _ast} ->
        acc

      {:error, {meta, message, token}} ->
        line = Keyword.get(meta, :line, 0)
        detail = "#{inspect(message)} #{inspect(token)}"
        [{file, line, detail} | acc]
    end
  end)

case failures do
  [] ->
    IO.puts("ok #{length(files)} file(s) parse")
    System.halt(0)

  found ->
    Enum.each(Enum.reverse(found), fn {file, line, detail} ->
      IO.puts(:stderr, "FAIL #{file}:#{line} #{detail}")
    end)

    System.halt(1)
end
