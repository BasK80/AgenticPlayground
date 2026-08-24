---
id: 006
title: Decide how the skills detect that cloud is unreachable
label: wayfinder:research
status: closed
assignee: Bas Kloet
blocked_by: []
---

## Question

Offline capability is one of the two drivers of this whole effort. How do the
skills **cheaply and reliably** tell whether GHE Copilot is reachable right now —
so the spill-tier consent gate can open automatically when it is not?

## Raised in importance by ticket 005 (2026-08-24)

Local is now **offline-only**, so this probe is no longer a gate-opener — it is
the **branch selector** for the entire routing decision. If it wrongly reports
offline, every task drops to a 7B model; if it wrongly reports online, offline
work fails outright. See
[Task taxonomy and routing policy](../assets/005-taxonomy-and-routing.md).

## Why it is not trivial here

This container has three distinct failure layers that all look like "no network"
but mean different things (documented in `CLAUDE.md`):

| Symptom | Layer | Meaning for routing |
| --- | --- | --- |
| HTTP `403` from the Squid proxy (`ERR_FIREWALL_BLOCKED` body) | allowlist | **Misconfiguration**, not offline — tell the human to allow the domain; do not silently fall back to local |
| `EAI_AGAIN` / `getaddrinfo ENOTFOUND` | DNS | stale firewall image — a *bug*, not offline |
| `ENETUNREACH` with DNS resolving fine | proxy bypass | a *bug* (process not using the proxy), not offline |
| genuine timeout / no route to the internet | actually offline | **open the gate** |

Conflating these would make the skill fall back to a slow local model when the
real problem was a missing allowlist entry — and hide the bug. `CLAUDE.md` is
explicit: do **not** retry blindly or assume the remote service is down.

## Lever found by ticket 002 (2026-08-24)

opencode exposes **`OPENCODE_DISABLE_MODELS_FETCH`**, **`OPENCODE_MODELS_PATH`**
and **`OPENCODE_MODELS_URL`** — so the model catalogue can be **pinned to a local
path** instead of fetched from models.dev. That directly serves the offline-first
invariant: consider setting these so no decision path can ever reach for the
network. See [opencode model switching](../assets/002-opencode-model-switching.md).

Also: `GET /api/model` on a running opencode server returns the full catalogue
*including* `cost`, `limit` and `variants` — a local, network-free source for the
data the router needs, when a server is reachable.

## Resolve specifically

1. The probe: what to hit, with what timeout, to distinguish the four cases
   above. Cost matters — this runs on every routing decision.
2. Whether to cache the verdict, and for how long. A probe on every decision may
   be too slow; a stale "offline" verdict is worse than a slow one.
3. What the skill *says* in each case. The allowlist case must surface as an
   actionable message (`curl -s http://firewall:8099` shows recent denials; the
   human allows domains from the host), never as a silent downgrade.
4. Whether ollama reachability needs the same treatment — the local side can also
   be down (`host.docker.internal:11434` unreachable), and then *cloud* is the
   only option. Both-down deserves a clear error.

## Note

Keep the probe out of the decision path if possible — map invariant 6 says no
decision may *require* a network call. A cached verdict plus a fast optional
refresh probably satisfies both.

## Resolution (2026-08-24)

**One `curl` against the real target host, classified by exit code plus a
`-D` header dump, distinguishes allowlist-block from everything else with a
unique, measured signature (`X-Squid-Error: ERR_FIREWALL_BLOCKED`) — genuine
offline and stale-image bugs remain indistinguishable from inside the
container (verified: both are ordinary squid error templates), so those two
are deliberately *not* split apart; the skill surfaces the raw signal instead
of guessing. Ollama needs the identical probe — measured live, ollama traffic
is also proxied through Squid and currently allowlisted via a live (not
checked-in) `fw allow`, so it can suffer the same allowlist-expiry failure
mode cloud can. Verdict cached in `preferences.json` with a 60s TTL, per
target, both directions. Five message variants (online / blocked / offline /
proxy-unreachable / both-down) specified, with blocked never phrased as
offline.** Full detail, exact commands and measured header output:
[offline detection asset](../assets/006-offline-detection.md).
