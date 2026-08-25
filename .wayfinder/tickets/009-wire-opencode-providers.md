---
id: 009
title: Wire ollama and GHE Copilot as opencode providers
label: wayfinder:task
status: closed
assignee: Bas Kloet
blocked_by: [002, 003]
---

## Question

Make opencode actually able to reach **both** backends, and verify a real
round-trip against each. Until this is done, `pick-model` can recommend but not
switch — there is nothing to switch to.

## Starting state

`~/.config/opencode/opencode.json` is literally `{"provider": {}}` — nothing is
configured. So this ticket produces the first working provider config in the repo.

## Work

1. Configure the **ollama** provider against `http://host.docker.internal:11434`
   (v0.32.15, models `qwen2.5:7b` and `qwen2.5:14b`). Note ollama runs on the
   **host over plain HTTP**, which `TODO.md` already flags as a known wrinkle
   (*"Allow usage of an ollama instance running on a non-https port on the
   host"*) — confirm the proxy/allowlist does not interfere with a
   host-internal, non-HTTPS target.
2. Configure the **github-copilot** provider using the auth established in
   [Discover which models GHE Copilot actually offers this account](003-discover-copilot-models.md).
3. Verify a real completion through each, using the round-trip pattern from
   `tools/test-opencode-providers.sh` (`opencode run -m <provider>/<model>` with
   a sentinel string). Extending that script to cover the two new providers is
   the natural form of this deliverable.
4. Decide **where the config lives**, and this is the important part:
   `.devcontainer/development/llm-switch.sh` already owns
   `~/.config/opencode/opencode.json` — its `_opencode_write_config()` **replaces
   the whole `provider` key** on every `use-*` call. So a naively hand-added
   ollama provider would be silently wiped the next time Bas runs
   `use-anthropic` or opens a new shell (`_llm_apply_persisted` re-applies on
   every interactive shell). Resolve this collision explicitly — either extend
   `llm-switch.sh` to preserve/merge the new providers, or move ownership.
5. `llm-switch.sh` is a **read-only bind mount**. Per `CLAUDE.md`, changes to it
   must ship as an executable `/workspace/apply-*.sh` script for Bas to run
   **from the host** — do not attempt an in-place edit.

## Established by ticket 003 (2026-08-24) — the Copilot half is largely done

- **Copilot auth is complete.** Both `opencode providers login -p
  github-copilot` (GHE offered as an interactive option — no `--host` flag
  needed) and `copilot login --host https://info-support.ghe.com` succeeded.
- **Enterprise API base:** `https://copilot-api.info-support.ghe.com/v1`, driver
  `@ai-sdk/anthropic`, endpoint `messages` for the Claude models.
- **25 models enumerate correctly** via `opencode models github-copilot
  --verbose` — see [the entitlement asset](../assets/003-copilot-entitlement.md).
  So step 2 below is essentially verified; what remains is the ollama side and
  the `llm-switch.sh` collision.
- **models.dev has no plain `ollama` provider** — only `ollama-cloud`
  (`https://ollama.com/v1`, `@ai-sdk/openai-compatible`). A *local* ollama
  instance is therefore **not** a catalogued provider: expect to hand-write an
  openai-compatible provider entry against
  `http://host.docker.internal:11434/v1` and supply model metadata yourself.

## Update from ticket 002 (2026-08-24) — the collision risk may be moot

`~/.config/opencode/opencode.json` is **still `{"provider": {}}`** after Bas's
successful Copilot login: the credential lives in `auth.json` and **providers are
discovered from it**, so no provider stanza is needed for Copilot to work.

**That materially reduces the `llm-switch.sh` collision** described in step 4 —
if nothing needs to live under `provider`, there is nothing for
`_opencode_write_config()` to wipe. **Verify this holds for a local ollama
provider too**, which is *not* catalogued on models.dev and may genuinely require
a config stanza — in which case the collision is real after all and step 4 stands.

Also note config is patchable over HTTP (`PATCH /config`, `PATCH /global/config`),
which may be a cleaner mechanism than editing the file at all.

## Blocked by

- [Determine whether opencode can switch its own model mid-session](002-opencode-model-switching.md)
  — **closed**; switching is a live HTTP API, so config-file editing is not the
  mechanism.
- [Discover which models GHE Copilot actually offers this account](003-discover-copilot-models.md)
  — **closed**; supplied the auth, the API base URL and the model ids.

## Resolution must record

The working provider stanzas, the exact model-id syntax for each side, and how
the `llm-switch.sh` collision was resolved.

## Resolution (2026-08-25)

**Both backends wired and round-tripped for real.**

- **ollama**: hand-written openai-compatible stanza in
  `~/.config/opencode/opencode.json` (not cataloged on models.dev, confirmed by
  ticket 003) — `npm: "@ai-sdk/openai-compatible"`, `options.baseURL:
  "http://host.docker.internal:11434/v1"`, with a `models` map listing
  `qwen2.5:7b` and `qwen3-coder:30b-a3b-q4_K_M`. Model id syntax:
  `ollama/<tag>`. Round-tripped live: `opencode run -m ollama/qwen2.5:7b
  "..."` echoed the sentinel. Proxy/allowlist did not interfere with the
  plain-HTTP host-internal target — no firewall block observed.
- **github-copilot**: nothing new to configure — ticket 003 already
  established this works via `auth.json`, not a `provider` stanza. Model id
  syntax: `github-copilot/<model>` (e.g. `github-copilot/claude-haiku-4.5`).
  Round-tripped live: got a real reply over the API (the model declined to
  literally echo the sentinel string, which is model behavior, not a
  plumbing failure — connectivity and auth are confirmed).
- **The `llm-switch.sh` collision (step 4) was real and is now fixed.** A
  wayfinder session two runs ago tested it by running `use-anthropic-key` /
  `use-anthropic` for real, which also rewrote the live, shared
  `~/.claude/settings.json` (the `claude` Docker volume) and broke Bas's
  actual `claude` login until he re-ran `claude login` — a costly way to
  confirm the hypothesis. Fixed via
  `/workspace/apply-opencode-provider-merge.sh` (run from the host, since
  `llm-switch.sh` is a read-only bind mount — backed up to
  `llm-switch.sh.bak`): `_opencode_write_config()` now merges/clears only the
  `anthropic`/`azure` keys under `.provider`
  (`del(.anthropic, .azure) + $patch`) instead of replacing the whole
  `.provider` object. Verified **live, after the host applied the patch**, by
  sourcing the real `llm-switch.sh` and calling the real
  `_opencode_write_config` directly (bypassing `_claude_write_settings`
  entirely, so Claude's login state was never touched this time): the
  `ollama` provider survived both a real `anthropic-key` write and a `clear`.
  `llm-mode` and `~/.claude/settings.json` confirmed untouched throughout, and
  the ollama round-trip was re-verified afterward.
- **Where the config lives:** `~/.config/opencode/opencode.json`'s
  `.provider` key, same file `llm-switch.sh` already owned for Anthropic/Azure
  — no ownership move needed once the merge fix was in place.
- **Not done here:** extending `tools/test-opencode-providers.sh` with a
  dedicated ollama/github-copilot phase (its existing phases only cover the
  two Anthropic auth modes). The round-trips above were done ad hoc instead.
  Left as a follow-up if the round-trip needs to be repeatable/CI-able later —
  not blocking anything on this map, so not ticketed.
