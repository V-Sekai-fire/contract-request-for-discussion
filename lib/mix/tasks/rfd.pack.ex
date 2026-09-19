# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT

defmodule Mix.Tasks.Rfd.Pack do
  @shortdoc "Write priv/corpus.bin so a release serves the corpus without compiling the sources"
  @moduledoc false
  use Mix.Task

  @impl true
  def run(_args) do
    Mix.Task.run("app.config")
    corpus = RFD.Corpus.build(RFD.Corpus.root())
    out = Path.join(File.cwd!(), "priv/corpus.bin")
    File.mkdir_p!(Path.dirname(out))
    File.write!(out, :erlang.term_to_binary(corpus))

    Mix.shell().info(
      "packed #{length(corpus.entries)} RFD(s), #{length(corpus.registers)} register(s), #{length(corpus.logbook)} logbook entries into #{out}"
    )
  end
end

defmodule Mix.Tasks.Rfd.Serve do
  @shortdoc "Serve the site and the MCP endpoint locally"
  @moduledoc false
  use Mix.Task

  @impl true
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [port: :integer])
    Application.put_env(:rfd, :serve, true)
    Application.put_env(:rfd, :port, opts[:port] || 4000)
    Mix.Task.run("app.start")
    Mix.shell().info("serving on http://localhost:#{opts[:port] || 4000}")
    Process.sleep(:infinity)
  end
end
