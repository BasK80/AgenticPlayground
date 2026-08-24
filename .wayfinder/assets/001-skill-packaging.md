# Skill packaging across opencode, Claude Code and Copilot CLI

Tested **2026-08-24** against opencode 1.18.21 by running real `opencode serve`
instances and querying `GET /api/skill` and `GET /config`. Asset of
[Decide how skills are packaged so opencode, Claude Code and Copilot CLI all find them](../tickets/001-skill-packaging.md).
All test artifacts (probe skills, temp project dirs, servers) were removed
afterwards; `git status` is clean of anything but this map's own files.

## The hypothesis from ticket 002 was wrong — tested and refuted

Ticket 002 speculated that `OPENCODE_DISABLE_CLAUDE_CODE_SKILLS` meant opencode
would already see `/workspace/.claude/skills/`. **It does not.** opencode's own
built-in `customize-opencode` skill (fetched live from the running server) is
authoritative and states the paths precisely:

| Scope | Path |
| --- | --- |
| Project skills | `.opencode/skill(s)/<name>/SKILL.md` |
| Global skills | `~/.config/opencode/skill(s)/<name>/SKILL.md` |
| **External, auto-loaded** | **`~/.claude/skills/<name>/SKILL.md`, `~/.agents/skills/<name>/SKILL.md`** |

The external auto-load paths are under **`$HOME`**, not the project. This repo's
skills live at `/workspace/.claude/skills/` — project-scoped — so they are
invisible to opencode by default. Confirmed empirically: a fresh
`opencode serve` in `/workspace` returned only the builtin skill from
`GET /api/skill`.

## What was verified live

| Mechanism | Result |
| --- | --- |
| `.opencode/skill/<name>/SKILL.md` (project) | **✅ Works.** A probe skill placed here was listed immediately by `GET /api/skill`. |
| `skills.paths` config pointing at an arbitrary directory | **❌ Did not work**, despite `GET /config` echoing the value back correctly. Tried via `OPENCODE_CONFIG_CONTENT` and via a real project `opencode.json`; neither picked up skills from the configured path. |
| `~/.claude/skills/`, `~/.agents/skills/` (home, auto-load) | **Not directly tested** (would require writing into the container's real home directory as a side effect), but documented by opencode's own builtin skill as the auto-load mechanism. Neither directory exists yet in this container (`$HOME/.claude/skills`, `$HOME/.agents/skills` are both absent), which independently explains why nothing is currently auto-loaded. |

**`skills.paths` not working is a real finding, not a config mistake** — `GET
/config` showed the exact value that was set. One candidate explanation:
`opencode serve` did not resolve the intended directory as its **project root**
in a manual test (`project.id` came back `"global"`, `directory: "/"`, even when
launched with `cwd` set to the target directory) — `serve` may not consume the
`[project]` positional the way the default TUI command does, so project-scoped
config may need to be launched differently than this test did. **Treat
`skills.paths` as unreliable for opencode 1.18.21 and do not depend on it for the
build tickets.**

## The packaging decision

**Use `.opencode/skill/<name>/SKILL.md` as a real file (or symlink) inside the
project — not `skills.paths`, not relying on home-directory auto-load.**

This repo already keeps skills at `.agents/skills/<name>/SKILL.md` as the
canonical source, with `.claude/skills/<name>` as symlinks (confirmed:
`grilling`, `research`, `wayfinder`, `ask-matt`, `implement` are all symlinks;
`security-test` is a plain directory, Claude-only). **The same pattern extends
cleanly:**

```
.agents/skills/pick-model/SKILL.md        ← canonical
.claude/skills/pick-model  → ../../.agents/skills/pick-model     (symlink)
.opencode/skill/pick-model → ../../.agents/skills/pick-model     (symlink)
```

One canonical file, three symlinks, zero duplication — satisfying the
future-proofing invariant (map invariant 7: the method lives in one place).

**Copilot CLI is the third harness and still unverified.** It has a genuine
`copilot skill` subcommand ("Manage skills"), discovered while resolving ticket
003, but its file format and discovery path were not checked this session. Split
out below rather than guessed.

## The actuation half is settled by ticket 002, not by this ticket

This ticket only answers *where the advice-giving skill file lives*. The
opencode-only **switching** mechanism was already settled in
[opencode model switching](002-opencode-model-switching.md): a prose skill
cannot address the running server (no discoverable URL/port), so switching needs
an **opencode plugin** (`.opencode/plugin/*.ts`, auto-discovered, or
`.opencode/plugins/`), which gets `serverUrl` and a typed client via
`PluginInput`. A plugin can register a real slash command
(`slash: {name, aliases}`).

**So the final shape:**

| Piece | Delivery | Location |
| --- | --- | --- |
| Advice (all three harnesses) | one `SKILL.md`, symlinked | `.agents/skills/pick-model/`, linked into `.claude/skills/` and `.opencode/skill/` |
| Actuation (opencode only) | a plugin registering `/pick-model` | `.opencode/plugin/pick-model.ts` (auto-discovered, per opencode's own docs — no config entry needed) |
| `ollama-curate` | advice only, no actuation needed | same pattern as the advice half above |

## Copilot CLI: verified, and it needs no extra work at all

`copilot skill --help` documents discovery sources directly:

> Project: `.github/skills/`, **`.agents/skills/`**, or `.claude/skills/`
> Personal: `~/.copilot/skills/` or `~/.agents/skills/`

**`.agents/skills/` — this repo's canonical location — is already a native
Copilot CLI discovery path.** Verified live with `copilot skill list --json`:
every existing skill (`ask-matt`, `grilling`, `implement`, `research`,
`wayfinder`, `security-test`) was listed with `"source": "project"` and the
correct path under `/workspace/.agents/skills/`, with no configuration and no
symlink.

**So the three-way packaging plan needs no fourth symlink.** One canonical file
under `.agents/skills/<name>/SKILL.md` is picked up by Copilot CLI directly, by
Claude Code via the existing `.claude/skills/<name>` symlink, and by opencode via
a new `.opencode/skill/<name>` symlink. The table above is final, not
provisional.
