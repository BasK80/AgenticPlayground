---
id: 002-gh-auth-error
title: "Fix 'Error: run gh auth login first' when running new-project.sh on host"
label: wayfinder:grilling
status: closed
assignee: copilot-cli-session
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

## Resolution

**No bug in this repo.** Root cause confirmed live with the reporter: on
their WSL2 host, `gh auth login`'s device-flow browser open failed silently
(`xdg-open` had no registered browser — `x-www-browser`, `firefox`, etc. all
missing), so the login never actually completed, leaving `gh` unauthenticated
on the host. `tools/new-project.sh`'s `gh auth status` check was correctly
reporting that real state — not misbehaving.

Fix (host-side, no code change needed): install `wslu` (provides `wslview`)
and set `BROWSER=wslview`, which `gh` (and most CLIs) check before falling
back to `xdg-open`:
```bash
sudo apt update && sudo apt install -y wslu
echo 'export BROWSER=wslview' >> ~/.bashrc && source ~/.bashrc
```
After that, `gh auth login` opened the browser automatically, login
succeeded, and re-running `new-project.sh` got past the check.

Documented as a WSL2 caveat in `USAGE.md`'s "Windows + WSL2 + Rancher
Desktop" prerequisites section so future WSL2 users don't hit the same
detour.

