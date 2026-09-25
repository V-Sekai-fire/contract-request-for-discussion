# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
#
# RFD 1088. `mix rfd.render` renders rfd/1088-https-setup/README.md and
# DETAILS.md from this file; the Markdown is a build artifact (RFD 2232).
defmodule RFD1088 do
  use RFD.DSL

  rfd 1088, "HTTPS for local WebXR development" do
    state :published

    scope "the Vite dev server, `certs/`"

    attest_in :none

    decision ~S"""
    Generate a local certificate into `certs/`, and let Vite pick it up
    automatically. `mkcert` is the recommended path: install it, run
    `mkcert -install` once for the local CA, then `mkcert localhost
    127.0.0.1 ::1 <LAN-IP>` for a certificate that also covers the
    headset's LAN address. An OpenSSL path (`npm run setup-https`, or a
    manual `openssl req`) covers a host without `mkcert`. A self-signed
    certificate still shows a browser warning; accepting it is safe for
    local development.

    See `DETAILS.md` for every option's exact commands, the headset
    network-access steps, and troubleshooting.
    """

    problem ~S"""
    WebXR needs HTTPS. A plain `npm run dev` over HTTP cannot open an
    AR or VR session at all, on a desktop browser or on a Galaxy XR
    headset over the LAN.
    """

    related ~S"""
    **Unresolved duplicate:** weftspun-3d-studio's own
    `thirdparty/m3/docs/HTTPS_SETUP.md` covers the same topic, with real
    content differences. Neither version is authoritative; that
    reconciliation is still open. RFD 1086 gives the Surface/DGX/headset
    topology this certificate serves.
    """

    details_title "HTTPS for local WebXR development"

    details "Option 1: mkcert, the easiest path", ~S"""
    1. Install `mkcert`: `choco install mkcert` on Windows, or download
       from its GitHub releases; `brew install mkcert` on macOS; see
       `mkcert`'s own installation guide on Linux.
    2. Install the local CA: `mkcert -install`.
    3. Generate certificates: `mkcert localhost 127.0.0.1 ::1 10.0.0.32`
       (that last address is an example LAN IP), producing
       `localhost+3.pem` and `localhost+3-key.pem`.
    4. Move the certificates into the certs directory:

       ```bash
       mkdir certs
       mv localhost+3.pem certs/localhost.pem
       mv localhost+3-key.pem certs/localhost-key.pem
       ```

    5. Restart the dev server: `npm run dev`.
    6. Access over HTTPS: `https://localhost:3000`, or
       `https://10.0.0.32:3000` for a Galaxy XR device.
    """

    details "Option 2: OpenSSL, one command", ~S"""
    ```bash
    npm run setup-https
    ```

    Generates certificates directly into `certs/`.
    """

    details "Option 3: manual certificate generation", ~S"""
    ```bash
    mkdir certs
    openssl req -x509 -newkey rsa:4096 -keyout certs/localhost-key.pem -out certs/localhost.pem
    -days 365 -nodes -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"
    ```

    Restart the dev server; Vite picks up the certificates
    automatically.
    """

    details "The browser security warning", ~S"""
    A self-signed certificate always triggers a warning. Click
    "Advanced" or "Show Details", then "Proceed to localhost (unsafe)"
    or "Accept the Risk and Continue". Safe for local development.
    """

    details "Network access, for a Galaxy XR device", ~S"""
    1. Put both devices on the same network.
    2. Find the computer's own IP address (for example, `10.0.0.32`).
    3. Add that IP to the certificate (see step 3 under mkcert, above).
    4. Access `https://10.0.0.32:3000` on the Galaxy XR device.
    """

    details "Troubleshooting", ~S"""
    - Certificate errors: confirm the certificates sit in `certs/`, with the exact expected names.
    - Connection refused: check firewall settings, and confirm port 3000 is open.
    - WebXR still not working: confirm HTTPS, not HTTP, and confirm the certificate warning was
    accepted.
    """

    drafted_by :ai
  end
end
