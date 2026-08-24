---
id: 005
title: Define the open task taxonomy and its routing table
label: wayfinder:grilling
status: closed
assignee: Bas Kloet
blocked_by: []
---

## RESOLUTION (2026-08-24) — closed

Full specification: [Task taxonomy and routing policy](../assets/005-taxonomy-and-routing.md).
It is what [Write the pick-model skill](011-write-pick-model.md) implements.

**The charting-time three-tier policy is replaced. Local is offline-only; cloud is
the default for every task type.** The credit lever is *which cloud model*, not
local-vs-cloud — routing doc work locally saves ~3 credits, routing a refactor
from Opus to Sonnet saves 45. Local's justification is **offline capability**
(a stated driver, untouched) plus zero marginal cost once the pool drains.

**Five axes, inferred and displayed — never asked.** Selection: reasoning depth,
agentic depth, **stakes** (added during grilling; without it the router can never
justify the expensive model). Cost + local feasibility: input size — *which is the
context length, one number not two* — and expected output size, which is
first-class because output costs 5–12× input. Local fit uses input + output, since
KV cache grows during generation. No latency axis.

**Five starting types:** `quick`, `doc-edit`, `doc-author`, `doc-review`,
`code-agentic`. Docs split three ways because they sit at opposite corners of the
cost axes. `quick`/`doc-edit` kept separate so the future benchmark can test the
difference. `code-agentic` left broad on purpose. **Taxonomy is open** — new types
appended as met, no skill-prose change.

**Matching: exemplars first, axis inference only for novel work** — because the
skill's own reasoning is not free (it spends tokens in the active session). Axis-
only matching was rejected: inference *is* the expensive step, so the cache would
buy nothing. Consequence: the taxonomy gets cheaper the longer it is used.
Spanning tasks → **more demanding type wins**.

**Consent gate now protects credits, not patience** (the spill-local gate has no
job since offline is a branch, not a decision). Per-type, remembered, threshold as
**% of monthly allowance**, **inform-only — never blocks**, and re-asks when an
estimate greatly exceeds the consented level. Allowance is a cached fact with a
refresh path.

**Escalation only on Bas's word — never automatic**, since a model judging its own
failure is what LLMs are worst at. Failures recorded per type; **two-to-three
shift the floor**. Note the double-pay trap largely evaporated with local demoted:
a failed cheap-cloud attempt is ~10% overhead, not 100%. The real cost of a failed
attempt is Bas's reading time, not the credits.

**Every default ships as `assumed`** and says so. Converting to `measured` is the
benchmark skill's job — **out of scope for this map** (its own effort later);
schema slots for measured speed/quality folded into
[the data schema ticket](007-data-schema.md).

---

## Question

What are the **task types** `pick-model` routes on, what does each one demand of
a model, and which tier is each one's default?

The taxonomy must be **open** (map invariant 7): new task types get appended as
Bas meets them, without editing skill prose. So the real deliverable is two
things:

1. A **starting set** of task types with their tier defaults — enough to be
   useful on day one.
2. The **rule for classifying an unseen task**, and for minting a new type when
   nothing fits. This is the future-proofing half, and it matters more than the
   starting set.

## Known inputs

Bas's actual workload, from charting:

- **Agentic coding** — multi-file edits, refactors, long tool-call chains.
  Default: **cloud (GHE Copilot)**. Local 7–8B at Q4 loses track of multi-step
  edits and mangles tool schemas.
- **Markdown documentation** — writing and editing technical, functional and
  architectural docs. High volume. Long-context prose, almost no tool-calling —
  the workload local models handle *best*. Default: **fast local**. This is
  likely the single biggest credit saving available.
- **Mechanical / high-volume trivia** — commit messages, renames, file
  summaries, regex, quick lookups. Default: **fast local**.

## Resolve specifically

1. What discriminates a task type — required context length, tool-calling depth,
   reasoning depth, output length? These are the axes the classifier reasons over,
   so name them explicitly rather than relying on task labels.
2. Does documentation work split further? Drafting new prose, editing existing
   prose, and *reviewing for architectural consistency across many files* have
   very different context demands and may not share a tier.
3. What does a task type record look like — the fields that let a stored type be
   matched against a new task later.
4. Which types get the **spill-tier consent gate**, and what exactly is
   remembered when Bas consents once (see
   [Design the schema for hardware.json, model cache and remembered preferences](007-data-schema.md)).
5. The escalation path when a local attempt visibly fails — and how to avoid
   double-paying (local latency **plus** the cloud call **plus** Bas's time
   judging the failure). Bas accepted this risk knowingly; make the skill
   minimise it rather than ignore it.

## Constraints established by ticket 003 (read before deciding)

See [the entitlement asset](../assets/003-copilot-entitlement.md).

- **DO rank cloud models by the `cost` field** — corrected by
  [ticket 013](013-premium-request-multipliers.md). Copilot bills **tokens**
  (GitHub AI Credits, 1 = $0.01), not premium requests, and all 25 models' `cost`
  values match GitHub's published rates exactly. Three caveats: `-fast` variants
  are under-priced 2×, long-context tiers cost up to 2×, and **cached input is
  10× cheaper — a bigger lever than model choice** on input-heavy work, so favour
  session continuity. See
  [the credit-cost asset](../assets/013-copilot-credit-costs.md).
- **Reasoning-effort variants are NOT free** — reasoning bills as output tokens,
  so effort is a cost dial, not a free lever. (Corrects the note below.)
- **Reconsider the credits case for local.** Credit pressure sits in
  expensive-model agentic coding, not doc work: a doc turn on `gpt-5.6-luna` is
  ~3 credits and a Business allowance covers ~600/month. Cheap cloud is
  competitive with free-but-slow local and far more capable. **Local's solid
  justification is offline capability, not credits.** This is Bas's decision to
  make in this ticket — the charting-time assumption that doc work goes local to
  save credits no longer holds up on the numbers.
- **Above ~32k context there is no local option at all.** Both installed ollama
  models cap at 32k, while every cloud model starts at 200k and most reach 1M. So
  "no local candidate fits" is a **first-class routing outcome**, not an error —
  and for large-context doc review the fast/spill distinction is moot because
  neither tier can hold the input. Decide what the skill says in that case.
- **All 25 cloud models are tool-capable and reasoning-capable**, so neither is a
  discriminator on the cloud side — only on the local side.
- **Reasoning-effort `variants` (`minimal`…`max`) are a routing lever**, possibly
  a free one. A cheap model at high effort may beat an expensive one at low
  effort; ticket 013 establishes whether effort costs extra.

## Notes

- Use `/grilling`. This is a decision ticket — do not invent Bas's workload.
- Resist a large starting taxonomy. Three or four types that are *correct* beat
  a dozen guessed ones, because the open-taxonomy rule covers the rest.
