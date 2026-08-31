---
id: 021
title: pick-model's catalogue has no Anthropic entries, but Claude Code runs on Anthropic
label: wayfinder:defect
status: closed
assignee: Bas Kloet
blocked_by: []
---

## Question

`models.json` contains exactly two providers:

| provider | entries |
| --- | --- |
| `github-copilot` | 5 |
| `ollama` | 3 |

There are **no Anthropic entries**. But the stated standard is that **Claude
Code runs on the Anthropic subscription**, and `llm-switch.sh`'s default is
`use-anthropic`.

So when `pick-model` runs inside Claude Code, every cloud model it can
recommend is one that harness isn't configured to reach, and the model
actually in use isn't in the catalogue at all.

## What this interacts with

Ticket 019 established that the credit story attaches to the *provider of the
chosen model* — Copilot-routed models show allowance and balance, everything
else shows nothing. That rule is correct and needs no change here, but it
means a Claude Code session currently gets cost reasoning for models it won't
run, and no cost reasoning for the model it will.

## What needs deciding

- Whether Anthropic models belong in `models.json` at all, or whether
  `pick-model` should declare itself out of scope when the active harness
  bills a subscription rather than metered credits.
- If they are added: what the cost axis means for a flat-rate subscription,
  where there is no per-token price to rank against. Ranking by cost is the
  core of the skill's routing, and a subscription has no such gradient.
- Whether `ollama-curate`'s refresh job or `pick-model` owns those entries.

Split out of ticket 019's grilling.

## Resolution

Grilled 2026-08-31. The premise behind "flat subscription, no cost axis" was
**wrong** — Bas's Anthropic access is an **enterprise-managed usage quota**,
structurally the same shape as Copilot's credit pool: a dollar-denominated
allowance ($150) with a hard stop, currently at $118 spent, managed by the
organisation rather than a per-seat flat fee. So the reason ticket 019 gave for
excluding Anthropic — no cost gradient to rank against — does not hold.

### Decisions

| # | Question | Decision |
| --- | --- | --- |
| 1 | Do Anthropic models belong in `models.json`? | **Yes.** They need the same credit-lever treatment as `github-copilot/*` entries — a real hard-wall quota exists, so cost-ranking applies. |
| 2 | What does the cost axis mean, given no per-token price was assumed? | Believed to mirror Copilot's premium-request-multiplier pattern (different models draw the pool at different rates) but the actual mechanics are **not known from memory** — split into a research ticket rather than guessed here. |
| 3 | Who owns adding/refreshing Anthropic entries — `ollama-curate` or `pick-model`? | **`pick-model`.** Reasoned live: Anthropic models are usable **only from within Claude Code** — unlike `ollama`/`github-copilot` entries, which serve routing decisions across all three harnesses via `ollama-curate`'s shared refresh path. Since the entries have exactly one consumer and one harness, `pick-model` owns them directly rather than inheriting them from `ollama-curate`'s cross-harness refresh job. |

**Unblocks:** [Research Anthropic Claude-for-Work per-model pricing and quota mechanics](022-anthropic-pricing-mechanics.md), which in turn unblocks a task to add the resulting Anthropic entries into `pick-model`'s `models.json` and cost reasoning (ticket 023).
