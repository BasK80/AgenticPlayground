---
id: 001-doc-split
title: Split upstream vs. project documentation when starting a new project
label: wayfinder:grilling
status: closed
assignee: copilot-cli-session
blocked_by: []
---

## Question

`tools/new-project.sh` currently strips a fixed list of template-specific docs
(`README.md`, `USAGE.md`, `presentation.html`, `docs/comparison.md`) and writes
a single `GOAL.md`, but everything else under `docs/` (allowlist, operations,
providers, security, auditing, file-guide, the two spin-off guides) stays
mixed in as-is, indistinguishable from docs the new project's own team will
add. How should upstream template documentation be separated from
project-specific documentation for a project created via
`tools/new-project.sh` (or by hand-following `docs/spin-off-new-project.md` /
`docs/spin-off-existing-repo.md`)? E.g.: move remaining template docs under a
dedicated subdirectory (`docs/template/`?), tag them with front-matter so a
future `sync-upstream.sh` pull can tell them apart, drop more of them
entirely, or something else — and does the answer differ for the `short` vs.
`long` lifecycle or `secure` vs `playground` tier?

Facts already gathered (no need to re-derive):
- Strip list lives in `tools/new-project.sh` around the "Strip
  template-specific docs" step.
- `tools/sync-upstream.sh` is the existing mechanism for pulling upstream
  changes into a spun-off project — any doc-separation scheme should stay
  compatible with it.

## Resolution

Extend the existing strip list in `tools/new-project.sh` (currently
`README.md`, `USAGE.md`, `presentation.html`, `docs/comparison.md`) to also
delete `docs/spin-off-new-project.md` and `docs/spin-off-existing-repo.md`.

Rationale: these two guides describe how to create a *new* project from this
template — they're meta/template documentation, not something the spun-off
project's own team needs. Everything else under `docs/` (`security.md`,
`allowlist.md`, `operations.md`, `providers.md`, `auditing.md`,
`file-guide.md`) describes the actual infrastructure the spun-off project
still runs, so those stay in place unchanged as living project docs.

This applies uniformly — no variation by `--tier` (secure/playground) or
`--lifecycle` (short/long), since the strip step already runs unconditionally
before that branching in the script.

Implementation note (left for the implementer, not decided here): the strip
step already runs before `--lifecycle` branches, so just adding the two
paths to the existing `rm -f` line is sufficient — no new script branches
needed.

