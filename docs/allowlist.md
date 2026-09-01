# Allowlist management

## Manage the allowlist from the host

```bash
# Set once in your host shell (or add to ~/.bashrc / ~/.zshrc):
FW="agentic-$(basename "$PWD")-firewall"

docker exec      "$FW" fw allow pypi.org                   # permanent allow
docker exec      "$FW" fw allow files.pythonhosted.org 60  # temporary allow, 60s TTL
docker exec      "$FW" fw deny  pypi.org                   # remove an allow (re-block); perm + temp
docker exec      "$FW" fw list                             # show the live, compiled allowlist
docker exec      "$FW" fw blocks                           # recent blocked requests
docker exec -it  "$FW" fw log                              # follow the access log

docker exec      "$FW" fw feature list                     # feature-sets + their domains + on/off
docker exec      "$FW" fw feature on  azure                # enable a feature-set
docker exec      "$FW" fw feature off npm                  # disable a feature-set
docker exec      "$FW" fw feature show npm                 # print the raw .list file for a feature
docker exec      "$FW" fw feature create mycdn \
  -d "My CDN" --domain cdn.example.com                     # create a user-defined feature (auto-enabled)
docker exec      "$FW" fw feature edit mycdn \
  --domain cdn.example.com --domain assets.example.com     # replace all domains for a user feature
docker exec      "$FW" fw feature delete mycdn             # delete a user-defined feature

docker exec      "$FW" fw allow-all 600                     # DANGER: bypass the entire firewall for 600s (max 3600s)
docker exec      "$FW" fw allow-all off                     # end it early
docker exec      "$FW" fw allow-all status                  # check whether it's active + time remaining
```

Changes take effect within ~5s (the firewall watcher reloads Squid). Run these on the **host**, not inside the dev container — `development` is deliberately unable to reach the management plane.

## Temporarily allowing all traffic

`fw allow-all` bypasses the firewall entirely — every domain and every port —
for a bounded, self-expiring window. It exists for playground projects with
looser security requirements where the allowlist model is too restrictive
(e.g. exploratory work against arbitrary third-party APIs). It is **not**
part of the default-deny model used for normal work; treat it as an escape
hatch, not a config knob.

```bash
docker exec "$FW" fw allow-all           # default TTL: 300s (5 min)
docker exec "$FW" fw allow-all 1800      # custom TTL, in seconds
docker exec "$FW" fw allow-all off       # turn it off before it expires
docker exec "$FW" fw allow-all status    # ACTIVE (+ seconds remaining) or inactive
```

Notes:

- **Always auto-expires.** There is no "permanent" allow-all; the TTL defaults
  to 300s and is hard-capped at 3600s (1 hour) — a request for a longer TTL is
  silently clamped down to the cap.
- **Bypasses everything, including the CONNECT port restriction.** Normally
  `CONNECT` is only allowed to port 443; while allow-all is active it's
  allowed to any port, so this really is "all traffic", not just "any domain
  on 443".
- **Host-only**, like every other `fw` command — it cannot be triggered from
  inside the dev container.
- **Auditable.** Every on/off transition (including automatic expiry) is
  appended to `/policy/allow_all_events.log` with a timestamp and the TTL
  requested. Squid's `access.log` (and the long-term audit DB) still records
  every individual request made during the window, same as always.
- Also available from the web dashboard (see below) as a red **Allow All
  (danger)** control with a persistent "ALL TRAFFIC ALLOWED" banner while
  active.

## Web dashboard (localhost only)

A single-page dashboard is served by the `control` container at **<http://127.0.0.1:8088>** (the default; the port is derived per project — the terminal banner prints the exact URL for each instance, and it is also written to `.devcontainer/.env` as `CONTROL_PORT`). It is bound to `127.0.0.1` only — the same localhost-only pattern as the Azure login ports — and is not reachable from inside `development`.

The dashboard has three tabs, plus a sidebar control for allow-all:

