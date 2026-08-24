---
id: 010
title: Write the ollama-curate skill
label: wayfinder:task
status: closed
assignee: Bas Kloet
blocked_by: [001, 007, 008, 017]
---

## Question

Build the skill that answers *"what local models should I have installed?"* on
demand — portable across opencode, Claude Code and Copilot CLI.

## What it must do

1. Report what is installed now (`GET /api/tags` on
   `http://host.docker.internal:11434`) with each model's **tier** at a relevant
   context length, using the formula from
   [Derive the VRAM fit formula that decides fast tier vs spill tier](004-vram-fit-formula.md).
2. Identify **gaps** against Bas's coverage needs — doc work, mechanical work,
   tool-capable local, deliberate spill tier — and recommend what to pull.
3. Recommend what to **drop**, with disk reclaimed.
4. **Own the hardware-spec refresh path.** It asks Bas for the specs it cannot
   probe (the GPU is invisible from inside the container), writes to
   `/workspace/.model-picker/hardware.json`'s `hardware` key, and re-asks only
   when told to refresh. First run must be a clean ask-and-cache, not a failure.
   Schema and file locations: [ticket 007](007-data-schema.md) /
   [data schema asset](../assets/007-data-schema.md). Also owns the
   `ollama/*` entries in `models.json`, including the `ollamaKvCacheAssumptions`
   fingerprint that must invalidate every ollama `slopeSource` if
   [ticket 016](016-kv-cache-quantisation.md) is ever acted on.
5. Re-derive facts from real sources at refresh time — never recite a model
   catalogue from memory (map invariant 5).

## Must not

- Hardcode model names, sizes, or hardware values in the skill prose. Every one
  of those belongs in the data files (map invariant 7). The skill text carries the
  *method* for deciding, so it stays correct when Bas's GPU or the model
  landscape changes.
- Require the network to report on what is already installed and cached — only
  the *refresh* path may need it.

## Blocked by

- [Decide how skills are packaged so opencode, Claude Code and Copilot CLI all find them](001-skill-packaging.md)
  — where the files go and in what format.
- [Design the schema for hardware.json, model cache and remembered preferences](007-data-schema.md)
  — what it reads and writes.
- [Choose the local model line-up for an 8 GB card covering code and docs](008-local-model-lineup.md)
  — its first-run output, and the reasoning it encodes.
- [Measure whether a CPU/RAM-bound slow tier is worth a dedicated model, and whether MoE changes the pick](017-cpu-ram-slow-tier.md)
  — may add a slow tier to what this skill recommends and manages, on top of
  ticket 008's fast-tier answer.

## Packaging (settled by ticket 001)

Write **one file**: `.agents/skills/ollama-curate/SKILL.md`. Then:
- symlink `.claude/skills/ollama-curate → ../../.agents/skills/ollama-curate`
- symlink `.opencode/skill/ollama-curate → ../../.agents/skills/ollama-curate`
- **no action needed for Copilot CLI** — it discovers `.agents/skills/` natively
  (verified: `copilot skill list --json`).

Do not use opencode's `skills.paths` config — confirmed not working in 1.18.21.

## Note

Use `/write-a-skill`. Follow the portability pattern of
`.claude/skills/security-test/SKILL.md` — harness-agnostic prose, shell and file
reads only, portability stated in the frontmatter `description`.

## Resolution (2026-08-24)

**Built, not just decided** (this ticket is `task` type, per the map's Notes
override). `.agents/skills/ollama-curate/SKILL.md` (69 lines: checklist +
must-nots) plus `REFERENCE.md` (208 lines: the VRAM/tiering formula, the
slow-tier evaluation method from ticket 017, coverage-gap and
pull/drop-recommendation logic, refresh procedure) — no model name, size, or
hardware number hardcoded in either; all of it reads live from
`/workspace/.model-picker/{hardware,models}.json` or the live ollama
API/catalogue. Symlinked at `.claude/skills/ollama-curate` and
`.opencode/skill/ollama-curate` (both → `../../.agents/skills/ollama-curate`),
per ticket 001's packaging convention — verified live: Claude Code lists it
as an available skill, and `copilot skill list --json` shows it discovered
natively with no extra step. `models.json` updated with the ticket 017 MoE
slow-tier entry (`ollama/qwen3-coder:30b-a3b-q4_K_M`, measured
`decodeThroughput`, `tier: "slow"`) and `decodeThroughput` measurements added
to the existing `qwen2.5:14b` entry (both fast- and slow-tier bars — it clears
neither, drop stands per ticket 008). `preferences.json` was deliberately
**not** touched — it's `pick-model`'s file, not this skill's, per the
ownership table in [the data schema asset](../assets/007-data-schema.md).
Detail on what was written and why: no separate asset — the built files
themselves are the deliverable, same convention `hardware.json`/`models.json`
already established in ticket 007.

**Not done here, left for other tickets:** actually running the skill
end-to-end against the live ollama instance to confirm its recommendations
match what a human would conclude (that's
[Verify both skills end to end](012-verify-end-to-end.md)'s job); updating
`preferences.json`'s offline defaults for `doc-review`/`code-agentic` to
point at the new slow tier (that's
[Write the pick-model skill](011-write-pick-model.md)'s job, since it owns
that file).
