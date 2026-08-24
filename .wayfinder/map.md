---
title: TODO.md backlog triage
label: wayfinder:map
status: open
---

## Destination

Every idea currently sitting in `TODO.md` has a clear, actionable spec or
decision — nothing left to decide before someone implements it. This map
does not implement anything itself; it ends when each idea is implementation-ready.

## Notes

- Tracker: **local-markdown** (no issue tracker was configured for this repo).
  Tickets live as files under `.wayfinder/tickets/`. Each ticket file has
  frontmatter: `id`, `title`, `label` (`wayfinder:<type>`), `status`
  (`open`/`closed`), `assignee`, `blocked_by` (list of ticket ids).
  A ticket is claimed by setting `assignee`. The frontier = open, unassigned
  tickets whose `blocked_by` ids are all `closed`.
- Domain: this is the `AgenticPlayground` dev-container tooling repo (fork of
  `AgenticDevcontainer`). Consult `docs/spin-off-new-project.md`,
  `tools/new-project.sh`, `docs/providers.md`, and
  `.devcontainer/development/ping-wrapper.sh` as needed — see individual
  tickets for pointers already gathered.
- Use `/grilling` (and `/domain-modeling` where relevant) to resolve each ticket.

## Decisions so far

- [Split upstream vs. project documentation when starting a new project](tickets/001-doc-split.md) — extend `new-project.sh`'s strip list to also delete `docs/spin-off-new-project.md` and `docs/spin-off-existing-repo.md`; infra docs (security/allowlist/operations/providers/auditing/file-guide) stay as living project docs, unchanged across tier/lifecycle.
- [Fix 'Error: run 'gh auth login' first' when running new-project.sh on my host](tickets/002-gh-auth-error.md) — not a bug: WSL2 host had no browser registered for `xdg-open`, so `gh auth login` silently never completed. Fixed by installing `wslu` + `BROWSER=wslview`; documented as a WSL2 caveat in USAGE.md.
- [Determine how to best implement a git-within-git approach for spin-off projects](tickets/005-git-within-git.md) — target repo clones into fixed, git-ignored `workspace/target/`; `new-project.sh` gets an optional `--target-repo` flag to automate the clone/`.gitignore`, else it's a manual `GOAL.md` step; a root-level `TARGET_REPO` marker file tells agents where the deliverable lives (outer repo stays freely editable); same-account auth needs no setup (the common case), with an opt-in per-directory `.gitconfig` `includeIf` for the rare different-account case and manual `gh auth switch` documented as `gh`'s own limitation.

## Not yet specified

(none yet — all four backlog ideas were sharp enough to ticket directly once
the surrounding facts were checked; see tickets)

## Out of scope

(none yet)
