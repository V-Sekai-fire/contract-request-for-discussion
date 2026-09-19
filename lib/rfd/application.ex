# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT

defmodule RFD.Application do
  @moduledoc """
  Serves the site and the MCP endpoint when `:rfd, :serve` is set (the release sets
  it; `mix rfd.serve` sets it for a local run). Under plain `mix` tasks nothing starts.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children =
      if Application.get_env(:rfd, :serve, false) do
        RFD.Corpus.load()
        port = Application.get_env(:rfd, :port, 8080)
        [{Plug.Cowboy, scheme: :http, plug: RFDWeb.Router, options: [port: port]}]
      else
        []
      end

    Supervisor.start_link(children, strategy: :one_for_one, name: RFD.Supervisor)
  end
end
