# Corporate CA certs

If your network sits behind a corporate TLS-inspecting (MITM) proxy, the
dev container build will fail with certificate verification errors on any
`curl`/`npm`/`git` HTTPS call (self-signed cert in the chain) unless it
trusts your organization's root CA.

Drop your corporate root CA certificate(s) in this directory as `.crt`
files (PEM format), e.g.:

```
.devcontainer/development/certs/corporate-root-ca.crt
```

The Dockerfile copies everything here into
`/usr/local/share/ca-certificates/corporate/` and runs
`update-ca-certificates` during the build, then points `NODE_EXTRA_CA_CERTS`
at the resulting bundle so Node/npm (which ignore the system store by
default) trust it too.

This directory is gitignored except for this README and `.gitkeep`, so
your certs never get committed. Rebuild the container after adding a cert.
