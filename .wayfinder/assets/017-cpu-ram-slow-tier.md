# CPU/RAM-bound slow tier — measured, not projected

Resolved **2026-08-24** for
[Measure whether a CPU/RAM-bound slow tier is worth a dedicated model, and whether MoE changes the pick](../tickets/017-cpu-ram-slow-tier.md).
All numbers below are live measurements against `http://host.docker.internal:11434`
(`/api/generate`, `eval_count`/`eval_duration` for decode, `prompt_eval_count`/
`prompt_eval_duration` for prefill), cross-checked against `/api/ps` for the
actual GPU/CPU split during decode — not projected from specs, per ticket 004's
method.

## Headline result: MoE wins by ~3x, and GPU offload is irrelevant to both

| Model | Config | ctx | GPU-resident | Decode tok/s | Prefill tok/s |
| --- | --- | --- | --- | --- | --- |
| `qwen2.5:14b` (dense, 14.8B) | natural (ollama auto-split) | 4096 | 62% (6.2/9.95 GB) | **6.15** | — |
| `qwen2.5:14b` (dense) | forced `num_gpu:0` | 4096 | 0% | **5.29** | — |
| `qwen2.5:14b` (dense) | natural | ~8192 (7080 in) | 59% (6.34/10.78 GB) | **3.74** | 467 |
| `qwen3-coder:30b-a3b-q4_K_M` (MoE, 30.5B/8-of-128 experts active) | natural | 4096 | 33% (6.29/19.2 GB) | **17.87** | — |
| `qwen3-coder:30b-a3b-q4_K_M` (MoE) | forced `num_gpu:0` | 4096 | 0% | **17.44** | — |
| `qwen3-coder:30b-a3b-q4_K_M` (MoE) | natural | ~8192 (7059 in) | 32% (6.36/19.6 GB) | **12.69** | 571 |

Two things fall out of the same data:

1. **MoE is ~2.9–3.4x faster decode than the dense model at every context length
   tested**, despite being over 2x larger on disk (19.2GB vs 8.99GB) and having
   a *lower* GPU-resident fraction. This directly confirms the ticket's
   hypothesis: decode cost tracks **active** parameters (this model: 8 of 128
   experts per token, `expert_feed_forward_length: 768` — a small per-expert
   FFN) not total resident size. The dense model pays full CPU-transfer cost
   for its whole 14.8B weights every decode step; the MoE model only moves the
   ~3B-worth of experts its router actually picks.
2. **Partial GPU offload barely moves the needle for either model** — forcing
   `num_gpu:0` cost the dense model ~14% (6.15→5.29 tok/s) and the MoE model
   ~2% (17.87→17.44 tok/s, within noise). This means the earlier "62%
   GPU-resident" framing from [ticket 004](004-vram-fit-formula.md), while
   correct as a VRAM-fit description, is **not a good proxy for usability** —
   a model can be mostly CPU-resident and still be perfectly fine, or mostly
   GPU-resident and still be too slow, because decode throughput is bound by
   *how many bytes move per token*, and GPU vs CPU memory bandwidth for that
   quantity turns out not to be the dominant factor once any real CPU offload
   is involved.

Both models degrade in decode speed as context grows (dense: 6.15→3.74 tok/s;
MoE: 17.87→12.69 tok/s from ctx 4k→~8k) — expected, since KV cache growth eats
into the same VRAM budget the weight layers compete for, per ticket 004's
mechanism. **Prefill is fast for both and was never the bottleneck** — 467–571
tok/s regardless of dense/MoE, so a large document review's *input* is not
what makes a slow tier slow; the *output* generation is.

## Establishing "meaningful" before judging the numbers

A tok/s figure alone means nothing without a bar. The floor that matters here
is grounded in how this tier is actually reached: it only fires when cloud is
offline (per [ticket 006](006-offline-detection.md)) and the task type is one
[ticket 008](008-local-model-lineup.md) found the fast 7B tier can't serve —
concretely, that's `doc-review` (large input, single-shot output) and
`code-agentic` (many tool-call turns). Proposed floor, **assumed** not
independently validated with Bas:

- **A single generation turn of realistic output length (~500–1000 tokens —
  one doc-review verdict, or one agentic tool-call turn) should complete in
  under ~2 minutes.** This is the "still usable as an emergency fallback, not
  a coffee-break" bar — long enough to tolerate "minutes not seconds," short
  enough that a multi-turn agentic task doesn't balloon past what a work
  session can absorb.

Against that floor:

