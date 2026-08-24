---
id: 014
title: Pin down the -fast variant pricing and the long-context tier threshold
label: wayfinder:research
status: open
assignee:
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
