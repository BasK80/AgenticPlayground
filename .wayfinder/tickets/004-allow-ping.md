---
id: 004-allow-ping
title: Allow ping (ICMP) out of the dev container
label: wayfinder:grilling
status: open
assignee: null
blocked_by: []
---

## Question

`ping` is deliberately non-functional today: `iputils-ping` is installed
(`Dockerfile`), but `post-start.sh` overlays a wrapper
(`.devcontainer/development/ping-wrapper.sh`) on `PATH` ahead of the real
binary that always prints an explanation and fails, because raw ICMP bypasses
the Squid proxy and the `development` network is `internal: true` with no
route out except through the proxy. Should this be changed to let `ping`
actually work, and if so how — e.g. route ICMP through the firewall
container as a NAT/forwarding gateway (a real topology change, weakening the
"proxy is the only egress path" security property described in
`docs/security.md`), restrict it to pinging allowlisted/internal hosts only,
or leave it as a documented limitation and instead improve the wrapper's
guidance? This is a security-posture tradeoff, not just a technical toggle,
so needs a decision from the reporter on how much of the current isolation
model they're willing to relax for this.

Facts already gathered:
- Wrapper source: `.devcontainer/development/ping-wrapper.sh`; installed by
  `.devcontainer/development/post-start.sh` (`~/.local/bin/ping`, ahead of
  `/usr/bin/ping` on `PATH` via `~/.zshrc`).
- Rationale for the current block is written in the wrapper's own comments
  and echoed in `docs/security.md`'s default-deny description.
