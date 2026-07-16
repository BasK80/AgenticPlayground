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

## Not yet specified

(none yet — all four backlog ideas were sharp enough to ticket directly once
the surrounding facts were checked; see tickets)

## Out of scope

(none yet)
