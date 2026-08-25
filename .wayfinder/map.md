---
title: Model-picking skills for ollama + GHE Copilot
label: wayfinder:map
status: open
---

## Destination

Two portable skills, **installed and verified working**, that let Bas pick the
right model per task across a local ollama instance and GitHub Enterprise
Copilot — biased toward preserving Copilot credits, functional with no network,
and honest about an 8 GB VRAM ceiling.

| Piece | Harnesses | Role |
| --- | --- | --- |
| `pick-model` | opencode + Claude Code + Copilot CLI | Task → model, with reasoning. Switches the model automatically **in opencode only**; elsewhere it prints the switch command. |
| `ollama-curate` | opencode + Claude Code + Copilot CLI | What to pull/drop for the current hardware, covering coding *and* markdown documentation work. Owns the hardware-spec refresh path. |
| `hardware.json` + prefs | shared data files | GPU/VRAM/RAM specs, per-model tier verdicts, remembered per-task-type consent. |

This map carries execution (see Notes): it ends when both skills are written,
wired, and demonstrated routing real tasks — not when a spec exists.

## Notes

- **Tracker: local-markdown** (no issue tracker configured for this repo).
  Tickets are files under `.wayfinder/tickets/`. Frontmatter: `id`, `title`,
  `label` (`wayfinder:<type>`), `status` (`open`/`closed`), `assignee`,
  `blocked_by` (list of ticket ids). A ticket is **claimed** by setting
  `assignee`. The **frontier** = open, unassigned tickets whose `blocked_by`
  ids are all `closed`.
- **This map overrides Wayfinder's plan-only default.** Decision tickets are
  front-loaded; the last four tickets are `task` type and do real work, so the
  build inherits settled answers instead of discovering them late.
- **Domain:** this repo (`ModelSwitcher`) is a spin-off of `AgenticPlayground`,
  a security-hardened dev container. Relevant existing machinery:
  - `.devcontainer/development/llm-switch.sh` — existing provider switcher for
    Claude Code **and** opencode (Azure Foundry / Anthropic key / Anthropic
    OAuth). Knows nothing about ollama or GitHub. **Read-only mount** — changes
    need the `/workspace/apply-*.sh` host-script workflow (see `CLAUDE.md`).
  - `tools/test-opencode-providers.sh` — the pattern for verifying an opencode
    round-trip, including how it handles un-scriptable interactive logins.
  - `.claude/skills/security-test/SKILL.md` — the precedent for a skill declared
    portable across all three harnesses.
  - `.agents/skills/<name>/SKILL.md` is the neutral home for skills;
    `.claude/skills/<name>` are symlinks into it.
- **Skills to consult:** `/grilling` for every decision ticket, `/research` for
  research tickets (it writes findings to a Markdown file in the repo),
  `/write-a-skill` for the two build tickets.

### Settled by charting (do not re-litigate)

1. **Routing policy — cloud by default, local when offline.** *Superseded the
   original three-tier policy* on 2026-08-24; the full spec is
   [Task taxonomy and routing policy](assets/005-taxonomy-and-routing.md). The
   credit lever is *which cloud model*, not local-vs-cloud. Local is **offline-only**
   — justified by offline capability, not by credits. Five inferred axes, five open
   task types, exemplar-first matching, credit-based consent gate that informs and
   never blocks, escalation only on Bas's word.
2. **Drivers are credits + offline capability.** Not privacy — sensitive-data
   routing is out of scope (see below).
3. **Tier is a property of `(model, context length)`, not of the model.** Doc
   work is the long-context case, so the fit prediction takes document size as
   an input.
4. **Advice degrades gracefully.** Actuation is an opencode-only bonus; the
   reasoning must stand alone as text in Claude Code and Copilot CLI.
5. **Discovered, not hardcoded.** The Copilot model list comes from the account
   at refresh time; the ollama list from `/api/tags`.
6. **Offline-first.** No decision may require a network call. `models.dev` and
   `ollama.com` are refresh-time-only sources.
