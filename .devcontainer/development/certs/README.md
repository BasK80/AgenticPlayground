# Corporate CA certs

If your network sits behind a corporate TLS-inspecting (MITM) proxy, the
dev container build will fail with certificate verification errors on any
`curl`/`npm`/`git` HTTPS call (self-signed cert in the chain) unless it
trusts your organization's root CA.

Drop your corporate root CA certificate(s) in this directory in **whatever
format you exported them as** — no manual conversion needed:

- PEM `.crt` / `.pem`
- Base64-encoded X.509 `.cer` (this is actually PEM text under a `.cer` name)
- DER-encoded binary X.509 `.cer` / `.der`
- PKCS#7 `.p7b` / `.p7c`

e.g.:

```
.devcontainer/development/certs/corporate-root-ca.cer
```

The Dockerfile copies everything here into
`/usr/local/share/ca-certificates/corporate/`, runs `convert-certs.sh` to
normalize whatever format you dropped in into PEM `.crt` (trying PEM/DER
`x509` and PEM/DER `pkcs7` in turn — unparsable files are skipped with a
build-time warning), then runs `update-ca-certificates`, then points
`NODE_EXTRA_CA_CERTS` at the resulting bundle so Node/npm (which ignore the
system store by default) trust it too.

This directory is gitignored except for this README and `.gitkeep`, so
your certs never get committed. Rebuild the container after adding a cert.
