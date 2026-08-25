# `-fast` variant pricing and the long-context tier threshold

Captured **2026-08-25**. Asset of
[Pin down the -fast variant pricing and the long-context tier threshold](../tickets/014-fast-and-longcontext-pricing.md).
Builds on [What Copilot actually costs Bas](013-copilot-credit-costs.md).

Primary source for both questions: **"Models and pricing for GitHub Copilot"**
(Enterprise Cloud edition), fetched directly and cross-checked with a second,
independent fetch asking for verbatim table rows. Supplementary pages checked
and found silent on both questions (see Sources).

## Question 1 — the `-fast` variants: only Opus 4.8 has a published rate

The pricing table on the Enterprise Cloud models-and-pricing page lists, under
Anthropic, these Opus rows and **no others**:

| Row as it appears in the table | Input | Cached input | Cache write | Output |
| --- | --- | --- | --- | --- |
| Claude Opus 4.6 | $5.00 | $0.50 | $6.25 | $25.00 |
| Claude Opus 4.7 | $5.00 | $0.50 | $6.25 | $25.00 |
| Claude Opus 4.8 | $5.00 | $0.50 | $6.25 | $25.00 |
| **Claude Opus 4.8 (fast mode) (preview)** | **$10.00** | **$1.00** | **$12.50** | **$50.00** |

There is **no "Claude Opus 4.6 (fast mode)" row and no "Claude Opus 4.7 (fast
mode)" row anywhere on the page** — confirmed by two independent fetches
(one asking for the general table, one asking specifically to quote every row
containing "Opus 4.6", "Opus 4.7", "Opus 4.8" verbatim) and by a full
model-by-model dump of the entire pricing table, which lists Claude Opus 4.6
and 4.7 as "Default only," with the single fast-mode row attached exclusively
to 4.8.

