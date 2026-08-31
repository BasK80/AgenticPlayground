# opencode's GitHub Copilot provider natively supports the GHE tenant

Resolved **2026-08-31** for
[Route opencode's Copilot provider at the GHE tenant instead of api.githubcopilot.com](../tickets/020-opencode-ghe-copilot-route.md).
Verified live against this container's real installed opencode (v1.18.18) —
no custom provider, no `baseURL` override, no reused token.

## The finding

`opencode auth login -p github-copilot` (equivalently `/connect` → GitHub
Copilot in the TUI) asks a **deployment-type** question the provider docs
page (opencode.ai/docs/providers) doesn't mention:

```
◆  Select GitHub deployment type
│  ○ GitHub.com (Public)
│  ○ GitHub Enterprise (Data residency or self-hosted)
```

Choosing **GitHub Enterprise** prompts for the tenant host, then runs its
**own** OAuth device-code flow against that host — not against
`github.com`:

```
◆  Enter your GitHub Enterprise URL or domain
│  company.ghe.com or https://company.ghe.com
→ info-support.ghe.com

●  Go to: https://info-support.ghe.com/login/device
●  Enter code: D0E1-BDF9
◒  Waiting for authorization…
◇  Login successful
```

This directly overturns the evidence ticket 020 opened with (tickets 002/003
found the literal string `api.githubcopilot.com` and no `ghe.com` substring
in the binary). That evidence wasn't wrong, just incomplete: the enterprise
host isn't a hardcoded literal, it's read at runtime from the stored
credential — `strings` on the binary shows the resolver
(`X.get(xY(X.enterpriseUrl), ...)`) and the auth-file shape
(`{"type":"oauth","refresh":…,"access":…,"expires":…,"enterpriseUrl":X}`).

## Verified end to end

```
$ opencode auth list
● GitHub Copilot oauth
└ 1 credentials

$ cat ~/.local/share/opencode/auth.json   # github-copilot entry
{"type":"oauth","refresh":"***","access":"***","expires":0,
 "enterpriseUrl":"info-support.ghe.com"}

$ opencode models | grep copilot
github-copilot/claude-sonnet-5
github-copilot/gpt-5.6-sol
github-copilot/mai-code-1-flash-picker
...
```

The returned catalogue is the **tenant's** model list (`gpt-5.6-*`,
`mai-code-*`, `claude-*-5` — the same custom line-up this very Copilot CLI
session sees), not the public GitHub Copilot catalogue. That's proof the
model-discovery call landed on `info-support.ghe.com`, not `github.com`.

**Not spent:** an actual chat completion through the new credential. Model
discovery against the correct, tenant-specific catalogue was judged
sufficient proof for this ticket's question; a live completion is a cheap
follow-up whenever someone next drives opencode for real work.

## How to reproduce (for someone hitting this fresh)

```sh
opencode auth login -p github-copilot
# → select "GitHub Enterprise (Data residency or self-hosted)"
# → enter the tenant host, e.g. info-support.ghe.com
# → open the printed device URL, enter the printed code, approve in browser
```

The device-code prompt is un-scriptable (needs a live human approval in the
browser, same shape as `tools/test-opencode-providers.sh`'s existing
un-scriptable-login handling) but the prompt sequence itself can be **driven**
non-interactively with a pty (`pexpect`/`script`) up to that point — useful
for anyone automating this again. See the ticket's resolution for the exact
Python snippet used here.
