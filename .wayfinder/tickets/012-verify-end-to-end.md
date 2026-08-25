---
id: 012
title: Verify both skills end to end, online and offline
label: wayfinder:task
status: open
assignee:
blocked_by: [010, 011]
---

## Question

Do the skills actually work, in Bas's hands, on real tasks? This ticket closes
the map — the destination is "installed and verified working", not "written".

## Scenarios to run

1. **Doc work routes local.** A real markdown editing task against something in
   `docs/` picks a fast-tier local model and switches opencode to it.
2. **Agentic coding routes to cloud.** A multi-file refactor picks GHE Copilot.
3. **Spill tier asks first, then stops asking.** A task that needs the 14B class
   prompts for consent, and the *second* task of that type does not.
4. **Offline opens the gate.** With cloud unreachable, routing falls back to
   local without asking — and a *firewall-blocked* request is reported as a
   misconfiguration instead, not as offline.
5. **Portability.** `pick-model` gives advice in Claude Code and Copilot CLI and
   states clearly that switching is opencode-only. `ollama-curate` works in all
   three.
6. **First-run and refresh.** With the data files absent, the skill asks for
   hardware specs and caches them. A refresh re-asks. A stale profile is visible.
7. **Tier self-correction.** After a local run, the measured `/api/ps` verdict is
   written back and a wrong prediction is corrected.

## Also confirm

- **The `llm-switch.sh` collision is really fixed.** Run `use-anthropic` and open
  a fresh shell, then check the ollama/copilot providers are still in
  `~/.config/opencode/opencode.json`. `_llm_apply_persisted` runs on every
  interactive shell and `_opencode_write_config` replaces the whole `provider`
  key — this is the most likely way the wiring silently rots.
- No decision path made a network call.

## Blocked by

- [Write the ollama-curate skill](010-write-ollama-curate.md) — **closed**
- [Write the pick-model skill](011-write-pick-model.md) — **closed**: both
  artifacts built, packaging verified in all three harnesses, and the
  actuation plugin's tool call was round-tripped live for **both** `ollama`
  and (with real credit spend) `github-copilot` — the github-copilot pass
  caught and fixed a real bug (validation was reading an endpoint that
  silently omits github-copilot models entirely). What's still unexercised:
  none of the skill's *reasoning* paths (matching, offline detection,
  consent, escalation) were driven by a real routing decision — that's
  squarely this ticket's job. See [its resolution](011-write-pick-model.md)
  for exactly what was and wasn't covered.

## On completion

Update `GOAL.md` and `TODO.md` if this effort resolved either of the standing
ideas there (the non-HTTPS host ollama item is directly related), and close the
map.