The legacy request-based multiplier page (annual-plan legacy billing, not
Bas's billing model) also has no row labelled "fast mode" for any Opus
version — it only lists flat per-model multipliers (Opus 4.6 = 9x, Opus 4.7 =
4.8 = 27x on that legacy scale), which don't map cleanly onto the token-based
fast-mode surcharge and predate the fast-mode preview's naming.

A live GitHub Community discussion —
["Fast mode models (Opus 4.6/4.7/4.8) have no pricing entry under usage-based
billing — what are they billed
at?"](https://github.com/orgs/community/discussions/199271) — asks this exact
question. As of this capture it is **unanswered by GitHub staff**: the poster
confirms Anthropic's own API charges 2x for Opus fast mode generally, but no
GitHub-authoritative source confirms whether Copilot applies the same 2x to
the 4.6 and 4.7 fast variants specifically.

**Answer: only `claude-opus-4.8-fast` has an individually documented rate
($10.00 in / $1.00 cached-in / $12.50 cache-write / $50.00 out — exactly 2x
non-fast Opus).** `claude-opus-4.6-fast` and `claude-opus-4.7-fast` have **no
individually published rate anywhere in GitHub's current or legacy docs** as
of 2026-08-25.

*Confidence:* the 2x figure for `-4.8-fast` is directly stated in the docs.
The 2x figure for `-4.6-fast` and `-4.7-fast` is **not documented** — it
remains an inference by analogy only (same family, same "fast mode"
mechanism, and the only two doc'd data points — non-fast Opus and 4.8-fast —
sit at exactly 1x/2x). Treat any 2x override for 4.6-fast/4.7-fast in routing
code as an assumption, not a sourced fact, and flag it for re-check next time
the pricing page is refreshed.

## Question 2 — the long-context tier

### (a) Token thresholds, per model, as published

Fetched twice independently (once as a general table read, once asking
specifically to quote the "Tier" and "Threshold (input tokens)" columns
verbatim with surrounding footnote text). Both fetches returned matching
numbers:

| Model | Default in/out | Long-context in/out | **Published threshold** |
| --- | --- | --- | --- |
| `gpt-5.4` | $2.50 / $15.00 | $5.00 / $22.50 | **> 272K input tokens** |
| `gpt-5.5` | $5.00 / $30.00 | $10.00 / $45.00 | **> 272K input tokens** |
| `gpt-5.6-luna` | $0.20 / $1.20 | $0.40 / $1.80 | **> 200K input tokens** |
| `gpt-5.6-sol` | $2.00 / $10.00 | $4.00 / $15.00 | **> 272K input tokens** |
| `gpt-5.6-terra` | $2.00 / $12.00 | $4.00 / $18.00 | **> 272K input tokens** |
| Gemini 3.1 Pro (not entitled) | — | $4.00 / $18.00 | > 200K input tokens |
| Grok 4.5 (not entitled) | — | $4.00 / $12.00 | > 200K input tokens |
| Grok 4.6 (not entitled) | — | $4.00 / $12.00 | > 200K input tokens |

So the ticket's premise that the threshold is unpublished turned out to be
**wrong for the current doc revision** — the "Threshold (input tokens)"
column does carry an explicit number (`> 272K` or `> 200K`) per model. This is
a genuinely new finding relative to asset 013, which was written from the
model metadata (no threshold data) rather than a fresh doc read; the doc page
itself was not re-read closely enough at that time to notice the threshold
column.

*Confidence:* high — two independent fetches of the same page, one
specifically asked to quote the threshold column and footnotes verbatim,
returned the same numbers with no discrepancy. This is read directly off
GitHub's published pricing table, not inferred.

### (b) Automatic per-request, not a separate selectable variant — inferred from table structure, not stated in prose

The page does **not** contain an explicit sentence such as "the long-context
tier is applied automatically" — that mechanism is not spelled out in prose
anywhere on the page, nor on the two other billing pages checked (`Requests in
GitHub Copilot`, `About billing for GitHub Copilot in organizations and
enterprises`, `Usage-based billing for organizations and enterprises`).

What the table itself shows, though, is:

- The **model ID column is identical** for the Default row and the Long
  context row of the same model — e.g. "GPT-5.4" appears as the model name in
  both the Default row and the Long context row. There is no distinct model
  ID such as `gpt-5.4-long-context` in the picker or in the pricing table.
- The distinguishing column between the two rows is purely
  **"Threshold (input tokens)"** — a property of the request, not of a model
  selection.

Taken together, this is a strong structural signal that the tier is a
**property of the request's actual input-token count**, selected
automatically per call against a single model ID — not a separate model
variant a caller must opt into. But this is a **structural inference from the
table layout**, not a directly stated confirmation.

*Confidence:* medium. No page states the selection mechanism explicitly. The
inference rests on: (1) no second model ID exists for the long-context tier
of any of these five models in the current entitlement list (asset 003) or in
the pricing table, and (2) the tier's only distinguishing column is a token
count, not a name. An empirical check (send a >272K-token request to `gpt-5.4`
and confirm the long-context rate appears on the usage report, vs a <272K
request on the same model ID showing the default rate) would upgrade this from
medium to high confidence and is recorded as the fallback the ticket itself
suggested; it was not performed in this pass.

### (c) Which of Bas's 25 entitled models actually have a long-context tier — re-derived from the docs, not from asset 013

A full model-by-model dump of the entire pricing table (every Anthropic, OpenAI,
Google, Microsoft, xAI and Moonshot AI row) was requested and cross-checked
against the 25-model entitlement list in
[003-copilot-entitlement.md](003-copilot-entitlement.md). Models with a
**Long context** row in GitHub's table, across every vendor:

`gpt-5.4`, `gpt-5.5`, `gpt-5.6-luna`, `gpt-5.6-sol`, `gpt-5.6-terra`,
Gemini 3.1 Pro, Grok 4.5, Grok 4.6.

Cross-referenced against the entitlement list: **Gemini 3.1 Pro, Grok 4.5, and
Grok 4.6 are not in Bas's 25 entitled models** (confirmed already in asset
003's "11 catalogued models are not available here" list, which names
`gemini-3.1-pro-preview`, `grok-4.5`, `grok-4.6` explicitly). Every other
entitled model — all Claude models (haiku/sonnet/opus, including the fast
variants), `gpt-5-mini`, `gpt-5.3-codex`, `gpt-5.4-mini`, all three Gemini
Flash models, and both MAI-Code models — appears in the pricing table as
**"Default only," with no Long context row at all.**

**Answer: exactly five of Bas's 25 entitled models carry a long-context tier —
`gpt-5.4`, `gpt-5.5`, `gpt-5.6-luna`, `gpt-5.6-sol`, `gpt-5.6-terra`.** This
independently reconfirms (does not merely repeat) the list already used in
asset 013's traps table.

*Confidence:* high — read directly from a full-table dump of the docs, then
diffed against asset 003's already-sourced entitlement list, not assumed.

## Side finding (out of scope, noted for later): data-residency surcharge

The data-residency reference page
(`admin/data-residency/github-copilot-with-data-residency`) states that
requests processed under its compliance enforcement carry **"a 10% increase
on AI credits consumption."** Bas is on a data-residency host
(`info-support.ghe.com`). This wasn't asked for by this ticket and isn't
folded into the numbers above, but it's a real, docs-stated additional
multiplier on top of everything in this file and in asset 013, and should be
picked up by whichever future ticket reconciles the full credit-cost model.
*Confidence: directly quoted from the page; not verified whether it stacks
multiplicatively or additively with the long-context/fast-mode tiers, or
whether it applies to every request on this host or only specific
compliance-flagged ones.*

## Sources

- [Models and pricing for GitHub Copilot — Enterprise Cloud](https://docs.github.com/en/enterprise-cloud@latest/copilot/reference/copilot-billing/models-and-pricing)
  — primary source for both questions; fetched multiple times on 2026-08-25,
  including one pass requesting a verbatim quote of every Opus 4.6/4.7/4.8 row
  and every long-context row/footnote, and one pass requesting a complete
  model-by-model dump of the whole table.
- [Requests in GitHub Copilot](https://docs.github.com/en/copilot/concepts/billing/copilot-requests)
  — checked; no mention of fast mode or long-context tiers.
- [Model multipliers for annual plans on request-based billing (legacy)](https://docs.github.com/en/copilot/reference/copilot-billing/request-based-billing-legacy/model-multipliers-for-annual-plans)
  — checked; legacy multipliers only, no fast-mode-labelled rows, no
  long-context threshold.
- [About billing for GitHub Copilot in organizations and enterprises](https://docs.github.com/en/copilot/concepts/billing/organizations-and-enterprises)
  — checked; no mention of fast mode or long-context mechanism; links to the
  usage-based-billing page below.
- [Usage-based billing for organizations and enterprises](https://docs.github.com/en/copilot/concepts/billing/usage-based-billing-for-organizations-and-enterprises)
  — checked; confirms cost depends on "the model and the number of tokens
  consumed" but does not explain tier-selection mechanism.
- [GitHub Copilot with data residency](https://docs.github.com/en/enterprise-cloud@latest/admin/data-residency/github-copilot-with-data-residency)
  — checked for host-specific pricing notes; found the unrelated 10%
  data-residency surcharge noted above.
- [GitHub Community: "Fast mode models (Opus 4.6/4.7/4.8) have no pricing
  entry under usage-based billing — what are they billed
  at?"](https://github.com/orgs/community/discussions/199271) — not a GitHub
  doc page; cited only as corroboration that the 4.6-fast/4.7-fast pricing gap
  is real and, as of this capture, unresolved even by GitHub staff.
- [GitHub Community: "GitHub Copilot Claude Opus 4.7 pricing not
  correct"](https://github.com/orgs/community/discussions/192814) — same
  caveat; self-answered by the original poster, not GitHub staff; not used as
  a pricing source, only as context that the 4.7 pricing/multiplier gap is a
  known community pain point.

**Capture date: 2026-08-25.** This is dated pricing policy — GitHub's
token-billing model went live 1 June 2026 and has already changed once since
then (per asset 013). Re-fetch before trusting these numbers more than a few
weeks stale.
