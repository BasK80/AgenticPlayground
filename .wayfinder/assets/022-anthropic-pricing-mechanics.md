# Anthropic Claude-for-Work pricing and quota mechanics

Captured **2026-08-31**. Asset of
[Research Anthropic Claude-for-Work per-model pricing and quota mechanics](../tickets/022-anthropic-pricing-mechanics.md).

## Headline

Ticket 021's guess was directionally right but the mechanism is not what it
implied. There is **no Copilot-style premium-multiplier table** on the
Anthropic side. Instead there are **two layered quota systems** for a
seat-based Enterprise account like Bas's:

1. A **base rolling-window usage pool** (the same mechanism Pro/Max users get:
   5-hour session + weekly limits), which Anthropic's own docs say is spent
   **unevenly by model** ("Opus uses meaningfully more of your quota... Haiku
   is the fastest and cheapest option") but **never gives the weighting
   numbers** — it is deliberately opaque, token/message-based, not
   dollar-denominated.
2. An **optional "usage credits" overage layer**, switched on per-organization
   by an Owner/Primary Owner, that activates **only after** the base pool
   (1) is exhausted and then bills every subsequent token at Anthropic's
   **fully published, standard per-model API rates** — the same table at
   `platform.claude.com/docs/en/about-claude/pricing` used for direct API
   billing — with a **hard stop** at whatever dollar spend limit the org set,
   resetting monthly.

Bas's "$118 of $150" (ticket 021) is almost certainly (2) — a dollar figure
only exists there — but this research did not directly observe Bas's own
Settings → Usage screen, so which of the two systems he is actually looking at
is a **medium-confidence inference**, not a re-confirmed fact. Recommend Bas
check whether the $150 figure sits under a "usage credits" heading or a
"plan limit" heading in `claude.ai` → Settings → Usage.

Where a number is needed, **the standard per-model API pricing table is the
right one to use**, and it maps onto the existing `costPerMTokUSD` schema
**without any change** — see "Schema fit" below. Long-context and
reasoning-effort billing are directly documented by Anthropic (not inferred by
analogy, unlike the Copilot `-fast` gap in asset 014). Programmatic balance
reading, however, is **worse** than Copilot's: every API that reports spend
requires an Admin API key or an Analytics API key, both restricted to
org admins / the primary owner. No regular-member endpoint analogous to
Copilot's undocumented `copilot_internal/user` was found.

## Q1 — Does the quota bill per-model, or is it a flat draw?

**Documented, high confidence, for the usage-credits overage layer:** once
usage credits activate, "Usage credits are billed at standard API pricing
rates" — i.e., per-model, per the published table (see Q2). Source:
[Manage usage credits for Team and seat-based Enterprise plans](https://support.claude.com/en/articles/12005970-manage-usage-credits-for-team-and-seat-based-enterprise-plans).

**Documented, medium confidence (qualitative only), for the base rolling-window
pool:** Anthropic's own Claude Code doc states model choice "materially
affects consumption" — Opus "uses meaningfully more of your quota," Sonnet is
"the default, cost-efficient baseline," Haiku is "the fastest and cheapest
option." No numeric weighting is published anywhere that was found. Source:
[Models, usage, and limits in Claude Code](https://support.claude.com/en/articles/14552983-models-usage-and-limits-in-claude-code).

**Not a flat draw either way.** The "flat regardless of model" hypothesis from
ticket 021 is not supported by any source found.

## Q2 — What are the per-model rates, and do they fit `costPerMTokUSD`?

**Documented, high confidence** — full table from
`platform.claude.com/docs/en/about-claude/pricing`, fetched directly
2026-08-31:

| Model | Base input | 5m cache write | 1h cache write | Cache hit (read) | Output |
| --- | --- | --- | --- | --- | --- |
| Claude Fable 5 | $10 | $12.50 | $20 | $1 | $50 |
| Claude Mythos 5 (limited availability) | $10 | $12.50 | $20 | $1 | $50 |
| Claude Opus 5 | $5 | $6.25 | $10 | $0.50 | $25 |
| Claude Opus 4.8 / 4.7 / 4.6 / 4.5 | $5 | $6.25 | $10 | $0.50 | $25 |
| Claude Sonnet 5 | $2 | $2.50 | $4 | $0.20 | $10 |
| Claude Sonnet 4.6 / 4.5 | $3 | $3.75 | $6 | $0.30 | $15 |
| Claude Haiku 4.5 | $1 | $1.25 | $2 | $0.10 | $5 |

All prices per MTok. Sonnet 5's $2/$10 was introductory pricing through
2026-08-31 and is now confirmed **permanent** — the scheduled bump to $3/$15
on 2026-09-01 was cancelled (a note on the pricing page dated this capture).

**Cross-check, high confidence:** these numbers match `models.json`'s existing
`github-copilot/claude-sonnet-5` (2/10/0.2/2.5) and `github-copilot/claude-opus-5`
(5/25/0.5/6.25) entries **exactly**. GitHub's Copilot pricing for these two
models is a straight pass-through of Anthropic's own direct API rates — a
second, independent confirmation that the `costPerMTokUSD` field shape
(`input`, `output`, `cacheRead`, `cacheWrite`) is the right shape here too.

### Schema fit: yes, no new schema needed

`costPerMTokUSD: { input, output, cacheRead, cacheWrite }` maps 1:1 onto
Anthropic's own table:

- `input` → Base Input Tokens
- `output` → Output Tokens
- `cacheRead` → Cache Hits & Refreshes (0.1x input, universal — see Q4)
- `cacheWrite` → 5-minute Cache Writes (1.25x input) — the more common of the
  two cache-write durations; the 1-hour variant (2x input) would need a
  second field if ever modeled, analogous to how Copilot's long-context tier
  needed a sibling block rather than overloading `costPerMTokUSD`.

**What does *not* fit this schema:** the base rolling-window pool's per-model
weighting (Q1) has no published numbers, so it cannot be entered as a rate at
all — only the usage-credits overage layer has a rate to enter, and only once
that layer is actually active for the account.

## Q3 — Is there a programmatic way to read the balance?

**Documented, high confidence: no route accessible to a regular member/seat
exists.** Every API that reports usage or cost requires an elevated
credential:

| API | Endpoint | Credential | Who can create the credential |
| --- | --- | --- | --- |
| Usage & Cost Admin API | `GET /v1/organizations/usage_report/messages`, `GET /v1/organizations/cost_report` | Admin API key (`sk-ant-admin01-...`) or OAuth `org:admin` scope | Organization admin |
| Claude Code Analytics API | `GET /v1/organizations/usage_report/claude_code` | Admin API key | Organization admin |
| Claude Enterprise Analytics API | `GET /v1/organizations/analytics/...` | Analytics API key | **Primary owner only** |

The Claude Enterprise Analytics API's cost/usage endpoints carry an explicit
caveat that matters for Bas's exact situation: **"for seat-based Enterprise
plans, they reflect usage credits only"** — i.e., even an admin calling this
API on a seat-based plan (Bas's shape) sees the usage-credits overage number,
not the base rolling-window pool's consumption. Source:
[Analytics APIs](https://platform.claude.com/docs/en/manage-claude/analytics-api).

**The one self-serve, no-special-role channel** is the same shape as
Copilot's web-UI fallback (ticket 019): `claude.ai` → Settings → Usage shows
progress bars for the 5-hour/weekly rolling limits and, separately, "how much
of your plan's limit you've used" for usage credits on Pro/Max/Team/seat-based
Enterprise plans. Source:
[Usage limit best practices](https://support.claude.com/en/articles/9797557-usage-limit-best-practices).
No API backs this UI that a regular member can call directly — unlike
Copilot, where the undocumented `copilot_internal/user` endpoint turned out to
need no special role. **No Anthropic analogue to that undocumented endpoint
was found**; this was not tested by intercepting the claude.ai web app's own
network calls (out of scope for a docs-only pass, and the kind of live probe
ticket 019 flagged as worth doing only deliberately).

**The `/cost` command exists in Claude Code but does not apply to Bas.** It
"shows your running spend for the current session" but is documented as
**API-key-only** — Enterprise-seat sign-in draws from the prepaid pool instead
and does not get a live dollar readout from `/cost`. Source:
[Models, usage, and limits in Claude Code](https://support.claude.com/en/articles/14552983-models-usage-and-limits-in-claude-code).

## Q4 — Long-context tiering and prompt-caching treatment

### Long context: no surcharge (direct contrast with Copilot)

**Documented, high confidence, directly stated — not inferred.** For Claude
4.6 and later models (and Claude Mythos Preview): "the full 1M token context
window \[is included] at standard pricing. (A 900k-token request is billed at
the same per-token rate as a 9k-token request.)" Source:
[Pricing → Long context pricing](https://platform.claude.com/docs/en/about-claude/pricing#long-context-pricing).

This is a genuine, sourced **contrast** with Copilot: asset 014 found GitHub
applies a documented 2x long-context multiplier past a 200K/272K-token
threshold for five of its models. Anthropic's current-generation Claude models
have **no equivalent tier at all** — this is Anthropic's own docs stating the
opposite explicitly, not a gap in documentation.

### Prompt caching: the same ~10x lever, fully specified

**Documented, high confidence.** Multipliers on base input price, universal
across every model:

| Cache operation | Multiplier | Duration |
| --- | --- | --- |
| 5-minute cache write | 1.25x | 5 minutes |
| 1-hour cache write | 2x | 1 hour |
| Cache read (hit) | **0.1x** | same as the write it reads |

A cache hit costs exactly 10% of standard input — the same ~10x lever asset
013 found for Copilot, but here it is Anthropic's own first-party number, not
a pass-through GitHub happened to preserve. These multipliers **stack** with
the Batch API discount (50% off both directions) and the data-residency
multiplier (see below). Source:
[Pricing → Prompt caching](https://platform.claude.com/docs/en/about-claude/pricing#prompt-caching).

### Fast mode: documented, but gated and narrow — not a routing lever yet

**Documented, high confidence, on scope; unknown whether it applies to Bas.**
Fast mode is 2x standard rates ($10/$50 vs $5/$25) and exists **only** for
Claude Opus 5 and Claude Opus 4.8; Opus 4.7 errors if asked for it, Opus 4.6
silently falls back to standard speed and standard billing. It requires the
`fast-mode-2026-02-01` beta header and is explicitly a **research preview**
gated behind an account manager or a waitlist — "Contact your account manager
to request access." It applies across the full context window (no
long-context carve-out) and stacks with caching and data-residency
multipliers. Source:
[Fast mode](https://platform.claude.com/docs/en/build-with-claude/fast-mode).

**Unknown:** whether Bas's org has fast-mode access, and whether Claude Code
itself exposes a way to set `speed: "fast"` — the Claude Code model-selection
doc (`/model`, `--model`, `$ANTHROPIC_MODEL`) makes no mention of a speed
control, and this beta header is documented only for direct Messages API
calls. Treat fast mode as **not actuable from inside Claude Code today**
absent further evidence.

### Reasoning-effort variants: not free, billed as output — directly confirmed

**Documented, high confidence, directly stated — not inferred by analogy.**
"Thinking has a cost: the tokens Claude spends reasoning are billed as output
tokens, even when the thinking text isn't returned to you, and they count
toward `max_tokens` alongside the response text." Source:
[Thinking](https://platform.claude.com/docs/en/build-with-claude/thinking).

This directly confirms, for Anthropic's own docs, what asset 013 only
inferred by analogy for Copilot. The `effort` parameter (`low` / `medium` /
`high` / `xhigh` / `max`) does not change the **per-token rate** — it changes
how many tokens get spent reasoning, tool-calling, and responding, which
changes the **bill**, not the price list. Claude Sonnet 5 and Claude Code both
default to `high`. Source:
[Effort](https://platform.claude.com/docs/en/build-with-claude/effort).

### Data residency: a documented multiplier, applicability to Bas unknown

**Documented, high confidence, on scope; unknown for Bas's org, by direct
analogy to asset 014's identical caveat for Copilot.** For Claude 4.6+ models,
setting `inference_geo: "us"` applies a **1.1x multiplier** on every token
category (input, output, cache write, cache read); global routing (default)
is standard price. Stacks with fast mode and caching. Source:
[Pricing → Data residency pricing](https://platform.claude.com/docs/en/about-claude/pricing#data-residency-pricing).
Whether Bas's org has pinned US-only inference was not checked — this is an
Anthropic-console admin setting, not something visible to a regular member,
mirroring the exact shape of the unresolved Copilot data-residency question in
asset 014.

## Traps to flag for whoever builds ticket 023's catalogue entries

1. **Two quotas, one dollar figure.** Don't assume `$150` is the base pool —
   it is very likely the usage-credits overage ceiling, which only activates
   after the (unpriced, per-model-weighted) base pool runs out. Ranking
   models by the published `$`/MTok table is only correct once Bas is in the
   overage layer; before that, the base pool's real per-model cost is
   unpublished.
2. **`/cost` does not work for Bas.** It is API-key-only; do not build any
   runtime enrichment around it for an Enterprise-seat account.
3. **No cheap balance read exists.** Unlike Copilot's `copilot_internal/user`,
   there is no undocumented low-privilege endpoint found here. Any balance
   enrichment has to be a **manual, self-reported number** (as ticket 021
   already treats it) — there is nothing to fetch.
4. **Long-context tiering does not carry over from the Copilot asset.**
   Current Claude models charge the same rate at 9K and 900K tokens. Do not
   port asset 013/014's long-context-tier logic onto Anthropic entries.
5. **Fast mode is not a live lever.** It exists on paper for two Opus models
   but is beta/waitlisted and not shown to be reachable from Claude Code.
   Don't add a `-fast` variant to the catalogue the way `claude-opus-4.8-fast`
   exists for Copilot unless Bas confirms he has access.

## Programmatic discoverability: worse than Copilot's, not better

- Pricing itself is **published documentation**, exactly as with Copilot —
  capture as a dated file, same as asset 013/014, and the map's invariant 7
  refresh obligation applies identically.
- **No balance-reading API is reachable without an Admin API key (org admin)
  or an Analytics API key (primary owner only).** A regular member/seat has
  **no API path at all** to their own remaining balance — this is a strictly
  worse position than Copilot's, where an undocumented endpoint required no
  special role.
- The only user-facing channel is the `claude.ai` Settings → Usage page,
  which — like Copilot's web UI — is not designed to be scraped
  programmatically and was not tested for a hidden backing endpoint in this
  pass.
- **Domain access during this research:** `docs.claude.com` (redirects to
  `platform.claude.com`), `support.claude.com`, `api.anthropic.com`, and
  `console.anthropic.com` (redirects to `platform.claude.com`) were all
  reachable. **`code.claude.com`, `claude.com`, and `www.anthropic.com` were
  blocked by the firewall (403 from the Squid proxy — allowlist layer, not
  DNS/network)** for the duration of this research. This matters because
  Claude Code's own dedicated docs site (`docs.claude.com/en/docs/claude-code/*`
  redirects to `code.claude.com`) was **not reachable** — anything Claude-Code
  -specific that lives only there (e.g. the OpenTelemetry monitoring guide,
  IAM docs) had to be worked around via `support.claude.com` help-center
  articles instead, which is why this asset leans on support articles for
  Claude-Code-specific claims rather than the primary docs site.

## Sources

- [Pricing](https://platform.claude.com/docs/en/about-claude/pricing) —
  primary source for the per-model rate table, prompt caching, fast mode,
  data residency, long-context, and batch pricing. Fetched directly,
  2026-08-31 (redirected from `docs.claude.com/en/docs/about-claude/pricing`).
- [Prompt caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)
  — confirms the 1.25x/2x/0.1x multipliers with a worked example.
- [Fast mode](https://platform.claude.com/docs/en/build-with-claude/fast-mode)
  — full mechanics, supported models, beta-gate language, rate limits.
- [Thinking](https://platform.claude.com/docs/en/build-with-claude/thinking)
  — direct quote confirming reasoning tokens bill as output tokens.
- [Effort](https://platform.claude.com/docs/en/build-with-claude/effort) —
  effort levels, per-model defaults and guidance, confirms effort changes
  spend not rate.
- [Usage and Cost API](https://platform.claude.com/docs/en/manage-claude/usage-cost-api)
  — Admin API key requirement, endpoint shapes, example requests.
- [Claude Code Analytics API](https://platform.claude.com/docs/en/manage-claude/claude-code-analytics-api)
  — per-user, per-model estimated-cost breakdown; Admin API key requirement;
  full response schema quoted above.
- [Analytics APIs](https://platform.claude.com/docs/en/manage-claude/analytics-api)
  — the two-API split (Admin API key vs. primary-owner-only Analytics API
  key), and the "seat-based plans see usage credits only" caveat.
- [Manage usage credits for Team and seat-based Enterprise plans](https://support.claude.com/en/articles/12005970-manage-usage-credits-for-team-and-seat-based-enterprise-plans)
  — usage credits bill at standard API rates; hard stop; activation only
  after the seat's base usage limit is reached; monthly billing period.
- [Claude Enterprise consumption guide](https://support.claude.com/en/articles/14782391-claude-enterprise-consumption-guide)
  — qualitative per-model consumption intensity (Fable "very high," Opus
  "high," Sonnet "moderate," Haiku "low"); org/group/user spend-limit levels;
  Settings → Usage and claude.ai/analytics as the human-facing views.
- [Manage groups and group spend limits on Enterprise plans](https://support.claude.com/en/articles/13799932-manage-groups-and-group-spend-limits-on-enterprise-plans)
  — dollar-amount spend limits, admin-only visibility ("Billing: Can manage"),
  hierarchical group/individual override rules.
- [Models, usage, and limits in Claude Code](https://support.claude.com/en/articles/14552983-models-usage-and-limits-in-claude-code)
  — Enterprise-seat vs. API-key vs. Pro/Max metering distinction; the `/cost`
  command being API-key-only; qualitative per-model quota consumption.
- [Use Claude Code with your Pro or Max plan](https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-or-max-plan)
  — Pro/Max included-usage vs. opt-in API-credit overage, distinct from the
  Team/Enterprise usage-credits mechanism.
- [Claude Code usage analytics](https://support.claude.com/en/articles/12157520-claude-code-usage-analytics)
  — confirms the org-facing analytics dashboard has no per-model cost
  breakdown and no programmatic access of its own (separate from the Admin
  API above).
- [Usage limit best practices](https://support.claude.com/en/articles/9797557-usage-limit-best-practices)
  — Settings → Usage progress bars as the one self-serve, no-special-role
  balance view.
- [Claude Code model configuration](https://support.claude.com/en/articles/11940350-claude-code-model-configuration)
  — `/model`, `--model`, `$ANTHROPIC_MODEL` selection mechanics; confirms no
  billing information is documented on this page.

**Domains blocked during this capture (403 from the firewall's Squid proxy,
allowlist layer):** `code.claude.com`, `claude.com`, `www.anthropic.com`. If
any future refresh needs Claude Code's own dedicated docs site or the
marketing pricing page, these will need allowlisting first — see
`.wayfinder/map.md`'s network-environment guidance and `CLAUDE.md`.

**Capture date: 2026-08-31.** Re-fetch before trusting these numbers more than
a few weeks stale — Anthropic revised Sonnet 5's pricing note the same week
this was captured (see the introductory-pricing note above), so this table
moves.
