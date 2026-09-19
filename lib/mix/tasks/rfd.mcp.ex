# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT

defmodule Mix.Tasks.Rfd.Mcp do
  @shortdoc "Serve the MCP tools over stdio, for a local MCP client"
  @moduledoc """
      mix rfd.mcp

  Only JSON-RPC goes to stdout; run it compiled (`mix compile` first) so Mix prints
  nothing there. Register it with a client as the command `mix rfd.mcp` in this
  directory.
  """
  use Mix.Task

  @impl true
  def run(_args) do
    Application.put_env(:ex_mcp, :stdio_mode, true)
    Mix.Task.run("app.start")
    RFD.Corpus.load()
    {:ok, _} = ExMCP.Server.StdioServer.start_link(module: RFD.MCP.Server)
    Process.sleep(:infinity)
  end
end
