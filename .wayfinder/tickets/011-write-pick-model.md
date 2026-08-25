---
id: 011
title: Write the pick-model skill
label: wayfinder:task
status: closed
assignee: Bas Kloet
blocked_by: [001, 005, 006, 007, 009, 013, 014]
---

## Note (2026-08-24, from ticket 007)

**015 is deliberately NOT a blocker.** `pick-model` self-serves
`hardware.json.creditAllowance.seatType` / `monthlyCredits` on first need — asks
Bas "Business or Enterprise?" once, caches it — exactly like `ollama-curate`
self-serves hardware specs. See
[the data schema asset](../assets/007-data-schema.md). Ticket 015 covers only the
harder "remaining balance" question, a degradable extra.

**Update (2026-08-25, from ticket 015's resolution):** the shared-pool
remaining balance is confirmed unreachable for Bas (regular member, no
org/enterprise billing role). A per-user AI-credit endpoint
(`/users/{username}/settings/billing/ai_credit/usage`) does exist and Bas can
read his own usage via the web UI with no special role — an *optional*
degradable extra this skill may surface ("you've used ~X credits recently")
but does not need to. Not wired up or tested against the live API; skip it if
it adds complexity disproportionate to the payoff.

**Update (2026-08-25, from ticket 018's resolution):** absolute credit
estimates carry an **unresolved ±10% uncertainty band** — a data-residency
Copilot policy, off by default, would multiply the already-tiered final cost
by 1.10 if Bas's enterprise has it on, and whether it does is genuinely
unconfirmed (admin-only toggle). Doesn't affect model *ranking* (uniform
either way) — just don't present a credit estimate as more precise than it
is. See [ticket 018](018-data-residency-surcharge.md).

## Question

Build the routing skill: given a task, recommend a model with reasoning — and
**in opencode, switch to it**.

## What it must do

**Implement [Task taxonomy and routing policy](../assets/005-taxonomy-and-routing.md)
— it is the spec. The summary below is a pointer, not a substitute.**

1. **Match** the task: exemplars first (cheap, no reasoning); run axis inference
   only when nothing matches, then mint a new type *with exemplars*. The taxonomy
   is open. Keep matching cheap — the skill's reasoning spends tokens in Bas's
   active session.
2. **Route to cloud by default; local only when offline.** Pick the cheapest
   cloud model that will succeed, using the five axes. When
   [offline detection](006-offline-detection.md) says there is no cloud, take the
   local branch and pick the best model that fits.
3. **Print the axis line and the matched type** before acting. Exemplar matching
   can be confidently wrong; visibility is the mitigation, and "that's not
   `doc-edit`" is the correction.
4. **Consent gate — credits, not patience.** Per type, remembered, threshold as a
   **percentage of the cached monthly allowance**, **inform-only: never block**.
   Re-ask when an estimate greatly exceeds the consented level.
5. **Escalate only on Bas's word — never automatically.** Record the failure
   against the type; shift its floor after a pattern of two-to-three, not one.
6. **Mark every default `assumed` or `measured`** and say which. All five starting
   types ship `assumed`.
6a. **Read from `/workspace/.model-picker/{hardware,models,preferences}.json`**
   (schema: [ticket 007](007-data-schema.md)). When a model entry has a
   `costOverride`, **use `costOverride.effectiveCostPerMTokUSD`, never the raw
   `costPerMTokUSD`** — the raw field is known-wrong for at least the `-fast`
   variants. This must be an enforced code path, not a convention.
7. Explain the choice. The reasoning is the product — it must read as a
   justification Bas can overrule, not an oracle.
5. **Actuate in opencode only.** Mechanism confirmed by
   [Determine whether opencode can switch its own model mid-session](002-opencode-model-switching.md):
   `POST /api/session/{sessionID}/model` with
   `{"model":{"providerID","id","variant"?}}` → 204, switching the model for
   subsequent turns. `variant` sets reasoning effort. **Validate the model against
   `GET /api/model` first — the API returns 204 for models and providers that do
   not exist and stores them**, leaving the session silently broken until the next
   prompt. In Claude Code and Copilot CLI, print the switch command instead and say
   plainly that switching is not available there.
6. Correct tier verdicts opportunistically: after a local run, read `/api/ps` and
   write the measured verdict back to the model cache.

## Must not

- Require a network call to reach a decision (map invariant 6).
- Hardcode model names, task types, or hardware values in prose (map invariant 7).
- Silently downgrade to local when the real problem is a firewall allowlist gap —
  see [Decide how the skills detect that cloud is unreachable](006-offline-detection.md).
  `CLAUDE.md` is explicit that a blocked request must not be treated as the
  service being down.

## Blocked by

- [Decide how skills are packaged so opencode, Claude Code and Copilot CLI all find them](001-skill-packaging.md)
- [Define the open task taxonomy and its routing table](005-task-taxonomy.md)
- [Decide how the skills detect that cloud is unreachable](006-offline-detection.md)
- [Design the schema for hardware.json, model cache and remembered preferences](007-data-schema.md)
- [Wire ollama and GHE Copilot as opencode providers](009-wire-opencode-providers.md)
  — **closed**: both providers wired and round-tripped live; model id syntax is
  `ollama/<tag>` and `github-copilot/<model>`
  ([resolution](009-wire-opencode-providers.md))
- [Determine the premium-request multiplier for each available Copilot model](013-premium-request-multipliers.md)
  — **closed**: billing is token-based, so the metadata `cost` field *is* the
  right ranking signal ([asset](../assets/013-copilot-credit-costs.md))
- [Pin down the -fast variant pricing and the long-context tier threshold](014-fast-and-longcontext-pricing.md)
  — **closed**: only `claude-opus-4.8-fast` has a documented 2× rate (4.6/4.7
  overridden by analogy, marked `assumed`); long-context threshold is
  published after all (272K/200K depending on model), engages automatically
  per-request against 5 of the 25 entitled models
  ([resolution](014-fast-and-longcontext-pricing.md))

## Packaging (settled by tickets 001 and 002)

**Two artifacts, not one:**

1. **Advice skill** — `.agents/skills/pick-model/SKILL.md`, symlinked to
   `.claude/skills/pick-model` and `.opencode/skill/pick-model`. Copilot CLI needs
   no extra step (native `.agents/skills/` discovery, verified).
2. **Actuation plugin (opencode only)** — `.opencode/plugin/pick-model.ts`,
   auto-discovered, no config entry needed. Registers a `/pick-model` slash
   command via `PluginInput`'s `client`/`serverUrl`, and calls
   `POST /api/session/{sessionID}/model` with `{"model":{providerID,id,variant?}}`.
   **Validate against `GET /api/model` before switching** — the endpoint returns
   204 for nonexistent models and providers and stores them anyway.

A prose skill **cannot** perform the switch itself — it cannot address the
running opencode server (no discoverable URL, no port file). The plugin is not
optional.

## Note

Use `/write-a-skill` for the advice half. Mirror the portability pattern of
`.claude/skills/security-test/SKILL.md`.

## Resolution (2026-08-25)

**Both artifacts built and packaging verified live in all three harnesses.**
`.agents/skills/pick-model/{SKILL.md,REFERENCE.md}` (checklist + method
reference, mirroring `ollama-curate`'s split), symlinked at
`.claude/skills/pick-model` and `.opencode/skill/pick-model`. Confirmed
discovered natively: Claude Code lists it as an available skill,
`copilot skill list --json` shows it with `"source": "project"`, and a live
`opencode serve` instance's `GET /skill` lists `pick-model` alongside the
other project skills. No model name, task type, or hardware value is
hardcoded in the prose — every fact is read from
`/workspace/.model-picker/{hardware,models,preferences}.json`.

**Data files updated** (this ticket's job per the ownership table in
[the data schema asset](../assets/007-data-schema.md)):
- `preferences.json`: `doc-review` and `code-agentic` offline defaults now
  point to `ollama/qwen3-coder:30b-a3b-q4_K_M` (ticket 017's slow tier),
  replacing the old `null`/`qwen2.5:7b` placeholders — this was flagged as
  this ticket's job in ticket 010's resolution.
- `models.json`: added a top-level `githubCopilotPricingCorrections` block
  encoding tickets 014 and 018's findings (the `-fast` 2x multiplier table,
  the five-model long-context threshold table, the unresolved
  data-residency ±10% band) as data the skill applies at discovery/refresh
  time, not hardcoded per-model. Updated `gpt-5.6-luna`'s
  `longContextTier.thresholdTokens` from `null` to `200000` now that ticket
  014 found it published after all.

**Actuation: the ticket's own plan needed correcting, caught by building it,
not by more reading.** The ticket specified "a `/pick-model` slash command
via `PluginInput`'s `client`/`serverUrl`" — reading the actual
`@opencode-ai/plugin` type definitions while implementing showed this is
inconsistent: slash-command registration only exists on an undocumented,
separate TUI-plugin export shape, not on the server-plugin shape that
carries `client`. **Pivoted to a plugin-provided tool instead**
(`.opencode/plugin/pick-model.ts`, tool `pickmodel_switch`) — documented,
stable API, and arguably better UX: the pick-model skill calls it directly
in the same turn it decides a model, no manual slash-command step, no
stale-file handoff.

**Two further implementation bugs found and fixed by actually running it
live, not by re-reading types harder:**
1. `PluginInput.client` is the **v1** SDK client — no `.model`/
   `session.switchModel`. Those only exist on `/api/*` routes (confirmed
   against the live server's own `/doc` OpenAPI spec; asset 002's original
   research, from before this SDK version distinction was understood, named
   the right routes but the wrong client).
2. Plain `fetch()` from inside the tool against the server's own address
   fails every time with a generic connection error — even though the
   identical URL is `curl`-reachable from a shell at the same instant, and
   an external fetch (to ollama) from the same tool call succeeds fine. A
   real self-connection limitation, not a proxy/DNS/hostname issue (an
   explicit IPv4-loopback-forcing rewrite made no difference). **Fix:**
   `client._client.get/post({ url, body })` — the generic transport the
   typed `client.*` methods are themselves built on — reaches `/api/*`
   routes without hitting this limitation. Confirmed with a real switch
   (`204`, session model actually changed) and a real validation-rejection
   (`no-such-model-xyz` correctly refused, no switch attempted).

**Verified live, end to end, for the ollama half:** `opencode run` with a
real prompt telling the model to call `pickmodel_switch` — the tool
validated against the live catalogue and switched the session for real
(confirmed via the tool's own output and repeat calls returning the same
success), and correctly refused a nonexistent model id without switching.

**Not done here, left for
[Verify both skills end to end](012-verify-end-to-end.md):**
- Exercising the actual *reasoning* paths this skill's prose describes —
  exemplar matching, the offline-detection probe, seat-type self-service,
  the consent gate, escalation — none of these were driven by a real task
  routing decision in this session, only written and reasoned about.
- The `variant` (reasoning-effort) lever was smoke-tested structurally
  (the tool accepts and forwards it) but not confirmed to actually change
  model behavior.

## Update (2026-08-25) — the `github-copilot` round-trip, done with real credits, found and fixed a real validation bug

Bas okayed spending real Copilot credits to close the one gap the resolution
above left open. **Good thing it was tested for real: validating against
`GET /api/model` — exactly what this ticket's plan and
[the model-switching asset](../assets/002-opencode-model-switching.md) both
pointed at — silently and permanently fails for `github-copilot`.**

Confirmed on multiple freshly-started `opencode serve` instances, before
*and* after routing a real, successful completion through
`github-copilot/gpt-5.6-luna` on that exact server process: `/api/model`
(and `/api/provider`) only ever listed `opencode`(zen) and `ollama` —
`github-copilot` never appeared, despite being fully configured and
directly usable via `-m github-copilot/...` and via the raw switch endpoint
itself (which always accepted it — consistent with ticket 002's finding
that the switch endpoint doesn't validate). Had this shipped as closed
without the real-credit test, `pickmodel_switch` would have **silently
refused every legitimate `github-copilot` switch, forever** — the ollama-only
verification in the original resolution above could not have caught this,
because ollama happens to appear correctly in `/api/model`.

**Fix:** validate against `GET /config/providers` instead (exposed on the
v1 client as the typed, documented `client.config.providers()` — no more
need for the `_client` escape hatch for this half). It reliably lists all
25 `github-copilot` models, including on a server with zero prior activity.
`.opencode/plugin/pick-model.ts` updated accordingly; the switch call itself
is unchanged (`client._client.post`, per the original resolution).

**Verified live, for real, with real credit spend:** `opencode run` told a
free `ollama` model to call `pickmodel_switch` with
`{providerID: "github-copilot", id: "gpt-5.6-luna"}` — switch succeeded.
Continued that exact session with a fresh prompt (no model specified,
inheriting the switch) — got a real completion (`"OPENCODE_RT_OK"`,
`metadata.copilot` present, 8545 input / 9 output tokens billed) and a
follow-up "what model are you" confirmed `github-copilot/gpt-5.6-luna`.
**The actuation half is now genuinely confirmed working end-to-end for both
providers**, closing the specific gap the original resolution flagged.
[Verify both skills end to end](012-verify-end-to-end.md) still owns
everything else in that section above (the reasoning paths, `variant`
behavior, and the other five scenarios on its own list).
