---
id: 014
title: Pin down the -fast variant pricing and the long-context tier threshold
label: wayfinder:research
status: closed
assignee: Bas Kloet
blocked_by: []
---

## Question

Two gaps in the credit-cost model that would make the router understate cost.
Close both.

**1. The `-fast` variants.** GitHub documents "Claude Opus 4.8 (fast mode)" at
**$10.00 in / $50.00 out — double** normal Opus. But `claude-opus-4.6-fast`,
`-4.7-fast` and `-4.8-fast` all report **5/25** in the model metadata, identical
to non-fast, because these three are absent from the models.dev catalogue and
their cost was inherited rather than sourced.

- Confirm the 2× for `-4.8-fast`, and establish whether `-4.6-fast` / `-4.7-fast`
  are also 2× (currently inferred by analogy, not documented individually).
- Decide where the override lives so the metadata's wrong value can't leak into a
  routing decision.

**2. The long-context tier threshold.** Several models bill a long-context tier at
up to 2× — `gpt-5.4` $2.50/$15 → **$5.00/$22.50**, `gpt-5.5` → **$10/$45**,
`gpt-5.6-luna` → **$0.40/$1.80**, `sol`/`terra` likewise. The metadata reports
**only the default tier**.

- **At what input-token count does the long-context tier engage?** Not stated in
  the pricing docs. Without it the router cannot predict cost for large inputs.
- Does it apply per-request based on prompt size, or per-model-variant selection?
- Which of the 25 available models have a long-context tier at all? Gemini 3.1
  Pro has one but is *not* in Bas's entitlement; confirm the list for models he
  can actually reach.

## Why it blocks the router

The whole point of ranking models is credit accuracy. A 2× error on the two axes
that large tasks hit — fast mode and long context — would make the skill
confidently recommend the wrong model on exactly the expensive requests where
being right matters most. See
[the credit-cost asset](../assets/013-copilot-credit-costs.md).

## Notes

- `docs.github.com` is now allowlisted (Bas added it 2026-08-24) — but it was
  blocked by default, so note that any refresh path depends on it staying allowed.
- If the threshold is genuinely unpublished, an empirical route exists: run a
  small and a large request and compare a real usage report. Record whichever
  source you used and its date.
- Do **not** state thresholds from memory. This is pricing policy and it changed
  as recently as June 2026.

## Resolution (2026-08-25)

Both gaps closed against GitHub's current "Models and pricing for GitHub
Copilot" (Enterprise Cloud) page, read directly (twice, independently) rather
than from memory. Full detail, table dumps and confidence notes:
[the pricing asset](../assets/014-fast-and-longcontext-pricing.md).

**1. `-fast` variants: only `claude-opus-4.8-fast` is actually documented.**
$10.00 in / $1.00 cached / $12.50 cache-write / $50.00 out — confirmed 2x
non-fast Opus, directly stated. `claude-opus-4.6-fast` and
`claude-opus-4.7-fast` have **no individually published rate anywhere** —
the docs list Opus 4.6 and 4.7 as "Default only." A live, GitHub-staff-unanswered
community thread confirms this gap is real, not a research miss. **Decision:
override all three fast variants to 2x their non-fast rate in the cost
metadata** (via ticket 007's `costOverride` mechanism), but flag the
4.6/4.7 overrides as `assumed`, not `measured` — re-check next pricing
refresh.

**2. Long-context threshold: published after all — the ticket's premise was
wrong.** The pricing table's "Threshold (input tokens)" column states it
explicitly: `gpt-5.4`/`gpt-5.5`/`gpt-5.6-sol`/`gpt-5.6-terra` engage above
**272K input tokens**; `gpt-5.6-luna` above **200K**. Mechanism is automatic
per-request against a single model ID (no separate long-context model
variant exists) — inferred from table structure at medium confidence, not
stated in prose; an empirical >272K-token test would upgrade this to high
confidence but wasn't run. Re-derived from a full table dump against ticket
003's entitlement list: **exactly 5 of Bas's 25 models** carry a long-context
tier at all (the same five above) — every other entitled model, including
all Claude variants, is "Default only."

**Side finding, out of scope here:** a data-residency compliance surcharge
(**+10% AI credits**) applies to requests on `info-support.ghe.com`-class
hosts, stacking with everything above — unverified whether additively or
multiplicatively, and whether it's blanket or only compliance-flagged
requests. Split into
[ticket 018](018-data-residency-surcharge.md) rather than resolved here,
since it's a uniform multiplier (doesn't corrupt model *ranking*, only
absolute credit estimates) and wasn't what this ticket was scoped to answer.
