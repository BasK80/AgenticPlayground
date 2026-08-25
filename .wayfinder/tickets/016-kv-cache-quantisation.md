---
id: 016
title: Decide whether to enable flash attention and q8_0 KV cache on the host
label: wayfinder:task
status: closed
assignee: Bas Kloet
blocked_by: []
---

## Question

Should Bas set `OLLAMA_FLASH_ATTENTION=1` and `OLLAMA_KV_CACHE_TYPE=q8_0` on the
**host** ollama service — and if so, what changes afterwards?

## ⚠ Recommendation revised 2026-08-24: probably NOT worth doing yet

After reading ollama's own docs, the case is much weaker than when this ticket was
created:

- **The gain is ~6.7%, not a new capability.** `qwen2.5:7b` is trained for 32,768
  tokens and already reaches ~30,700 at f16. `q8_0` buys **+2,068 tokens**. Past
  32,768 the *model* is the limit, not VRAM.
- **The docs name this exact family as the worst case:** *"Models that have a high
  GQA count (e.g. Qwen2) may see a larger impact on precision from quantization."*
  Both installed models are `qwen2`; the 7b's GQA ratio is 28/4 = **7**.
- **It is global** — "all models will run with the specified quantization type".
  No per-model control.
- **Flash attention is likely already on.** Docs: ollama "uses Flash Attention
  automatically when the selected backend and devices support it." The earlier
  claim that it was off was an overclaim — the KV slope says nothing about FA.

**So this becomes worth revisiting only when a model with a long trained context
(e.g. 128k) is on the table**, where f16 KV is the binding constraint rather than
the model's own ceiling. That is a
[local model line-up](008-local-model-lineup.md) question.

**The more valuable host-side finding instead:** ollama defaults context length
**from VRAM**, and `< 24 GiB VRAM → 4k`. So every local run is capped at 4,096
tokens unless `num_ctx` is set per request. Prefer per-request `num_ctx` over a
global `OLLAMA_CONTEXT_LENGTH` — see
[the VRAM fit asset](../assets/004-vram-fit-formula.md).

## Why it looked worth doing (original framing)

Established by [the VRAM fit measurements](../assets/004-vram-fit-formula.md):
the KV cache is currently **f16** (inferred from the measured slope of 58,368
B/token matching the f16 prediction of 57,344 within 1.8%). Quantising it to
`q8_0` roughly halves KV cost:

| | f16 (current) | q8_0 (projected) |
| --- | --- | --- |
| `qwen2.5:7b` KV/token | 58,368 | ~29,200 |
| footprint @ 32768 | 6.42 GB — **spills** | ~5.47 GB — **fits** |
| max fully-resident ctx | ~30.7k | ~32.8k (capped by trained 32k) |

Right now the 7b **misses its own advertised 32k context by roughly 70 MB** — about
1%. This change turns that from unreachable into comfortable, which matters
because `doc-review` is the task type most starved of local context, and local is
now the offline-only tier.

## Resolve specifically

1. **Does it help or hurt in practice?** `q8_0` trades some quality for space.
   Measure, do not assume — compare output on a real `doc-edit` task before and
   after.
2. **Does it help the 14b at all?** Almost certainly not: its weights alone
   (~9.1 GB) exceed the ~6.3 GB ceiling, so KV savings cannot make it resident.
   Confirm, so the answer is on record.
3. **Where does the setting live** so it survives a host reboot — the ollama
   service environment on Windows, not the dev container. This is a **host-side**
   change; per `CLAUDE.md` the agent cannot make it, so hand Bas a precise
   checklist.
4. **What must be re-measured afterwards.** Enabling this **invalidates the
   cached `SLOPE` for every model.** The mechanism now exists:
   `/workspace/.model-picker/models.json` carries an `ollamaKvCacheAssumptions`
   fingerprint (`flashAttention`, `kvCacheType`) — if this change is made, update
   that fingerprint and reset every ollama entry's `fitFormula.slopeSource` back
   to `"metadata_x1.02_unfitted"` until re-measured. See
   [the data schema asset](../assets/007-data-schema.md).

## Notes

- Flash attention is typically a prerequisite for KV quantisation in ollama —
  verify for v0.32.15 rather than assuming.
- `q4_0` KV is also available and halves again, but quality cost rises sharply;
  judge whether it is worth evaluating at all.
- Not a blocker for anything: it is an improvement to local capability, and local
  is the offline-only tier. Worth doing before
  [Choose the local model line-up for an 8 GB card](008-local-model-lineup.md)
  if convenient, since it changes what fits.

## Resolution (2026-08-25)

**Decision: skip it for now — do not set `OLLAMA_KV_CACHE_TYPE=q8_0` on the
host.** Confirmed with Bas directly, presenting the 2026-08-24 analysis above
(gain, GQA-quality risk, global scope, 14b non-benefit) as the basis. He chose
"skip it for now" over enabling-and-measuring.

Resolving the four "resolve specifically" items in that light:

1. **Quality impact:** not measured — moot, since the decision is not to
   enable it. Would need a live before/after `doc-edit` comparison if this is
   ever revisited.
2. **Does it help the 14b:** confirmed no, by arithmetic (weights alone
   ~9.1 GB > the ~6.3 GB ceiling from [the VRAM fit formula](004-vram-fit-formula.md)).
   Moot twice over now — [ticket 008](008-local-model-lineup.md) already
   dropped `qwen2.5:14b` from the lineup entirely, for reasons unrelated to
   KV cache.
3. **Host-side checklist:** not written — no change to make. If revisited,
   the setting is `OLLAMA_KV_CACHE_TYPE=q8_0` (plus confirming
   `OLLAMA_FLASH_ATTENTION`, though docs say ollama enables flash attention
   automatically when supported) in the Windows host's ollama service
   environment, not the dev container.
4. **Re-measurement / fingerprint invalidation:** not needed — nothing
   changed. The `ollamaKvCacheAssumptions` fingerprint mechanism in
   `models.json` ([schema](../assets/007-data-schema.md)) stays as the
   trigger for whenever this *is* revisited — no action needed today.

**The trigger to revisit, unchanged from the 2026-08-24 analysis:** a model
with a long trained context (e.g. 128k) entering the local lineup, where f16
KV would be the binding VRAM constraint rather than the model's own trained
ceiling. That's a future
[local model line-up](008-local-model-lineup.md)-style question, not
ticketed now since no such model is currently on the table.

**Kept regardless of this decision — the more valuable finding already on
this ticket:** ollama defaults context length from VRAM
(`< 24 GiB VRAM → 4k`), so every local run is capped at 4,096 tokens unless
`num_ctx` is set per request. Prefer per-request `num_ctx` over a global
`OLLAMA_CONTEXT_LENGTH` — relevant to whichever ticket implements the actual
ollama call (`pick-model` or `ollama-curate`).
