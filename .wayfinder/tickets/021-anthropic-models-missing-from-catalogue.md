---
id: 021
title: pick-model's catalogue has no Anthropic entries, but Claude Code runs on Anthropic
label: wayfinder:defect
status: open
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
