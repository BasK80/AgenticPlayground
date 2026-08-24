# Data schema — hardware.json, models.json, preferences.json

Prototyped **2026-08-24** as real files with real values, then walked through
five routing decisions on paper. Asset of
[Design the schema for hardware.json, model cache and remembered preferences](../tickets/007-data-schema.md).

The files themselves are the deliverable and live at
`/workspace/.model-picker/{hardware,models,preferences}.json` — read them
directly for the exact current shape; this asset explains the *decisions*
behind that shape.

## Location: `/workspace/.model-picker/`, not `$HOME`

**This was forced by a fact, not a preference — checked, not assumed.**
`docker-compose.yml` bind-mounts `/workspace` straight from the host
(`..:/workspace:cached`) — genuine persistent disk. `$HOME` is **not**
generally persistent: only specific subpaths are named volumes (`.claude`,
`.claude-json`, npm/pip/uv/cargo caches). **`~/.config/opencode` and
`~/.local/share/opencode` are absent from that list.**

**Consequence beyond this ticket's scope, flagged for Bas separately:** the
opencode and Copilot CLI device logins completed earlier this session live under
those unmounted paths and will be **wiped on the next container rebuild** —
and `CLAUDE.md` explicitly instructs rebuilding whenever DNS or proxy issues
appear, so this isn't hypothetical. Fixing auth persistence is a devcontainer
infrastructure concern, outside this map's destination — not ticketed here,
just surfaced.

For *this* ticket, the fact settles the location question directly: anything
meant to survive a rebuild must live under `/workspace`. Bas chose
**`.model-picker/`** at repo root — mirroring the existing `.wayfinder/`
convention — over `.agents/state/` (would mix machine-local state into the
version-controlled skills home) or scattered root dotfiles. Gitignored, same
precedent as `**/.claude/settings.local.json`.

## Three files, not one — confirmed by walking real decisions

Each has a distinct lifecycle and owner:

| File | Changes | Owner |
| --- | --- | --- |
| `hardware.json` | rarely (a GPU swap, a new seat) | `ollama-curate` (hardware); see below for `creditAllowance` |
| `models.json` | on refresh, and after every local run (tier correction) | `ollama-curate` (`ollama/*` keys, discovery); `pick-model` (narrow tier corrections only) |
| `preferences.json` | continuously, as Bas works | `pick-model` only |

**Write convention: read-modify-write, merging only owned keys** — the same
discipline `llm-switch.sh`'s `_opencode_write_config()` already uses in this
repo ("merges only the `provider` key so user settings survive"). This is a
single-user, sequential-tool-call tool, not a concurrent service, so no
locking is designed for; noted as an accepted simplification.

**Schema versioning:** a top-level `"schemaVersion": 1` integer in every file.

## Five decisions walked through on paper — one gap found, four confirmed clean

1. **`doc-edit`, ~10k tokens total →** matches `gpt-5.6-luna` via the online
   default, cost computes to ~0.4 credits directly from `costPerMTokUSD`. Clean.
2. **`code-agentic`, ~120k tokens →** matches `claude-opus-5`, computes to
   ~100 credits. **Here the schema broke**: the consent gate is specified as "%
   of monthly allowance" but `hardware.json.creditAllowance.monthlyCredits` is
   `null` — [seat type and balance](../tickets/015-seat-type-and-credit-balance.md)
   is unresolved. See the resolution below.
3. **`doc-review` with no local model that fits →** `preferences.json` expresses
   this explicitly as `offline.modelKey: null` with a note, rather than
   crashing or silently degrading to a bad match. Clean — this was one of
   [ticket 005](../assets/005-taxonomy-and-routing.md)'s requirements
   ("say plainly which task types cannot be served offline").
4. **Tier correction after a real run →** `fitFormula.slopeSource` moves from
   `"metadata_x1.02_unfitted"` to `"measured"` once two non-spilled probes exist,
   exactly the mechanism [ticket 004](004-vram-fit-formula.md) needs for future
   models. Clean.
5. **Escalation and floor-shift →** `failureCounters` keyed by `modelKey` inside
   each task type accumulates; the two-to-three-strike rule from
   [ticket 005](005-taxonomy-and-routing.md) reads directly off it. Clean.

## The gap found, and how it's resolved

**`monthlyCredits` (a near-constant: 1,900 or 3,900 depending on seat type) was
conflated in ticket 015 with `remaining balance` (genuinely hard — may need
admin access).** Blocking the whole router on the harder question was
unnecessary. **Resolution: `pick-model` self-serves `monthlyCredits`** — the
first time it needs the consent gate and finds `creditAllowance.seatType` null,
it asks Bas "Business or Enterprise?" once and caches the answer in
`hardware.json`, exactly like `ollama-curate` already does for hardware specs.
The harder *remaining-balance* half stays in
[ticket 015](../tickets/015-seat-type-and-credit-balance.md), now scoped down.

**Consequence: [Write the pick-model skill](../tickets/011-write-pick-model.md)
is NOT blocked on ticket 015** — it owns asking for seat type itself. Ticket
015 is re-scoped to the balance-reading question only, decoupled from being a
build blocker.

## `costOverride`: correcting known-wrong metadata without silently editing it

`claude-opus-4.8-fast` in `models.json` demonstrates the pattern for
[ticket 014](../tickets/014-fast-and-longcontext-pricing.md)'s known 2× error:
the raw `costPerMTokUSD` field is left as opencode reports it (wrong), and a
`costOverride` object sits alongside it with the corrected
`effectiveCostPerMTokUSD` and a `reason`. **Routing code must read
`costOverride.effectiveCostPerMTokUSD` when present, never the raw field
directly** — this needs to be an explicit, testable rule in
[pick-model](../tickets/011-write-pick-model.md), not a convention hoped for.

## Invalidation fingerprint for the KV cache assumption

`models.json` carries a top-level `ollamaKvCacheAssumptions` block
(`flashAttention`, `kvCacheType`) that every ollama `fitFormula` implicitly
depends on. If [ticket 016](../tickets/016-kv-cache-quantisation.md) is ever
acted on, this fingerprint stops matching reality and **every** ollama
`slopeSource` must be invalidated back to metadata-only until re-measured —
this is the concrete answer to "needs an invalidation trigger, not just a
refresh command" from the ticket's own content list.

## First-run / missing-file behaviour

If `.model-picker/` or any file inside it is absent, the owning skill creates it
fresh: `ollama-curate` asks for hardware specs, `pick-model` asks for seat type
when first needed. Never guess silently — every asked fact gets a
`lastConfirmed`/`source` marker so staleness is visible, per map invariant 7.
