#!/usr/bin/env bash
# new-project.sh — bootstrap a new dev container project scoped to a goal.
#
# Usage:
#   ./tools/new-project.sh --name <slug> --goal "<text>" --tier secure|playground \
#       --lifecycle short|long [--dest <parent-dir>] [--public]
#   ./tools/new-project.sh --promote --name <slug> [--dest <parent-dir>]
#
# --tier secure      use github.com/BasK80/AgenticDevcontainer as the template
# --tier playground  use github.com/BasK80/AgenticPlayground as the template
#
# --lifecycle short  local-only git repo, no GitHub involved (fast, disposable)
# --lifecycle long   creates a private (or --public) GitHub repo via
#                    `gh repo create --template ...`
#
# --promote          run from inside an existing --lifecycle short project to
#                    turn it into a real GitHub-backed (long-running) one.
#
# Requires: git, and (for --lifecycle long / --promote) the `gh` CLI, logged in,
# with AgenticDevcontainer and AgenticPlayground marked as GitHub "template
# repositories" (Settings → Template repository) so `gh repo create --template`
# works.
set -euo pipefail

SECURE_REPO="BasK80/AgenticDevcontainer"
PLAYGROUND_REPO="BasK80/AgenticPlayground"

usage() {
    grep '^#' "$0" | sed -e '1d' -e 's/^# \{0,1\}//'
    exit 1
}

NAME=""
GOAL=""
TIER=""
LIFECYCLE=""
DEST_PARENT="${AGENTIC_PROJECTS_DIR:-..}"
VISIBILITY="--private"
PROMOTE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name) NAME="$2"; shift 2 ;;
        --goal) GOAL="$2"; shift 2 ;;
        --tier) TIER="$2"; shift 2 ;;
        --lifecycle) LIFECYCLE="$2"; shift 2 ;;
        --dest) DEST_PARENT="$2"; shift 2 ;;
        --public) VISIBILITY="--public"; shift ;;
        --promote) PROMOTE=1; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown argument: $1" >&2; usage ;;
    esac
done

[[ -n "$NAME" ]] || { echo "Error: --name is required" >&2; exit 1; }

# ── Promotion mode: turn an existing local-only project into a GitHub repo ──
if [[ "$PROMOTE" -eq 1 ]]; then
    PROJECT_DIR="$DEST_PARENT/$NAME"
    [[ -d "$PROJECT_DIR/.git" ]] || { echo "Error: $PROJECT_DIR is not a git repo" >&2; exit 1; }

    command -v gh >/dev/null 2>&1 || { echo "Error: gh CLI is required for --promote" >&2; exit 1; }
    gh auth status >/dev/null 2>&1 || { echo "Error: run 'gh auth login' first" >&2; exit 1; }

    echo "Promoting $PROJECT_DIR to a GitHub-backed repo..."
    (
        cd "$PROJECT_DIR"
        gh repo create "$NAME" --source=. --push "$VISIBILITY"
    )
    echo "Done. 'origin' now points at your new GitHub repo; 'upstream' was already configured."
    exit 0
fi

# ── Regular scaffold: validate remaining required flags ─────────────────────
[[ -n "$GOAL" ]] || { echo "Error: --goal is required" >&2; exit 1; }
[[ "$TIER" == "secure" || "$TIER" == "playground" ]] || { echo "Error: --tier must be 'secure' or 'playground'" >&2; exit 1; }
[[ "$LIFECYCLE" == "short" || "$LIFECYCLE" == "long" ]] || { echo "Error: --lifecycle must be 'short' or 'long'" >&2; exit 1; }

if [[ "$TIER" == "secure" ]]; then
    TEMPLATE_REPO="$SECURE_REPO"
else
    TEMPLATE_REPO="$PLAYGROUND_REPO"
fi
TEMPLATE_URL="https://github.com/${TEMPLATE_REPO}.git"

PROJECT_DIR="$DEST_PARENT/$NAME"
[[ -e "$PROJECT_DIR" ]] && { echo "Error: $PROJECT_DIR already exists" >&2; exit 1; }

echo "Cloning template ($TEMPLATE_REPO) into $PROJECT_DIR..."
git clone --quiet "$TEMPLATE_URL" "$PROJECT_DIR"

# ── Strip template-specific docs, write a starter README ────────────────────
(
    cd "$PROJECT_DIR"
    rm -f README.md USAGE.md presentation.html docs/comparison.md
    printf '# %s\n\nSee GOAL.md for what this project is for.\n' "$NAME" > README.md
)

# ── Write GOAL.md ─────────────────────────────────────────────────────────
cat > "$PROJECT_DIR/GOAL.md" << EOF
# Goal

$GOAL

- **Tier:** $TIER (template: $TEMPLATE_REPO)
- **Lifecycle:** $LIFECYCLE
- **Created:** $(date -u +%Y-%m-%dT%H:%M:%SZ)

## Manual next steps (if needed)

- Need extra network domains? See docs/allowlist.md.
- Need extra dependencies installed on first boot? See post-create.sh
  (edit it on the host — it's read-only inside the container).
EOF

# ── Fresh git history + remotes ──────────────────────────────────────────────
(
    cd "$PROJECT_DIR"
    rm -rf .git
    git init --quiet
    git remote add upstream "$TEMPLATE_URL"
    git add -A
    git commit --quiet -m "chore: bootstrap $NAME from $TEMPLATE_REPO ($TIER, $LIFECYCLE)"
)

# ── Long-running: create the real GitHub repo now ────────────────────────────
if [[ "$LIFECYCLE" == "long" ]]; then
    command -v gh >/dev/null 2>&1 || { echo "Error: gh CLI is required for --lifecycle long" >&2; exit 1; }
    gh auth status >/dev/null 2>&1 || { echo "Error: run 'gh auth login' first" >&2; exit 1; }

    echo "Creating GitHub repo $NAME (template: $TEMPLATE_REPO, $VISIBILITY)..."
    (
        cd "$PROJECT_DIR"
        gh repo create "$NAME" --source=. --push "$VISIBILITY"
    )
fi

cat << EOF

Done! Project scaffolded at: $PROJECT_DIR

Next steps:
  cd $PROJECT_DIR
  code .
  # then "Reopen in Container"
EOF
