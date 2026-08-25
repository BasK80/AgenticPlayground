---
id: 018
title: Confirm the data-residency AI-credit surcharge and how it stacks
label: wayfinder:research
status: open
assignee:
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
