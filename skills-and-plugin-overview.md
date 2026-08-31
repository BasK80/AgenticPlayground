# Skills and Plugin Overview

## pick-model

**Location:** `.agents/skills/pick-model/` (symlinked into `.claude/skills/` and `.opencode/skill/`)

Recommends which AI model to use for a given task. Shows its reasoning so you can overrule it — never just asserts an answer.

### How it works

- Matches the task to a type using cached exemplars, then falls back to full axis inference only when nothing matches.
- Picks the cheapest online model that fits; falls back to local ollama models only when the network is genuinely unreachable (distinguishes firewall blocks from true offline).
- Fetches the live Copilot credit balance once per session (never asks for a seat type) and informs — never blocks — when a run looks expensive, expressed as money first, credits second. Shifts to actively proposing cheaper models only once consumption is running ahead of the billing period.
- In opencode, switches the session model automatically via the companion plugin. In Claude Code and the Copilot CLI, prints the switch command instead.

### Trigger phrases

- "Which model should I use for this?"
- "Am I overspending credits on this task?"
- "Switch to a cheaper model"

---

## ollama-curate

**Location:** `.agents/skills/ollama-curate/` (symlinked into `.claude/skills/` and `.opencode/skill/`)

Audits what ollama models are installed locally, tiers each one by GPU-fit on the current hardware, identifies offline coverage gaps, and recommends what to pull or drop.

### How it works

- Queries `/api/tags` on the local ollama endpoint to list installed models — no network required for this step.
- Classifies each model as fast (fully GPU-resident) or slow (CPU/RAM-bound) using a tiering formula derived from hardware specs and model size, caching results for future runs.
- Reports gaps against required offline task coverage categories.
- Recommends pulls/drops with disk impact stated upfront; always asks before downloading.
- On explicit refresh, re-scrapes the live ollama catalogue — never recites specs from memory.

### Trigger phrases

- "What local models should I have?"
- "Curate my ollama models"
- "What should I pull or drop?"

---

## pick-model Plugin (opencode only)

**Location:** `.opencode/plugin/pick-model.ts`

The actuation half of the `pick-model` skill. Exposes `pickmodel_switch` — called in the same turn the skill picks a model, so no manual step is needed.

### Why a plugin

A skill running shell commands cannot reach the live opencode server (no discoverable port or lock file). A plugin receives the opencode client automatically.

### What it does

1. Validates the requested model against the live provider catalogue via `client.config.providers()` — the raw switch endpoint accepts bogus IDs silently, so validation is mandatory.
2. Performs the switch via `client._client.post` — the only transport that reliably reaches opencode's internal routes from within a tool call on this version.
3. Returns a plain confirmation, or a specific error that the skill surfaces to the user before proceeding.

### Interface

```ts
pickmodel_switch({ providerID, id, variant? })
// providerID: e.g. "github-copilot" or "ollama"
// id:         exact key from models.json, e.g. "gpt-5.6-luna"
// variant:    optional reasoning-effort level, e.g. "low" | "high"
```
