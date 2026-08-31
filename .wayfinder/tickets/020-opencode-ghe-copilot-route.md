---
id: 020
title: Route opencode's Copilot provider at the GHE tenant instead of api.githubcopilot.com
label: wayfinder:defect
status: closed
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

## Resolution

Investigated and **verified live 2026-08-31** — full detail and reproduction
steps in
[the login asset](../assets/020-opencode-ghe-copilot-login.md). Summary:

The premise in "Evidence" was incomplete, not wrong. opencode's built-in
`github-copilot` provider **already supports the GHE tenant natively** —
`opencode auth login -p github-copilot` offers a "GitHub Enterprise (Data
residency or self-hosted)" deployment type, un-mentioned in the public
provider docs, that asks for the tenant host and runs its own OAuth
device-code flow against it. Confirmed live: authenticated against
`info-support.ghe.com`, and `opencode models` returned the tenant's own
model catalogue (`gpt-5.6-*`, `mai-code-*`, `claude-*-5`), not the public
GitHub Copilot line-up — proof the calls land on the right host.

### Decisions

| # | Question | Decision |
| --- | --- | --- |
| 1 | Custom provider + `baseURL` override, or built-in? | **Built-in.** No custom `npm`/`baseURL` provider needed — `options.enterpriseUrl` (present in the schema and in the installed 1.18.18 binary) is a first-class, supported path. |
| 2 | Does this become a `use-copilot` function in `llm-switch.sh`? | **No.** It's a one-time OAuth login (`opencode auth login -p github-copilot` → Enterprise → host), stored in opencode's own `auth.json` — not a runtime env-var toggle like `use-anthropic`/`use-foundry`, so it doesn't fit that pattern. Model selection then happens via opencode's own `/models` picker. Matches the existing precedent that Copilot auth is separate from the `use-*` switches (see `llm-switch.sh`'s header note on the Copilot CLI). |
| 3 | Token in opencode's own `auth.json`, or read from `~/.copilot/config.json`? | **opencode's own `auth.json`.** It gets there via opencode's own device-flow login against the tenant, entirely independent of the Copilot CLI's token — no token sharing/reuse between the two tools was needed or attempted. |

**Consequence for `pick-model`:** its `github-copilot/*` recommendations are
now actionable in opencode on this machine — the "why it matters beyond
opencode" concern this ticket opened with is resolved by the same login.

**Not verified:** an actual chat completion through the new credential
(judged unnecessary spend — model-catalogue discovery against the correct,
tenant-specific model list was sufficient proof). Fair game as a cheap
follow-up the next time opencode is used for real work.
