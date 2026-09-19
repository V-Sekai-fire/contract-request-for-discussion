# SPDX-License-Identifier: Apache-2.0 OR MIT
# Gate: the aphoristic negative definition, ratcheted toward how people actually write.
#
# THE TROPE. "A number nobody waited for isn't a measurement." "An ignore is not a lock."
# A short sentence, generic subject, predicate a negation, landing as a maxim. tropes.fyi
# catalogues its neighbours -- negative parallelism ("It's not X, it's Y") and quotable
# one-liners -- and stops short of this form, so the gate names it.
#
# CALIBRATED AGAINST THE COMMONS RATHER THAN AGAINST OURSELVES. A first version took its
# ceiling from the p90 of this repository's own files, which bakes the habit in: a document may
# be as aphoristic as its neighbours, and its neighbours are us. Measured instead against
# public-domain works chosen for reading MORE easily than technical writing:
#
#     Alice in Wonderland        0.15 per 1000 words    Flesch 81.3    27,427 words
#     Wizard of Oz               0.28                   Flesch 80.0    40,000
#     Aesop's Fables             0.31                   Flesch 68.0    45,078
#     Tom Sawyer                 0.32                   Flesch 79.6    74,383
#     Peter Pan                  0.60                   Flesch 81.1    48,036
#                                ----                   ---------
#     mean 0.30 once quoted mentions are dropped           Flesch 68-81
#
#     CLAUDE.md                  2.69                   Flesch 57.6     8,537
#
# Eight times the commons rate, in prose measurably harder to read. Public domain rather than
# CC-BY-SA, because share-alike is blocklisted here. Gutenberg ids 11, 55, 21, 74 and 16,
# fetched 2026-08-23 and recorded here rather than re-fetched: a gate needing the network fails
# for reasons unrelated to the file under test.
#
# GENRE EXPLAINS PART OF THE GAP. Strunk's Elements of Style, prescriptive writing guidance
# like ours, scores 1.01 per 1000 at Flesch 58.7 -- three times the narrative rate. Some of our
# density comes from the genre. Three times the commons rate is 0.90 against our 2.69, which
# leaves most of the gap to the habit.
#
# NOT OBTAINED, named rather than dropped: pre-2020 US government plain-language guidance, which
# is public domain and written to be read. plainlanguage.gov serves guidelines whose text
# extracts to 413 words, and the 2011 PDF URL returns HTML.
#
# THE RULE IS A RATCHET, so the tree walks down instead of being condemned:
#
#     above the commons rate      may not rise; it holds or falls
#     at or under it              may not cross
#     a file that is new          must land at or under the commons rate
#
# WHY ELIXIR. The other gate in this workspace is `Mix.Tasks.CheckSkipTags`, and this follows
# its shape -- documented switches, an exit code, controls that must fail. A standalone script
# rather than a Mix task because this repository is prose and has no mix project; `elixir
# scripts/check_prose_tropes.exs` needs nothing built.
#
# EQUIVALENCE WITH THE PYTHON IT REPLACES WAS MEASURED RATHER THAN ASSUMED. Both were run over
# the same six files and agreed to two decimals every time: 2.66, 0.90, 0.00, 2.23, 0.83, 0.82,
# with identical control output. `--rate <file>` prints one file's figure, which is how that
# comparison was made and how the next one can be. The Python is deleted, so the rule has one
# home.
#
# Usage:
#     elixir scripts/check_prose_tropes.exs [<repo>] [--base <ref>]
#     elixir scripts/check_prose_tropes.exs --self-test
#     elixir scripts/check_prose_tropes.exs --rate <file>
#
# Exit codes: 0 within the ratchet, 1 a file rose or crossed, 2 bad usage.

