---
id: 002
title: Determine whether opencode can switch its own model mid-session
label: wayfinder:research
status: closed
assignee: Bas Kloet
blocked_by: []
---

## RESOLUTION (2026-08-24) — closed

Verified live by running `opencode serve` and exercising the HTTP API. No prompts
sent, so no credits spent; probe session deleted, server stopped. Full detail:
[opencode model switching — verified live](../assets/002-opencode-model-switching.md).

**1. Yes — mid-session switching is fully supported.**
`POST /api/session/{sessionID}/model` with
`{"model":{"providerID","id","variant"?}}` → **204**, and the spec says it
*"switches the model used by subsequent provider turns"*. Confirmed by reading the
session back. **So "recommend + switch" survives intact** — no degradation to
"edit config and run `/model`".

**2. `variant` works and persists** — `claude-sonnet-5` + `variant:"high"` read
back as `high`; omitted yields `default`. The reasoning-effort lever from ticket
013 is settable per session.

**3. ⚠ The API does not validate that the model exists.** A bogus `id` *and* a
bogus `providerID` both return **204 and are stored**; only body-shape errors 400.
The session is then silently pointing at a model that fails at the next prompt.
**`pick-model` must validate against `GET /api/model` first — a 204 is not
evidence the model is real.**

**4. Model-id syntax:** `ModelRef = {id, providerID, variant?}` — a structured
object, *not* the `provider/model` string the CLI's `-m` flag takes.

**The real constraint is addressing the server, not switching.** A **plugin** gets
`serverUrl` and a typed client for free via `PluginInput`, and can register a real
**slash command** (`slash: {name, aliases}` + `onSelect`). A **prose skill running
shell commands cannot find the server**: no `OPENCODE_SERVER_URL` env var, no
port/lock file, and `--port` defaults to random. **So the opencode half of
`pick-model` should be a plugin** — recorded on
[Decide how skills are packaged](001-skill-packaging.md), which owns that call.

**Question 2 as asked is moot** and untested: config is patchable via
`PATCH /config` and the model is settable per session, so file-editing is the wrong
mechanism either way.

**Bonus for [provider wiring](009-wire-opencode-providers.md):** `opencode.json` is
*still* `{"provider": {}}` after Bas's successful Copilot login — the credential
lives in `auth.json` and providers are discovered from it. **This materially
reduces the `llm-switch.sh` collision risk**, since there may be nothing in
`provider` worth protecting.

**Bonus for [skill packaging](001-skill-packaging.md):**
`OPENCODE_DISABLE_CLAUDE_CODE_SKILLS` exists — **opencode natively reads Claude
Code skills.** Plus `OPENCODE_DISABLE_EXTERNAL_SKILLS`, `OPENCODE_SKILL_DESCRIPTION`
and a `/api/skill` route.

**Bonus for [offline detection](006-offline-detection.md):**
`OPENCODE_DISABLE_MODELS_FETCH`, `OPENCODE_MODELS_PATH` and `OPENCODE_MODELS_URL`
allow pinning the model catalogue to a local path — directly serving the
offline-first invariant.

---

## Question

`pick-model` is meant to **recommend and then switch** (opencode only). Can a
skill running inside an opencode session actually change the model that session
is using — and if not, what is the closest thing that still feels like one step?

Answer these specifically:

1. Can a skill/plugin/command change the *active session's* model at runtime?
2. If not: does writing `~/.config/opencode/opencode.json` take effect on the
   next message, or only in a fresh session?
3. Is there a programmatic route (plugin SDK, local HTTP/RPC server, CLI flag)
   that beats editing the config file?
4. What exact provider/model id syntax does a switch need (e.g.
   `ollama/qwen2.5:7b`, `github-copilot/<model>`)?

## Why this gates the design

If mid-session switching is impossible, "recommend + switch" degrades to
"write the config and tell the user to run `/model`" — still acceptable, but it
changes what
[Write the pick-model skill](011-write-pick-model.md) builds and what
[Wire ollama and GHE Copilot as opencode providers](009-wire-opencode-providers.md)
has to arrange. Resolve before either.

## What is already known

- `~/.config/opencode/opencode.json` is currently `{"provider": {}}` — nothing
  configured, so there is no working example on disk to copy.
- `.devcontainer/development/llm-switch.sh` is the existing precedent for
  machine-editing that file: `_opencode_write_config()` merges **only** the
  `provider` key via `jq` so user settings survive. Reuse that discipline.
- `tools/test-opencode-providers.sh` shows the non-interactive invocation
  shape: `opencode run -m anthropic/claude-haiku-4-5 "<prompt>"`. The `-m
  provider/model` flag is a confirmed switching mechanism for *new* runs.
- opencode v1.18.21; `@opencode-ai` SDK present in `~/.config/opencode/node_modules`.

## Notes

- A cheap empirical check beats doc-reading here: configure a provider, start a
  session, mutate the config, and see whether the next message changes model.
- Record the answer as a hard constraint, not a preference — the switcher's whole
  ergonomics hang on it.
