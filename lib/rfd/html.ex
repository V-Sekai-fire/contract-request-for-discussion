# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT

defmodule RFD.HTML do
  @moduledoc "The site's pages: one layout, Markdown through Earmark, tables built here."

  @css """
  :root{--ink:#1d2a33;--muted:#5c6b75;--line:#d9e0e5;--paper:#fbfcfd;--tint:#eef3f6;--link:#0b5a8a}
  @media(prefers-color-scheme:dark){:root{--ink:#e6edf1;--muted:#9fb0bb;--line:#2c3a44;--paper:#101a21;--tint:#182430;--link:#7cc0ee}}
  *{box-sizing:border-box}body{margin:0;background:var(--paper);color:var(--ink);font:16px/1.55 system-ui,-apple-system,Segoe UI,Roboto,sans-serif}
  header{border-bottom:1px solid var(--line);background:var(--tint)}header nav{max-width:64rem;margin:0 auto;padding:.7rem 1.2rem;display:flex;gap:1.2rem;flex-wrap:wrap;align-items:baseline}
  header nav a{color:var(--ink);text-decoration:none;font-weight:600}header nav a.brand{font-size:1.1rem;margin-right:auto}
  main{max-width:64rem;margin:0 auto;padding:1.2rem}a{color:var(--link)}
  h1{font-size:1.6rem;line-height:1.25}h2{font-size:1.2rem;margin-top:2rem;border-bottom:1px solid var(--line);padding-bottom:.2rem}
  table{border-collapse:collapse;width:100%;font-size:.95rem}th,td{text-align:left;padding:.4rem .5rem;border-bottom:1px solid var(--line);vertical-align:top}th{color:var(--muted);font-weight:600}
  code,pre{font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;font-size:.9em}pre{background:var(--tint);padding:.8rem;overflow-x:auto;border-radius:4px}code{background:var(--tint);padding:.05em .3em;border-radius:3px}pre code{background:none;padding:0}
  .meta{color:var(--muted)}.state{display:inline-block;padding:0 .4em;border:1px solid var(--line);border-radius:3px;font-size:.85em;color:var(--muted)}
  .dim td{color:var(--muted)}input[type=search]{width:100%;padding:.5rem;border:1px solid var(--line);border-radius:4px;background:var(--paper);color:var(--ink);font-size:1rem}
  footer{max-width:64rem;margin:2rem auto;padding:1rem 1.2rem;color:var(--muted);border-top:1px solid var(--line);font-size:.9rem}
  """

  @nav [
    {"/", "Register"},
    {"/flight-levels/l3", "L3 · Strategy"},
    {"/flight-levels/l2", "L2 · Coordination"},
    {"/flight-levels/l1", "L1 · Operations"},
    {"/logbook", "Logbook"},
    {"/serials", "Serials"},
    {"/agreements", "Agreements"},
    {"/mcp-usage", "MCP"}
  ]

  def page(title, body) do
    nav = Enum.map_join(@nav, "", fn {href, text} -> ~s(<a href="#{href}">#{text}</a>) end)

    """
    <!doctype html>
    <html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
    <title>#{escape(title)}</title><style>#{@css}</style></head>
    <body><header><nav><a class="brand" href="/">Request for Discussion</a>#{nav}</nav></header>
    <main>#{body}</main>
    <footer>Rendered from the Elixir sources in <a href="https://github.com/V-Sekai-fire/request-for-discussion">v-sekai-fabric/request-for-discussion</a>. The same corpus answers over MCP at <code>/mcp</code>.</footer>
    </body></html>
    """
  end

  def markdown(nil), do: ""

  def markdown(md) do
    Earmark.as_html!(md, escape: false, smartypants: false, breaks: false)
  end

  def escape(nil), do: ""

  def escape(s) when is_binary(s) do
    s
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  def escape(other), do: other |> to_string() |> escape()

  @doc "A table of RFD entries: serial, title, state, scope, level."
  def entry_table(entries) do
    rows =
      Enum.map_join(entries, "\n", fn e ->
        dim = if e.state in [:abandoned, :moved], do: ~s( class="dim"), else: ""

        """
        <tr#{dim}><td><a href="/rfd/#{e.serial}-#{e.slug}">#{e.serial}</a></td><td><a href="/rfd/#{e.serial}-#{e.slug}">#{escape(e.title)}</a></td><td><span class="state">#{e.state}</span></td><td>#{level(e.flight_level)}</td><td class="meta">#{inline(e.scope)}</td></tr>
        """
      end)

    """
    <table><thead><tr><th>RFD</th><th>Title</th><th>State</th><th>Level</th><th>Scope</th></tr></thead><tbody>
    #{rows}
    </tbody></table>
    """
  end

  def level(nil), do: ""
  def level(l), do: l |> Atom.to_string() |> String.upcase()

  defp inline(nil), do: ""

  defp inline(md) do
    md |> markdown() |> String.replace(~r{</?p>}, "") |> String.trim()
  end
end