defmodule ProseTropes do
  # A short sentence whose predicate is a negation. Length does real work: an aphorism is
  # pithy, and a long negating sentence is usually an argument.
  @maxim ~r/\b(?:is|are|was|were)\s+not\b|\b(?:isn't|aren't|wasn't|weren't)\b/i
  @sentence ~r/[^.!?\n]+[.!?]/
  @word ~r/[A-Za-z']+/
  # USE, NOT MENTION. Quoted spans are dropped before scanning. A gate that defines a trope has
  # to quote specimens of it, and a control that reintroduces a defect has to contain the
  # defect, so counting those would fail every file for saying what it catches. Re-measured
  # under this rule the commons moves 0.33 to 0.30 -- fiction dialogue is rarely aphoristic --
  # while this file drops 7.08 to 3.12. Both sides of the comparison carry the same rule.
  @quoted ~r/"[^"\n]*"/
  @max_words 22
  @commons 0.30
  @floor_words 200
  @exts [".md", ".py", ".ex", ".exs", ".usda"]
  # USD CARRIES PROSE THAT THIS GATE NEVER SCORED. `rfd1122-plan.usda` holds 11,096 words of
  # `doc` strings -- the largest single body of prose in this repository -- at 2.16 per
  # 1k, higher than CLAUDE.md or BLOCKLIST.md. It went unscored because this gate
  # selected markdown and source, and a layer file is neither. Only the doc strings are
  # read: scoring the whole file would count `float2 extent = (0, 1)` as prose, and the
  # quote-stripping rule would eat a single-line `doc = "..."` entirely.
  @usda_doc_block ~r/doc\s*=\s*"""(.*?)"""/s
  @usda_doc_line ~r/doc\s*=\s*"([^"\n]*)"/

  @doc "The scoreable prose in a file: doc strings for USD, the whole text otherwise."
  def prose(path, text) do
    if String.ends_with?(path, ".usda"), do: usda_doc(text), else: text
  end

  def usda_doc(text) do
    blocks = Regex.scan(@usda_doc_block, text) |> Enum.map(fn [_, body] -> body end)
    rest = Regex.replace(@usda_doc_block, text, " ")
    lines = Regex.scan(@usda_doc_line, rest) |> Enum.map(fn [_, body] -> body end)
    Enum.join(blocks ++ lines, "\n\n")
  end

  def rate(text) do
    text = Regex.replace(@quoted, text, " ")
    words = Regex.scan(@word, text) |> length()

    if words == 0 do
      {0.0, [], 0}
    else
      hits =
        @sentence
        |> Regex.scan(text)
        |> Enum.map(fn [s] -> String.trim(s) end)
        |> Enum.filter(fn s ->
          n = Regex.scan(@word, s) |> length()
          n > 0 and n <= @max_words and Regex.match?(@maxim, s)
        end)

      {length(hits) / words * 1000, hits, words}
    end
  end

  @doc "The ratchet, in one place so the message and the rule cannot drift apart."
  def judge(_before, now, false), do: {now <= @commons, @commons, "new file, commons rate"}

  def judge(before, now, true) when before > @commons,
    do: {now <= before, before, "already above commons; hold or fall, do not rise"}

  def judge(_before, now, true),
    do: {now <= @commons, @commons, "at or under commons; may not cross"}

  def git(repo, args) do
    case System.cmd("git", ["-C", repo | args], stderr_to_stdout: true) do
      {out, 0} -> out
      _ -> nil
    end
  end

  def check(repo, base) do
    changed =
      (git(repo, ["diff", "--name-only", base]) || "")
      |> String.split("\n", trim: true)
      |> Enum.filter(fn f -> Enum.any?(@exts, &String.ends_with?(f, &1)) end)

    if changed == [] do
      IO.puts("no prose files changed")
      0
    else
      Enum.reduce(changed, 0, fn path, bad -> bad + score(repo, base, path) end)
      |> report()
    end
  end

  defp score(repo, base, path) do
    full = Path.join(repo, path)

    if not File.exists?(full) do
      0
    else
      {now, hits, words} = rate(prose(path, File.read!(full)))

      cond do
        words < @floor_words ->
          IO.puts("  ..   #{path}: #{words} words, under the #{@floor_words}-word floor, not scored")
          0

        true ->
          prev = git(repo, ["show", "#{base}:#{path}"])
          before = if prev, do: elem(rate(prose(path, prev)), 0), else: 0.0
          {ok, ceiling, why} = judge(before, now, prev != nil)

          if ok do
            IO.puts("  ok   #{path}: #{f(now)} per 1k (was #{f(before)}, ceiling #{f(ceiling)})")
            0
          else
            IO.puts("  FAIL #{path}: #{f(now)} per 1k, ceiling #{f(ceiling)} -- #{why}")
            Enum.take(hits, 3) |> Enum.each(&IO.puts(~s(        "#{String.slice(&1, 0, 86)}")))
            1
          end
      end
    end
  end

  defp report(0) do
    IO.puts("\nWithin the ratchet.")
    0
  end

  defp report(bad) do
    IO.puts("\n#{bad} file(s) reach for the maxim more than they did, or more than the " <>
              "commons rate of #{f(@commons)} per 1000 words.")
    IO.puts("Say the thing plainly, or carry the argument the maxim stands in for.")
    1
  end

  def f(x), do: :erlang.float_to_binary(x * 1.0, decimals: 2)

  # Controls. The detector and the decision are separate code and fail separately: all four
  # detector controls can pass while the ratchet returns 0 on a file that got worse.
  def self_test do
    plain = String.duplicate("The renderer writes depth in metres. ", 40)

    stuffed =
      List.duplicate(
        "A number nobody waited for is not a measurement. An ignore is not a lock. " <>
          "A file is not a capability.",
        8
      )
      |> Enum.join(" ")

    detector = [
      {"prose with no maxims scores zero", plain, fn r -> r == 0.0 end},
      {"prose stuffed with maxims scores high", plain <> stuffed, fn r -> r > 5.0 end},
      # One maxim in ~725 words is 1.38 per 1k. An earlier control guessed "under 1.0" and
      # failed on arithmetic rather than on the detector, so this one divides instead.
      {"a single maxim in 725 words is 1.38",
       String.duplicate(plain, 3) <> " A file is not a capability.",
       fn r -> r > 1.3 and r < 1.5 end},
      {"a long negating sentence is not a maxim",
       "The schema the specification publishes is not a document any player will read before " <>
         "it renders the animation you gave it, which is the whole problem.",
       fn r -> r == 0.0 end}
    ]

    IO.puts("detector controls:")

    bad =
      Enum.reduce(detector, [], fn {label, text, ok}, acc ->
        {r, _, _} = rate(text)
        IO.puts("  #{if ok.(r), do: "ok  ", else: "BAD "} #{label}: #{f(r)} per 1k")
        if ok.(r), do: acc, else: [label | acc]
      end)

    IO.puts("extraction controls:")

    # BUILT WITHOUT BACKSLASH-ESCAPED QUOTES, AND THAT IS LOAD-BEARING. The use/mention rule
    # drops `"..."` spans before scanning, and a fixture written with \" splits the span at the
    # escape, so the specimen inside leaks out and is counted against this file. It did: these
    # controls failed their own gate until the quote came from a variable instead.
    q = <<34>>

    usd_noise =
      "# A stage is not a scene." <>
        "\ndef Xform " <> q <> "root" <> q <> " {\n  float2 extent = (0, 1)\n  int parent = -1\n}\n"

    usd_block =
      "def Xform " <> q <> "root" <> q <> " {\n  doc = " <> q <> q <> q <>
        plain <> " An ignore is not a lock." <> q <> q <> q <> "\n}\n"

    usd_line =
      "def Xform " <> q <> "root" <> q <> " {\n  doc = " <> q <>
        plain <> " A file is not a capability." <> q <> "\n}\n"

    extraction = [
      {"usd syntax outside a doc string is not prose", "x.usda", usd_noise, fn r -> r == 0.0 end},
      {"a triple-quoted doc string is read", "x.usda", usd_block, fn r -> r > 0.0 end},
      {"a single-line doc string is read", "x.usda", usd_line, fn r -> r > 0.0 end},
      {"a non-usda path is passed through whole", "x.md", usd_noise, fn r -> r > 0.0 end}
    ]

    bad =
      Enum.reduce(extraction, bad, fn {label, path, text, ok}, acc ->
        {r, _, _} = rate(prose(path, text))
        IO.puts("  #{if ok.(r), do: "ok  ", else: "BAD "} #{label}: #{f(r)} per 1k")
        if ok.(r), do: acc, else: [label | acc]
      end)

    IO.puts("ratchet controls:")

    decision = [
      {"above commons and rising is rejected", {2.66, 3.10, true}, false},
      {"above commons and holding is accepted", {2.66, 2.66, true}, true},
      {"above commons and falling is accepted", {2.66, 1.20, true}, true},
      {"a new file above commons is rejected", {0.0, 0.60, false}, false},
      {"a new file at the commons rate is accepted", {0.0, 0.30, false}, true},
      {"a clean file crossing commons is rejected", {0.20, 0.90, true}, false}
    ]

    bad =
      Enum.reduce(decision, bad, fn {label, {b, n, existed}, want}, acc ->
        {got, _, _} = judge(b, n, existed)
        IO.puts("  #{if got == want, do: "ok  ", else: "BAD "} #{label}")
        if got == want, do: acc, else: [label | acc]
      end)

    if bad == [] do
      IO.puts("\nAll #{length(detector) + length(decision)} controls behaved.")
      0
    else
      IO.puts("\n#{length(bad)} control(s) failed.")
      1
    end
  end
end

case System.argv() do
  ["--self-test"] ->
    System.halt(ProseTropes.self_test())

  ["--rate", file] ->
    {r, _hits, words} = ProseTropes.rate(File.read!(file))
    IO.puts("#{ProseTropes.f(r)} per 1k words over #{words} words")
    System.halt(0)

  args ->
    {opts, rest, _} = OptionParser.parse(args, strict: [base: :string])
    repo = List.first(rest) || "."
    System.halt(ProseTropes.check(repo, opts[:base] || "HEAD"))
end
