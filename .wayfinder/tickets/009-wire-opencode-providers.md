---
id: 009
title: Wire ollama and GHE Copilot as opencode providers
label: wayfinder:task
status: open
assignee:
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