7. **Future-proof: skill text holds the method, data files hold the facts.**
   Anything that can change — GPU, model lists, task types, tier verdicts,
   consent choices — lives in a file the skill maintains, never in prose baked
   into `SKILL.md`. The task taxonomy is therefore **open**: new task types are
   appended as they are met.

### Environment facts already established

- ollama is reachable from the container at `http://host.docker.internal:11434`
  (v0.32.15). Installed: `qwen2.5:14b` (8.99 GB), `qwen2.5:7b` (4.68 GB).
- Hardware: **NVIDIA GPU with 8 GB VRAM**, 32 GB DDR5 system RAM, Intel Core
  Ultra 7 366H (16 cores). **The GPU is invisible from inside the container**
  (`nvidia-smi` absent) — this is exactly why specs must be asked for and
  cached rather than probed.
- `opencode` is v1.18.21. `~/.config/opencode/opencode.json` currently has
  `provider: {}` — nothing configured. The `@opencode-ai` plugin SDK is present
  in that directory's `node_modules`.
- Allowlist: `.githubcopilot.com`, `.ghe.com`, `github.com`, `models.dev` are
  allowed. **`models.github.ai` (GitHub Models marketplace) is NOT** — that path
  is out of scope anyway.
- `gh` is not currently logged in to any host.

## Decisions so far

<!-- one line per closed ticket -->

- [Choose the local model line-up for an 8 GB card covering code and docs](tickets/008-local-model-lineup.md)
  — **keep exactly one model: `qwen2.5:7b-instruct-q4_K_M`** (already installed,
  4.68 GB). Drop `qwen2.5:14b` (frees 8.99 GB) — checked its entire real quant
  ladder, no tag leaves usable headroom, confirmed categorical (not
  `qwen2.5`-specific) against `qwen3:14b`. No coder-specialised slot
  (`qwen2.5-coder:7b` is architecturally identical, not worth a second disk slot
  for a rare offline-and-coding intersection) and no spill/quality tier (all
  alternatives fail the same weights-only budget check, or buy too little
  context for a second blob). Sourced against the live ollama library, not
  memory — full byte math and catalogue scan:
  [local model lineup asset](assets/008-local-model-lineup.md). Plainly:
  `doc-review` and `code-agentic` cannot be served offline on this card;
  `quick`/`doc-edit`/`doc-author` can. Unblocks
  [Write the ollama-curate skill](tickets/010-write-ollama-curate.md). *(This
  ruled out a fast, GPU-resident spill tier only — whether a deliberately slow,
  CPU/RAM-bound tier is worth a slot, and whether MoE changes that, was not
  measured and is split into
  [ticket 017](tickets/017-cpu-ram-slow-tier.md).)*
- [Discover which models GHE Copilot actually offers this account](tickets/003-discover-copilot-models.md)
  — **25 models** on `info-support.ghe.com` (API base
  `https://copilot-api.info-support.ghe.com/v1`), all active, tool- and
  reasoning-capable, 200k–1.05M context; device login done for both opencode and
  Copilot CLI; `opencode models github-copilot --verbose` is a trustworthy
  re-derivation command because the list is **real entitlement, not the models.dev
  catalogue** (11 catalogued models absent, 3 uncatalogued ones present). Premium
  -request multipliers are **not** in the metadata — split into ticket 013. Full
  table: [entitlement asset](assets/003-copilot-entitlement.md). *(Its claim that
  the `cost` field is the wrong currency was corrected by the next entry.)*
- [Determine the premium-request multiplier for each available Copilot model](tickets/013-premium-request-multipliers.md)
  — **premise was wrong: multipliers are legacy.** Copilot moved to **usage-based
  token billing on 1 June 2026**; Bas's currency is **GitHub AI Credits**
  (1 = $0.01; Business 1,900/user/mo, Enterprise 3,900, pooled, overage billed not
  cut off). The metadata `cost` field **is** the right ranking signal — all 25
  models verified against GitHub's published rates. Traps: `-fast` under-priced
  2×, long-context tiers up to 2× (threshold unpublished), **cached input 10×
  cheaper**. No 0× models exist. Effort variants cost extra. **~23× spread between
  cheapest and dearest model, and the credits case for routing doc work locally is
  much weaker than assumed — local's solid justification is offline capability.**
  Details: [credit-cost asset](assets/013-copilot-credit-costs.md).
