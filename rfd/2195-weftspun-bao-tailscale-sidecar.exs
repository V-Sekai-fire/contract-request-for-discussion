# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2195. `mix rfd.render` renders rfd/2195-weftspun-bao-tailscale-sidecar/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2195 do
  use RFD.DSL

  rfd 2195, "Expose weftspun-bao privately via Tailscale" do
    state :discussion

    feature "run Tailscale sidecar in the weftspun-bao Fly machine"

    scope "`weftspun-bao` Fly app, `Dockerfile.fdb`, `entrypoint.sh`"

    decision ~S"""
    Add a Tailscale sidecar to the `weftspun-bao` Fly.io machine so
    peers on the user's tailnet reach OpenBao at
    `weftspun-bao.<tailnet>.ts.net:8200`. No public IP, no fly.toml
    service exposure. Mutual-TLS at OpenBao's listener stays as the
    second factor; Tailscale is transport only.

    Container installs the Tailscale APT package and swaps its entry
    point to a script that starts `tailscaled --tun=userspace-networking`
    (Fly machines lack `/dev/net/tun`), runs `tailscale up` with
    `TS_AUTHKEY`, then `exec dumb-init bao server -config=...`.

    `TS_AUTHKEY` is a Tailscale admin-console auth key tagged
    `tag:fly-bao` (ephemeral + reusable + pre-approved), set as a Fly
    secret before deploy. Full steps + scripts in `DETAILS.md`.
    """

    problem ~S"""
    OpenBao is the workspace's PKI + KV store for agent secrets
    (future: KV v2 at `agents/`, cert-auth issued via bao's PKI). It
    runs on Fly at `weftspun-bao` (sjc, 1 machine, FoundationDB
    backend, mTLS listener). Reaching it from any of the operator's
    laptops or workstations without opening a public IP needs a
    private overlay. Tailscale is what the workspace already uses for
    that shape.
    """

    related ~S"""
    `weftspun-bao` Fly app (state summarised in DETAILS.md),
    `weftspun-fdb` (FoundationDB backend), RFD 2142 (bao PKI zerotrust
    service TLS), RFD 2146 (zerotrust roles first run).
    """

    details_title "Expose weftspun-bao privately via Tailscale"

    details "0. Prereqs on your Tailscale admin console", ~S"""
    - Create a **tag** for Fly machines: **Access controls → Tags** → add `tag:fly-bao`, owned by
    your user.
    - **Machines → Auth keys → Generate auth key**
     , Reusable: **yes**
     , Ephemeral: **yes** (machine deregisters on shutdown)
     , Pre-approved: **yes**
     , Tags: `tag:fly-bao`
     , Copy the `tskey-auth-…` string.
    """

    details "1. Set the auth key as a Fly secret", ~S"""
    ```sh
    flyctl secrets set TS_AUTHKEY=tskey-auth-XXXXXXXXXXXX --app weftspun-bao
    ```
    """

    details "2. Extend the OpenBao container", ~S"""
    Add to `Dockerfile.fdb` (append to whatever's there now):

    ```dockerfile
    # Tailscale
    RUN apt-get update && apt-get install -y --no-install-recommends \
          curl gnupg iptables && \
        curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg \
          -o /usr/share/keyrings/tailscale-archive-keyring.gpg && \
        curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.tailscale-keyring.list \
          -o /etc/apt/sources.list.d/tailscale.list && \
        apt-get update && apt-get install -y --no-install-recommends tailscale && \
        rm -rf /var/lib/apt/lists/*

    # Replace whatever CMD/ENTRYPOINT you have with:
    COPY entrypoint.sh /entrypoint.sh
    RUN chmod +x /entrypoint.sh
    ENTRYPOINT ["/entrypoint.sh"]
    ```
    """

    details "3. `entrypoint.sh`", ~S"""
    ```sh
    #!/bin/sh
    set -eu

    # Start tailscaled in userspace-networking mode (no TUN needed on Fly VMs)
    mkdir -p /var/lib/tailscale
    /usr/sbin/tailscaled \
        --state=/var/lib/tailscale/tailscaled.state \
        --socket=/var/run/tailscale/tailscaled.sock \
        --tun=userspace-networking &

    # Wait for it, then join the tailnet with the auth key
    sleep 2
    tailscale up \
        --authkey="${TS_AUTHKEY}" \
        --hostname=weftspun-bao \
        --advertise-tags=tag:fly-bao \
        --accept-dns=false

    # Now run OpenBao (the original CMD)
    exec dumb-init bao server -config=/bao/config/config.hcl
    ```

    Notes:
    - `--tun=userspace-networking`, Fly machines don't get `/dev/net/tun`; userspace tun works
    fine, just slightly slower.
    - `--hostname=weftspun-bao` gives you the stable MagicDNS name
    `weftspun-bao.<your-tailnet>.ts.net`.
    - Openbao still listens on `[::]:8200` inside the machine; Tailscale routes to it because it's
    in the same netns.
    """

    details "4. Deploy", ~S"""
    ```sh
    flyctl deploy --app weftspun-bao
    ```
    """

    details "5. From any Tailscale peer", ~S"""
    ```sh
    export BAO_ADDR=https://weftspun-bao.<tailnet>.ts.net:8200
    export BAO_CACERT=~/.bao/ca-chain.pem
    export BAO_CLIENT_CERT=~/.bao/cert.pem   # signed by that CA
    export BAO_CLIENT_KEY=~/.bao/key.pem
    bao status
    ```

    The mTLS requirement in your listener config is unchanged, Tailscale is just the transport.
    Peers still need a client cert signed by `/bao/data/tls/ca-chain.pem`.
    """

    details "6. Client cert distribution (the remaining piece)", ~S"""
    Two options:
    - **Simple, small trust surface**: `flyctl ssh sftp shell -a weftspun-bao`, `get
    /bao/data/tls/cert.pem` + `key.pem` + `ca-chain.pem`, `chmod 600` on the laptop.  That cert is
    the machine's own cert, fine for a bootstrap admin, don't share it as an agent identity.
    - **Proper**: enable bao's PKI secrets engine, issue per-agent client certs signed by the same
    CA (or a sub-CA). Then each Claude Code session mints its own cert on first run.
    """

    details "7. mTLS + Tailscale ACL: belt and suspenders", ~S"""
    With mTLS enforced you can also lock down Tailscale ACLs so only your user's devices can reach
    `weftspun-bao:8200`. In the Tailscale admin console → **Access controls**:

    ```json
    "acls": [
      { "action": "accept",
        "src": ["group:you"],
        "dst": ["tag:fly-bao:8200"] }
    ]
    ```

    Now a rogue Tailscale device can't even open TCP to 8200, let alone attempt mTLS.
    """

    details "8. Multi-machine (later)", ~S"""
    Your config already sets `min_machines_running: 3` (currently 1). When you scale (`flyctl
    scale count 3 -a weftspun-bao`), each machine joins Tailscale with its own `weftspun-XXXX`
    hostname. Point clients at any one, or use `weftspun-bao.internal:8200` (the Fly 6PN LB name)
    if the client is on Fly, or add all three as `--advertise-tags` peers behind a Tailscale
    Serve.
    """

    details "Cheaper \"dev\" alternative that reuses zero Fly changes", ~S"""
    Skip everything above and use `flyctl proxy 8200:8200 -a weftspun-bao` while you develop. It
    forwards localhost:8200 through Fly's WireGuard mesh, no public exposure, no container change.
    Only good for interactive use; a daemon that depends on it dies when you close the laptop.
    """

    details "Gotchas that cost the setup an hour each", ~S"""
    Six backlog items from the first two agents running against this. Each is a
    one-line footgun that reads as an unrelated problem until you know it.

    ### Client cert must include the intermediate

    Bao's listener trusts only the Root CA. A client that presents only its
    leaf cert is rejected with `unknown certificate authority`, even though the
    leaf is validly signed. Bao expects the client to include the intermediate
    in its own chain.

        cat leaf.pem intermediate.pem > client-fullchain.pem
        export BAO_CLIENT_CERT=client-fullchain.pem

    The same shape bites the listener the other way: full-chain the server cert
    too, or clients see the same error against your Bao.

    ### Cert-auth alias name is the full CN; KV keys mirror it

    The templated policy at `auth/cert/certs/agents-weftspun` uses
    `{{identity.entity.aliases.<accessor>.name}}`, and that resolves to the
    alias's Name field, which cert-auth populates with the CN. Bao does not
    strip a trailing suffix. Two conventions have to line up:

    - CN in the CSR is the full `<short>.agents.weftspun` form.
    - KV keys under `agents/` use the same full-CN form (`agents/mps-45994b.agents.weftspun`), not
    the short form.

    Mixing shapes makes the templated write silently no-op, the policy
    resolves to `agents/mps-45994b.agents.weftspun` and your session's write
    to `agents/mps-45994b` gets 403.

    ### Named grant `agents/data/+ read` for peer visibility

    Templated per-agent write isolates *writes* to your own row, but it also
    prevents you seeing peers' rows. Add a separate grant to the same policy:

        path "agents/data/+" { capabilities = ["read"] }
        path "agents/metadata" { capabilities = ["list"] }

    Now every agent can see the coordination store; only its own row is
    writable.

    ### `flyctl ssh console -C "cat file" | head` truncates on SIGPIPE

    `flyctl ssh console -C "cat /some/big/file" | tee copy | head -3` returns
    truncated stdout because the SSH stream races the pipe. The fix is
    write-then-read:

        flyctl ssh console -C "cat /some/big/file" > local.copy
        head -3 local.copy

    Same for any long stdout through `flyctl ssh console -C`.

    ### `openssl req -subj "/CN=..."` mangles on Git-Bash

    MSYS silently rewrites `/CN=weftspun-bao` to a filesystem path when the
    argument starts with a single slash. The resulting cert has `CN=
    C:\...\CN=weftspun-bao` or similar. Escape with a double slash:

        openssl req -new -key key.pem -subj "//CN=weftspun-bao.internal" ...

    Same for every `-subj` on Git-Bash. Native shells (zsh, POSIX sh under
    WSL) do not need this.

    ### Rule zero: every live session gets an identity

    Formalised in `weftspun/dot-claude` PR #15's `agent-sync.md` skill body.
    The rule: every session that appears in `ListAgents` gets a Bao client
    cert and a `agents/<cn>.agents.weftspun` KV row, minted by whichever
    session holds the admin policy (currently `mps-45994b` via
    `auth/cert/certs/mps-45994b`). Read-only policy is fine as a first
    grant; write is deferred until the operator or the session itself asks
    for it. The provisioning bundle (leaf cert + intermediate + root CA)
    lands in Bao KV at `certs/<cn>`, public material only, private key
    stays on the requesting session's box. The receiving session's first
    action is `bao login -method=cert` against it. **1Password is not the
    right store for agent certs**, Bao KV is the store the agents already
    have to reach anyway.

    ### Shared-$HOME machines need per-agent-suffixed credential dirs

    Two agents on the same box under the same `$HOME` (two Claude sessions
    opened from separate editors on one Windows machine, say) will both
    resolve `~/.bao-creds/` to the same directory, and the second agent's
    onboarding drill will overwrite the first agent's private key. The key
    is gone from the filesystem and the first agent's cert on disk is
    still valid until its TTL runs out but unusable, the pubkey no longer
    has a matching private key. Verified by
    `openssl x509 -in cert.pem -noout -pubkey` vs the (nonexistent) key.

    The 2026-09-04 reference case: HAILO on-boarded on the same box as
    CUDA and wrote `/c/Users/ernes/.bao-creds/client-key.pem`, clobbering
    CUDA's. Both agents moved to suffixed dirs and CUDA re-enrolled from
    its new location with a fresh CSR against the same CN.

    Convention going forward: **each agent uses `~/.bao-creds-<agent>/`**,
    not the bare `~/.bao-creds/`. The onboarding drill each agent hands
    its successor spells that out explicitly. The onboarding message the
    admin session sends when signing a new cert names the target directory
    per-agent rather than the default.

    ### A stale token file is another agent's identity, not an expired one

    A 403 on the agent's own row is almost never the policy. `agents-rw`
    grants `create, read, update, delete` on
    `agents/data/{{identity.entity.aliases.<cert accessor>.name}}`, and the
    alias name is the certificate CN (see above), so the template resolves
    to the row the agent is writing. What produces the 403 is the token the
    CLI actually sends: `bao` reads `~/.bao-token` (or `BAO_TOKEN`) before
    it re-authenticates, cert tokens live 8 h, and neither file is touched
    by rotate or migrate.

    The 2026-09-04 reference case: two agents on the shared box carried a
    row-update 403 for a working day while the server side read clean. One
    agent's `~/.bao-token` held a token bound to a different agent's
    entity, so every write ran under that identity and matched only the
    `agents/data/+ read` grant. The other held a token minted before the
    group reconciler attached its `agents-*` group, so `identity_policies`
    was empty. The admin session reproduced the server side by minting a
    five-minute token bound to the first agent's real entity: full write on
    its row, `deny` on anything under it. `rm ~/.bao-token && bao login
    -method=cert` fixed both on the first retry.

    The fix above held for thirty minutes. The token "went stale again" on
    one agent, which an eight-hour token does not do. What happens is the
    shared-`$HOME` gotcha one section up, applied to the token file: three
    agents on one box resolve `~/.bao-token` to one file, and every `bao
    login` by any of them overwrites it for all three. The agent whose file
    held another's identity had not inherited a leftover; it had been
    clobbered by a peer's later login, and the peer whose writes worked all
    day was the one who happened to log in last. Deleting and re-logging in
    fixes one agent until the next peer login.

    So the durable rule is that no session on a shared box writes the
    shared file at all:

        bao login -method=cert -no-store -token-only > ~/.bao-creds-<agent>/session-token
        export BAO_TOKEN=$(cat ~/.bao-creds-<agent>/session-token)
        rm -f ~/.bao-token

    `-no-store` keeps the login from touching `~/.bao-token`; `BAO_TOKEN`
    in the session's own environment wins over any file; the per-agent
    directory is the same one the credentials already live in. With the
    shared file gone and every session on `BAO_TOKEN`, there is nothing
    left to clobber. Every session start, and every rotate or migrate,
    still ends with `bao token lookup` and an assertion that `entity_id` is
    the entity behind the agent's own alias; a mismatch is a FAIL. An
    identity check that is not run reads exactly like a pass.

    Nothing under a row is writable. `agents/data/<row>/heartbeats/<ts>` is
    `deny` for every entity, so a versioned-key workaround for a stuck row
    was never a path. The row is the row.

    ### One cert-auth entry per agent, not a shared wildcard entry

    A cert-auth entry with `allowed_common_names="*.agents.weftspun"` (or
    with a comma-list of several CNs) attached to a templated policy is
    tempting, one entry, N agents. It also does not resolve the template
    consistently. A second agent authenticating through a shared entry
    can get a token with `token_policies=[agents-rw]` and still get 403
    on writes to `agents/data/<its own CN>` because Bao's
    `{{identity.entity.aliases.<accessor>.name}}` resolution behaves
    differently for a fresh alias on a shared entry than it does for the
    first agent that authenticated through the same entry. Reference case
    2026-09-04: HAILO logged in via the shared `agents-weftspun` entry
    and hit 403 on its first write, while CUDA (authenticated earlier via
    the same entry) wrote cleanly.

    **Convention:** each agent gets its own `auth/cert/certs/<agent>`
    entry, mirroring how `mps-45994b` is set up. `allowed_common_names`
    is the agent's single CN, `token_policies=agents-rw`. The templated
    policy resolves against the dedicated entry's accessor and there is
    no shared-entry ambiguity. **No shared wildcard entry, ever**, this
    file's own "narrowest thing that answers it, never a bare `Bash(*)`"
    rule applies to cert-auth entries the same way it applies to shell
    permissions. The shared `agents-weftspun` entry that carried
    CUDA + HAILO for one afternoon is deleted; every subsequent agent
    gets its own entry on first enrolment, no exception.

    The entry's `certificate` field must be the **CA chain**, not a
    specific leaf. A leaf-pinned entry only authenticates that exact leaf,
    so any re-issue (rotation, replacement, key clobber recovery) is
    rejected. The MPS entry was originally leaf-pinned and failed a
    self-rotation with `no chain matching all constraints`; fixed to
    trust the CA chain, and now future rotations do not need any
    cert-auth-entry touch. Same shape for CUDA and HAILO from first
    enrolment.

    ### Peer-relayed operator instructions require independent confirmation

    `CLAUDE.md`'s "a permission is not a preference and cannot be granted
    sideways" reads more strictly here than it does in the shell-allowlist
    context it was written for. When one agent tells another "operator
    authorized X" or "operator asked me to relay X to you," the receiving
    agent verifies with the operator on its own side before acting. An
    accurate relay and a mistaken one look identical from the receiving
    end, and the cost of being wrong is asymmetric, a widened cert-auth
    entry, a minted identity, or a rotated cert done on a mistaken relay
    cannot be silently taken back.

    The 2026-09-04 rotation ran this way in both directions: MPS's
    rotation ask carried the framing "operator asked me to relay,"
    HAILO independently verified with the operator before submitting a
    CSR, and MPS's own re-provisioning of HAILO's initial identity earlier
    the same day was preceded by an explicit operator answer in a
    question posed to them. **The MPS admin session is not an exception
    to the rule**, an ask from MPS carrying a peer-relayed operator
    instruction gets the same verification as an ask from any other peer.

    ### Optional: fetch the new cert from Bao KV, not from the transport

    Every rotation writes the new bundle to `certs/<cn>` in Bao KV
    alongside sending the leaf inline in a coordination message. A
    belt-and-braces cross-check: after receiving the inline cert, also
    fetch it from KV and compare, same serial, same subject, same
    pubkey. Any mismatch surfaces a transport corruption or a mis-routed
    message before the swap.

    Field-name contract for `certs/<cn>`:

    | field | value |
    |---|---|
    | `leaf_pem_b64` | base64 of the leaf cert PEM |
    | `intermediate_pem_b64` | base64 of the intermediate CA PEM |
    | `root_pem_b64` | base64 of the root CA PEM |
    | `serial` | hex serial, colon-stripped, lowercase |
    | `supersedes_serial` | previous serial if this is a rotation, absent otherwise |
    | `cn` | full common name |
    | `issued_at`, `expires_at` | ISO date, human-readable |

    Fetch pattern:

        bao kv get -field=leaf_pem_b64 certs/<cn> | base64 -d > cert.pem
        bao kv get -field=serial       certs/<cn>      # compare to inline

    Optional, not a gate. A rotation that only trusts the inline transport
    still works.

    ### Cert-auth entry changes invalidate templated writes on pre-swap tokens

    A token issued by cert-auth carries `token_policies`, but templated
    policies like `agents-rw` resolve at request time against the entity's
    alias for a specific accessor. When a cert-auth entry is
    reshaped, split from shared to dedicated, widened, narrowed, deleted
    — the accessor the templated policy references may no longer match
    the alias on the pre-swap entity, and writes 403 with `preflight
    capability check`. The token itself is authentic; the template just
    resolves to nothing.

    Reference case 2026-09-04: HAILO's first token came from the shared
    `agents-weftspun` entry (one accessor). Moving HAILO to a dedicated
    `hailo-552dfa` entry left the old token holding an alias from the
    old accessor, so writes to `agents/data/hailo-552dfa.agents.weftspun`
    resolved to a policy path that no longer matched. `bao login` again
    minted a fresh token bound to the new accessor's alias, and writes
    worked.

    **Convention:** any cert-auth reshape names the affected agents in
    its coordination message and asks them to `bao login` again. The
    token still on their disk isn't a security issue (its bearer is still
    authorised for what it was issued for) but it can no longer resolve
    against a rewritten templated policy.

    ### Do not touch a peer's branch without owner ack

    A CLEAN or DIRTY `mergeStateStatus` on a peer's PR is a state to
    report to the peer, not a state to fix by running a rebase yourself.
    Reference case 2026-09-04: PR #257 (authored by CUDA) showed DIRTY
    during a coordination sweep; MPS ran `git rebase weftspun/main` on
    the branch, git evaluated the peer's diff against a newer main and
    collapsed it into zero commits, MPS then force-pushed the empty state
    and GitHub auto-closed the PR because branch == main. Content
    recovery was possible because the old commit was still in the local
    object store; a fresh PR (#265) had to be filed to route back through
    review, and the actual rebase then had to happen on the author's
    side anyway (real conflicts in BLOCKLIST.md that require author
    intent to resolve).

    **Convention:** a peer's stuck PR gets a message, not a rebase. The
    peer's session is the only one that can answer "which side wins" on
    a real content conflict. The only rebases MPS runs on peer branches
    are prettier-only reformats where no substantive content moves, and
    even those get a note in the coordination message so the peer can
    see it and refuse if the shape isn't right.

    ### Bao requires mTLS on every request, not just login

    The listener enforces `tls_require_and_verify_client_cert = true`, so
    the TLS handshake needs the client cert on **every** API call. A
    `bao login -method=cert` handshake gives you a token; that token
    alone is not sufficient for subsequent calls, every follow-up
    request handshakes anew and needs the same client cert. If
    `BAO_TOKEN` is exported but `BAO_CLIENT_CERT` / `BAO_CLIENT_KEY` /
    `BAO_CACERT` are not, the next call fails with:

        remote error: tls: certificate required

    Not an authorisation error (token is fine); a TLS-handshake error
    before the token is even sent.

    Reference case 2026-09-04: ANCHOR's first `bao kv put` after login
    failed with this exact message when only the token helper was in
    play. Diagnosed as env-var scope, not a Bao config bug. Convention:
    keep all four env vars exported for the shell session:

        export BAO_ADDR=https://weftspun-bao.stonecat-ratio.ts.net:8200
        export BAO_CACERT=~/.bao-creds-<agent>/root-ca.pem
        export BAO_CLIENT_CERT=~/.bao-creds-<agent>/client-fullchain.pem
        export BAO_CLIENT_KEY=~/.bao-creds-<agent>/<agent>-key.pem
        export BAO_TOKEN=$(cat ~/.bao-creds-<agent>/session-token)

    The four together are the working configuration. Dropping any one
    breaks subsequent calls in different ways: dropping the token gives
    403 or "no token"; dropping the client cert / key / CA gives
    "certificate required" or "unknown certificate authority". Diagnosis
    per RFD 2195's other cert-auth gotchas applies.

    The Bao cert-auth method does not consult CRLs by default. `pki/revoke
    serial_number=<X>` records the revocation in the PKI store but does not
    gate access, a revoked cert still authenticates until you take one of
    these steps:

    1. **Narrow the cert-auth entry's `allowed_common_names`** to exclude the
       revoked CN. Immediate effect, no reload needed. Best for revoking one
       CN from a shared wildcard entry (e.g. change `*.agents.weftspun` to
       `cuda-a63415.agents.weftspun` when revoking mps-dataset).
    2. **Delete the cert-auth entry** entirely (`bao delete
       auth/cert/certs/<name>`). Immediate effect. Best when revoking every
       identity that authed through that entry.
    3. **Enable CRL consultation** via `auth/cert/crls/<name>` and reload the
       CRL after every revoke. Correct but higher operational load and the
       default intermediate here reports `error building CRLs: x509: issuer
       certificate doesn't contain a subject key identifier`, a re-issue of
       the intermediate is needed before this path works.

    Options 1 and 2 are what we use. The KV row also gets deleted (`bao kv
    metadata delete agents/<cn>.agents.weftspun`) so peers don't see a stale
    identity, and the cert bundle at `certs/<cn>` gets deleted or annotated
    with a `revoked_at` field. A key clobber (see the shared-$HOME gotcha
    above) doesn't need PKI revocation, the old cert is unusable without
    its key, but does need the CN removed from the cert-auth allowlist
    until the new cert is issued, so the old cert can't be replayed if the
    key was leaked before it was gone.
    """

    drafted_by :ai
  end
end
