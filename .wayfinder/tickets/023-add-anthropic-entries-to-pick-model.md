---
id: 023
title: Add Anthropic entries to pick-model's models.json and cost reasoning
label: wayfinder:task
status: closed
assignee: Bas Kloet
blocked_by: [022]
---

## Question

Implement ticket 021's decision: add Anthropic/Claude entries to
`models.json`, owned and refreshed by `pick-model` (not `ollama-curate`),
using the pricing/quota mechanics ticket 022 establishes. Wire pick-model's
cost-reasoning and consent-gate logic (the pattern ticket 019 built for
Copilot) to also cover Anthropic when running under Claude Code, including
whatever balance-reporting ticket 022 finds is possible.

## Resolution

Built and verified live 2026-08-31 (this map's Notes override plan-only for
`task` tickets).

**`models.json`:** added three `anthropic/*` entries — `claude-sonnet-5`
($2/$10), `claude-opus-5` ($5/$25), `claude-haiku-4-5-20251001` ($1/$5),
cross-checked exactly against ticket 022's published table (and, for
sonnet/opus, against the existing `github-copilot/*` mirrors). Deliberately
**left out** Claude Fable 5 and Claude Mythos 5 — "limited availability,"
entitlement for this Enterprise seat unchecked — add only if confirmed
selectable. New top-level `anthropicPricingMechanics` block mirrors
`githubCopilotPricingCorrections`'s shape but encodes ticket 022's five traps
so they're never silently ported across providers: no long-context tier
exists at all (a direct contrast, not a gap), fast mode is documented but not
shown reachable from Claude Code, the data-residency ±10% band is unresolved
exactly like Copilot's, prompt caching is the same 10x lever, and the balance
is **not fetchable** by a regular member at any privilege level (worse than
Copilot's undocumented-but-reachable route).

**A design gap surfaced while wiring this, not just a data gap:** the
routing method had no concept of *which providers the current harness can
even reach* — it just ranked every `models.json` entry by cost regardless.
That's exactly what ticket 021 flagged (Claude Code recommending
`github-copilot`/`ollama` switches it has no way to carry out) and it would
have recurred in the other direction the moment `anthropic/*` entries
existed (opencode/Copilot CLI sessions "recommending" a model only Claude
Code can use). Fixed with a new REFERENCE.md § **Harness reachability**:
detect the current harness (`$CLAUDECODE == "1"`, live-verified against this
real session), filter candidates to its reachable provider(s) *before*
ranking by cost, and treat a task type's stored `defaults.online.modelKey`
as a hint that's ignored — not treated as a bug — when its provider isn't
reachable this session; the routing method computes fresh from the reachable
subset instead. No `preferences.json` schema change — the per-type stored
default stays single-valued and un-harness-aware, on purpose, to avoid
building a bigger schema than this ticket needed.

**Credit/consent wiring:** `REFERENCE.md` § Credit allowance and balance now
states plainly it's Copilot-specific, with a new "Anthropic — no fetchable
balance" subsection: never attempt a live fetch for an `anthropic/*` model,
treat any self-reported figure (e.g. "$118 of $150") as manual and
uncached, and never invent a credit-style unit Anthropic doesn't have. The
consent gate and pace-warning sections were both updated to state cost in
money alone for `anthropic/*`, with no balance and no parenthetical credit
count. `SKILL.md`'s checklist (steps 5–6) and "Must not" ownership bullet
were updated to match.

**Verified live, in this Claude Code session:** ran the actual `pick-model`
skill against a `quick`-type sample task. It correctly detected
`CLAUDECODE=1`, ignored the stored `github-copilot/gpt-5.6-luna` default as
unreachable, computed fresh from the three `anthropic/*` entries, picked the
cheapest (`claude-haiku-4-5-20251001`), skipped the consent gate (well under
$1) and the balance/pace checks (correctly, since none exists for
Anthropic), and printed a manual `/model` switch hint rather than attempting
opencode-only actuation. This is the real routing path, not a simulation.

**Two things this surfaced that are not resolved here, split out below:**
the harness-reachability table's opencode/Copilot CLI rows have no
live-verified positive detection signal yet (only Claude Code's `$CLAUDECODE`
was actually checked) — [ticket 024](024-verify-harness-detection-signals.md).
Azure Foundry-routed models (also switchable via `llm-switch.sh`, also a real
cost surface) are entirely unaddressed by `models.json` — too unscoped to
ticket yet, noted in the map's Not yet specified section instead.
