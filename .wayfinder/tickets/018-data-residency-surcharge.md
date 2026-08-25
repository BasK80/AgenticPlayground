---
id: 018
title: Confirm the data-residency AI-credit surcharge and how it stacks
label: wayfinder:research
status: closed
assignee: Bas Kloet
blocked_by: []
---

## Question

Surfaced as a side finding while resolving
[Pin down the -fast variant pricing and the long-context tier threshold](014-fast-and-longcontext-pricing.md).
GitHub's data-residency reference page states that requests processed under
its compliance enforcement carry "a 10% increase on AI credits consumption."
Bas is on a data-residency host (`info-support.ghe.com`), so this may apply to
some or all of his Copilot usage — see
[the pricing asset](../assets/014-fast-and-longcontext-pricing.md#side-finding-out-of-scope-noted-for-later-data-residency-surcharge)
for the exact quote and source.

Two things are unverified:

1. **Scope** — does the +10% apply to *every* request on this host, or only to
   requests GitHub specifically flags as "compliance-enforced"? If the latter,
   what makes a request compliance-enforced, and is that Bas's normal usage?
2. **How it stacks** — additively or multiplicatively with the `-fast` 2x
   surcharge (ticket 014) and the long-context 2x tier (ticket 014)? E.g. for a
   long-context `gpt-5.4` request, is the total 2.0x, 2.1x, or 2.2x the base
   rate?

## Why it's split out rather than folded into ticket 014

It's a **uniform multiplier** (if it applies at all, it applies the same way
regardless of which model is chosen), so it doesn't corrupt the router's
model-to-model *ranking* the way the `-fast` and long-context gaps would have
— it only affects the absolute credit estimate the skill reports. Lower
priority than ticket 014 was, but still needed before `pick-model`'s credit
estimates can be called accurate rather than approximate.

## Notes

- Primary source so far:
  [GitHub Copilot with data residency](https://docs.github.com/en/enterprise-cloud@latest/admin/data-residency/github-copilot-with-data-residency).
  Re-read it closely for scope language, and check whether a linked
  compliance/data-residency admin doc defines "compliance-enforced request."
- Do not state a stacking formula from memory — this is the same class of
  fast-moving pricing policy ticket 014 already found changed unexpectedly.
- If genuinely unpublished, an empirical route may exist: compare a real usage
  report's billed credits against the base-rate prediction for a known
  request, on this host vs. (if accessible) a non-data-residency host.

## Resolution (2026-08-25)

Both questions have a clear mechanism answer from the docs (re-read closely,
verbatim, on
[GitHub Copilot with data residency](https://docs.github.com/en/enterprise-cloud@latest/admin/data-residency/github-copilot-with-data-residency)).
**Whether it's actually active for Bas is a separate, genuinely unresolved
question — recorded as such rather than guessed.**

**1. Scope — it's an independently-toggled policy, not automatic from being
on a data-residency host.** The surcharge is tied to one specific setting:
**"Restrict Copilot to data residency compliant models,"** under Policy
controls → Features in the enterprise's Copilot policies. Quoted directly:
*"This policy is disabled by default, and enabling it will affect your
pricing for Copilot requests."* So merely being on `info-support.ghe.com` (a
data-residency-capable host) does **not** by itself mean every request is
surcharged — an enterprise admin has to explicitly turn this policy on.
*Confidence: high — directly quoted, not inferred.* The docs do **not**
state what happens on the *other* side (data residency configured, but this
specific Copilot policy left off) — so the relationship between "enterprise
has data residency: EU configured" and "this Copilot policy is on" is not
spelled out either way. Bas confirmed he can see "data residency: EU" on his
enterprise page, but that is the general enterprise-level data-residency
setting, **not** confirmation of this specific Copilot-only policy — the two
are documented as independently togglable, so one being on doesn't prove the
other is. **Whether the policy is actually enabled for Bas's enterprise
remains unknown** — he's a regular member and can't see that admin-only
policy toggle directly, and resolving it further would need either an
enterprise-admin answer or an empirical credit-usage comparison (his own
usage report, per [ticket 015](015-seat-type-and-credit-balance.md)'s
finding that he can see his own usage), neither of which was done in this
session.

**2. Stacking — multiplicative, on top of the fully-tiered per-request
cost, confirmed by the docs' own worked example.** Quoted directly: *"if an
interaction would normally consume 100 AI credits, the same interaction
processed with this enforcement enabled consumes 110 AI credits."* The
"100 AI credits" in that example is *already* whatever the request's tiered
cost is (base rate, or 2x fast-mode, or 2x long-context, whichever applied) —
the surcharge multiplies the final number by 1.10, it does not add a flat
10-percentage-point additive term to the base rate independently. So for a
`gpt-5.4` long-context request under this policy: `2.0x (long-context) ×
1.10 (residency) = 2.2x` the default rate — not `2.0x + 0.10 = 2.1x`.
*Confidence: high — read directly from the docs' own numeric example, not
inferred from prose.* The docs say nothing about interaction with the
`-fast` surcharge specifically, but the same "final cost × 1.10" reading
applies by the same logic.

**For `pick-model`:** treat the data-residency surcharge as an **unresolved
±10% uncertainty band** on absolute credit estimates for Bas's account
specifically — not a confirmed multiplier to bake in, and not something to
ignore either. Ranking between models is unaffected either way (it's
uniform), which is why this was split from ticket 014 in the first place.