| Tab | What it shows |
|---|---|
| **Traffic** | A live traffic stream (every proxied request, green/red, filterable by host). Below it, two stacked panels: **Active Allowlist** (top) lets you add a domain manually and shows **Manual (permanent)**, **Temporary** (live countdown), and a collapsible **Baseline (always on)** section; **Recently Blocked** (bottom) lists denied hosts with their last-seen time (ISO 8601, e.g. `2026-06-21 13:02:43`) and hit count, with a single **Allow ▾** button that expands to Permanent / 5m / 15m / 1h / Custom options inline. Allowing a blocked domain immediately marks its row as resolved — no page switch needed. |
| **Audit Log** | Long-term SQLite history of all proxied traffic. Filter by date range, host, and decision; download any period as CSV. |
| **Feature Sets** | One row per toggleable feature-set (`anthropic`, `github`, `npm`, …). The **State** column shows **On** (green), **Via \<name\>** (blue, pulled in as a dependency), or **Off** (gray). The **Actions** column has **Enable**/**Disable** for directly-controllable features; dependency-pulled features show **Locked by \<name\>** instead of a toggle. User-created features also have **Edit** and **Delete** buttons. A **Create Feature** button above the table opens a form to define a new feature-set (name, description, domains, dependencies) stored persistently in `/policy/features.d/`. |

The sidebar also has an **Allow All (danger)** box: pick a TTL (5m/15m/30m/1h) and click **Activate** to bypass the firewall entirely. While active, a red **"ALL TRAFFIC ALLOWED — expires in …"** banner is pinned to the top of every tab with a **Disable now** button.

Every mutation from the dashboard writes to the same shared `policy` volume that the `fw` script modifies directly, so the CLI and the dashboard are always in sync.

## Configuring the allowlist (feature-sets)

The allowlist is split into a small always-on **baseline** plus named
**feature-sets** you toggle on or off. The baseline is only what's needed to
open and operate the dev container itself (VS Code server + marketplace, Debian/
Microsoft apt, a generic JS CDN); everything project-specific is a feature.

| Feature | Grants access to | Default |
|---|---|---|
| `anthropic` | Claude Code / Anthropic API (`api.anthropic.com`, `claude.ai`) | **on** |
| `github` | git, `gh`, GitHub package/skill installs | **on** |
| `npm` | npm / yarn registries | **on** |
| `opencode` | opencode's model catalogue (`models.dev`) | **on** |
| `copilot` | GitHub Copilot inference (`*.githubcopilot.com`); **depends on `github`** | **on** |
| `pypi` | Python package index | **on** |
| `golang` | Go module proxy + checksum DB | **on** |
| `azure` | Azure AI Foundry (Entra ID, ARM, Foundry portal, data plane) | off |
| `ollama` | A local ollama on the host (`host.docker.internal`, plain HTTP on `11434`) — see [LLM providers](providers.md#local-ollama-on-the-host) | off |
| `infosupport` | Info Support LLM gateway (test) | off |

Definitions live in two places:

- **Built-in features** — `.devcontainer/firewall/features/*.list`, baked read-only into the firewall image. Adding or editing a built-in feature is a maintainer action (edit + rebuild), so a process inside the dev container cannot grant itself new domains.
- **User-created features** — `/policy/features.d/*.list`, on the shared `policy` Docker volume. Created, edited, and deleted at runtime via `fw feature create/edit/delete` or the web UI. Persist across container restarts. Built-in features take precedence; a user feature cannot reuse a built-in name.

### User-defined features

You can define your own feature-sets for any group of domains your project regularly needs — for example, a private registry, a staging API, or a CDN:

```bash
# Create a user feature (automatically enabled, stored in /policy/features.d/)
docker exec "$FW" fw feature create myregistry \
  -d "Private npm registry" \
  --domain registry.example.com

# Create with a dependency (this feature's domains + github's domains are allowed together)
docker exec "$FW" fw feature create myapp \
  -d "My application services" \
  --depends github \
  --domain api.myapp.com --domain cdn.myapp.com

# Edit (full replacement — supply all domains you want)
docker exec "$FW" fw feature edit myregistry \
  -d "Private npm registry" \
  --domain registry.example.com --domain registry2.example.com

# Pipe domains from stdin instead of --domain flags
printf 'registry.example.com\nregistry2.example.com\n' | \
  docker exec -i "$FW" fw feature create myregistry -d "Private npm registry"

# Delete
docker exec "$FW" fw feature delete myregistry
```

The same operations are available in the **Feature Sets** tab of the web dashboard at <http://127.0.0.1:8088>.

**Toggle a feature** (effective within ~5s, no rebuild):

```bash
docker exec "$FW" fw feature on  azure     # or use the control web UI
docker exec "$FW" fw feature off pypi
```

Enabling a feature transparently pulls in its dependencies (turning on `copilot`
also allows `github`'s domains, even if `github` is off). Manual `fw allow`
additions and TTL entries are kept separate from features; removing a
feature-granted domain with `fw deny` is refused and points you at
`fw feature off <name>`.

> **🔒 Maximise security — disable what you don't use.** The defaults enable
> `anthropic`, `github`, `npm`, and `opencode` (the API-key agentic tools and
> their common ecosystem). For the tightest egress surface, **turn off the
> agentic frameworks you don't run**
> — if you only use Claude Code, `fw feature off opencode`; if you only use
> opencode, `fw feature off anthropic`; enable `copilot` only when you actually
> use Copilot. Likewise leave `pypi` / `golang` / `azure` / `infosupport` off
> unless the project needs them. To reproduce the old "everything allowed"
> behaviour, enable every feature: `for f in anthropic github npm opencode copilot pypi golang azure infosupport; do docker exec "$FW" fw feature on $f; done`.

## See blocks from inside the dev container

- Each blocked request shows up as a `403` proxy error in your tools.
- Read-only recent-blocks feed: `curl -s http://firewall:8099`

## Debugging blocked traffic

```bash
# From inside the dev container:
curl -s http://firewall:8099 | tail -30

# From the host (FW="agentic-$(basename "$PWD")-firewall"):
docker exec      "$FW" fw blocks                           # last 30 access log lines
docker exec -it  "$FW" fw log                              # live tail
docker exec      "$FW" fw list                             # current compiled allowlist
docker exec      "$FW" fw allow <hostname>                 # add the missing destination
docker exec      "$FW" fw allow <hostname> 300             # 5-minute temporary allow while debugging
```
