# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT

defmodule RFD.Board do
  @moduledoc """
  The flight-levels board: the critical-path plan and the order the register
  reads in. The order is the sequence of steps completed to reach a strategy,
  so operations sort first (L1), then coordination (L2), then strategy (L3),
  then the unlevelled rest. Within a level the critical path leads.
  """
  alias RFD.Corpus

  # The Skateboard's critical path as a checked-in taskweft plan (RFD 1037): the
  # L1 steps in execution order. An RFD off the plan sorts after it by serial.
  @critical_path [2263, 2234, 2264, 2248, 2249, 1147]

  def critical_path, do: @critical_path

  def level_rank(:l1), do: 0
  def level_rank(:l2), do: 1
  def level_rank(:l3), do: 2
  def level_rank(nil), do: 3

  def cp_index(serial) do
    Enum.find_index(@critical_path, &(&1 == serial)) || length(@critical_path)
  end

  @doc "Register order: L1, L2, L3, unlevelled; critical path within, then serial descending."
  def sort(entries) do
    Enum.sort_by(entries, &{level_rank(&1.flight_level), cp_index(&1.serial), -&1.serial})
  end

  @doc """
  The board invariants, as a list of problems ([] when clean): every critical-path
  step is a live L1 RFD, the plan has no gaps, and the sorted register's levels run
  L1, L2, L3, unlevelled without a step out of place.
  """
  def check(entries \\ Corpus.entries()) do
    by = Map.new(entries, &{&1.serial, &1})

    steps =
      for {serial, i} <- Enum.with_index(@critical_path) do
        case by[serial] do
          nil ->
            "critical-path step #{i} names RFD #{serial}, which has no source"

          %{flight_level: l} when l != :l1 ->
            "critical-path RFD #{serial} is #{l || "unlevelled"}, not L1"

          %{state: s} when s in [:abandoned, :moved] ->
            "critical-path RFD #{serial} is #{s}"

          _ ->
            nil
        end
      end
      |> Enum.reject(&is_nil/1)

    ranks = entries |> sort() |> Enum.map(&level_rank(&1.flight_level))

    order =
      if ranks == Enum.sort(ranks),
        do: [],
        else: ["register levels are not ordered L1, L2, L3, then unlevelled"]

    steps ++ order
  end
end
