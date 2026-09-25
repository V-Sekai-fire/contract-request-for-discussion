# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 2255. `mix rfd.render` renders rfd/2255-bao-ssh-tunnel/README.md
# and DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD2255 do
  use RFD.DSL

  rfd 2255, "an SSH tunnel to Bao for Bao-signed certificates" do
    state :committed

    feature "A desk with no tailnet and no private-network peer reaches\nBao's listener through sshd on the Bao machine, using a\none-hour SSH certificate that Bao itself signs"

    scope "`service-openbao` (`sshd_config`, `Dockerfile.fdb`,\n`entrypoint-fdb.sh`, `fly.toml`), and Bao's `ssh/` mount,\n`ssh/roles/bao-tunnel` and the `ssh-bao-tunnel` policy"

    decision ~S"""
    The Bao machine runs sshd on port 2222. It trusts one user CA,
    the key of Bao's own `ssh/` engine, and accepts one principal,
    `tunnel`. That user has no shell and may forward only to
    `127.0.0.1:8200`. An agent signs its SSH key with its Bao token
    at `ssh/sign/bao-tunnel`, gets a certificate valid for an hour,
    and runs `ssh -N -L` to the listener. The listener's mTLS stays
    the second factor: the tunnel carries TLS, it does not replace
    it.
    """

    problem ~S"""
    Bao is reached over the tailnet or the private network, and a
    desk can lack both: a WSL distro is on neither, and its
    WireGuard peer fails to add its route. Every other route in
    use was an operator-held proxy, which is a person, not a path.
    """

    related ~S"""
    - RFD 2195 (Bao over the tailnet), the path this complements.
    - RFD 2146 (Bao is the secret store), the cert-auth identities
      that sign here.
    - RFD 2142 (Bao PKI), the root the agent certificates chain to.
    """

    drafted_by :ai

    details_title "an SSH tunnel to Bao for Bao-signed certificates"

    details "Using it", ~S"""
    With a Bao token from cert login (RFD 2195's four variables):

        ssh-keygen -y -f key.pem > key.pub
        bao write -field=signed_key ssh/sign/bao-tunnel \
            public_key=@key.pub valid_principals=tunnel > key-cert.pub
        ssh -N -L 18200:127.0.0.1:8200 -p 2222 \
            -i key.pem -o CertificateFile=key-cert.pub tunnel@<bao address>
        export BAO_ADDR=https://127.0.0.1:18200
        export BAO_TLS_SERVER_NAME=weftspun-bao.internal

    The key can be the same P-256 key as the agent's cert-auth
    identity, converted to PKCS#8, so a desk holds one private key.
    """

    details "What is measured", ~S"""
    Run against the deployed image through a proxy to port 2222,
    and before that against a local sshd with the same config:

    | case | expected | deployed |
    | --- | --- | --- |
    | Bao-signed cert, forward to 8200 | Bao answers | `cert-fedora-cad853` |
    | plain key, no certificate | refused | `Permission denied (publickey)` |
    | cert, user `root` | refused | `Permission denied (publickey)` |
    | cert, a shell command | refused | `This account is currently not available.` |
    | cert, forward to 8201 | refused | `administratively prohibited` |
    | sign for principal `root` | refused | `root is not a valid value for valid_principals` |

    The public address is IPv6 only, and it is untested from this
    desk: WSL here has no IPv6 route.
    """

    details "What it costs", ~S"""
    A redeploy restarts Bao, and Bao comes back sealed; the rollout
    that shipped this needed one unseal. The image rebuild also
    re-clones the OpenBao fork at its branch head, so a rebuild for
    sshd can change the Bao binary too. The public 8200 service is
    gone from `fly.toml`, so the only public port is 2222.

    The host key sits on the data volume and survives a redeploy.
    Its fingerprint is `SHA256:6xkNw5/8n/fRVyYU9SC0/ON+qRh+WSfVCYp8CCeuaXg`.
    """
  end
end
