# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2146. `mix rfd.render` renders rfd/2146-bao-is-the-secret-store/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2146 do
  use RFD.DSL

  rfd 2146, "Bao is the secret store, cert-auth is the fence" do
    state :discussion

    scope "the workspace's Bao instance and every consumer that
already presents a per-identity TLS leaf."

    attest_in :details

    decision ~S"""
    The cert is the answer. Bao's cert auth backend accepts each
    identity's per-service leaf as the login credential, mints a scoped
    token bound to that identity's role's policies, and returns it. No
    shared bearers, no root token in service code, no network ACL as an
    identity substitute. The cert is already the fence at TLS; this RFD
    extends it up the stack.

    Two axes carry the design. **Policies** shape `<verb>-<scope>`:
    verb in {read, write, admin, issue}; scope is a KV subtree, a PKI
    mount, or `*` for sudo. **Roles** bind one identity's leaf (or a
    small exact-match CN allow-list, no globs) to a set of policies
    with a short-session TTL. New app: one policy, one role. New
    capability: one policy against an existing scope.

    The store becomes the source of truth for every secret; 1P retains
    the material as an offline mirror. Role table, walkthrough, negative
    controls in `DETAILS.md`.
    """

    problem ~S"""
    Every service ends up with three identity questions: what secrets
    can it read, what actions can it take, and how does it prove it is
    what it claims to be. Left alone, each answer accretes its own
    credential: a shared bearer for reads, a root token for writes, a
    network ACL as an identity substitute. Every one becomes a rotation
    problem and a leak surface. When the store sits behind mTLS, the
    client already presents a per-identity cert at the TLS handshake,
    and the API layer above ignores it and re-asks with a token.
    """

    related ~S"""
    RFD 2140, 2142 (implemented here), 2144, 2145.
    """

    details_title "Bao is the secret store, cert-auth is the fence"

    details "KV layout", ~S"""
    Every secret under `secret/weftspun/*` is a source-of-truth entry
    tagged `{source_of_truth:true, moved_from:<1P item>, moved_at:<date>}`.
    1P retains the same values as an offline mirror, so a Bao outage does
    not lock the operator out.

        secret/weftspun/fdb/cluster-id            weft:<hex>@<coord-list>
        secret/weftspun/fdb/r2-dr                 R2 S3 keys (RFD 2143 fan-out)
        secret/weftspun/cloudflare/edit-zone-dns  bearer for chibifire.com zone DNS
        secret/weftspun/cloudflare/r2-bearer      bearer for R2 bucket mgmt

    App-scoped secrets go under `secret/apps/<app>/*` (empty today; roles
    below already fence access).
    """

    details "Policies", ~S"""
    Five policies, named for what they let you do, not who they're for.

        admin              path "*"                             sudo + all verbs
        dns-editor         secret/{data,metadata}/weftspun/cloudflare/*   read, list
        fdb-config-reader  secret/{data,metadata}/weftspun/fdb/*          read, list
        pki-issuer         pki/issue/*, pki/sign/*,
                           pki-wt/issue/*, pki-wt/sign/*        create, update
        app-reader-spot    secret/{data,metadata}/apps/spot-broker/*      read, list

    Naming convention: each policy is a verb ("editor", "reader",
    "issuer") over a scope ("dns", "fdb-config", "app-<name>"). Scopes
    map to KV subtrees; verbs to Bao capability sets.

    Adding a new app is a policy per app (`app-reader-<name>`) plus one
    subtree under `secret/apps/<name>/*`. Adding a new capability is a
    policy per verb, per scope. Two axes; nothing else needs to change.
    """

    details "Cert-auth roles", ~S"""
    Bao's `cert` auth backend was enabled by RFD 2146. Every role binds
    one leaf (or a small allow-list of CNs) to a set of policies. The
    leaf is Bao-PKI-issued by `chibifire.com Intermediate CA v2` (except
    the operator's admin cert, which is signed directly by the Root, a
    one-hop shortcut that lets the admin swap in without an intermediate
    in the trust chain).

        role                cn(s)                                            policies
        ---------------     ----------------------------------------------   ----------------------------------------
        admin-v2            bao-admin.chibifire.com                          admin, dns-editor, pki-issuer,
                                                                             fdb-config-reader
        spot-broker-app     fdb-spot-broker.chibifire.com                    fdb-config-reader, app-reader-spot
        fdb-cluster         fdb-{8d1d2ebed71158,2861e4dc350678,
                                0803267bd16708}.chibifire.com                fdb-config-reader

    `allowed_common_names` is exact-match (no globs) so a compromised
    leaf under a shared CA cannot cross into another role's scope by
    renaming its CSR. Token TTL 8h, max TTL 24h, a session's window,
    not a service's lifetime.
    """

    details "Walkthrough: DNS edit without 1P", ~S"""
        scratchpad/cf-bearer.sh:
          curl -sk --cert  admin-v2.cert  --key admin-v2.key \
            -X POST $BAO/v1/auth/cert/login  -d '{"name":"admin-v2"}'
          -> {"client_token":"s.xxxx",  "policies":["admin","default","dns-editor","fdb-config-reader","pki-issuer"]}
          curl -sk --cert admin-v2.cert --key admin-v2.key \
            -H "X-Vault-Token: s.xxxx" \
            $BAO/v1/secret/data/weftspun/cloudflare/edit-zone-dns
          -> {"data":{"data":{"bearer":"cfut_..."}}}
        then: curl -H "Authorization: Bearer cfut_..." api.cloudflare.com/...

    No `op read` in the chain. The admin cert is on this desk. Bao's
    cert-auth backend checks the presented leaf against the role, mints
    a scoped token, and returns it. Verified 2026-09-01 against
    `spot.chibifire.com` DNS records under the Cloudflare zone.
    """

    details "Negative controls (proved on the same day)", ~S"""
    - `spot-broker-app` logging in with its own cert reads
      `secret/data/weftspun/fdb/cluster-id` -> value returned; reads
      `secret/data/weftspun/cloudflare/edit-zone-dns` -> **permission
      denied**. The `app-reader-spot` + `fdb-config-reader` bundle has
      no path into `cloudflare/*`.
    - `fdb-cluster` logging in with an FDB machine cert reads
      `cluster-id` -> value returned; reads `cloudflare/edit-zone-dns`
      -> **permission denied**. `fdb-config-reader` is the only grant.

    Both negative controls fire on the same DENIED shape a real
    attacker would see: 403 with `permission denied`. Nothing about the
    policy leaks to the caller.
    """

    details "What this RFD does not cover", ~S"""
    - **Approle / token-based auth.** Kept enabled for the root break-
      glass path. Not the primary auth pattern for services.
    - **Cert renewal.** Roles carry a specific leaf's DER hash. When the
      leaf rotates (90 days per RFD 2145), the role has to be re-bound.
      A followup script watches `pki/` for issuance and re-runs
      `bao write auth/cert/certs/<role> certificate=@<new-leaf>`
      automatically. Filed in the workspace task list.
    - **Namespaces.** OpenBao has enterprise-only namespaces. This RFD
      uses path prefixes instead (`secret/weftspun/`, `secret/apps/`).
    """

    details "Sources", ~S"""
    - RFD 2140 (Bao on FDB), the storage backend this all sits on.
    - RFD 2142, service TLS design; this RFD's role table is its
      implementation.
    - RFD 2145, cert lifetimes that constrain how often roles rotate.
    """

    drafted_by :ai
  end
end
