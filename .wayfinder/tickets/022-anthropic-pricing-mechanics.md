---
id: 022
title: Research Anthropic Claude-for-Work per-model pricing and quota mechanics
label: wayfinder:research
status: closed
assignee: Bas Kloet
blocked_by: []
---

## Question

Ticket 021 established that Bas's Anthropic access is an **enterprise-managed
usage quota** (dollar-denominated, currently $118 of $150 spent, hard stop) —
structurally like Copilot's credit pool, not a flat per-seat subscription. It
also guessed, without verifying, that different Claude models draw down that
quota at different rates (mirroring Copilot's premium-request-multiplier
pattern that ticket 013 found and corrected).

This ticket resolves the actual mechanics, mirroring what tickets 013/014 did
for Copilot:

- Does the org-managed Anthropic quota bill per-model at different effective
  rates, or is it a flat draw regardless of which Claude model is used?
- If per-model rates exist, what are they (ideally sourced from
  Anthropic/Claude-for-Work docs, not inferred), and do they map cleanly onto
  a `costPerMTokUSD`-shaped structure like the `github-copilot/*` entries use,
  or does the quota need a different schema (e.g. a flat per-message/session
  cost, or an org-specific negotiated rate not published anywhere)?
- Is there a programmatic way (API or config) to read the current balance —
  the "$118 of $150" figure — the way ticket 019 found `GET
  /copilot_internal/user` for Copilot, or is this manually tracked by
  Bas/his org?
- Any long-context or other tiering behavior analogous to Copilot's
  documented long-context 2x multiplier (ticket 014)?

Output: a markdown findings asset (per the `/research` skill's convention),
covering what's documented vs. inferred vs. unknown, with sources.

## Resolution

Researched 2026-08-31 against primary sources (`platform.claude.com`,
`support.claude.com`, `api.anthropic.com`, `console.anthropic.com` —
`docs.claude.com` and `support.claude.com` were newly allowlisted for this
ticket). Full findings:
[Anthropic Claude-for-Work pricing and quota mechanics](../assets/022-anthropic-pricing-mechanics.md).

**No Copilot-style multiplier table exists.** Instead there are **two layered
quotas**: an opaque, per-model-weighted rolling-window pool (Anthropic states
Opus draws "meaningfully more" than Sonnet/Haiku but publishes no numbers),
and an optional dollar-denominated "usage credits" overage layer that
activates only once the base pool is exhausted and then bills at Anthropic's
fully-published standard per-model API rates (Sonnet 5 $2/$10, Opus 5 $5/$25,
Haiku 4.5 $1/$5 per MTok) — a hard stop, resetting monthly. Bas's "$118 of
$150" is almost certainly this overage layer (a dollar figure only exists
there), though this was not directly confirmed against his own Settings →
Usage screen.

That published table maps onto `models.json`'s existing `costPerMTokUSD`
schema (`input`/`output`/`cacheRead`/`cacheWrite`) with **no schema change
needed** — cross-checked exactly against the `github-copilot/claude-sonnet-5`
and `claude-opus-5` entries already in the file. What does *not* fit: the base
pool's per-model weighting has no published numbers at all, so it can't be
entered as a rate until/unless Anthropic publishes one.

Contrasts with the Copilot findings (tickets 013/014): **no long-context
surcharge** on current Claude models (directly stated — the full 1M context
window bills at standard rate); prompt caching gets the identical ~10x lever
(0.1x for cache reads, universal); reasoning/thinking tokens are explicitly
billed as output tokens (confirmed by Anthropic's own docs, not inferred by
analogy as asset 013 had to for Copilot); a beta "fast mode" exists on paper
for two Opus models only, gated behind an account manager/waitlist, with no
evidence it's reachable from inside Claude Code — treat as not actuable.

**Balance-reading is worse than Copilot's, not better.** Every usage/cost API
(Admin API, Claude Code Analytics API, Enterprise Analytics API) requires an
org-admin or primary-owner credential. No low-privilege analogue to Copilot's
undocumented `copilot_internal/user` was found. The Enterprise Analytics API
also has a caveat specific to Bas's seat-based plan shape: even an admin
calling it sees only the usage-credits number, not the base pool. `/cost` is
documented as API-key-only and does not work for an Enterprise-seat sign-in.
The only self-serve view is `claude.ai` → Settings → Usage progress bars —
same shape as Copilot's web-UI fallback, but with no backing API found.

**Unblocks** [Add Anthropic entries to pick-model's models.json and cost reasoning](../tickets/023-add-anthropic-entries-to-pick-model.md),
which should treat the balance as a manual, self-reported number (no fetch
path exists) and flag the two-quota ambiguity rather than assuming the
published rate table prices *all* of Bas's usage.
