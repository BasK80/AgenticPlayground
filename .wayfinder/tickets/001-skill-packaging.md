---
id: 001
title: Decide how skills are packaged so opencode, Claude Code and Copilot CLI all find them
label: wayfinder:research
status: closed
assignee: Bas Kloet
blocked_by: []
---

## RESOLUTION (2026-08-24) — closed

Verified live against all three harnesses (real `opencode serve` instances,
`copilot skill list --json`). Full detail:
[Skill packaging across opencode, Claude Code and Copilot CLI](../assets/001-skill-packaging.md).

**One canonical file, symlinked twice — no fourth copy needed:**

```
.agents/skills/<name>/SKILL.md        ← canonical
.claude/skills/<name>   → ../../.agents/skills/<name>     (existing pattern)
.opencode/skill/<name>  → ../../.agents/skills/<name>     (new symlink)
```

**Copilot CLI needs nothing extra.** `copilot skill --help` documents
`.agents/skills/` as a native **project**-scope discovery path; verified live —
`copilot skill list --json` listed every existing repo skill with
`"source":"project"` and the correct path, no config.

**The ticket's own hypothesis (from ticket 002) was tested and refuted.**
`OPENCODE_DISABLE_CLAUDE_CODE_SKILLS` does **not** mean opencode already reads
`.claude/skills/` in this project — a fresh `opencode serve` in `/workspace`
listed only opencode's own builtin skill via `GET /api/skill`. opencode's builtin
`customize-opencode` skill (fetched from the live server) states the real paths:
project skills live at **`.opencode/skill(s)/<name>/SKILL.md`**; the
`~/.claude/skills/` / `~/.agents/skills/` auto-load is **home-directory only**,
and neither exists in this container yet.

**`.opencode/skill/<name>/SKILL.md` was verified working** by placing a probe
skill there and confirming `GET /api/skill` listed it immediately.

**⚠ `skills.paths` config does NOT work** in opencode 1.18.21 — tested twice
(via `OPENCODE_CONFIG_CONTENT` and a real project `opencode.json`); `GET /config`
echoed the value correctly but the referenced skills never appeared. Do not rely
on it. (Candidate cause: `opencode serve` resolved `project.id` as `"global"`,
`directory:"/"` in the test rather than the launch directory — project-scoped
config may need a different invocation than tested.)

**Actuation (opencode-only, from ticket 002) is unaffected by this ticket**: the
switching mechanism is a plugin (`.opencode/plugin/*.ts`, auto-discovered), not a
skill file — a prose skill cannot address the running server.

---

## Question

Both skills must be invokable from **opencode, Claude Code, and the GitHub
Copilot CLI**. What is the actual packaging and discovery mechanism for each, and
what single on-disk layout satisfies all three?

Resolve concretely enough that ticket
[Write the pick-model skill](011-write-pick-model.md) knows exactly which files
to create, where, and in what format.

## What is already known

- This repo's convention: skills live at `.agents/skills/<name>/SKILL.md` (the
  neutral home), and `.claude/skills/<name>` are **symlinks** into it. Confirm
  with `ls -la /workspace/.claude/skills/`.
- `.claude/skills/security-test/SKILL.md` is a real directory (not a symlink) yet
  its frontmatter claims portability *"across Claude Code, opencode, and the
  GitHub Copilot CLI"* — so "portable" here may mean *the instructions are
  harness-agnostic*, installed separately per harness, rather than one shared
  path all three read. Establish which.
- opencode is **v1.18.21**. `~/.config/opencode/` contains a `package.json` and
  `node_modules/@opencode-ai` — so a plugin SDK exists. Whether v1.18 has a
  first-class *skill* concept (vs. custom commands, agents, or plugins) is the
  open question. **Do not guess the mechanism from memory — check the docs for
  this version.**
- Copilot CLI is v1.0.80, at
  `~/.vscode-server/data/User/globalStorage/github.copilot-chat/copilotCli/copilot`.
- **Copilot CLI has a first-class `copilot skill` subcommand** ("Manage skills")
  — found while working
  [Discover which models GHE Copilot actually offers this account](003-discover-copilot-models.md).
  So the Copilot side has a real skill mechanism to target; start with
  `copilot skill --help`. It also has `copilot plugin` / `copilot plugins`, and
  `copilot init` ("Initialize Copilot instructions"), which may be the
  AGENTS.md-style path instead.

## Evidence from ticket 002 (2026-08-24) — this ticket now has a likely answer

See [opencode model switching](../assets/002-opencode-model-switching.md).

- **opencode natively reads Claude Code skills.** The binary carries
  `OPENCODE_DISABLE_CLAUDE_CODE_SKILLS` (plus `OPENCODE_DISABLE_EXTERNAL_SKILLS`,
  `OPENCODE_SKILL_DESCRIPTION`, `OPENCODE_DISABLE_CLAUDE_CODE`) and the server
  exposes `GET /api/skill`. So **one Claude-Code-format skill may satisfy both
  Claude Code and opencode** — verify by listing `/api/skill` with a skill present
  and confirming it appears.
- **Copilot CLI has `copilot skill`** ("Manage skills"), so the third harness has
  its own mechanism. Start at `copilot skill --help`.
- **But the actuation half cannot be a prose skill.** A skill running shell
  commands has no way to address the opencode server — no `OPENCODE_SERVER_URL`,
  no port/lock file, `--port` defaults to random. A **plugin** gets `serverUrl`
  and a typed client via `PluginInput`, and can register a real slash command
  (`slash: {name, aliases}` + `onSelect`).

**So the likely shape of the answer** — confirm or refute it rather than assuming:

| Piece | Delivery |
| --- | --- |
| Advice (all three harnesses) | one Claude-Code-format `SKILL.md`, symlinked per harness |
| Actuation (opencode only) | an **opencode plugin** registering a `/pick-model` slash command |

Also settle **how a plugin is installed** — there is an `opencode plugin <module>`
CLI command ("install plugin and update config") and a `plugin` key in the config
schema.

## Notes

- `opencode.ai` may not be on the firewall allowlist; `models.dev` and
  `github.com` are. If a docs domain is blocked, expect an HTTP 403 from the
  proxy and ask the user to allow it from the host (see `CLAUDE.md`) rather than
  working around it.
- Prefer one shared source of truth with per-harness symlinks if all three can
  be made to read it — that directly serves the future-proofing invariant.
- Use `/research` so the findings land as a Markdown file in the repo, and link
  it from the resolution comment.
