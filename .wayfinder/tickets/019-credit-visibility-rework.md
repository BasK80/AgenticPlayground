---
id: 019
title: Rework how pick-model establishes and communicates the credit picture
label: wayfinder:grilling
status: resolved
assignee: Bas Kloet
blocked_by: []
---

## Question

The credit story `pick-model` tells is incoherent. The *research* behind it is
sound — tickets 013, 014, 015, 018 and 012's live verification each hold up on
their own — but the skill's own instructions were never reconciled with what
those tickets found. The data got corrected; the prose that produces the data
did not.

This ticket is the grilling that decides what the skill should actually do.

## What the skill does today

| Step | Where | Behaviour |
| --- | --- | --- |
| 1 | `SKILL.md` checklist step 1 | If `creditAllowance.seatType` is `null`: ask **once** "Business or Enterprise?", cache, move on |
| 2 | `REFERENCE.md` § Seat type self-service | That question maps to **1,900** (Business) / **3,900** (Enterprise) credits/month |
| 3 | `REFERENCE.md` § Consent gate | Express cost as **% of `monthlyCredits`** ("~13% of your month"). Informs, never blocks |
| 4 | — | **Remaining balance appears nowhere in the runtime path.** Deliberately not cached, since it drains continuously |

## What the research established

- 1 credit = $0.01, token-denominated. Code completions are not billed.
- Every license feeds a **shared enterprise pool**. Overage bills at $0.01 per
  credit — it is **not a cutoff** (asset 013).
- Pool-level balance via REST requires administrator or billing-manager rights
  → unreachable as a regular member (ticket 015).
