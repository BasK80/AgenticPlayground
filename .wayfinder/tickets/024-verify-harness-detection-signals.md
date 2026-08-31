---
id: 024
title: Verify live detection signals for opencode and Copilot CLI in pick-model's harness-reachability table
label: wayfinder:task
status: open
assignee:
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
