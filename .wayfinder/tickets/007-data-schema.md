---
id: 007
title: Design the schema for hardware.json, model cache and remembered preferences
label: wayfinder:prototype
status: closed
assignee: Bas Kloet
blocked_by: [004, 005]
---

## RESOLUTION (2026-08-24) — closed

Prototyped as real files with real values, then walked five routing decisions
through them on paper. Full reasoning:
[Data schema — hardware.json, models.json, preferences.json](../assets/007-data-schema.md).
The files themselves are the primary deliverable:

```
/workspace/.model-picker/hardware.json      (gitignored)
/workspace/.model-picker/models.json
/workspace/.model-picker/preferences.json
```

**Location was forced by a checked fact, not chosen freely.** `docker-compose.yml`
bind-mounts `/workspace` from the host — genuine persistent disk. `$HOME` is
**not** generally persistent; `~/.config/opencode` and `~/.local/share/opencode`
are absent from the named-volume list. **Side finding, flagged to Bas, not
ticketed** (outside this map's destination): the opencode/Copilot device logins
done earlier this session will be **wiped on the next container rebuild**, and
`CLAUDE.md` explicitly instructs rebuilding for DNS/proxy fixes — this is a real,
likely-to-be-hit risk, just not one this map is scoped to fix.

**Three files, not one — confirmed, not assumed**, by walking real decisions
through them: each has a distinct lifecycle and owner (`ollama-curate` for
hardware + local model discovery, `pick-model` for preferences + narrow tier
corrections). Write convention: read-modify-write merging only owned keys — the
same discipline `llm-switch.sh` already uses in this repo. `schemaVersion: 1` in
each.

**A real gap was found and fixed by prototyping, not by discussion**: routing a
`code-agentic` task on paper required the consent gate's "% of allowance", which
needs `monthlyCredits` — and ticket 015 had conflated that near-constant fact
(1,900 vs 3,900, just "which seat do you have?") with the genuinely hard
"remaining balance" question. **Un-conflated: `pick-model` self-serves
`monthlyCredits` on first need**, exactly like `ollama-curate` self-serves
hardware specs — so **[Write the pick-model skill](011-write-pick-model.md) is
NOT blocked on ticket 015**, which is now re-scoped to the balance-reading
question alone.

**`costOverride` pattern** (demonstrated on `claude-opus-4.8-fast`) fixes ticket
014's known 2× pricing error without silently editing the raw metadata — routing
code must read `costOverride.effectiveCostPerMTokUSD` when present, a rule now
made explicit for [pick-model](011-write-pick-model.md) rather than hoped for.

**Invalidation fingerprint for ticket 016**: `models.json` carries
`ollamaKvCacheAssumptions` (flash attention state, KV cache type) — if that
config ever changes on the host, every ollama `fitFormula.slopeSource` is
invalidated back to metadata-only until re-measured. This is the concrete
mechanism the ticket asked for ("an invalidation trigger, not just a refresh
command").

**Four other paper walkthroughs confirmed clean**: cheap `doc-edit` routing,
`doc-review`'s explicit `offline.modelKey: null` for the no-local-fit case (a
ticket 005 requirement), tier-correction via `slopeSource` transitioning from
metadata to measured, and failure-counter accumulation for the two-to-three
strike floor shift.

---

## Question

What exactly do the shared data files contain, and where do they live?

These files *are* the future-proofing mechanism (map invariant 7): the skill text
holds the method, these hold every fact that can change. Get this wrong and the
skills calcify.

## Content to place

1. **Hardware profile** — GPU model, **VRAM (8 GB)**, system RAM (32 GB DDR5),
   CPU. Asked from Bas once (the GPU is *invisible* from inside the container,
   so it cannot be probed), cached, and re-asked only on explicit refresh. Needs
   a "last confirmed" marker so staleness is visible.
2. **Model cache** — per model: weights size, context limit, capabilities (tool
   support), and the **tier verdict** — predicted, then overwritten by the measured
   `/api/ps` result. Covers both ollama models and the discovered GHE Copilot list.
   Per [the VRAM fit formula](../assets/004-vram-fit-formula.md), local models need
   **`BASE` and `SLOPE`** (not just KV-bytes-per-token): `SLOPE` starts as
   metadata × 1.02 and becomes exact after two measurements at different context
   lengths, at which point prediction is byte-exact. Also store the
   **`USABLE_VRAM` estimate** — it is *not* a constant (~6.3 GB observed of 8 GB,
   and it drops when other apps use the GPU), so it needs its own confidence/
   last-measured marker rather than being treated as hardware truth.
   **Needs an invalidation trigger, not just a refresh command**: enabling
   [flash attention + q8_0 KV](016-kv-cache-quantisation.md) invalidates every
   cached `SLOPE` at once.
3. **Remembered preferences** — the task-type records, now specified by
   [Task taxonomy and routing policy](../assets/005-taxonomy-and-routing.md).
   Each record holds: type name, **exemplar task descriptions** (the matching
   key), the five **axis values**, **default model** for online and offline each
   marked `assumed` | `measured`, a **consent record** (whether an expensive model
   was approved and at roughly what cost level, so a much larger estimate
   re-asks), and a **failure counter** per model for the two-to-three-strike floor
   shift.
4. **Cached allowance** — the monthly AI-credit allowance (Business 1,900 /
   Enterprise 3,900, 1 credit = $0.01). Changes rarely, so treat it exactly like
   the hardware profile: ask once, store with a "last confirmed" date, refresh on
   request. The consent threshold is expressed as a **percentage of it**.
5. **Reserved slots for measured speed/quality** per `(model, task type)`. The
   benchmark skill is out of scope for this map but will write here, and
   `pick-model` will read it to flip a default from `assumed` to `measured`.
   Reserving the shape now is cheap; retrofitting it later is not.

## Resolve specifically

1. **One file or three?** The map's destination names `hardware.json` + prefs.
   Hardware changes rarely, the model cache changes on every refresh, and prefs
   change as Bas works — different lifecycles argue for splitting.
2. **Where on disk?** Must be readable by all three harnesses and survive a
   container rebuild. Candidates: in-repo under `.agents/` (versioned, shared,
   but hardware specs are machine-specific and would be committed) vs.
   `~/.config/` (machine-local, but outside the repo and lost on rebuild unless
   on a volume). Note `.gitignore` already excludes `**/.claude/settings.local.json`
   as the precedent for machine-local state.
3. **Schema versioning.** A `version` field costs nothing now and makes later
   migration possible — decide the shape.
4. **Who writes it.** `ollama-curate` owns the refresh path per the destination;
   confirm `pick-model` only ever *appends* prefs and tier corrections, so two
   skills never fight over the same file.
5. **What happens when a file is missing or stale** — the first-run experience.
   The skill must ask for specs rather than fail or guess.

## Blocked by

- [Derive the VRAM fit formula that decides fast tier vs spill tier](004-vram-fit-formula.md)
  — determines which metadata fields the model cache must store.
- [Define the open task taxonomy and its routing table](005-task-taxonomy.md)
  — determines the shape of a task-type record.

## Note

Prototype it: write real files with real values for the two installed models and
Bas's actual hardware, and check they answer a routing question end to end on
paper. A schema that looks fine but cannot express "this 7B spills at 64k" has
failed.
