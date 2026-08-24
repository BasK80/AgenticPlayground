# VRAM fit formula — fast tier vs spill tier

Measured **2026-08-24** against the live ollama (v0.32.15) at
`http://host.docker.internal:11434`, NVIDIA 8 GB card. Asset of
[Derive the VRAM fit formula that decides fast tier vs spill tier](../tickets/004-vram-fit-formula.md).

All models were unloaded (`keep_alive: 0`) after each probe.

## The formula

```
head_dim            = <arch>.embedding_length / <arch>.attention.head_count
kv_bytes_per_token  = 2 × block_count × head_count_kv × head_dim × bytes_per_elem
                      ( 2 = K and V; bytes_per_elem = 2 for the f16 default )

total_bytes(ctx)    = BASE + SLOPE × ctx
SLOPE               = kv_bytes_per_token × 1.02      ← +2% correction, measured
BASE                = weights + fixed buffers        ← measure once per model

fully GPU-resident  ⟺  total_bytes(ctx) ≤ USABLE_VRAM
```

`ctx` is **input + expected output** tokens, because the KV cache grows during
generation.

### Metadata fields (exact keys)

From `POST /api/show` → `.model_info`, prefixed by `general.architecture`
(`qwen2` for both installed models):

| Field | 7b | 14b |
| --- | --- | --- |
| `<arch>.block_count` | 28 | 48 |
| `<arch>.attention.head_count` | 28 | 40 |
| `<arch>.attention.head_count_kv` | 4 | 8 |
| `<arch>.embedding_length` | 3584 | 5120 |
| `<arch>.context_length` | 32768 | 32768 |

**`key_length` / `value_length` are absent**, so `head_dim` must be derived as
`embedding_length / head_count` — 128 for both models. A skill that expects those
keys will fail.

## USABLE_VRAM ≈ 6.3 GB of 8 GB — not 8 GB

This is the single most important correction. When a model spills, `size_vram`
plateaus at the ceiling:

| Probe | `size_vram` at plateau |
| --- | --- |
| 7b @ 32768 | 6,248,223,210 |
| 14b @ 4096 | 6,203,847,474 |
| 14b @ 32768 | 6,305,129,430 |

And the largest **fully resident** footprint observed was **6,302,046,616**
(7b @ 30720). So:

- **USABLE_VRAM ≈ 6.30–6.42 GB** (5.87–5.98 GiB)
- **~1.6–1.7 GB of the 8 GB card is unavailable** to ollama — driver reserve,
  CUDA context, and the Windows desktop compositor

**This is not a constant.** Anything else using the GPU — a browser, a video
call, a game — lowers it. So prediction must use a conservative budget and the
measured `/api/ps` check is the ground truth.

**Recommended: predict against 6.0 GB**, leaving ~300–400 MB of headroom for
desktop variance. Measured residency can then pleasantly exceed the prediction
rather than the reverse.

## Validation: the linear model is byte-exact

Fitted on `qwen2.5:7b` from the 4096 and 16384 probes
(`BASE = 4,508,981,656`, `SLOPE = 58,368`), then used to predict:

| num_ctx | Predicted `size` | Measured `size` | Error | %GPU |
| --- | --- | --- | --- | --- |
| 4096 | — (fit) | 4,748,056,984 | — | 100 |
| 16384 | — (fit) | 5,465,282,968 | — | 100 |
| 24576 | 5,943,433,624 | 5,943,433,624 | **0 bytes** | 100 |
| 28672 | 6,182,508,952 | 6,182,508,952 | **0 bytes** | 100 |
| 30720 | 6,302,046,616 | 6,302,046,616 | **0 bytes** | 100 |
| 32768 | 6,421,584,280 | 6,819,854,415 | +6.2% | **91 — spills** |

**Exact to the byte in the non-spilled regime.** The 32768 row diverges because
once a model spills, `size` includes host-side allocations and stops being
comparable — so the formula is only valid *up to* the spill point, which is
precisely where it is used.

### Metadata prediction vs measured slope

| | 7b | 14b |
| --- | --- | --- |
| Predicted KV/token (f16) | 57,344 | 196,608 |
| Measured slope | 58,368 | ~202,022 |
| Error | **+1.8%** | **+2.8%** |

Hence the **×1.02 correction** in the formula. The 7b's extra 1,024 B/token is
consistent and unexplained by the KV formula alone; treat it as per-token
overhead rather than chasing it.

## Two findings that change the local story

### 1. `qwen2.5:7b` cannot use its full 32k context — and misses by ~70 MB

Fully resident up to **~30.7k tokens**; at its advertised 32,768 it needs
6.42 GB against a ~6.35 GB ceiling. **It misses by roughly 70 MB** — about 1%.

So the model's advertised context is, on this card, *just* out of reach. Max safe
fully-resident context is **~29–30k** predicted conservatively, ~30.7k measured
with an idle desktop.

### 2. `qwen2.5:14b` can never be fully GPU-resident on this card

Its weights alone are ~9.1 GB against a ~6.3 GB ceiling, so **no context length
makes it fit** — confirmed at 62% GPU at 4096, falling to 40% at 32768. It is
permanently spill-tier, running 38–60% on CPU.

Input for [Choose the local model line-up for an 8 GB card](../tickets/008-local-model-lineup.md):
a "deliberate spill tier" on 8 GB may not be worth having at all. Even an
aggressive re-quant of a 14B stays above the ceiling, so the realistic choice is a
*good* 7–9B that fits, rather than a bigger model that thrashes.

## KV cache is f16 — but quantising it is a *marginal* win for these models

