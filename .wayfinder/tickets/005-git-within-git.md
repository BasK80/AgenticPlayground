---
id: 005-git-within-git
title: Determine how to best implement a git-within-git approach for spin-off projects
label: wayfinder:grilling
status: closed
assignee: copilot-cli-session
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

## Resolution

**Location:** the target repo (the actual deliverable) lives in a
git-ignored subdirectory of the outer scaffold repo, at a **fixed** path:
`workspace/target/`. It's cloned there as its own normal, independent git
repo; the outer repo's `.gitignore` excludes it entirely so the outer repo's
git never sees its files or history. Rejected: sibling directory outside the
outer repo (adds path-discovery complexity for no benefit since the
container filesystem root is already project-scoped), and git submodules
(wrong model — submodules imply the outer repo tracks/pins the inner repo's
history, but the outer repo is just a scaffold, not a monorepo pinning a
dependency).

**Automation:** `tools/new-project.sh` gains an optional flag (e.g.
`--target-repo <url>`) that clones the target repo into `workspace/target/`
and adds the `.gitignore` entry as part of spin-off. When the flag is
omitted (target repo not yet known at spin-off time), this stays a manual
step per `GOAL.md`'s existing "Manual next steps" convention — the fixed
`workspace/target/` path is still the destination to document there.

**Telling agents which repo is which:** a dedicated, machine-readable file
at the outer repo's root (e.g. `TARGET_REPO`, containing the path and/or
remote URL) records which directory holds the actual deliverable, plus a
one-line pointer in `GOAL.md` for humans. This file marks the **default**
location for commits/pushes related to the stated goal — it is *not* an
"outer repo is off-limits" rule. The outer scaffold remains freely editable
whenever the work requires touching it (e.g. adjusting container config to
support the inner work); the file only disambiguates "where does the
deliverable live" for tooling/agents that need to find it programmatically.

**Multi-account auth (bonus question):** in normal usage the outer scaffold
and the inner target repo use the **same** GitHub account/credentials —
this is the common case (~99% of usage) and requires **no special setup at
all**; nothing new-project.sh does is unconditional here. For the
occasional case where the target repo genuinely needs a different identity,
the supported mechanism is a per-directory `.gitconfig` `includeIf`
(`gitdir:workspace/target/`) that overrides `user.name`/`user.email`/
credential config automatically for plain `git` commands run inside that
directory — wired up opt-in (e.g. via the same `--target-repo` flag or a
separate flag/manual step), not by default. The `gh` CLI's own auth context
is global rather than directory-scoped, so switching `gh` accounts for the
target repo is a **documented manual step** (`gh auth switch` before running
`gh` commands against the target repo) rather than something automated —
this limitation should just be called out in docs, not solved further here.

Implementation notes (left for the implementer, not decided here): the exact
flag name(s) and whether the identity override and the clone/`.gitignore`
step share one flag or split across two; the exact filename/format for the
target-repo marker file; where in `new-project.sh`'s existing flow the new
step(s) should run.
