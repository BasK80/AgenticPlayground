---
id: 011
title: Write the pick-model skill
label: wayfinder:task
status: open
assignee:
blocked_by: [001, 005, 006, 007, 009, 013, 014]
---

## Note (2026-08-24, from ticket 007)

**015 is deliberately NOT a blocker.** `pick-model` self-serves
`hardware.json.creditAllowance.seatType` / `monthlyCredits` on first need — asks
Bas "Business or Enterprise?" once, caches it — exactly like `ollama-curate`
self-serves hardware specs. See
[the data schema asset](../assets/007-data-schema.md). Ticket 015 covers only the
harder "remaining balance" question, a degradable extra.

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
