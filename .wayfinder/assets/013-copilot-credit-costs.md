# What Copilot actually costs Bas — GitHub AI Credits

Captured **2026-08-24**. Asset of
[Determine the premium-request multiplier for each available Copilot model](../tickets/013-premium-request-multipliers.md).

## Headline: premium-request multipliers do not apply

**GitHub replaced request-based billing with usage-based billing on 1 June 2026.**
Cost now depends on *the model and the number of tokens consumed*.

Premium-request multipliers still exist, but only as **legacy** billing for
"Copilot Pro and Copilot Pro+ subscribers on an existing **annual plan** who
remained on the legacy premium request-based billing model after June 1, 2026."
Bas is on a GitHub Enterprise Cloud host with Business/Enterprise seats, so the
multiplier table is **not his currency** and is deliberately not reproduced here.

**His currency is GitHub AI Credits, which are token-denominated:**

- **1 AI credit = $0.01 USD**
- Credits are consumed by input tokens, output tokens and cached tokens
- **Copilot Business: 1,900 credits/user/month** · **Copilot Enterprise: 3,900**
- Each license contributes to a **shared enterprise pool**; overage is billed at
  $0.01 per credit (overage, not cutoff)
- **Code completions and next-edit suggestions are not billed in AI credits**

## The `cost` field in the model metadata is correct — verified

Every one of the 25 available models was cross-checked against GitHub's published
per-1M-token rates. **All 25 matched exactly** — `claude-haiku-4.5` 1/5,
`claude-sonnet-4.5` 3/15, `claude-sonnet-5` 2/10, `gpt-5-mini` 0.25/2,
`gpt-5.3-codex` 1.75/14, `gpt-5.4` 2.5/15, `gpt-5.5` 5/30, `gpt-5.6-luna`
0.2/1.2, `gpt-5.6-sol` 2/10, `gpt-5.6-terra` 2/12, `gemini-3.5-flash` 1.5/9,
`gemini-3.6/3.7-flash` 0.75/3.75, `mai-code-1.1-flash` 0.2/1.2, all Opus 5/25.

**So `cost.input`/`cost.output` from `opencode models --verbose` is a valid,
offline-readable proxy for credit burn** — subject to the three traps below.

## ⚠ Three traps in the metadata

### 1. The `-fast` variants are under-priced by 2×

GitHub lists **"Claude Opus 4.8 (fast mode) — $10.00 input / $1.00 cached /
$12.50 cache write / $50.00 output"** — exactly **double** normal Opus.

But `claude-opus-4.6-fast`, `-4.7-fast` and `-4.8-fast` all report **5/25** in the
metadata, same as non-fast. These are the three models absent from the models.dev
catalogue, so their cost was inherited rather than sourced. **A router trusting
the metadata would treat `-fast` as free speed when it actually doubles credit
burn.** Override these to 2× until corrected upstream.

*Confidence:* the 2× is documented for Opus 4.8 fast mode specifically; 4.6-fast
and 4.7-fast are not individually listed, so 2× is inferred by analogy.

### 2. Long-context tiers cost up to 2× and the metadata shows only the default

| Model | Default in/out | Long-context in/out |
| --- | --- | --- |
| `gpt-5.4` | $2.50 / $15.00 | **$5.00 / $22.50** |
| `gpt-5.5` | $5.00 / $30.00 | **$10.00 / $45.00** |
| `gpt-5.6-luna` | $0.20 / $1.20 | **$0.40 / $1.80** |
| `gpt-5.6-sol` | $2.00 / $10.00 | **$4.00 / $15.00** |
| `gpt-5.6-terra` | $2.00 / $12.00 | **$4.00 / $18.00** |

The metadata reports only the default tier, so **a long-context task silently
costs up to 2× the advertised rate**. This dovetails with the map's core insight
that tier is a function of `(model, context length)` — context length now drives
*cloud* cost too, not just local feasibility.

**The token threshold that trips the long-context tier is not stated** in the
pricing docs — see the follow-up ticket.

