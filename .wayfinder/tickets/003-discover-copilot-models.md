---
id: 003
title: Discover which models GHE Copilot actually offers this account
label: wayfinder:task
status: closed
assignee: Bas Kloet
blocked_by: []
---

## Question

Which models does Bas's **GitHub Enterprise Copilot** entitlement actually
expose, and how can a skill enumerate that list *programmatically* at refresh
time?

Bas does not know the list, and enterprise Copilot policy can restrict which
models are available — so it must be **discovered, not hardcoded** (map
invariant 5). Produce both:

1. The concrete list as it stands today (model ids, context windows, and any
   premium-request/quota multipliers that affect the credits calculus).
2. The **command or endpoint** a skill can run later to re-derive that list
   without a human — or a clear statement that a human step is unavoidable.

## Why this is a task, not research

This is **HITL** and cannot be scripted: Copilot needs a one-time interactive
device/browser login. `tools/test-opencode-providers.sh` documents the same wall
for Anthropic OAuth — *"a one-time interactive browser/device login that cannot
be scripted"* — and exits with code 2 telling the human what to do. Expect the
same shape here.

Steps, roughly: authenticate `gh` against the enterprise host (`gh` is currently
logged in to **no** host), and/or complete opencode's `github-copilot` provider
login, then enumerate.

## What is already known

- The firewall already allows `.githubcopilot.com` and `.ghe.com`. The
  `copilot.list` allowlist comment names the intent explicitly: *"GitHub Copilot
  inference (agentic framework: opencode/Copilot CLI backend) — device login +
  token exchange ride on the github feature"*. So the plumbing was anticipated.
- `models.github.ai` (GitHub Models) is **not** allowlisted and is out of scope.
- Copilot CLI v1.0.80 is installed and has its own separate auth (`/login`)
  — per `CLAUDE.md`, it does **not** use the `use-*` switches.

## Resolution must record

The model list, the re-derivation command, where any credential lives, and the
enterprise host name — later tickets depend on these facts.

---

## RESOLUTION (2026-08-24) — closed

**25 models are available**, all `active`, **all tool-capable and
reasoning-capable**, context windows 200k–1.05M. Full table, provenance analysis
and raw capture: [GHE Copilot model entitlement](../assets/003-copilot-entitlement.md).

- **Enterprise host:** `info-support.ghe.com`
- **Copilot API base:** `https://copilot-api.info-support.ghe.com/v1`
- **Re-derivation command:** `opencode models github-copilot --verbose`
- **Auth:** device login, both completed — `opencode providers login -p
  github-copilot` **and** `copilot login --host https://info-support.ghe.com`.

**The list is genuine entitlement, not a catalogue dump.** models.dev catalogues
33 `github-copilot` models; 11 of those are unavailable here and 3 available ones
are absent from the catalogue (33 − 11 + 3 = 25). Since it is not a *subset*, it
cannot be catalogue-derived — so **map invariant 5 holds** and the re-derivation
command above is trustworthy. Exclusions are vendor-shaped (all Grok and Kimi
gone; only Anthropic/OpenAI/Google/Microsoft remain), consistent with an approved-
vendor policy that can change without notice. Re-derive, never hardcode.

**The one requirement this ticket could NOT meet:** premium-request multipliers
are absent from the metadata. The `cost` fields are models.dev $/Mtok list
prices — the wrong currency, since Copilot bills premium requests. Split out into
[Determine the premium-request multiplier for each available Copilot model](013-premium-request-multipliers.md),
which now blocks [Write the pick-model skill](011-write-pick-model.md).

> **CORRECTION (2026-08-24, from ticket 013):** the paragraph above is wrong.
> Copilot moved to **usage-based (token) billing on 1 June 2026**; premium-request
> multipliers are legacy and do not apply to Bas's Enterprise Cloud seats. The
> `cost` fields are therefore the **right** currency — all 25 were verified
> against GitHub's published per-1M-token AI-credit rates and matched exactly.
> Three caveats remain (`-fast` under-priced 2×, long-context tiers up to 2×,
> cached input 10× cheaper): see
> [What Copilot actually costs Bas](../assets/013-copilot-credit-costs.md).

**Concern retired:** `opencode providers login` has no `--host` flag, but its
flow offers GHE as an **interactive option** and authenticated correctly against
`info-support.ghe.com`. Enterprise support in opencode is not a risk.

---

## Findings so far (AFK half — complete, 2026-08-24)

**Superseded by the resolution above; kept for the reasoning trail.**

### Established facts

- **Enterprise host: `info-support.ghe.com`** (GitHub Enterprise Cloud with data
  residency). Bas chose the **device-login** route over a static PAT.
- **No pre-existing auth in the container.** No `~/.config/github-copilot/`, no
  `~/.config/gh/`; `gh auth status` reports no host. `~/.copilot/` exists but is
  only CLI state created at container start (`config.json` is 131 bytes and *not*
  valid JSON — it is not a readable token store).
- **The enumeration endpoints are reachable through the firewall** — verified
  unauthenticated, so only the credential is missing:

  | Endpoint | Unauthenticated response | Reading |
  | --- | --- | --- |
  | `api.github.com/copilot_internal/v2/token` | `401 Requires authentication` | GitHub's own reply, **not** a proxy `403` — path works |
  | `api.githubcopilot.com/models` | `400 missing required Authorization header` | **Endpoint exists and is reachable**; needs a Bearer token |

  The two-step mechanism is therefore: exchange a GitHub OAuth token at
  `/copilot_internal/v2/token`, then `GET .../models` with the returned bearer.
  The exchange response also carries the API base URL in `endpoints.api` — prefer
  that over hardcoding, since this is an enterprise host.

### Login commands (interactive — HITL, cannot be scripted)

```sh
opencode providers login -p github-copilot        # on-point: enables `opencode models github-copilot`
copilot login --host https://info-support.ghe.com # reliable: documented GHE data-residency support
```

- `copilot login` auto-selects the **device-code flow** in a dev container
  (`--device-code` forces it); `--host` is documented for GHE data residency.
- **`opencode providers login` has no `--host`/enterprise flag** — only
  `-p/--provider` and `-m/--method`. If its Copilot flow is hardcoded to
  `github.com` it will fail or authenticate the wrong account against
  `info-support.ghe.com`. **That outcome is a constraint for
  [Wire ollama and GHE Copilot as opencode providers](009-wire-opencode-providers.md)**,
  not a defect of this ticket.

### Re-derivation command candidate

`opencode models [provider] --verbose` (`--refresh` re-pulls from models.dev).
**It reflects configured providers, not the whole catalogue** — verified: with
nothing authenticated it lists only 7 `opencode/*` free models, not the full
models.dev set. Whether it further reflects *enterprise policy filtering* within
`github-copilot` is the one thing only a completed login can reveal — check it,
because map invariant 5 ("discovered, not hardcoded") depends on the answer.

### Rejected alternative (recorded so it is not revisited)

A fine-grained (v2) PAT with the **"Copilot Requests"** permission, exported as
`COPILOT_GITHUB_TOKEN` / `GH_TOKEN` / `GITHUB_TOKEN`, is a fully headless option
(classic `ghp_` tokens are rejected). Bas declined it: this repo has a standing
position against static keys on disk — `llm-switch.sh`'s header notes the default
provider *"carries no static key on disk for an agent to read"*. Revisit only if
credential-store loss on rebuild becomes painful.
