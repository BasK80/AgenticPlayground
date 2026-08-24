---
id: 008
title: Choose the local model line-up for an 8 GB card covering code and docs
label: wayfinder:research
status: closed
assignee: Bas Kloet
blocked_by: [004]
---

## RESOLUTION (2026-08-24) — closed

**Keep exactly one model: `qwen2.5:7b-instruct-q4_K_M` (already installed, 4.68 GB).
Drop `qwen2.5:14b` (frees 8.99 GB). No coder-specialised slot, no spill tier.**

Researched against the live [ollama.com/library](https://ollama.com/library) and
`registry.ollama.ai` manifests (network access allowed through the firewall for
this ticket) — not recited from memory. Full reasoning, byte-level VRAM math per
candidate, and sources fetched:
[local model lineup asset](../assets/008-local-model-lineup.md).

- `qwen2.5:7b` confirmed fully resident to ~30.7k tokens (re-verified from a fresh
  manifest fetch, not just re-asserted from ticket 004).
- `qwen2.5:14b`: checked its *entire* real quant ladder — even the smallest
  published tag (`q2_K`, 5.77 GB) leaves only ~1,100–2,600 usable KV tokens.
  Cross-checked against a newer family (`qwen3:14b`, 9.28 GB, no smaller quant
  offered) to confirm 14B-class is categorically wrong for this card, not a
  `qwen2.5` quirk.
- `qwen2.5-coder:7b` is architecturally identical to `qwen2.5:7b` (Δ96 bytes) —
  fits equally well, but not worth a second 4.68 GB slot: the generalist already
  absorbed coder-expert training per its own model card, and `qwen2.5-coder`'s
  benchmark wins are demonstrated at 32B, not 7B.
- A same-size quality-tier alternative (`q5_K_M`) was explicitly considered and
  rejected — it only extends the ceiling to ~8–10k tokens, a third of `q4_K_M`'s,
  for a second 5.44 GB blob.
- **`doc-review` and `code-agentic` plainly cannot be served offline** on this
  card — both need context beyond the ~30.7k local ceiling vs cloud's 200k+.
  `quick`, `doc-edit`, `doc-author` are fine offline.
- Architecture metadata (GQA ratios) for `qwen3`, `llama3.1`, `mistral-nemo`
  wasn't sourceable — the GGUF blob redirect goes to
  `dd20bb891979d25aebc8bec07b2b3bbc.r2.cloudflarestorage.com`, which the firewall
  blocks. Didn't change the recommendation (all three were screened out on
  weights-only byte math regardless), so not worth a follow-up ticket — noted in
  the asset in case it matters for a future model.
- Unblocks [Write the ollama-curate skill](010-write-ollama-curate.md) (all three
  of its blockers are now closed).

## Question

Which ollama models should Bas actually have installed, given **8 GB VRAM** and
32 GB system RAM — and which should he drop?

This is the standing advice Bas asked for, and it is also the **first run** of
`ollama-curate`: whatever reasoning answers this ticket is the reasoning the
skill encodes.

## ⚠ REFRAMED by ticket 005 (2026-08-24)

**Local is now offline-only.** This ticket was scoped around local models being
the *default* for doc and mechanical work; that policy is gone — see
[Task taxonomy and routing policy](../assets/005-taxonomy-and-routing.md).

The optimisation target has changed: not "best model for the workload I route
here daily" but **"best offline fallback"**. That favours **breadth of competence
over specialisation**, because offline you get whatever happens to be installed —
there is no cheap cloud model to fall back to. A single capable generalist may now
beat two specialists that together fill the same disk.

It also **lowers this ticket's urgency** relative to charting time: it no longer
gates daily use, only the offline case. It still blocks
[Write the ollama-curate skill](010-write-ollama-curate.md).

## Hard numbers from ticket 004 (measured, not estimated)

See [VRAM fit formula](../assets/004-vram-fit-formula.md).

- **The real budget is ~6.3 GB, not 8 GB** — ~1.6–1.7 GB of the card is
  unavailable. Predict against a conservative **6.0 GB**. Any candidate must be
  sized against that, not against the nominal 8 GB.
- **`qwen2.5:7b` stays** — fully resident to ~30.7k tokens, which is nearly its
  full context. It is a genuine fast-tier model on this card.
- **`qwen2.5:14b` should probably go.** Weights alone ~9.1 GB exceed the ceiling,
  so it is *never* fully resident — 62% GPU at 4k, 40% at 32k. It thrashes at every
  context length.
- **Therefore question the "spill tier" slot entirely.** Even an aggressive
  re-quant of a 14B stays above 6.3 GB. The realistic choice on this card is a
  *good* 7–9B that fits, not a bigger model that runs half on CPU. Argue this
  explicitly rather than reserving a slot out of habit.
- **Candidate sizing rule:** weights + `1.02 × kv_bytes_per_token × ctx` ≤ 6.0 GB,
  where `kv_bytes_per_token = 2 × block_count × head_count_kv × head_dim × 2`.
  A model with fewer KV heads (strong GQA) buys far more usable context per GB —
  that is a primary selection criterion, not a footnote.
- If [flash attention + q8_0 KV](016-kv-cache-quantisation.md) is enabled first,
  KV halves and the sizing rule changes materially. Check its status before
  recommending.

## Coverage required

Judged as an **offline fallback set**, spanning the five task types
(`quick`, `doc-edit`, `doc-author`, `doc-review`, `code-agentic`):

- **Generalist that fits VRAM** — must cover prose *and* mechanical work at a
  realistic document context length, not just 4k. With local demoted, breadth
  matters more than being best-in-class at any one thing.
- **Tool-capable** — for any local agentic work, the model must handle tool
  schemas without mangling them. Verify rather than trusting the model card;
  `/api/tags` reports a `capabilities` array (both installed models list `tools`).
- **Spill tier** — the deliberate "slow but local" option for harder offline work.
  14B+ class. Still worth a slot, but now only for the offline case.
- **Honest limits.** `doc-review` needs large input, and both installed models cap
  at 32k while every cloud model starts at 200k. Say plainly which task types
  simply **cannot** be served offline at all — that is more useful than a
  recommendation that pretends otherwise.

## Resolve specifically

1. Concrete recommendations with quantisation levels, sized against the real VRAM
   budget from
   [Derive the VRAM fit formula that decides fast tier vs spill tier](004-vram-fit-formula.md).
   A model that fits at Q4 but not Q5 is a different recommendation.
2. Whether `qwen2.5:7b` / `qwen2.5:14b` (currently installed) stay, and what
   each is best at.
3. Whether a **coder-specialised** model earns a slot over a strong general
   instruct model, given that doc work is a primary use case and coding is
   largely going to the cloud anyway. Argue it rather than assuming.
4. Disk cost of the recommended set, and what to drop if it is too much.
5. **The source of truth.** Read a *real* catalogue (the ollama library) rather
   than reciting model names from memory — local model releases move monthly and
   this is exactly the fact class an LLM hallucinates. If the domain is
   firewall-blocked, ask the user to allow it from the host rather than guessing.

## Notes

- Today's date matters: recommendations must reflect what exists **now**, not a
  remembered snapshot. State the date the advice was given so staleness is visible.
- Verify each candidate's real context limit — advertised context and *usable*
  context on 8 GB are very different numbers.