### 3. Cached input is 10× cheaper — the biggest single lever

Cached input is one tenth of fresh input across every model ($0.50 vs $5.00 for
Opus; $0.02 vs $0.20 for Luna). Cache *write* costs ~1.25×.

**Prompt-cache reuse is worth more than model choice on input-heavy work.** For a
100k-input Opus turn, caching the input drops the turn from 75 credits to 30 — a
2.5× saving with no quality loss. Routing should favour session continuity.

## What this means in practice

Illustrative, for a turn of 100k input + 10k output:

| Model | Cost | Credits | Turns per 1,900-credit Business allowance |
| --- | --- | --- | --- |
| `claude-opus-5` | $0.75 | 75 | ~25 |
| `claude-opus-5`, input cached | $0.30 | 30 | ~63 |
| `claude-sonnet-5` | $0.30 | 30 | ~63 |
| `gpt-5.6-luna` | $0.032 | 3.2 | ~594 |
| `mai-code-1.1-flash` | $0.032 | 3.2 | ~594 |

**A ~23× spread between the cheapest and most expensive model.**

### The strategic finding — this weakens the credits case for local

Credit pressure is concentrated in **expensive-model agentic coding**, not in doc
work. A doc-editing turn on `gpt-5.6-luna` costs ~3 credits; the Business
allowance covers roughly 600 of them per month. Local models were justified at
charting time on **credits + offline**; on the credits half, cheap cloud is now
demonstrably competitive with free-but-slow local, and far more capable.

Local's remaining justifications are **offline capability** (a stated driver, and
untouched by this finding) and zero marginal cost as insurance once the pool is
exhausted. But the argument "route doc work locally to save credits" is much
weaker than assumed. **This is Bas's call** — recorded for
[Define the open task taxonomy and its routing table](../tickets/005-task-taxonomy.md).

### And the 0× hope is dead

Last session flagged that a 0×-multiplier model could displace the local tier
entirely. **There are no zero-cost models** — every model carries per-token
charges. Only code completions and next-edit suggestions are unbilled.

## Reasoning-effort variants are not free

Under token billing, reasoning tokens are billed as **output** tokens, so a
higher `variants` effort (`low`…`max`, some with explicit
`thinking.budgetTokens`) costs strictly more. Under the old multiplier billing it
would have been free. This **inverts** the speculation recorded on ticket 005
that effort might be a free lever — treat effort as a cost dial.

*Confidence:* the docs state credits are consumed by "input tokens, output
tokens, and cached tokens" and do not carve out reasoning tokens; billing
reasoning as output is the standard treatment. Not explicitly confirmed for
Copilot — worth a spot-check against a real usage report.

## Programmatic discoverability: no

- **`GET https://api.info-support.ghe.com/copilot_internal/v2/token` → 404.** The
  internal token-exchange endpoint does not exist on this data-residency host, so
  the editor-client route to an authenticated `/models` (which might have carried
  billing metadata) is not available as used on `api.github.com`.
- Pricing is **published documentation, not an API**. It must be captured as a
  dated data file and refreshed — exactly what map invariant 7 requires.
- **`docs.github.com` was firewall-blocked** and had to be allowlisted by Bas
  from the host mid-session. Any refresh path that reads GitHub docs depends on
  that domain staying allowed.

## Sources

- [Requests in GitHub Copilot](https://docs.github.com/en/copilot/concepts/billing/copilot-requests)
- [Models and pricing for GitHub Copilot — Enterprise Cloud](https://docs.github.com/en/enterprise-cloud@latest/copilot/reference/copilot-billing/models-and-pricing)
- [Model multipliers for annual plans on request-based billing (legacy)](https://docs.github.com/en/copilot/reference/copilot-billing/request-based-billing-legacy/model-multipliers-for-annual-plans)
- [About billing for GitHub Copilot in organizations and enterprises](https://docs.github.com/en/copilot/concepts/billing/organizations-and-enterprises)