- [Decide how skills are packaged so opencode, Claude Code and Copilot CLI all find them](tickets/001-skill-packaging.md)
  — **one canonical `.agents/skills/<name>/SKILL.md`, symlinked twice.** New
  symlink `.opencode/skill/<name>` for opencode (verified working live; opencode's
  home-directory auto-load and its `skills.paths` config were both tested and do
  **not** cover this project — `skills.paths` is confirmed broken in 1.18.21).
  **Copilot CLI needs nothing extra** — `.agents/skills/` is a native project-scope
  discovery path, verified with `copilot skill list --json` against the real repo
  skills. Ticket 002's hypothesis that `OPENCODE_DISABLE_CLAUDE_CODE_SKILLS` meant
  opencode already saw `.claude/skills/` was **tested and refuted**. Actuation
  stays a separate opencode plugin, per ticket 002. Detail:
  [skill packaging asset](assets/001-skill-packaging.md).
- [Design the schema for hardware.json, model cache and remembered preferences](tickets/007-data-schema.md)
  — files live at **`/workspace/.model-picker/{hardware,models,preferences}.json`**
  (gitignored), *not* under `$HOME` — forced by a checked fact:
  `docker-compose.yml` bind-mounts `/workspace` from the host, but
  `~/.config/opencode`/`~/.local/share/opencode` are **not** persistent named
  volumes, so **this session's opencode/Copilot logins will be wiped on the next
  container rebuild** (flagged to Bas, not ticketed — outside this map's
  destination). Three files, not one, confirmed by walking five routing
  decisions on paper; one of those walkthroughs found that
  [ticket 015](tickets/015-seat-type-and-credit-balance.md) had conflated a
  near-constant (seat type/allowance — self-served by `pick-model`) with a
  genuinely hard question (remaining balance) — **un-conflated, and ticket 011 no
  longer blocks on 015.** `costOverride` pattern fixes ticket 014's known pricing
  error without touching raw metadata; `ollamaKvCacheAssumptions` gives ticket
  016 a concrete invalidation trigger. Detail:
  [data schema asset](assets/007-data-schema.md).
- [Determine whether opencode can switch its own model mid-session](tickets/002-opencode-model-switching.md)
  — **yes.** `POST /api/session/{sessionID}/model` with
  `{"model":{"providerID","id","variant"?}}` → 204, switching the model for
  subsequent turns; `variant` sets reasoning effort and persists. **"Recommend +
  switch" survives intact.** ⚠ **The API does not validate model existence** — a
  bogus id *or* providerID returns 204 and is stored, so validate against
  `GET /api/model` first. The real constraint is *addressing* the server: a prose
  skill cannot find it (no env var, no port file, random default port), but a
  **plugin** gets `serverUrl` + client and can register a slash command — so the
  opencode half should be a plugin. Also found: **opencode natively reads Claude
  Code skills**, `opencode.json` stays `provider:{}` because auth.json drives
  provider discovery, and `OPENCODE_MODELS_PATH`/`_DISABLE_MODELS_FETCH` can pin
  the catalogue offline. Detail:
  [model switching asset](assets/002-opencode-model-switching.md).
- [Define the open task taxonomy and its routing table](tickets/005-task-taxonomy.md)
  — **replaced the three-tier policy: cloud by default, local offline-only.** Five
  axes inferred and displayed, never asked (reasoning depth, agentic depth,
  **stakes**; input size — which *is* the context length — and expected output
  size). Five open types: `quick`, `doc-edit`, `doc-author`, `doc-review`,
  `code-agentic`. Matching is **exemplar-first with axis inference as fallback**,
  because the skill's own reasoning costs tokens in the active session. Consent
  gate guards **credits** as a % of allowance, **informs and never blocks**;
  escalation only on Bas's word, floor shifts after 2–3 failures; spanning tasks →
  more demanding type wins; every default ships marked `assumed`. Spec:
  [taxonomy and routing asset](assets/005-taxonomy-and-routing.md).
