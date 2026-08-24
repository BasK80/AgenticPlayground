---
id: 004
title: Derive the VRAM fit formula that decides fast tier vs spill tier
label: wayfinder:research
status: closed
assignee: Bas Kloet
blocked_by: []
---

## RESOLUTION (2026-08-24) — closed

Full measurements, formula and raw data:
[VRAM fit formula](../assets/004-vram-fit-formula.md).

**The formula, and it is byte-exact in the regime where it is used:**

```
head_dim           = embedding_length / attention.head_count      (= 128 both models)
kv_bytes_per_token = 2 × block_count × head_count_kv × head_dim × 2   (f16)
total_bytes(ctx)   = BASE + (kv_bytes_per_token × 1.02) × ctx
fully resident     ⟺ total_bytes(ctx) ≤ USABLE_VRAM
```

`ctx` = **input + expected output**. Fitted on two probes of `qwen2.5:7b`, it then
predicted 24576, 28672 and 30720 **to the exact byte** (6,182,508,952 and
6,302,046,616 predicted *and* measured). Metadata-only prediction is within
**+1.8%** (7b) / **+2.8%** (14b) of the measured slope — hence the ×1.02.

**Note `key_length`/`value_length` are absent from `/api/show`** — `head_dim` must
be derived from `embedding_length / head_count`. A skill expecting those keys
fails.

**USABLE_VRAM ≈ 6.3 GB, not 8 GB.** When a model spills, `size_vram` plateaus at
6.20–6.31 GB, and the largest fully-resident footprint seen was 6,302,046,616. So
**~1.6–1.7 GB of the card is unavailable** (driver, CUDA context, desktop
compositor). It is **not a constant** — a browser or video call lowers it — so
predict against a conservative **6.0 GB** and let the measured `/api/ps` check be
ground truth.

**Two findings that change the local story:**

1. **`qwen2.5:7b` cannot use its advertised 32k context — it misses by ~70 MB**
   (~1%). Max fully-resident context is ~29–30k conservatively, ~30.7k measured
   on an idle desktop. **Never trust the advertised context length.**
2. **`qwen2.5:14b` can never be fully GPU-resident here** — weights alone ~9.1 GB
   against a ~6.3 GB ceiling, so no context length fits. Measured 62% GPU at
   4096, 40% at 32768. It is permanently spill-tier, running 38–60% on CPU.

**KV cache is f16; flash attention and KV quantisation are off** — inferred from
the slope, not assumed. Enabling `q8_0` would roughly halve KV cost and turn the
7b's full 32k from unreachable into comfortable. Split into
[Decide whether to enable flash attention and q8_0 KV cache on the host](016-kv-cache-quantisation.md)
— a host-side change the agent cannot make, and one that **invalidates the cached
slope for every model**.

**How the skill uses it:** cache `BASE` and `SLOPE` per model (one measurement
gives `BASE`, metadata × 1.02 gives `SLOPE`, a second measurement makes it exact);
predict offline against 6.0 GB; correct from `/api/ps` after real runs; treat a
single spill as evidence rather than proof, since the ceiling moves.

---

## Question

Given a model and a target context length, decide **offline** whether it will run
fully GPU-resident (*fast tier*) or spill into system RAM (*spill tier*).

Deliver a formula plus the exact metadata fields it consumes, accurate enough to
route on and cheap enough to run per decision with no network.

## Why it matters

Tier is a property of **`(model, context length)`**, not of the model (map
invariant 3). With 8 GB VRAM this is the difference between a usable local
default and a frustrating one — and markdown doc work is precisely the
long-context case that can push a fitting model over the edge.

## The two mechanisms to reconcile

- **Predicted** (what routing needs — no load cost, works offline): weights size
  + KV-cache estimate vs the VRAM budget. `POST /api/show` returns a
  `model_info` block with the fields needed to compute KV bytes per token
  (block/layer count, KV head count, head dim); `/api/tags` gives weights size
  and `context_length`.
- **Measured** (ground truth, requires the model to be loaded): `GET /api/ps`
  returns `size` and `size_vram` per loaded model. `size_vram == size` means
  fully GPU-resident; `size_vram < size` means partial offload. This is what
  `ollama ps` renders as its `PROCESSOR` column (`100% GPU` vs `52%/48%
  CPU/GPU`).

**Design intent: predict at routing time, then correct with measurement.** The
first real run of a model reads `/api/ps` and writes the measured verdict back
into the cache, so the estimate self-corrects.

## Resolve specifically

1. The KV-bytes-per-token formula, and which `model_info` keys supply each term
   (name them exactly — they are model-family-prefixed, e.g. `qwen2.*`).
2. The VRAM budget: how much of 8 GB is actually available after driver,
   desktop and compute-buffer overhead. This is the fudge factor that decides
   accuracy — get it from measurement, not theory.
3. Whether quantised KV cache / flash attention are in play, since they change
   the per-token cost materially.
4. Validation: check the prediction against measured `/api/ps` for both installed
   models at a couple of context lengths, and report the error.

## Sanity anchors (from charting — verify, don't trust)

Against an 8 GB budget:

| Model | Weights | est. KV @ 32k | Expected |
| --- | --- | --- | --- |
| `qwen2.5:7b` | 4.68 GB | ~1.8 GB | fits — fast tier |
| `qwen2.5:14b` | 8.99 GB | ~6.3 GB | over budget before KV — spill tier |

ollama is at `http://host.docker.internal:11434` (v0.32.15). Loading a model to
measure is expected and fine.
