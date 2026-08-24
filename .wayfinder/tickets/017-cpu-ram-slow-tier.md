---
id: 017
title: Measure whether a CPU/RAM-bound slow tier is worth a dedicated model, and whether MoE changes the pick
label: wayfinder:research
status: closed
assignee: Bas Kloet
blocked_by: [008]
---

## Question

[The local model lineup](008-local-model-lineup.md) optimised for **GPU-resident**
fit and rejected any 14B+ model on that basis. But ollama already runs partial
CPU offload automatically when a model doesn't fit VRAM — `qwen2.5:14b` is
already doing this today (62% GPU at ctx=4096, 40% at ctx=32768, per
[the VRAM fit asset](../assets/004-vram-fit-formula.md)), just slowly. Given
local is now the **offline-only** tier — where responsiveness already matters
less than it would as a daily driver — is a deliberate, dedicated **CPU/RAM-bound
slow tier** (accept minutes instead of seconds, in exchange for real capability
when there is truly no cloud) worth a slot? And does an MoE model change the
answer, since MoE compute cost tracks *active* parameters, not total resident
size, which is the axis that matters for CPU throughput but not for the VRAM
budget ticket 008 used to exclude it?

## Why ticket 008 didn't answer this

Ticket 008's rejection of any 14B+ model, and its immediate exclusion of MoE
tiers (`qwen3-coder:30b-a3b`, 19 GB), was **entirely VRAM-budget-based** — "does
it fit in 6.0–6.3 GB." That is the right test for a fast, fully GPU-resident
tier, and the fast-tier conclusion (`qwen2.5:7b-instruct-q4_K_M` only) stands.
But it is the wrong test for *this* question, which is about a tier that
deliberately runs mostly or entirely on the 32 GB system RAM.

**No throughput numbers exist anywhere in this map.** Checked tickets 004 and
008: both measured VRAM-residency **percentage** as a proxy for viability, never
actual tokens/sec. So "it thrashes" was a fair description of interactive
latency, not a measured claim about whether it can do meaningful work at all.

## The MoE angle, stated precisely

- Dense models: CPU decode cost scales with **total** parameters resident —
  a 14B model split 40% GPU / 60% CPU pays CPU cost for ~8.4B-worth of weights
  per token.
- MoE models: decode cost scales with **active** parameters per token, not
  total. `qwen3-coder:30b-a3b` has ~3B active parameters — if run mostly on
  CPU, its per-token compute is closer to a dense 3B model's, despite a 19 GB
  disk/RAM footprint that would never have cleared ticket 008's VRAM test.
- 32 GB system RAM comfortably holds a 19 GB MoE weight set plus KV cache and
  the OS/other processes, so the RAM ceiling (unlike the 6 GB VRAM ceiling)
  is not obviously binding here — but this needs checking, not assuming.
- Open question this ticket must resolve: is a CPU-bound MoE model actually
  **faster** than a CPU-bound dense 14B despite being larger on disk? That
  determines whether MoE, not a bigger dense model, is the right shape for a
  slow tier.

## Resolve specifically

1. **Measure real tokens/sec**, not residency percentage, for at least:
   - `qwen2.5:14b-instruct-q4_K_M` (already installed until/unless ticket 008's
     drop is acted on — measure before removing, or re-pull for the test) at a
     realistic context length, forced or observed at its current partial-offload
     split.
   - A same-class dense model fully forced to CPU (`num_gpu_layers: 0` or
     equivalent), to get a clean CPU-only baseline uncontaminated by PCIe
     transfer overhead from a partial split.
   - `qwen3-coder:30b-a3b` (or the smallest sensible MoE tag available at
     measurement time — re-check the live catalogue, don't assume `30b-a3b`
     is still current) under the same conditions.
2. **Establish what "meaningful" means before measuring speed** — a throughput
   number is meaningless without a bar to compare it to. Propose a concrete
   floor (e.g. "a `doc-edit` completes in under N minutes," or "a `code-agentic`
   tool-call round-trip doesn't time out downstream integrations") grounded in
   how the offline-fallback case is actually hit, not an arbitrary tok/s figure.
3. **Whether it changes ticket 008's recommendation** — this could mean: keep
   `qwen2.5:14b` after all as a labelled slow tier instead of dropping it, add
   an MoE model as a *different* slow tier, or confirm neither clears the bar
   and ticket 008's "no spill tier" stands as-is once actually measured rather
   than projected.
4. **RAM headroom check** — does the recommended slow-tier candidate's
   footprint (weights + KV + ollama overhead) actually fit comfortably in 32 GB
   alongside a normal desktop session, or does it also need a sizing formula
   the way VRAM did in ticket 004?
5. **Disk cost** — if a slow tier is added, what's the total disk cost of the
   final lineup (fast tier from ticket 008 + this), and is it still proportionate.

## Notes

- This is a **research** ticket: measure on the live ollama instance
  (`http://host.docker.internal:11434`), don't project from specs. Unload
  models (`keep_alive: 0`) between probes, per ticket 004's method.
  `/api/ps` reports the live GPU/CPU split; ollama's `/api/generate` response
  includes `eval_count`/`eval_duration` (and `prompt_eval_count`/
  `prompt_eval_duration`) — tokens/sec is `eval_count / (eval_duration / 1e9)`.
- Re-check the live catalogue for MoE tags — ticket 008 already found the
  catalogue moves monthly and includes families not in memory.
- Downloading a 19 GB model for this test is a real disk/bandwidth cost — flag
  it before pulling rather than doing it silently.
- If this concludes a slow tier is worth adding, it changes what
  [the ollama-curate skill](010-write-ollama-curate.md) recommends and manages —
  that ticket should stay blocked on this one, not just on 008.

## Resolution (2026-08-24)

**Yes — add `qwen3-coder:30b-a3b-q4_K_M` (MoE, 8-of-128 experts active) as a
dedicated third, slow tier.** Measured live (not projected): it decodes
~2.9–3.4x faster than the dense `qwen2.5:14b` at every context length tested
(17.87 vs 6.15 tok/s at ctx≈4k; 12.69 vs 3.74 tok/s at ctx≈8k), confirming
decode cost tracks active parameters, not resident size. GPU partial offload
turned out to be nearly irrelevant to both (±2–14%) — CPU/RAM bandwidth
dominates either way. Floor proposed: a ~500–1000 token turn should finish
under ~2 minutes ("emergency fallback," not interactive) — MoE clears this at
both tested context lengths, dense only at short context. RAM headroom is
comfortable (~20GB total footprint in 32GB, KV cache cheap by construction:
4 kv-heads, embedding 2048) — no VRAM-style sizing formula needed. Disk cost
of the full local lineup: ~23.3GB. **Ticket 008's fast-tier pick and its drop
of `qwen2.5:14b` both stand unchanged** — this adds a slot, it doesn't
replace one. This is a capability claim, not a quality one (no eval run) —
ships `assumed`. Full measurements, exact commands, and the resulting
`models.json`/`preferences.json` change list for
[the ollama-curate skill](010-write-ollama-curate.md) to apply:
[slow-tier asset](../assets/017-cpu-ram-slow-tier.md).
