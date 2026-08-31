---
id: 024
title: Verify live detection signals for opencode and Copilot CLI in pick-model's harness-reachability table
label: wayfinder:task
status: closed
assignee: opencode
blocked_by: []
---

## Question

Ticket 023 added a **Harness reachability** table to `pick-model`'s
`REFERENCE.md` so routing only recommends models the current harness can
actually reach. The Claude Code row is live-verified (`$CLAUDECODE == "1"`,
checked against a real session). The **opencode** and **GitHub Copilot CLI**
rows have no live-verified positive signal — they're currently just "assume
this row when Claude Code's signal doesn't fire," which works by
elimination for exactly two harnesses but gives no real signal to tell
opencode and Copilot CLI apart from each other, and is unverified either
way.

Run a real session inside opencode and inside the Copilot CLI, dump `env`
(the same way ticket 023 did for Claude Code — `$CLAUDECODE`,
`$CLAUDE_CODE_ENTRYPOINT`, `$AI_AGENT` were all found that way), and record
whichever variable(s) reliably and positively identify each harness. Update
the Harness reachability table in `pick-model`'s `REFERENCE.md` with the
confirmed signals, replacing the by-elimination placeholder for both rows.

Also settle, while there: whether opencode's `anthropic` reachability truly
depends on `llm-switch.sh`'s live `llm-mode` state (ticket 023's inline
caveat) or whether there's a more direct signal (e.g. reading opencode's own
`auth.json`/config) — same live-verification standard as the harness
signal itself.

## Resolution

Resolved live inside a real opencode session. `env` dumped in full; findings:

**opencode signal — `$OPENCODE == "1"` (confirmed).** Present in this
session (`OPENCODE=1`, `OPENCODE_PID=86649`). `$AGENT=1` is also present but
not opencode-specific — do not use it alone. This is a positive signal that
unambiguously separates opencode from both Claude Code (`$CLAUDECODE`) and
Copilot CLI (sets neither).

**Copilot CLI signal — by elimination, now unambiguous.** The native Copilot
CLI binary (`@github/copilot-linux-x64/copilot`, v1.0.81) was inspected via
`strings` — no harness env var is injected by the binary or its npm loader.
The `gh` binary's own string table shows `COPILOT_CLI`/`OPENCODE`/`CLAUDE_CODE`
as labels it uses for user-agent strings, not env vars it exports to the
agent's environment. With opencode now having a positive signal, the two-way
elimination is unambiguous: Copilot CLI = `$CLAUDECODE` absent AND `$OPENCODE`
absent.

**Anthropic reachability in opencode — direct config check, not `llm-mode`.**
`llm-switch.sh`'s `llm-mode` reflects the Claude Code provider, not
opencode's. The direct signals are:
- Key-based: `~/.config/opencode/opencode.json` → `provider.anthropic`
  present (written by `use-anthropic-key`).
- OAuth-based: `~/.local/share/opencode/auth.json` → top-level `anthropic`
  key (written by `opencode auth login → Anthropic`).
Currently neither is set — only `github-copilot` is in `auth.json` — which
correctly reflects that Anthropic isn't wired for opencode in this
environment.

`REFERENCE.md`'s Harness reachability table updated accordingly.
