defmodule Mix.Tasks.Rfd.Board do
  @shortdoc "Print the flight-levels board in register order; --check fails on drift"
  @moduledoc """
  Prints the levelled RFDs in the order the register reads: L1, L2, L3, then the
  unlevelled, the critical path leading within each level.

      mix rfd.board            # print the board
      mix rfd.board --check    # exit non-zero if an invariant is broken

  --check is the gate: every critical-path step is a live L1 RFD, the plan has no
  gaps, and the sorted levels run L1, L2, L3 without a step out of place.
  """
  use Mix.Task

  @impl true
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [check: :boolean])

    entries = RFD.Corpus.entries()
    plan = RFD.Board.critical_path()

    entries
    |> RFD.Board.sort()
    |> Enum.filter(& &1.flight_level)
    |> Enum.each(fn e ->
      lvl = e.flight_level |> Atom.to_string() |> String.upcase()
      step = if e.serial in plan, do: " step #{Enum.find_index(plan, &(&1 == e.serial)) + 1}", else: ""
      Mix.shell().info("#{lvl}#{step}\t#{e.serial}  #{e.title}")
    end)

    if opts[:check] do
      case RFD.Board.check(entries) do
        [] -> Mix.shell().info("\nboard OK: #{length(plan)} critical-path steps, levels ordered")
        problems ->
          Enum.each(problems, &Mix.shell().error("FAIL: #{&1}"))
          Mix.raise("#{length(problems)} board invariant(s) broken")
      end
    end
  end
end