- **MoE clears it at both measured context lengths**: 1000 tokens ≈ 56s at
  ctx≈4k (17.87 tok/s), ≈79s at ctx≈8k (12.69 tok/s).
- **Dense clears it only at short context** (1000 tokens ≈ 163s at ctx≈4k —
  already over the 2-minute floor) **and clearly misses it at longer context**
  (1000 tokens ≈ 267s ≈ 4.5 min at ctx≈8k, and would keep degrading further
  as context grows, per the same mechanism ticket 004 measured for the fast
  tier's VRAM squeeze).
- For `code-agentic` specifically (many compounding turns), the gap compounds:
  10 turns of ~500 tokens each is ≈5 min on MoE vs ≈14–22 min on dense at
  realistic agentic context lengths. Neither is fast, but only the MoE number
  stays inside "a coffee break," which is the realistic tolerance for an
  emergency offline fallback.

## RAM headroom — checked, not assumed

`qwen3-coder:30b-a3b-q4_K_M`'s on-disk/resident weight size is **~18.3 GiB**
(measured via `/api/ps`, varies slightly 19.05–19.6 GB across runs depending on
loaded context). Its KV cache is cheap by construction — `head_count_kv: 4`,
`embedding_length: 2048` → `head_dim = 2048/32 = 64`, so per-token KV cost is
`2 × 4 × 64 × 48 blocks × 2 bytes (f16) ≈ 48 KB/token` — under 1.5 GB even at
32k context. **Total footprint (~20 GB weights+KV) fits comfortably inside 32
GB system RAM** alongside a normal desktop session (browser, IDE, OS) with
10+ GB headroom to spare — unlike the 6 GB VRAM ceiling ticket 004 had to
fight for every byte of, RAM is not the binding constraint here and doesn't
need its own sizing formula the way VRAM did.

## Disk cost

Fast tier (`qwen2.5:7b-instruct-q4_K_M`, per ticket 008: 4.68 GB) + this slow
tier (`qwen3-coder:30b-a3b-q4_K_M`, 18.6 GB downloaded / ~19.2 GB on disk) =
**~23.3 GB total local lineup.** Proportionate: it's the cost of turning two
currently-unservable-offline task types (`doc-review`, `code-agentic`) into
served-with-a-real-wait ones, for one extra disk slot.

## Does this change ticket 008's recommendation?

**Ticket 008's fast-tier pick stands exactly as-is** — `qwen2.5:7b-instruct-q4_K_M`
is still the only fully GPU-resident, low-latency model, and nothing here
argues for touching it. Ticket 008's **drop of `qwen2.5:14b` also stands** —
measured here to be strictly worse than the MoE option in every dimension
(slower decode at every context length, same "doesn't fit VRAM" problem, no
compensating advantage), so there's no case for resurrecting it as the slow
tier.

**What changes: add a third, dedicated slow-tier slot —
`qwen3-coder:30b-a3b-q4_K_M`** — not to replace the fast tier, but to extend
offline capability to `doc-review` and `code-agentic`, the two task types
ticket 008 explicitly found unservable on this card. This is a **capability**
claim (a much larger, current-gen model is more likely to produce a usable
answer than the 7B fast tier for those task types), not a **quality** one —
no eval/benchmark was run here (that's explicitly out of scope, reserved for
the separate benchmarking effort per the map's Out of scope section) — so it
should ship marked `assumed`, same discipline as every other default in this
map.

## Consequence for the build tickets

Unblocks [Write the ollama-curate skill](../tickets/010-write-ollama-curate.md)
(its last remaining blocker). When that ticket is executed, it should:

- Add a `qwen3-coder:30b-a3b-q4_K_M` entry to `models.json` with `tier: "slow"`,
  the measured decode/prefill figures above (`slopeSource`-style provenance:
  "measured", dated 2026-08-24), and the KV-cheapness fact
  (`head_count_kv: 4`, `embedding_length: 2048`) so future context-scaling
  predictions have real `archFields` to start from, per ticket 004's pattern.
- Update `preferences.json`'s `doc-review.defaults.offline` (currently
  `modelKey: null`) and `code-agentic.defaults.offline` (currently
  `ollama/qwen2.5:7b`, flagged "likely inadequate") to point at the new slow
  tier instead — both marked `provenance: "assumed"` per the capability-not-quality
  caveat above, ready for `failureCounters` to correct in practice.
- Manage the ~2-minute-per-turn expectation explicitly in whatever message
  `pick-model` shows when routing to this tier (an honest "this will take
  a while" notice), reusing the messaging pattern established in
  [ticket 006](006-offline-detection.md) for degraded-but-working states.
