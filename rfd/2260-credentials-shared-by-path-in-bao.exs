# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2260. `mix rfd.render` renders rfd/2260-credentials-shared-by-path-in-bao/README.md
# and DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2260 do
  use RFD.DSL

  rfd 2260, "agent credentials are shared by path in Bao" do
    state :committed

    feature "An agent enrolls with a CSR and receives a shared credential
as read access to one Bao path, confirmed by the operator"

    scope "Bao's `auth/cert` entries, `secret/gh/*` and the per-path read\npolicies bound to them"

    decision ~S"""
    An agent generates its key and sends a CSR and an SSH public key;
    its private key never leaves its desk. An enrolled agent signs it
    and writes a cert-auth entry with `agents-rw`, `ssh-bao-tunnel`
    and `default`. A shared credential lives at `secret/gh/<name>`
    with a read policy on that path alone, bound only after the
    operator confirms it; a request relayed by a peer does not grant.
    """

    problem ~S"""
    The persona key sat under another desk's agent tree, readable by
    nothing else, and a peer asked for it through a relay, which is
    how a grant slides sideways without a human seeing it.
    """

    related ~S"""
    - RFD 2195 (Bao over the tailnet), the cert-auth convention.
    - RFD 2255 (SSH tunnel to Bao), how an enrolled agent reaches Bao.
    - RFD 2060 (org-scoped app token), what the persona key mints.
    """

    drafted_by :ai

    details_title "agent credentials are shared by path in Bao"

    details "What is measured", ~S"""
    A token holding only `agents-rw`, `ssh-bao-tunnel` and
    `gh-persona-read` read `secret/gh/v-sekai-fire-persona`, was
    denied `secret/gh/ghcr-write` and the original under
    `secret/agents/`, and was denied a write to the shared path. The
    copy's `private_key` hashed the same as the source's. Enrolling a
    peer through the tunnel took 2.9 s.
    """
  end
end