- [Derive the VRAM fit formula that decides fast tier vs spill tier](tickets/004-vram-fit-formula.md)
  — `total = BASE + (kv_bytes_per_token × 1.02) × ctx`, **byte-exact** once two
  probes fix `BASE`/`SLOPE`; metadata-only prediction is within 1.8–2.8%.
  `head_dim` must be derived (`embedding_length / head_count`) as
  `key_length`/`value_length` are absent. **Usable VRAM is ~6.3 GB, not 8 GB**, and
  it is not constant — predict against 6.0 GB, correct from `/api/ps`.
  **`qwen2.5:7b` misses its advertised 32k context by ~70 MB** (max ~30.7k);
  **`qwen2.5:14b` can never be GPU-resident here** (62% GPU at 4k, 40% at 32k), so
  the spill tier may not be worth having on this card. KV is f16 and quantising it
  is the cheapest local win — split into ticket 016. Measurements:
  [VRAM fit asset](assets/004-vram-fit-formula.md).

- [Decide how the skills detect that cloud is unreachable](tickets/006-offline-detection.md)
  — **one `curl` per target, classified by exit code + a `-D` header dump.**
  `X-Squid-Error: ERR_FIREWALL_BLOCKED` (measured live) uniquely identifies an
  allowlist block — the one failure mode that must never be phrased as
  offline. Genuine offline and a stale firewall image are **not**
  distinguishable from inside the container (both are ordinary squid error
  templates); the skill surfaces the raw signal rather than guessing.
  **Ollama needs the identical treatment** — measured: its traffic is also
  proxied through Squid and allowlisted only via a live, possibly TTL-scoped
  `fw allow`, so it can go "blocked" the same way cloud can. Verdict cached in
  `preferences.json`, 60s TTL, both directions — satisfies invariant 6 (no
  decision *requires* a network call). Five message variants specified
  (online / blocked / offline / proxy-layer-unreachable / both-down). Unblocks
  [Write the pick-model skill](tickets/011-write-pick-model.md). Detail:
  [offline detection asset](assets/006-offline-detection.md).

- [Measure whether a CPU/RAM-bound slow tier is worth a dedicated model, and whether MoE changes the pick](tickets/017-cpu-ram-slow-tier.md)
  — **yes: add `qwen3-coder:30b-a3b-q4_K_M` (MoE) as a third, dedicated slow
  tier.** Measured live (18.6 GB pull, real generations, not projected): MoE
  decodes **~2.9–3.4x faster than the dense `qwen2.5:14b`** at every context
  tested (17.87 vs 6.15 tok/s at ctx≈4k; 12.69 vs 3.74 tok/s at ctx≈8k) —
  confirms decode cost tracks *active* parameters (8-of-128 experts), not
  resident size. GPU partial offload turned out nearly irrelevant to both
  (±2–14%) — CPU/RAM bandwidth dominates regardless of VRAM-resident
  fraction, so ticket 004's "% GPU-resident" is not a usability proxy. Floor:
  a ~500–1000 token turn under ~2 minutes ("emergency fallback," not
  interactive) — MoE clears it at both tested context lengths, dense only at
  short context. RAM fits comfortably (~20 GB in 32 GB, KV cache cheap by
  construction). **Ticket 008's fast-tier pick and its drop of `qwen2.5:14b`
  both stand unchanged** — this adds a slot for `doc-review`/`code-agentic`
  offline capability, it doesn't replace the fast tier. Capability claim, not
  quality (no eval run) — ships `assumed`. Unblocks
  [Write the ollama-curate skill](tickets/010-write-ollama-curate.md) (its
  last remaining blocker). Detail:
  [slow-tier asset](assets/017-cpu-ram-slow-tier.md).

