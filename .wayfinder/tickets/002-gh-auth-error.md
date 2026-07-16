---
id: 002-gh-auth-error
title: "Fix 'Error: run gh auth login first' when running new-project.sh on host"
label: wayfinder:grilling
status: open
assignee: null
blocked_by: []
---

## Question

`tools/new-project.sh` (and `tools/sync-upstream.sh`) both gate on
`gh auth status >/dev/null 2>&1 || { echo "Error: run 'gh auth login' first" >&2; exit 1; }`
before any `--lifecycle long` or `--promote` operation. The reporter hits this
error running the script on their **host** (not inside the dev container).
Needs a live session with the reporter to pin down root cause before a fix can
be chosen: is `gh` installed on the host at all, is it logged in under a
different account/hostname than the check expects, does `gh auth status`
require a TTY the script's invocation doesn't provide, or is something else
going on? Once the cause is known, decide the fix — e.g. a clearer error
message pointing at the actual missing prerequisite, a pre-flight check with
setup instructions, or documentation stating `gh` must be authenticated on the
host (not just in-container) before running these scripts.

Facts already gathered:
- Both checks are identical one-liners, at `tools/new-project.sh:185` (inside
  `--promote`) and `:251` (inside `--lifecycle long`), and
  `tools/sync-upstream.sh:81`.
- The scripts are documented (`docs/spin-off-new-project.md`) as run from a
  clone of AgenticPlayground — doesn't specify host vs. container explicitly.
