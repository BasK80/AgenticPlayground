---
id: 020
title: Route opencode's Copilot provider at the GHE tenant instead of api.githubcopilot.com
label: wayfinder:defect
status: open
assignee: Bas Kloet
blocked_by: []
---

## Question

The stated standard is that **both the Copilot CLI and opencode run against
the GHE tenant**, with Claude Code on the Anthropic subscription. The Copilot
CLI half works. The opencode half does not.

## Evidence

- `~/.config/opencode/opencode.json` has an empty `provider` block, and
  `opencode auth list` reports **0 credentials**. opencode is not
  authenticated against Copilot at all.
- The opencode binary (1.18.18) contains `api.githubcopilot.com` and no
  `ghe.com` string anywhere — its built-in `github-copilot` provider points at
  public GitHub.
- The tenant publishes its own hosts, from `GET /copilot_internal/user`:
  - `api: https://copilot-api.info-support.ghe.com`
  - `proxy: https://copilot-proxy.info-support.ghe.com`
- `llm-switch.sh` currently offers Anthropic (OAuth), Anthropic (key) and
  Foundry/Azure. It has no Copilot route, and its header comment states the
  Copilot CLI is deliberately separate.

## What needs deciding

- Whether opencode can reach the tenant via a custom `provider` block with an
  overridden `baseURL`, reusing the same GHE token that `pick-model` now
  resolves (ticket 019), or whether the built-in provider is too hardcoded.
- Whether this becomes a `use-copilot` function in `llm-switch.sh`, matching
  the existing provider-switch pattern.
- Whether the token belongs in opencode's own `auth.json` or is read from
  `~/.copilot/config.json` as `pick-model` does.

## Why it matters beyond opencode

`pick-model` recommends models from a catalogue containing only
`github-copilot/*` and `ollama/*` entries. In opencode those Copilot
recommendations are currently unactionable, because opencode cannot reach
them on this tenant.

Split out of ticket 019's grilling, where it surfaced while deciding how the
skill resolves its token.