> **CORRECTED 2026-08-24.** This section originally claimed flash attention was
> off and that quantising KV was "the cheapest available win". Both were wrong —
> see the corrections inline below. The ollama docs are authoritative:
> `docs/faq.mdx` and `docs/context-length.mdx` in `ollama/ollama`.

**KV quantisation is NOT active — the cache is `f16` (ollama's default).**
Inferred, not assumed: the measured slope (58,368) matches the f16 prediction
(57,344) within 1.8%. Under `q8_0` the slope would be roughly half, which the data
rules out.

**Flash attention state is unknown, and the earlier claim that it is off was an
overclaim.** Flash attention reduces the attention *scratch* buffer, not KV size,
so the slope reveals nothing about it. Per the docs, ollama "uses Flash Attention
automatically when the selected backend and devices support it" — on a CUDA card
it is most likely **already on**.

Enabling them on the host (`OLLAMA_FLASH_ATTENTION=1`,
`OLLAMA_KV_CACHE_TYPE=q8_0`) would roughly **halve KV cost**:

| | f16 (current) | q8_0 (projected) |
| --- | --- | --- |
| 7b KV/token | 58,368 | ~29,200 |
| 7b footprint @ 32768 | 6.42 GB — **spills** | ~5.47 GB — **fits comfortably** |
| 7b max resident ctx | ~30.7k | ~32.8k (capped by the model's trained 32k) |

**But the gain for the currently installed models is only ~6.7%**, and that is the
correction. `qwen2.5:7b` is *trained* for 32,768 tokens and already reaches
~30,700 at f16 — so `q8_0` buys **+2,068 usable tokens**, not a new capability
class. Beyond 32,768 the model itself is the limit, not VRAM.

**And the docs name this exact model family as the worst case:** *"Models that
have a high GQA count (e.g. Qwen2) may see a larger impact on precision from
quantization."* Both installed models are `qwen2` architecture, and the 7b's GQA
ratio is 28/4 = **7** — high. So Bas would pay an above-average quality cost for a
6.7% context gain.

**Revised recommendation: do not enable `q8_0` for these models.** It becomes
decisive only for a model with a *long trained context* (say 128k), where f16 KV
is the binding constraint rather than the model's own ceiling — which is a
question for
[Choose the local model line-up for an 8 GB card](../tickets/008-local-model-lineup.md).

It is a **host-side environment change** (ollama runs as a systemd service in
WSL2), so it needs Bas to apply it, and it **invalidates the `SLOPE` cached for
every model**.

Ticketed as
[Decide whether to enable flash attention and q8_0 KV cache on the host](../tickets/016-kv-cache-quantisation.md).

## ollama's default context is 4k on this hardware

From `docs/context-length.mdx`: ollama picks a default context length **from VRAM**
— **`< 24 GiB VRAM: 4k context`**. Bas's card is 8 GB, so **every local run
defaults to 4,096 tokens** unless the client sets `num_ctx` per request or
`OLLAMA_CONTEXT_LENGTH` is set on the service.

This is arguably more consequential than KV quantisation: a `doc-review` task
would silently truncate to 4k while the model is capable of ~30k.

**Prefer per-request `num_ctx` over a global default.** A global
`OLLAMA_CONTEXT_LENGTH` is a blunt instrument — set to 32768 at f16 the 7b would
spill on *every* load (6.42 GB vs a ~6.35 GB ceiling), so a global value would have
to be capped near 24576–28672 and would then over-allocate for short tasks.
Sizing `num_ctx` per task is exactly what this formula exists to enable.

**Whether opencode's ollama provider can set `num_ctx` per request is an open
question** for
[Wire ollama and GHE Copilot as opencode providers](../tickets/009-wire-opencode-providers.md).
If it cannot, a capped global default is the fallback — and that constraint would
materially limit the local tier.

`ollama ps` also reports a `CONTEXT` column, useful for confirming what was
actually allocated.

## How the skill should use this

1. **Cache per model**: `BASE`, `SLOPE`, and the metadata fields. `BASE` needs one
   measurement per model; `SLOPE` comes from metadata × 1.02 and is confirmed by a
   second measurement.
2. **Predict** with `total = BASE + SLOPE × (input + expected_output)` against a
   conservative **6.0 GB** budget. No network needed — this is the offline path.
3. **Correct with measurement**: after a real run, read `/api/ps` and compare
   `size_vram` to `size`. Write the verdict back. Two measurements at different
   context lengths give an exact `BASE`/`SLOPE` for that model, after which
   prediction is byte-exact.
4. **Re-measure when the ceiling moves** — a model that spilled when a browser was
   open may fit when it is closed. Treat a single spill as evidence, not proof.
5. **Never trust the advertised context length.** Both installed models advertise
   32,768; the usable figure here is ~30.7k for the 7b and effectively nil for the
   14b.

## Raw measurements

| Model | num_ctx | `size` | `size_vram` | %GPU |
| --- | --- | --- | --- | --- |
| qwen2.5:7b | 4096 | 4,748,056,984 | 4,748,056,984 | 100 |
| qwen2.5:7b | 16384 | 5,465,282,968 | 5,465,282,968 | 100 |
| qwen2.5:7b | 24576 | 5,943,433,624 | 5,943,433,624 | 100 |
| qwen2.5:7b | 28672 | 6,182,508,952 | 6,182,508,952 | 100 |
| qwen2.5:7b | 30720 | 6,302,046,616 | 6,302,046,616 | 100 |
| qwen2.5:7b | 32768 | 6,819,854,415 | 6,248,223,210 | 91 |
| qwen2.5:14b | 4096 | 9,953,733,507 | 6,203,847,474 | 62 |
| qwen2.5:14b | 32768 | 15,746,098,788 | 6,305,129,430 | 40 |