- [Write the ollama-curate skill](tickets/010-write-ollama-curate.md) — **built**
  (this map's Notes override plan-only for `task` tickets):
  `.agents/skills/ollama-curate/{SKILL.md,REFERENCE.md}`, symlinked into
  `.claude/skills/` and `.opencode/skill/` per ticket 001, verified discovered
  natively by both Claude Code and `copilot skill list --json`. Carries the
  VRAM-tiering formula (ticket 004), the slow-tier evaluation method (ticket
  017), and coverage-gap/pull-drop logic as **method only** — every model
  name, size, and hardware number is read live from
  `.model-picker/{hardware,models}.json`, never hardcoded. `models.json`
  updated with the ticket 017 MoE slow-tier entry and `qwen2.5:14b`'s
  decode-throughput numbers (confirms its drop). Deliberately does **not**
  touch `preferences.json` (that's `pick-model`'s file). Detail is the built
  files themselves — see
  [the ticket's resolution](tickets/010-write-ollama-curate.md) for exactly
  what was written.

- [Wire ollama and GHE Copilot as opencode providers](tickets/009-wire-opencode-providers.md)
  — **both wired and round-tripped live.** `ollama`: hand-written
  openai-compatible provider stanza (`@ai-sdk/openai-compatible`, baseURL
  `http://host.docker.internal:11434/v1`, model id `ollama/<tag>`) — not
  cataloged on models.dev, per ticket 003. `github-copilot`: nothing new
  needed, `auth.json` already covers it (ticket 003); model id
  `github-copilot/<model>`. The real `llm-switch.sh` collision (its
  `_opencode_write_config()` replaced the *whole* `.provider` key on every
  `use-*` call, silently wiping a hand-added `ollama` entry) is **fixed** —
  patched from the host via `apply-opencode-provider-merge.sh` (the file is a
  read-only bind mount) to merge/clear only the `anthropic`/`azure` keys.
  Verified live post-patch: `ollama` survives both a real `anthropic-key`
  write and a `clear`. ⚠ **Process note, not a design decision:** an earlier
  session tested this collision by running `use-anthropic-key`/`use-anthropic`
  for real, which also rewrote the live, shared `~/.claude/settings.json` and
  broke Bas's actual `claude` login — the re-verification this time called
  `_opencode_write_config` directly instead, touching only opencode's config.
  No new asset — detail is in
  [the ticket's resolution](tickets/009-wire-opencode-providers.md). Unblocks
  the last blocker on [Write the pick-model skill](tickets/011-write-pick-model.md)
  besides [ticket 014](tickets/014-fast-and-longcontext-pricing.md).

- [Pin down the -fast variant pricing and the long-context tier threshold](tickets/014-fast-and-longcontext-pricing.md)
  — **only `claude-opus-4.8-fast` has a documented rate** (2×, confirmed
  directly): $10/$1(cached)/$12.50(cache-write)/$50. `-4.6-fast`/`-4.7-fast`
  have **no individually published rate anywhere** (a live GitHub-staff-unanswered
  community thread confirms the gap is real) — override both to 2× but mark
  `assumed`, not `measured`. **The ticket's own premise on the long-context
  threshold was wrong — it *is* published**: `gpt-5.4`/`gpt-5.5`/`gpt-5.6-sol`/`gpt-5.6-terra`
  engage above **272K input tokens**, `gpt-5.6-luna` above **200K**; applied
  automatically per-request against a single model id (medium confidence —
  structural inference, not stated in prose); re-derived from the docs that
  **exactly 5 of the 25 entitled models** carry a long-context tier at all.
  Surfaced a uniform **+10% data-residency surcharge** (unverified scope and
  stacking) split into
  [ticket 018](tickets/018-data-residency-surcharge.md) rather than resolved
  here. Detail: [pricing asset](assets/014-fast-and-longcontext-pricing.md).
  **Unblocks [Write the pick-model skill](tickets/011-write-pick-model.md) —
  its last blocker, now fully open.**

- [Establish Bas's seat type and how to read the remaining AI credit pool](tickets/015-seat-type-and-credit-balance.md)
  — **the shared-pool remaining balance is genuinely out of reach**: GitHub's
  billing API gates it behind enterprise/org admin or billing-manager role,
  and Bas confirmed he's a regular member — matches the ticket's own
  "acceptable outcome" branch. **But a third option surfaced that the ticket
  didn't anticipate:** a per-user AI-credit endpoint exists
  (`/users/{username}/settings/billing/ai_credit/usage`), and Bas confirmed
  live, via the web UI, that he can see his own usage with no admin rights.
  A tempting corroboration (a June-2026 changelog adding `ai_credits_used`)
  turned out to be a **different, still admin-gated API** — caught by
  checking, not assumed. `pick-model` ranks by relative cost only, per
  ticket 013/014, and may optionally surface Bas's own recent consumption as
  a degradable extra — not built here, flagged for
  [Write the pick-model skill](tickets/011-write-pick-model.md). No separate
  asset — detail is in
  [the ticket's resolution](tickets/015-seat-type-and-credit-balance.md).

- [Decide whether to enable flash attention and q8_0 KV cache on the host](tickets/016-kv-cache-quantisation.md)
  — **skip it for now**, confirmed with Bas. The projected gain (+2,068
  tokens, ~6.7%, on a model that already reaches ~30.7k of its own 32k
  trained ceiling at f16) doesn't clear the bar against ollama's own docs
  naming Qwen2's high GQA ratio as the worst case for quantization quality
  loss, and it's a global setting with no per-model control. Does nothing for
  the 14b (already dropped in [ticket 008](tickets/008-local-model-lineup.md)
  for unrelated reasons). **Revisit only if a long-trained-context local
  model (e.g. 128k) enters the lineup** — the `ollamaKvCacheAssumptions`
  fingerprint mechanism ([ticket 007](tickets/007-data-schema.md)) is already
  in place for that day. Kept regardless: ollama defaults context length
  from VRAM (`<24 GiB → 4k`), so prefer per-request `num_ctx` over a global
  `OLLAMA_CONTEXT_LENGTH` wherever the ollama call is actually made. No
  separate asset — detail in
  [the ticket's resolution](tickets/016-kv-cache-quantisation.md).

## Not yet specified

- **The calibration loop.** How a bad recommendation gets fed back so the skill
  improves — correcting a tier verdict is already covered, but correcting a
  *routing* choice is not. Too vague to ticket until the prefs schema exists.
- **Multi-model workflows.** Draft with a cheap model then review with a better
  one, or vice versa. Attractive for credits but no clear shape yet — and now
  partly overlapping the benchmark effort, which is out of scope.

## Out of scope

- **Sensitive-data routing.** Bas is building a separate approach for truly
  sensitive information; GHE is acceptable for the code he edits. Privacy is
  therefore not a design axis for these skills.
- **Model *switching* for Claude Code and Copilot CLI.** Both get the advice half
  of `pick-model` only. Claude Code cannot talk to ollama at all — it speaks the
  Anthropic API shape — so switching it would require a proxy shim.
- **An ollama-to-Claude-Code proxy shim.** A separate effort if ever wanted.
- **GitHub Models (`models.github.ai`).** A different product with different
  auth and entitlement, and firewall-blocked. GHE Copilot is the chosen surface.
- **A model benchmarking / evaluation skill.** Bas asked for the ability to test
  speed and quality of local and cloud models per task, judged by a more capable
  model. Ruled out of *this* destination on 2026-08-24 as its own effort: an eval
  harness (fixtures, judge prompts, rubrics, sampling, result storage, comparison
  reporting) is plausibly larger than both skills here combined, and it **needs
  this map's taxonomy as its input** — it measures models *per task type*, so
  building it first would benchmark against categories not yet settled. This map
  reserves the schema slots it will write into (folded into
  [the data schema ticket](tickets/007-data-schema.md)) and ships every default
  marked `assumed`, giving the benchmark an obvious later job: convert `assumed`
  to `measured`. Deserves its own map.
