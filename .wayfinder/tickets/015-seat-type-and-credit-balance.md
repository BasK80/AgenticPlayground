---
id: 015
title: Establish Bas's seat type and how to read the remaining AI credit pool
label: wayfinder:task
status: open
assignee:
blocked_by: []
---

## ⚠ Re-scoped 2026-08-24 (from ticket 007)

This ticket originally bundled two questions of very different difficulty.
**Un-conflated:**

1. **Seat type / monthly allowance** (Business=1900, Enterprise=3900) — a
   near-constant Bas can simply state. **This is no longer this ticket's
   concern**: `pick-model` self-serves it directly into
   `hardware.json.creditAllowance` on first need, exactly like `ollama-curate`
   self-serves hardware specs. See
   [the data schema asset](../assets/007-data-schema.md). This is *why*
   [Write the pick-model skill](011-write-pick-model.md) is **not** blocked on
   this ticket.
2. **Reading the remaining live balance** — genuinely hard, may need admin
   rights Bas doesn't have. **This is what remains in scope here.**

## Question

**How is the remaining pool read** — the harder half, now the only thing this
ticket covers (seat type is self-served elsewhere, see above).

Credits are pooled at the billing-entity level across all licenses, so Bas's
personal usage is not the whole picture — the pool can be drained by colleagues.
Establish whether there is:
   - a REST endpoint for enterprise/org Copilot usage or billing that Bas has
     permission to call (he may not be an enterprise admin),
   - a per-user view he can always reach, or
   - only an admin-only settings page.

If only an admin page exists, say so plainly — the skill then ranks by relative
cost and cannot show remaining budget. That is an acceptable outcome; a wrong
budget number would be worse than none.

## Why it does not block the router

Ranking models by credit cost works without knowing the balance. Showing
remaining budget is a **degradable enhancement**, so
[Write the pick-model skill](011-write-pick-model.md) is deliberately *not*
blocked on this. Resolve it if it is cheap; skip it if it needs admin rights Bas
does not have.

## Notes

- Overage is **not** a service cutoff — usage beyond the pool is billed at $0.01
  per credit. So "out of credits" means "now costing real money", which is
  arguably a *more* important thing for the skill to surface than a hard limit.
- Context: [the credit-cost asset](../assets/013-copilot-credit-costs.md).
- Auth is already in place (see ticket 003); `gh` is authenticated for
  `info-support.ghe.com` via the Copilot CLI login.
