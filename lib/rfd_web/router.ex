# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT

defmodule RFDWeb.Router do
  @moduledoc """
  The site and the MCP endpoint. Pages come from `RFD.Corpus`; `/mcp` is
  `ExMCP.HttpPlug` over `RFD.MCP.Server`, public and read-only.
  """

  use Plug.Router
  import RFD.HTML, only: [page: 2, markdown: 1, escape: 1, entry_table: 1, level: 1]

  alias RFD.Corpus

  plug(Plug.Logger, log: :info)
  plug(:match)
  plug(:dispatch)

  @version Mix.Project.config()[:version]

  forward("/mcp",
    to: ExMCP.HttpPlug,
    init_opts: [
      handler: RFD.MCP.Server,
      server_info: %{name: "rfd", version: @version},
      sse_enabled: true,
      cors_enabled: true,
      allowed_origins: :any,
      validate_origin: false
    ]
  )

  get "/health" do
    json(conn, 200, %{status: "ok", version: @version, rfds: length(Corpus.entries())})
  end

  get "/" do
    entries = Corpus.entries()
    live = Enum.reject(entries, &(&1.state in [:abandoned, :moved]))

    html(conn, "Request for Discussion", """
    <h1>The register</h1>
    <p class="meta">#{length(live)} live of #{length(entries)} numbered documents. A serial names one document for as long as the arc exists; <a href="/serials">the serial pages</a> hold the allocated and the deleted.</p>
    <form action="/search" method="get"><input type="search" name="q" placeholder="Search every RFD's prose" aria-label="Search"></form>
    #{entry_table(entries)}
    """)
  end

  get "/search" do
    conn = fetch_query_params(conn)
    q = String.trim(conn.query_params["q"] || "")

    body =
      if q == "" do
        "<p class=\"meta\">Type a phrase.</p>"
      else
        hits = Corpus.search(q)

        items =
          Enum.map_join(hits, "\n", fn {e, lines} ->
            """
            <li><a href="/rfd/#{e.serial}-#{e.slug}">RFD #{e.serial}: #{escape(e.title)}</a>
            <pre>#{lines |> Enum.map_join("\n", &escape/1)}</pre></li>
            """
          end)

        "<p class=\"meta\">#{length(hits)} RFD(s) mention “#{escape(q)}”.</p><ul>#{items}</ul>"
      end

    html(conn, "Search", """
    <h1>Search</h1>
    <form action="/search" method="get"><input type="search" name="q" value="#{escape(q)}" aria-label="Search"></form>
    #{body}
    """)
  end

  get "/rfd/:name" do
    case Corpus.entry(name) do
      nil ->
        not_found(conn)

      e ->
        canonical = "#{e.serial}-#{e.slug}"

        if name != canonical do
          redirect(conn, "/rfd/#{canonical}")
        else
          details =
            if e.details,
              do: "<h2 id=\"details\">Details</h2>\n" <> markdown(strip_title(e.details)),
              else: ""

          html(conn, "RFD #{e.serial}: #{e.title}", """
          <p class="meta"><a href="/rfd/#{canonical}/README.md">README.md</a>#{if e.details, do: ~s( · <a href="/rfd/#{canonical}/DETAILS.md">DETAILS.md</a>), else: ""} · <a href="https://github.com/V-Sekai-fire/request-for-discussion/blob/main/rfd/#{canonical}.exs">source</a>#{if e.flight_level, do: " · " <> level(e.flight_level), else: ""}</p>
          #{markdown(e.readme)}
          #{details}
          """)
        end
    end
  end

  get "/rfd/:name/README.md" do
    case Corpus.entry(name),
      do: (
        nil -> not_found(conn)
        e -> text(conn, e.readme)
      )
  end

  get "/rfd/:name/DETAILS.md" do
    case Corpus.entry(name) do
      %{details: d} when is_binary(d) -> text(conn, d)
      _ -> not_found(conn)
    end
  end

  get "/flight-levels/:level" do
    case level do
      l when l in ~w(l1 l2 l3) ->
        atom = String.to_existing_atom(l)

        titles = %{
          l1: "Level 1 · Operations",
          l2: "Level 2 · Coordination",
          l3: "Level 3 · Strategy"
        }

        html(conn, titles[atom], """
        <h1>#{titles[atom]}</h1>
        <p class="meta">RFDs tagged <code>flight_level #{inspect(atom)}</code> on the register (RFD 2177).</p>
        #{entry_table(Corpus.by_level(atom))}
        """)

      _ ->
        not_found(conn)
    end
  end

  get "/logbook" do
    items =
      Enum.map_join(Corpus.logbook(), "\n", fn {name, md} ->
        title =
          md
          |> String.split("\n")
          |> Enum.find("", &String.starts_with?(&1, "# "))
          |> String.trim_leading("# ")

        ~s(<li><a href="/logbook/#{name}">#{escape(if title == "", do: name, else: title)}</a> <span class="meta">#{name}</span></li>)
      end)

    html(conn, "Logbook", """
    <h1>Logbook</h1>
    <p class="meta">Entries record what was measured, not what was intended. Retractions stay next to what they retract.</p>
    <ul>#{items}</ul>
    """)
  end

  get "/logbook/:name" do
    case Corpus.logbook_entry(name) do
      nil -> not_found(conn)
      {_, md} -> html(conn, name, markdown(md))
    end
  end

  get "/serials" do
    sections =
      Enum.map_join(Corpus.registers(), "\n", fn {file, r} ->
        {a, d} = RFD.Register.tables(r)

        rows = fn table, kind ->
          Enum.map_join(Enum.sort(table), "\n", fn {s, v} ->
            link =
              case {kind, Corpus.entry(s)} do
                {:allocated, %{slug: slug}} -> ~s(<a href="/rfd/#{s}-#{slug}">#{escape(v)}</a>)
                _ -> escape(v)
              end

            "<tr><td>#{s}</td><td>#{link}</td></tr>"
          end)
        end

        """
        <h2>#{escape(r.name)} · site #{r.layer[:site]} · <code>#{file}.usda</code></h2>
        <p class="meta">#{escape(r.thesis)}</p>
        <h3>Allocated (#{map_size(a)})</h3><table><tbody>#{rows.(a, :allocated)}</tbody></table>
        <h3>Deleted (#{map_size(d)})</h3><table><tbody>#{rows.(d, :deleted)}</tbody></table>
        """
      end)

    html(conn, "Serials", "<h1>Serial registers</h1>\n" <> sections)
  end

  get "/SERIALS.usda" do
    register_usda(conn, "SERIALS")
  end

  get "/SERIALS-:site.usda" do
    register_usda(conn, "SERIALS-" <> site)
  end

  get "/agreements" do
    html(conn, "Working agreements", markdown(Corpus.document("CLAUDE.md")))
  end

  get "/blocklist" do
    html(conn, "Blocklist", markdown(Corpus.document("BLOCKLIST.md")))
  end

  get "/mcp-usage" do
    html(conn, "MCP", """
    <h1>The corpus over MCP</h1>
    <p>Every page here is also a tool call. The endpoint is public and read-only; point an MCP client at it:</p>
    <pre>{ "mcpServers": { "rfd": { "url": "#{base_url(conn)}/mcp" } } }</pre>
    <table><thead><tr><th>Tool</th><th>What it returns</th></tr></thead><tbody>
    <tr><td><code>list_rfds</code></td><td>serial, slug, title, state, flight level and scope for every RFD; filter by <code>state</code> or <code>flight_level</code></td></tr>
    <tr><td><code>get_rfd</code></td><td>one RFD's README and DETAILS as Markdown, by serial</td></tr>
    <tr><td><code>search_rfds</code></td><td>the RFDs whose prose contains a phrase, with the matching lines</td></tr>
    <tr><td><code>get_register</code></td><td>both serial registers: allocated and deleted serials per site, and the next unused serial</td></tr>
    <tr><td><code>list_logbook</code> / <code>get_logbook_entry</code></td><td>the logbook entries</td></tr>
    <tr><td><code>get_agreements</code></td><td>the working agreements (CLAUDE.md) or the blocklist</td></tr>
    </tbody></table>
    """)
  end

  match _ do
    not_found(conn)
  end

  defp register_usda(conn, name) do
    case List.keyfind(Corpus.registers(), name, 0) do
      nil -> not_found(conn)
      {_, r} -> text(conn, RFD.Register.usda(r))
    end
  end

  defp strip_title(details) do
    details
    |> String.split("\n")
    |> Enum.drop_while(&String.starts_with?(&1, "# "))
    |> Enum.join("\n")
  end

  defp base_url(conn) do
    scheme = List.first(get_req_header(conn, "x-forwarded-proto")) || Atom.to_string(conn.scheme)
    "#{scheme}://#{conn.host}#{if conn.port in [80, 443], do: "", else: ":#{conn.port}"}"
  end

  defp html(conn, title, body) do
    conn |> put_resp_content_type("text/html") |> send_resp(200, page(title, body))
  end

  defp text(conn, body) do
    conn |> put_resp_content_type("text/markdown") |> send_resp(200, body)
  end

  defp json(conn, status, map) do
    conn |> put_resp_content_type("application/json") |> send_resp(status, Jason.encode!(map))
  end

  defp redirect(conn, to) do
    conn |> put_resp_header("location", to) |> send_resp(302, "")
  end

  defp not_found(conn) do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(404, page("Not found", "<h1>Not found</h1>"))
  end
end
