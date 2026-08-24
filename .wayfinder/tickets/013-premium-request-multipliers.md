---
id: 013
title: Determine the premium-request multiplier for each available Copilot model
label: wayfinder:research
status: closed
assignee: Bas Kloet
blocked_by: []
---

## RESOLUTION (2026-08-24) — closed

**The premise of this ticket was wrong: premium-request multipliers do not apply
to Bas.** GitHub replaced request-based billing with **usage-based billing on
1 June 2026**. Multipliers survive only as legacy billing for Pro/Pro+ subscribers
on an existing *annual* plan; Bas is on Enterprise Cloud with Business/Enterprise
seats. Full detail, tables and sources:
[What Copilot actually costs Bas — GitHub AI Credits](../assets/013-copilot-credit-costs.md).

**His currency is GitHub AI Credits, and they are token-denominated.**
1 credit = $0.01. Business = **1,900 credits/user/month**, Enterprise = **3,900**,
pooled across the enterprise; overage is billed, not cut off. Code completions and
next-edit suggestions are unbilled.

**Consequence — this reverses ticket 003's conclusion.** Ticket 003 recorded that
the metadata `cost` field was "the wrong currency". It is in fact the **right**
one: all 25 models' `cost.input`/`cost.output` were cross-checked against
GitHub's published per-1M-token rates and **all 25 matched exactly**. So the
router can rank by credit burn from cached, offline metadata. Ticket 003's
resolution has been annotated with this correction.

**Three traps that survive** (details in the asset):

1. **`-fast` variants are under-priced 2×** — docs list Opus 4.8 fast mode at
   $10/$50, but metadata reports 5/25 for all three `-fast` models.
2. **Long-context tiers cost up to 2×** and the metadata shows only the default
   tier; the token threshold that trips it is **unpublished**.
3. **Cached input is 10× cheaper** — a bigger lever than model choice on
   input-heavy work. Favour session continuity.

Traps 1 and 2 are split into
[Pin down the -fast variant pricing and the long-context tier threshold](014-fast-and-longcontext-pricing.md),
which now blocks [Write the pick-model skill](011-write-pick-model.md).

**Requirement 1 (0× models): there are none.** Every model carries per-token
charges. This kills the possibility, flagged at the end of the previous session,
that a free model could displace the local tier.

**Requirement 2 (allowance): answered** for the plan tiers, but Bas's own seat
type and the pool balance are open — split into
[Establish Bas's seat type and how to read the remaining AI credit pool](015-seat-type-and-credit-balance.md),
deliberately **not** blocking the router since budget display is degradable.

**Requirement 3 (programmatic discoverability): no.** Pricing is published
documentation, not an API. `GET api.info-support.ghe.com/copilot_internal/v2/token`
returns **404** on this data-residency host, so the editor-client route to an
authenticated `/models` is unavailable. Capture pricing as a dated, refreshable
data file per map invariant 7. Note `docs.github.com` was **firewall-blocked** and
Bas allowlisted it mid-session — refresh paths depend on it staying allowed.

**Requirement 4 (do effort variants cost more): yes.** Under token billing,
reasoning tokens bill as output tokens, so higher effort costs strictly more.
This **inverts** the note left on ticket 005 that effort might be a free lever.

**Strategic finding for the routing policy.** Credit pressure is concentrated in
expensive-model agentic coding, not doc work: a doc turn on `gpt-5.6-luna` costs
~3 credits, so a Business allowance covers ~600/month. The spread between
cheapest and dearest model is ~23×. **The credits argument for routing doc work
locally is therefore much weaker than assumed at charting time** — cheap cloud is
competitive with free-but-slow local and far more capable. Local's remaining
justification is **offline capability** (untouched) plus zero marginal cost once
the pool is drained. Recorded for Bas to decide on
[Define the open task taxonomy and its routing table](005-task-taxonomy.md).

---

## Question

What does each of the 25 available Copilot models actually **cost in premium
requests**, and can that multiplier be discovered programmatically?

## Why this exists

Surfaced by
[Discover which models GHE Copilot actually offers this account](003-discover-copilot-models.md).
Preserving Copilot credits is one of the two drivers of this whole map — and the
model metadata `opencode models` returns **does not contain the credit cost**.

Its `cost.input` / `cost.output` fields are models.dev **list prices in $/Mtok**.
GHE Copilot does not bill Bas per token; it bills **premium requests**, each model
carrying a multiplier. Routing on the `cost` field would optimise a currency Bas
never spends — and could easily pick a model that looks 25× cheaper per token
while costing the same or more in premium requests.

This is the difference between the skill saving credits and merely appearing to.

## Resolve specifically

1. The multiplier per model for the 25 in
   [the entitlement asset](../assets/003-copilot-entitlement.md). Include any
   that are **0×** (unlimited/base) — those are the single most valuable routing
   targets in the whole system, because they make cloud free at the point of use
   and would partly displace the local tier.
2. Whether Bas's plan has a **monthly premium-request allowance**, what it is,
   and how much is left — i.e. whether the skill can show a budget rather than
   just a relative cost.
3. **Is it discoverable programmatically?** Candidates to check:
   - the Copilot API at `https://copilot-api.info-support.ghe.com/v1` — does a
     `/models` response carry billing metadata that opencode discards?
   - GitHub's Copilot usage/billing REST endpoints for the enterprise
   - the enterprise Copilot settings UI (human-read fallback)
   If no programmatic route exists, say so plainly and record the multipliers as
   a dated, refreshable data file — **with the date visible**, since a
   hardcoded-and-forgotten table is exactly what map invariant 7 forbids.
4. Whether reasoning-effort `variants` (`low`…`max`, some with explicit
   `thinking.budgetTokens`) change the premium cost, or only latency and quality.
   If effort is free, it is a large lever the router should use aggressively.

## Notes

- `.githubcopilot.com` and `.ghe.com` are allowlisted; the token-exchange and
  models endpoints were verified reachable while resolving ticket 003. Both
  `copilot login --host https://info-support.ghe.com` and
  `opencode providers login -p github-copilot` are complete, so authenticated
  calls are possible now.
- Do **not** state multipliers from memory — this is per-plan, per-enterprise,
  and changes. Read a real source and cite it.
