# Local model lineup for an 8 GB card — researched 2026-08-24

Researched **2026-08-24** against the live [ollama.com library](https://ollama.com/library)
and [registry.ollama.ai](https://registry.ollama.ai) manifests through the container's
firewall proxy. Asset of
[Choose the local model line-up for an 8 GB card covering code and docs](../tickets/008-local-model-lineup.md).
Builds directly on the measured formula and numbers in
[VRAM fit formula](004-vram-fit-formula.md) — those are treated as settled fact here,
not re-derived.

**Bottom line up front:** keep exactly one model — `qwen2.5:7b-instruct-q4_K_M`
(the tag already installed). Drop `qwen2.5:14b` outright. Do not add a
coder-specialised model. Do not add a second "spill tier" model — on this card
there isn't a good one. Total recommended disk cost: **4.68 GB**, down from
13.67 GB today.

## Catalogue scan — what's actually in the library right now

Full list scraped from [ollama.com/library](https://ollama.com/library) (2026-08-24).
It is much larger than memory would suggest — includes several families that don't
exist in any pre-2026 write-up (`glm-5.x`, `deepseek-v4-*`, `nemotron-3.x`,
`olmo-3.x`, `qwen3.5`/`qwen3.6`/`qwen3.8`, `minimax-m2.7`/`m3`, etc.), confirming the
ticket's warning that local releases move monthly and reciting from memory would
have hallucinated or missed real entries.

Filtered to the families the ticket named (qwen2.5/qwen3, llama3.x, gemma2/3,
mistral/mistral-nemo, phi, coder-specialised) and to sizes in the 7–14B class that
could plausibly fit a ~6 GB budget. `qwen3-coder` and `qwen3`'s MoE tiers (30B-A3B,
235B-A22B) were excluded immediately — MoE "active parameter" counts don't reduce
disk/VRAM footprint, ollama still loads the full expert set. Smallest `qwen3-coder`
tag is `30b-a3b-q4_K_M` at **19 GB** — over 3× the VRAM budget on its own, not a
serious candidate at any quant.

## Step 1 — capability gate: does the model declare `tools`?

Ticket 008 requires tool-calling for any local agentic work, and to trust the
declared capability badge, not memory. Checked each model's ollama.com page for the
`tools` badge (`<span ... class="...bg-indigo-50...">tools</span>` in the page HTML):

| Model | `tools` badge | Source |
| --- | --- | --- |
| `qwen2.5` | yes | [ollama.com/library/qwen2.5](https://ollama.com/library/qwen2.5) |
| `qwen2.5-coder` | yes | [ollama.com/library/qwen2.5-coder](https://ollama.com/library/qwen2.5-coder) |
| `qwen3` | yes | [ollama.com/library/qwen3](https://ollama.com/library/qwen3) |
| `qwen3-coder` | yes (but excluded on size, see above) | [ollama.com/library/qwen3-coder](https://ollama.com/library/qwen3-coder) |
| `llama3.1` | yes | [ollama.com/library/llama3.1](https://ollama.com/library/llama3.1) |
| `llama3.2` | yes (but only 1B/3B — no 7–14B tag exists) | [ollama.com/library/llama3.2](https://ollama.com/library/llama3.2) |
| `llama3.3` | yes (70B only — no 7–14B tag exists) | [ollama.com/library/llama3.3](https://ollama.com/library/llama3.3) |
| `mistral` | yes | [ollama.com/library/mistral](https://ollama.com/library/mistral) |
| `mistral-nemo` | yes | [ollama.com/library/mistral-nemo](https://ollama.com/library/mistral-nemo) |
| `mistral-small3.2` | yes (24B — over budget at any quant worth using) | [ollama.com/library/mistral-small3.2](https://ollama.com/library/mistral-small3.2) |
| `phi4-mini` | yes (3.8B — below the 7–14B class asked for) | [ollama.com/library/phi4-mini](https://ollama.com/library/phi4-mini) |
| `gemma2` | **no** | [ollama.com/library/gemma2](https://ollama.com/library/gemma2) |
| `gemma3` | **no** | [ollama.com/library/gemma3](https://ollama.com/library/gemma3) |
| `phi3.5` | **no** | [ollama.com/library/phi3.5](https://ollama.com/library/phi3.5) |
| `phi4` | **no** | [ollama.com/library/phi4](https://ollama.com/library/phi4) |
| `codegemma` | **no** | [ollama.com/library/codegemma](https://ollama.com/library/codegemma) |
| `deepseek-coder-v2` | **no** | [ollama.com/library/deepseek-coder-v2](https://ollama.com/library/deepseek-coder-v2) |

**The entire Gemma and Phi families (except the too-small `phi4-mini`) and
`deepseek-coder-v2`/`codegemma` are ruled out on this axis alone** — no declared
tool-calling support, so no local agentic work regardless of how well they'd fit in
VRAM. This leaves five real 7–14B-class, tool-capable contenders:
`qwen2.5`, `qwen2.5-coder`, `qwen3`, `llama3.1` (8B only), `mistral-nemo` (12B only).

## Step 2 — architecture metadata: mostly not obtainable through primary sources

The formula needs `block_count`, `attention.head_count`, `attention.head_count_kv`,
`embedding_length` per model. Neither ollama.com model pages nor the
`registry.ollama.ai/v2/<model>/manifests/<tag>` JSON expose these — the manifest
only lists layer digests and byte sizes (config/template/license/params layers,
each a few hundred bytes to a few KB; the actual GGUF weight blob is a separate
layer of `mediaType: application/vnd.ollama.image.model`).

The GGUF header (which does contain this metadata) lives inside that blob. Fetching
it requires following the registry's redirect, which points to a signed
Cloudflare R2 URL:

```
GET https://registry.ollama.ai/v2/library/<model>/blobs/sha256:<digest>
→ 307 → https://dd20bb891979d25aebc8bec07b2b3bbc.r2.cloudflarestorage.com/...
```

That redirect target is **blocked by this container's firewall** (`403
ERR_FIREWALL_BLOCKED` from squid, confirmed on two different blobs, same R2 account
hostname both times). Per this repo's network policy, that's an allowlist decision
for the host, not something fixable from inside the container. **Stating this
plainly rather than guessing:** no GQA ratios or head dims for `qwen3`, `llama3.1`,
or `mistral-nemo` were obtained from a primary source in this pass. If exact sizing
math for those three is wanted later, allow
`dd20bb891979d25aebc8bec07b2b3bbc.r2.cloudflarestorage.com` (or the equivalent R2
range) from the host and re-run the blob-header fetch.

**One exception: `qwen2.5-coder` can be sized exactly, by inference, not by
guessing.** Its manifest-reported weight-blob sizes match `qwen2.5`'s **to within 96
bytes at every quant level checked**:

| Tag | `qwen2.5` weight bytes | `qwen2.5-coder` weight bytes | Δ |
| --- | --- | --- | --- |
| `7b-instruct-q4_K_M` | 4,683,073,952 | 4,683,074,048 | 96 B |
| `14b-instruct-q4_K_M` | 8,988,110,688 | 8,988,110,784 | 96 B |

(Both via `registry.ollama.ai/v2/library/<model>/manifests/<tag>`, fetched
2026-08-24.) A 96-byte difference on multi-gigabyte blobs is not "similar" — it's
the same architecture and parameter count, consistent with Qwen's own description of
Qwen2.5-Coder as continued pretraining on the Qwen2.5 backbone. So `qwen2.5-coder`
inherits `qwen2.5`'s exact `BASE`/`SLOPE` from ticket 004 directly — no new
measurement needed, and this is a sourced inference, not a recited GQA number.

## Step 3 — sizing math against the 6.0 GB budget

### `qwen2.5:7b-instruct-q4_K_M` and `qwen2.5-coder:7b-instruct-q4_K_M` (identical)

Using `BASE = 4,508,981,656`, `SLOPE = 58,368` B/token from ticket 004:

| ctx (tokens) | `total_bytes(ctx)` | GB | Verdict vs 6.0 GB budget |
| --- | --- | --- | --- |
| 8,192 | 4,987,132,312 | 4.99 | fully resident, 1.0 GB headroom |
| 16,384 | 5,465,282,968 | 5.47 | fully resident (measured exact) |
| 30,720 | 6,302,046,616 | 6.30 | fully resident (measured exact, ~100% GPU) — practical max |
| 32,768 (model's own ceiling) | 6,421,584,280 predicted | 6.42 | **not** fully resident — measured 91% GPU, spills |

Same numbers, same verdicts for `qwen2.5-coder:7b-instruct-q4_K_M` (Δ96 bytes is
noise). Both are genuinely usable up to ~30k input+output tokens — enough for
`quick`, `doc-edit`, most `doc-author`, and a real (if not huge) `doc-review`.

### `qwen2.5:14b` / `qwen2.5-coder:14b` — no quantisation fits

No clean `BASE` exists for the 14B — every measured probe in ticket 004 was already
spilled (62% GPU at ctx=4096), so the linear formula's own validity condition
("only up to the spill point") is never met for this model. Falling back to the
weights-only floor, which is decisive on its own:

| Quant tag | weight bytes | GB | vs 6.0 GB budget | vs 6.3 GB ceiling |
| --- | --- | --- | --- | --- |
| `q4_K_M` (the installed one) | 8,988,110,688 | 8.99 | **−2.99 GB** | −2.69 GB |
| `q3_K_L` | 7,924,768,608 | 7.92 | −1.92 GB | −1.62 GB |
| `q3_K_M` | 7,339,204,448 | 7.34 | −1.34 GB | −1.04 GB |
| `q3_K_S` | 6,659,596,128 | 6.66 | −0.66 GB | −0.36 GB |
| `q2_K` (smallest tag ollama offers) | 5,770,497,888 | 5.77 | **+0.23 GB** | +0.53 GB |

`q2_K` is the *only* tag whose weights alone fit under budget, and it leaves 230–530
MB for KV cache + fixed buffers + generation. At the 14B's own measured KV slope
(~202,022 B/token, from ticket 004's metadata-predicted 196,608 × the same-family
correction), that headroom is **~1,100–2,600 tokens** — not enough for a real
system prompt plus a short answer, let alone a doc task. (All sizes via
`registry.ollama.ai/v2/library/qwen2.5/manifests/<tag>`, fetched 2026-08-24; same
Δ96-byte match confirms `qwen2.5-coder:14b` is identical.)

**Confirms the ticket's given fact with real quant-ladder byte math, not just the
default tag: no quantisation of `qwen2.5:14b` (or `qwen2.5-coder:14b`) is usable on
this card.** 14B-class is categorically wrong for a 6 GB budget, not just
under-quantised.

### Same-class 14B from another family: `qwen3:14b` — worse, not better

`qwen3:14b-q4_K_M` weighs **9,276,184,896 bytes (9.28 GB)** — *larger* than
`qwen2.5:14b` at the same quant, and `qwen3`'s tags page offers **no smaller quant
than `q4_K_M`** (only `q4_K_M` / `q8_0` / `fp16` are published for `qwen3:14b` —
confirmed by enumerating every tag on
[ollama.com/library/qwen3/tags](https://ollama.com/library/qwen3/tags), fetched
2026-08-24). There is no `q3_K_S`/`q2_K` escape hatch to even test. This closes the
"maybe a newer 14B family fits" question: it doesn't, and this one doesn't even
offer a way to try.

### The other three candidates — qualitative disk-size screen only (architecture unsourced)

No GQA data for these (see Step 2), so no ctx table — weights-only comparison
against the two *known* quantities (`qwen2.5:7b` BASE ≈ 4.51 GB, fits to ~30.7k):

| Model:tag | weight bytes | GB | vs `qwen2.5:7b-instruct-q4_K_M` (4.68 GB) |
| --- | --- | --- | --- |
| `qwen3:8b-q4_K_M` | 5,225,374,496 | 5.23 | **+0.54 GB heavier** — meaningfully less KV headroom left in the same 6.0 GB budget; also the only small quant ollama offers for this tag (no q3/q5 ladder — same gap as the 14B) |
| `llama3.1:8b-instruct-q4_K_M` | 4,920,738,944 | 4.92 | +0.24 GB heavier — in the same ballpark, but no sourced KV slope to confirm where it caps |
| `mistral-nemo:12b-instruct-2407-q4_K_M` | 7,477,204,672 | 7.48 | **over the 6.3 GB ceiling on weights alone**, same failure mode as the 14Bs |
| `mistral-nemo:12b-instruct-2407-q3_K_S` (smallest reasonable) | 5,534,226,112 | 5.53 | fits on weights alone, ~0.5 GB headroom — same order-of-magnitude problem as `qwen2.5:14b`'s `q2_K` case above |

`qwen3:8b` also defaults to a "thinking" template family (visible on
[ollama.com/library/qwen3](https://ollama.com/library/qwen3) — the `30b-a3b`
variants are explicitly split into `-instruct-2507` vs `-thinking-2507` tags, and
the dense 4B tag ships a `-thinking` variant too), which spends extra tokens on
reasoning before answering — extra tokens that grow the KV cache in an already
tighter budget than `qwen2.5:7b`'s. Combined with less quant flexibility and no
sourced KV numbers, `qwen3:8b` is not a demonstrated improvement — it's an
unmeasured, tighter-fitting alternative to a model that's already measured and
known to work. Not adopted without a benchmark.

`mistral-nemo:12b` is ruled out the same way the 14Bs are: even its smallest
practical quant is a 12B squeezed into ~5.5 GB, leaving the same order of headroom
(~0.5 GB) that was decisive against `qwen2.5:14b`. The "12B is smaller than 14B so
maybe it clears the bar" hope doesn't survive contact with the byte math — it's the
same failure mode one size class down.
`llama3.1:8b` is the closest in weight to the incumbent but offers no evidence of
being *better* than it, and no sourced way to compute its actual ceiling — so there
is no basis to prefer it over the model that is already measured, installed, and
known to hit ~30.7k tokens.

## Decisions

### 1. `qwen2.5:7b` stays — `qwen2.5:7b-instruct-q4_K_M`, exactly as installed

Re-verified from first principles, not just re-asserted: its manifest weight size
(4,683,073,952 B) matches the "4.68 GB on disk" given fact exactly, and the ticket
004 formula — now cross-checked against the fresh manifest byte counts — still says
it's fully resident to ~30.7k tokens. Nothing about the current catalogue scan
produces a same-size-class model with sourced evidence of being better. Keep it,
unchanged.

### 2. `qwen2.5:14b` goes — no rescue exists at any quant

Byte math above is decisive: the smallest quant ollama publishes for `qwen2.5:14b`
(`q2_K`, 5.77 GB) leaves ~1,100–2,600 usable KV tokens, and every larger quant
exceeds the weight budget before KV is even counted. Checked a same-class model
from a different, newer family (`qwen3:14b`) specifically to make sure this isn't a
`qwen2.5`-specific weakness — it's worse (9.28 GB, no smaller quant offered at all).
**14B-class is categorically wrong for a ~6 GB budget on this hardware, full stop.**
Uninstall it; it frees 8.99 GB for nothing lost, since it was never fully resident
at any context per ticket 004 anyway.

### 3. No dedicated coder-specialised slot

`qwen2.5-coder:7b-instruct-q4_K_M` is architecturally identical to
`qwen2.5:7b-instruct-q4_K_M` (Δ96 bytes) — it would fit exactly as well, to exactly
the same ~30.7k ceiling. The question is not "does it fit" but "is it worth a second
4.68 GB slot," and the answer is no, for three reasons sourced from the model cards
themselves:

- `qwen2.5`'s own page states it already has "significantly more knowledge and...
  enhanced capabilities in coding and mathematics, due to specialized expert
  models in these domains"
  ([ollama.com/library/qwen2.5](https://ollama.com/library/qwen2.5)) — the
  generalist already absorbed coder-model training, it isn't starting from zero.
- `qwen2.5-coder`'s own marketing benchmarks (EvalPlus, LiveCodeBench, Aider,
  McEval, MdEval, "competitive with GPT-4o") are all demonstrated at the **32B**
  flagship on
  [ollama.com/library/qwen2.5-coder](https://ollama.com/library/qwen2.5-coder);
  the 7B is only credited with "impressive performance in code reasoning" on one
  metric. The advantage this family is famous for isn't the size that fits here.
- Per ticket 005's reframe, docs are the primary local use case and
  `code-agentic` mostly routes to cloud — offline is the rare intersection of
  "no internet" *and* "need to write code right now." Paying a second full model's
  disk cost for a narrow win on a rare path is exactly the specialisation the
  reframe said to stop optimising for.

If a future benchmark shows `qwen2.5:7b-instruct` concretely failing
`code-agentic` tasks offline, revisit. Don't provision for it pre-emptively.

### 4. No spill tier — considered and rejected explicitly

Ticket 004 already showed no bigger model clears the ceiling; this pass confirms it
generalises across families (`qwen3:14b`, `mistral-nemo:12b` fail the same way).
The remaining idea worth checking was a **quality tier at the same size** — a
higher-precision quant of the same 7B, trading context ceiling for per-token
quality on short tasks:

`qwen2.5:7b-instruct-q5_K_M` weighs 5,444,831,648 B (+761,757,696 over `q4_K_M`).
Since `SLOPE` is architecture-driven and quant-invariant, `BASE_q5_K_M ≈
5,270,739,352` B. At ctx=8,192: **5,748,890,008 B (5.75 GB)** — fits, ~250 MB
headroom. At ctx=16,384: **6,227,040,664 B (6.23 GB)** — already past the 6.0 GB
conservative budget and at the edge of the measured 6.0–6.3 GB ceiling. So `q5_K_M`
buys a modest quality bump only up to ~8–10k tokens, in exchange for a second
5.44 GB blob on disk and a context ceiling roughly a third of `q4_K_M`'s. **Not
worth it** — rejected. The realistic choice on this card is the one 7B that fits
well, not a second copy of it at a different trade-off point.

## Coverage across the five task types

| Type | Served offline by `qwen2.5:7b-instruct-q4_K_M`? |
| --- | --- |
| `quick` | Yes — trivially, tiny input/output, nowhere near the ceiling. |
| `doc-edit` | Yes — small–medium input, small output, well inside ~30.7k. |
| `doc-author` | Mostly — medium input + **large** output. Fine for realistic doc lengths; a genuinely long draft (output alone approaching 20–30k tokens) starts eating into the same ~30.7k combined budget the model shares with input. Soft limit, not a hard failure. |
| `doc-review` | **No, plainly.** This type is defined by needing large input across many files. Local caps at ~30.7k input+output combined; cloud starts at 200k+. A real multi-file review will not fit. Offline `doc-review` is only viable for a small file set, not the general case the type exists for. |
| `code-agentic` | **No, plainly, for anything nontrivial.** Large input, large output, and *many* tool calls each round-tripping through the same shared context — this burns the ~30.7k ceiling faster than any other type. Tool-calling capability (confirmed via the `tools` badge) is necessary but not sufficient; there isn't enough context budget on this card for a real multi-file refactor loop. This matters less in practice because `code-agentic` already routes to cloud by default (ticket 005) — the gap is real but rarely hit. |

**Two of five task types cannot be adequately served offline on this hardware:
`doc-review` and `code-agentic`.** Both are exactly the two types the taxonomy
(ticket 005) marks with large input and/or output — the local ceiling (~30.7k) and
cloud's 200k+ starting point are not close enough to paper over. State it, don't
pretend otherwise.

## Total disk cost and what to cut

**Recommended set: `qwen2.5:7b-instruct-q4_K_M` only — 4.68 GB.**

Nothing else clears its own bar: `qwen2.5:14b` (drop, 8.99 GB freed),
`qwen2.5-coder:7b` (no, redundant footprint for a rare use case),
`qwen3:8b`/`14b` (no, unmeasured and tighter-fitting than the incumbent),
`mistral-nemo:12b` (no, same failure mode as 14B one size down),
`llama3.1:8b` (no evidence it beats the incumbent), a `q5_K_M`/`q8_0` quality tier
of the same model (no, rejected above on the byte math).

This isn't a large total, so there's nothing to trim further — the answer to
"what to cut if it's too much" is that it's already at the floor: one model, one
quant, sized to a measured, sourced ceiling.

## Sources fetched (2026-08-24)

- [ollama.com/library](https://ollama.com/library) — full catalogue scrape
- [ollama.com/library/qwen2.5](https://ollama.com/library/qwen2.5), [.../qwen2.5/tags](https://ollama.com/library/qwen2.5/tags)
- [ollama.com/library/qwen2.5-coder](https://ollama.com/library/qwen2.5-coder), [.../qwen2.5-coder/tags](https://ollama.com/library/qwen2.5-coder/tags)
- [ollama.com/library/qwen3](https://ollama.com/library/qwen3), [.../qwen3/tags](https://ollama.com/library/qwen3/tags)
- [ollama.com/library/qwen3-coder](https://ollama.com/library/qwen3-coder), [.../qwen3-coder/tags](https://ollama.com/library/qwen3-coder/tags)
- [ollama.com/library/llama3.1](https://ollama.com/library/llama3.1), [.../llama3.1/tags](https://ollama.com/library/llama3.1/tags)
- [ollama.com/library/llama3.2](https://ollama.com/library/llama3.2)
- [ollama.com/library/llama3.3](https://ollama.com/library/llama3.3)
- [ollama.com/library/gemma2](https://ollama.com/library/gemma2), [ollama.com/library/gemma3](https://ollama.com/library/gemma3)
- [ollama.com/library/mistral](https://ollama.com/library/mistral), [.../mistral/tags](https://ollama.com/library/mistral/tags)
- [ollama.com/library/mistral-nemo](https://ollama.com/library/mistral-nemo), [.../mistral-nemo/tags](https://ollama.com/library/mistral-nemo/tags)
- [ollama.com/library/mistral-small3.2](https://ollama.com/library/mistral-small3.2)
- [ollama.com/library/phi3.5](https://ollama.com/library/phi3.5), [ollama.com/library/phi4](https://ollama.com/library/phi4), [ollama.com/library/phi4-mini](https://ollama.com/library/phi4-mini), [.../phi4-mini/tags](https://ollama.com/library/phi4-mini/tags)
- [ollama.com/library/codegemma](https://ollama.com/library/codegemma), [ollama.com/library/deepseek-coder-v2](https://ollama.com/library/deepseek-coder-v2)
- `registry.ollama.ai/v2/library/<model>/manifests/<tag>` for: `qwen2.5:7b-instruct-{q4_K_M,q5_K_M,q8_0}`, `qwen2.5:14b-instruct-{q2_K,q3_K_S,q3_K_M,q3_K_L,q4_K_M}`, `qwen2.5-coder:7b-instruct-q4_K_M`, `qwen2.5-coder:14b-instruct-q4_K_M`, `qwen3:8b-q4_K_M`, `qwen3:14b-q4_K_M`, `llama3.1:8b-instruct-q4_K_M`, `mistral-nemo:12b-instruct-2407-{q3_K_S,q4_K_M}`
- `registry.ollama.ai/v2/library/qwen3/blobs/sha256:...` and `.../llama3.1/blobs/sha256:...` — attempted, redirected to `dd20bb891979d25aebc8bec07b2b3bbc.r2.cloudflarestorage.com`, blocked by the container firewall (`403 ERR_FIREWALL_BLOCKED`). This is why architecture metadata (block_count / head_count / head_count_kv / embedding_length) could not be sourced for anything beyond `qwen2.5`/`qwen2.5-coder` in this pass.

**Staleness note:** local model releases move monthly (see the long tail of
2026-only families in the catalogue scan above). Re-scrape
[ollama.com/library](https://ollama.com/library) before trusting this file more than
a few months out.
