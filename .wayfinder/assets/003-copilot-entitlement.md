# GHE Copilot model entitlement — `info-support.ghe.com`

Captured **2026-08-24**. Asset of
[Discover which models GHE Copilot actually offers this account](../tickets/003-discover-copilot-models.md).

- **Enterprise host:** `info-support.ghe.com`
- **Copilot API base (per-model `api.url`):** `https://copilot-api.info-support.ghe.com/v1`
  (npm driver `@ai-sdk/anthropic` for Claude models, endpoint `messages`)
- **Re-derivation command:** `opencode models github-copilot --verbose`
- **Raw capture:** [`003-copilot-models-verbose.txt`](003-copilot-models-verbose.txt)
  · **parsed array:** [`003-copilot-models.json`](003-copilot-models.json)

## The 25 available models

All are `status: active`, **all support tool calls**, and **all support
reasoning**. `IN$`/`OUT$` are models.dev list prices in $/Mtok — **not** Copilot
premium-request cost (see the warning below).

| ID | Context | Max out | IN$ | OUT$ |
| --- | --- | --- | --- | --- |
| `claude-haiku-4.5` | 200k | 64k | 1 | 5 |
| `claude-opus-4.5` | 200k | 32k | 5 | 25 |
| `claude-opus-4.6` | 1M | 64k | 5 | 25 |
| `claude-opus-4.6-fast` | 1M | 64k | 5 | 25 |
| `claude-opus-4.7` | 1M | 64k | 5 | 25 |
| `claude-opus-4.7-fast` | 1M | 64k | 5 | 25 |
| `claude-opus-4.8` | 1M | 64k | 5 | 25 |
| `claude-opus-4.8-fast` | 1M | 64k | 5 | 25 |
| `claude-opus-5` | 1M | 64k | 5 | 25 |
| `claude-sonnet-4.5` | 200k | 32k | 3 | 15 |
| `claude-sonnet-4.6` | 1M | 64k | 3 | 15 |
| `claude-sonnet-5` | 1M | 64k | 2 | 10 |
| `gemini-3.5-flash` | 1M | 64k | 1.5 | 9 |
| `gemini-3.6-flash` | 1M | 64k | 0.75 | 3.75 |
| `gemini-3.7-flash` | 1M | 64k | 0.75 | 3.75 |
| `gpt-5-mini` | 264k | 64k | 0.25 | 2 |
| `gpt-5.3-codex` | 400k | 128k | 1.75 | 14 |
| `gpt-5.4` | 1.05M | 128k | 2.5 | 15 |
| `gpt-5.4-mini` | 400k | 128k | 0.75 | 4.5 |
| `gpt-5.5` | 1.05M | 128k | 5 | 30 |
| `gpt-5.6-luna` | 1.05M | 128k | 0.2 | 1.2 |
| `gpt-5.6-sol` | 1.05M | 128k | 2 | 10 |
| `gpt-5.6-terra` | 1.05M | 128k | 2 | 12 |
| `mai-code-1-flash-picker` | 256k | 128k | 0.75 | 4.5 |
| `mai-code-1.1-flash` | 256k | 128k | 0.2 | 1.2 |

Several models expose reasoning-effort `variants` (`minimal`/`low`/`medium`/
`high`/`xhigh`/`max`, some with explicit `thinking.budgetTokens`). These are a
routing lever in their own right — a cheap model at `high` effort may beat an
expensive one at `low`.

## Provenance: this is real entitlement, not a catalogue dump

Compared against `https://models.dev/api.json` (which catalogues **33**
`github-copilot` models):

- **11 catalogued models are not available here** — `claude-fable-5`,
  `claude-sonnet-4`, `gemini-3.1-pro-preview`, `gpt-4.1`, `gpt-5.2`,
  `gpt-5.2-codex`, `gpt-5.4-nano`, `grok-4.5`, `grok-4.6`, `kimi-k2.7-code`,
  `kimi-k3`.
- **3 available models are not in the catalogue at all** —
  `claude-opus-4.6-fast`, `claude-opus-4.7-fast`, `claude-opus-4.8-fast`.

33 − 11 + 3 = 25. Because the list is **not a subset** of models.dev, it cannot
be catalogue-derived: `opencode models github-copilot` reflects live account
entitlement, merged with models.dev metadata.

The exclusions are **vendor-shaped** — every Grok and Kimi model is absent,
leaving only Anthropic, OpenAI, Google and Microsoft. That looks like an Info
Support approved-vendor policy, which means **the list can change without
notice** when policy changes. Re-derive; never hardcode.

## ⚠ The `cost` field is the wrong currency

`cost.input`/`cost.output` are models.dev **list prices in $/Mtok**. GHE Copilot
does not bill Bas per token — it bills **premium requests**, each model carrying
a multiplier. Optimising the numbers in this table would optimise a currency Bas
never spends.

The multiplier is **absent from this metadata**, so it is tracked separately by
[Determine the premium-request multiplier for each available Copilot model](../tickets/013-premium-request-multipliers.md).

## Side finding for provider wiring

models.dev has **no plain `ollama` provider** — only `ollama-cloud`, pointing at
`https://ollama.com/v1` with `@ai-sdk/openai-compatible`. So a *local* ollama
instance is not a catalogued provider and needs a hand-written
openai-compatible provider entry against `host.docker.internal:11434`. Recorded
on [Wire ollama and GHE Copilot as opencode providers](../tickets/009-wire-opencode-providers.md).