- The per-user endpoint exists in the docs but returned a **clean 404** on all
  three variants against this GHE Data Residency tenant — materially different
  from the explicit 403 `/user/orgs` returns, so the route appears simply not
  implemented there (ticket 012's live check).
- The **web UI does show your own recent consumption**, with no special role
  (ticket 015).
- The real figure here: **15,000 pooled**, not 3,900. ~10,000 consumed as of
  2026-08-25, so ~5,000 remaining.

## The fault lines to grill

**1. The skill asks the wrong question.** Step 1 and § Seat type self-service
still instruct "Business or Enterprise?" → 1,900/3,900. The note inside
`hardware.json` states outright that this mapping is wrong here and that
*"asking seat type alone isn't enough."* Only the **data** was corrected; the
**instruction** never was. Against a fresh `.model-picker/` the skill will
cache 3,900 again — off by a factor of 3.8. Ticket 012 flagged this explicitly
as "a genuine design gap worth flagging for whoever revisits `pick-model`" and
nobody revisited it.

**2. "% of your month" uses the wrong denominator.** It is a percentage of the
*total* monthly allowance, not of what remains. At 5,000 left of 15,000,
"~13% of your month" is really ~39% of what you still have. The signal gets
weaker as the month progresses — exactly backwards.

**3. Pooled is not personal.** The denominator is a pool colleagues also drain,
but it is presented as "your month."

**4. There is no refresh trigger on the number that matters.** *"Re-ask only if
the seat changed"* — but a pooled allowance changes when licenses are added or
removed, without your seat changing at all.

**5. Self-contradiction about the endpoint.** `REFERENCE.md` says *"never wired
up or tested against the live API"*, while ticket 012 did test it live and got
404s. The port into `AgenticDevcontainer` currently carries **both** claims in
one sentence — introduced while inlining, and wrong there too. Whatever is
decided must land in both repos.

**6. That overage is not a cutoff is never said.** "Out of credits" here means
"now costing real money" — arguably more important to surface than a hard
limit, but the runtime path is silent on it.

**7. The one working channel goes unused.** The web UI works. The skill cannot
read it, but it could name the URL, or ask once per session. It does neither.

## Decisions this grilling must reach

- What replaces "Business or Enterprise?" as the allowance self-serve — and how
  a pooled figure is obtained and kept fresh.
- Whether the consent gate's denominator stays the monthly allowance, becomes
  remaining balance, or shows both.
- Whether remaining balance enters the model at all, given it cannot be read
  programmatically and goes stale by the hour.
- Whether the skill surfaces the overage-not-cutoff fact, and where.
- Whether to spend anything at all on the per-user endpoint, given the 404.
- How the fix propagates to the `AgenticDevcontainer` copy.

## Resolution

Grilled 2026-08-31. The premise underneath the whole ticket collapsed during
the session: **the balance *is* programmatically readable.** The earlier
research was not wrong, it was pointed at the wrong endpoint.

```
GET https://api.<host>/copilot_internal/user   -> 200
  quota_snapshots.premium_interactions:
    entitlement 15000  remaining 3291  percent_remaining 21.9
  quota_reset_date: 2026-09-01
```

The three *documented* billing routes all 404 on this tenant, which is what
tickets 012 and 015 found. The undocumented `copilot_internal` route — the one
the editors themselves use — needs no admin or billing-manager role. Token
scopes here are `codespace, gist, read:org, read:user, repo`; no billing scope
is involved.

Two further facts settled by measurement rather than debate:

- **`credits_used` lags.** It stayed at 10526 across two hours while
  `remaining` fell 3602 → 3291. Trust `remaining` / `percent_remaining`. This
  explains the apparent arithmetic contradiction (15000 − 10526 ≠ 3602).
- **`timestamp_utc` is live**, not a periodic snapshot.

And one correction from the account holder that invalidated a load-bearing
assumption: **the allowance is personal, not a shared pool** — which had been
one of my own arguments for dropping percentage framing, and was also the
basis of the "overage, not cutoff" claim.

### Decisions

| # | Decision |
| --- | --- |
| 1 | Consent gate expresses **money first, credits second**: `~$1.50 (≈150 credits)`. No percentage of allowance. |
| 2 | Superseded by the fetch discovery. |
| 3 | Balance is a **best-effort enrichment**: fetch, cache, degrade silently. |
| 4 | Token chain: `$GITHUB_TOKEN`/`$GH_TOKEN` → `gh auth token` → `~/.copilot/config.json`. |
| 5 | **Informing, not steering** — revised by decision 12. |
| 6 | The "Business or Enterprise?" question is **removed entirely**. Published figures are starting points an org may raise per user. |
| 7 | Fetch **once per session**, cached with a timestamp. Intra-session drift accepted. |
| 8 | Balance shows **always in the gate**, elsewhere only on the pace warning. |
| 9 | "Low" is **pace-aware**: warn when the remaining-allowance fraction falls below the remaining-time fraction. A flat threshold misfires near reset. |
| 10 | Gate fires above **~$1.00**, or at **~3×** the level already approved for that type. |
| 11 | Superseded by decision 12. |
| 12 | Credits are assumed to **stop hard**. Because the wall is real, the skill **shifts from informing to steering once the pace warning fires**. |
| 13 | The credit story attaches to the **provider of the chosen model** (`github-copilot` only) — not to the harness, not to token presence. |
| 14 | The four living files are corrected; asset 013 keeps its text under a dated correction note. |
| 15 | The template seed ships `creditAllowance` empty; the live fetch fills it. |

### Fault lines, disposed

1, 2, 3, 4 and 7 dissolve — the figure is fetched, personal, and accurate.
5 (the self-contradictory endpoint sentence) is deleted in both repos rather
than reconciled. 6 is inverted: there is no overage to surface, there is a
wall, and decision 12 responds to it.

### Not claimed

The hard wall is the account holder's stated understanding, not a verified
fact — `overage_permitted: true` points the other way, and verifying would
mean exhausting the allowance. `/copilot_internal/user` is undocumented and
was tested only against a GHE Data Residency tenant, never against
github.com. Hence best-effort, never a hard dependency.

### Split out

- [Route opencode's Copilot provider at the GHE tenant](020-opencode-ghe-copilot-route.md)
- [Anthropic models missing from the catalogue](021-anthropic-models-missing-from-catalogue.md)
