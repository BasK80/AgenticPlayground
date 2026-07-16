---
id: 005-git-within-git
title: Determine how to best implement a git-within-git approach for spin-off projects
label: wayfinder:grilling
status: open
assignee: null
blocked_by: []
---

## Question

A spin-off container (created via `tools/new-project.sh`) is scaffolded as its
own git repo (fresh history, `origin`/`upstream` remotes pointing at the
project itself and the template). But the actual *work* the project executes
often needs to land in a **different, unrelated git repository** — e.g. a
project whose `GOAL.md` is "fix the documentation in
`acme-corp/some-other-repo`" needs to clone, branch, commit, and push against
that other repo, nested somewhere inside (or alongside) the spin-off
project's own working tree.

Decide how this nested/second-repo relationship should be structured and
supported:
- Where does the target repo live relative to the spin-off project's own repo
  — a subdirectory excluded from the outer repo's git (`.gitignore`d clone), a
  sibling directory outside the outer repo entirely, a git submodule, or
  something else?
- Does `new-project.sh` need a new flag/step to clone the target repo and
  record which directory holds it (vs. leaving it to `GOAL.md`'s existing
  "manual next steps" convention)?
- How should agents inside the container be told which repo is "the outer
  scaffold" (not to touch) vs. "the actual deliverable" (where commits/pushes
  should go) — a convention in `GOAL.md`? A dedicated file? Environment
  variable?
- Bonus (nice-to-have, not required for the core decision): can the outer
  spin-off repo and the nested target repo authenticate as **different**
  GitHub accounts (e.g. via `gh auth switch`, per-directory `.gitconfig`
  includeIf, or separate credential helpers), so pushes to each go out under
  the right identity?

Facts already gathered:
- `tools/new-project.sh` already does one `git clone` (of the template) plus
  a fresh `git init`, and writes `GOAL.md` with a "Manual next steps" section
  — a natural place to point at this, if the answer keeps it manual.
- `gh auth status` is already a hard dependency for `--lifecycle long` /
  `--promote` (see the gh-auth-error ticket) — any multi-account bonus design
  should account for `gh`'s own auth model (`gh auth switch`, `gh auth login
  --hostname`) alongside plain git credential handling.
- No existing nested-repo or multi-account pattern exists anywhere in this
  repo today (checked `docs/`, `tools/`, `.devcontainer/`) — this is new
  ground, not an extension of something already partially built.
