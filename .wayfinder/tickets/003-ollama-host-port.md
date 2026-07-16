---
id: 003-ollama-host-port
title: Allow usage of an Ollama instance running on a non-HTTPS port on the host
label: wayfinder:grilling
status: open
assignee: null
blocked_by: []
---

## Question

The dev container currently has no documented or configured path for talking
to an Ollama instance running on the host (typically plain HTTP on a
non-standard port, e.g. `http://host.docker.internal:11434`). `docs/providers.md`
covers Anthropic API, Azure AI Foundry, and Copilot OAuth provider setups, but
nothing for Ollama. How should this be supported, given the container has no
direct route out and all egress goes through the Squid proxy (which is built
for HTTPS/domain-based allowlisting, not a same-host plain-HTTP port)? Options
to weigh with the reporter: reach the host directly via the `internal: true`
network's gateway instead of routing through Squid (would need a compose /
firewall change), proxy host-Ollama traffic through Squid with a
CONNECT-style or plain-HTTP allowance, or something else. Also decide whether
this becomes a new provider section in `docs/providers.md` alongside a
firewall/compose change.

Facts already gathered:
- No existing references to Ollama anywhere in `docs/` or `.devcontainer/`.
- The `development` container network is `internal: true` (see
  `docs/security.md`) — no route to the internet or, by default, to the host
  — so this is architecturally different from the other providers' plain
  domain-allowlist model.
