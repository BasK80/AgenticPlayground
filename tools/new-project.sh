#!/usr/bin/env bash
# new-project.sh — bootstrap a new dev container project scoped to a goal.
#
# Usage:
#   ./tools/new-project.sh
#       (no arguments) — launches an interactive wizard that prompts for
#       everything below.
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

# ── Interactive wizard (used when the script is run with no arguments) ──────
run_wizard() {
    echo "No arguments given — starting interactive setup. (Run with -h to see the non-interactive CLI form instead.)"
    echo

    echo "What would you like to do?"
    local mode
    PS3="Select an option: "
    select mode in "Create a new project" "Promote an existing project to GitHub"; do
        case "$REPLY" in
            1) PROMOTE=0; break ;;
            2) PROMOTE=1; break ;;
            *) echo "Invalid choice, try again." ;;
        esac
    done
    echo

    local input
    read -rp "Destination parent directory [$DEST_PARENT]: " input
    DEST_PARENT="${input:-$DEST_PARENT}"
    echo

    if [[ "$PROMOTE" -eq 1 ]]; then
        while true; do
            read -rp "Name of the project to promote: " NAME
            if [[ -z "$NAME" ]]; then
                echo "Name cannot be empty." >&2
                continue
            fi
            if [[ ! -d "$DEST_PARENT/$NAME/.git" ]]; then
                echo "Error: $DEST_PARENT/$NAME is not a git repo." >&2
                continue
            fi
            break
        done
        echo
    else
        while true; do
            read -rp "Project name (slug): " NAME
            if [[ -z "$NAME" ]]; then
                echo "Name cannot be empty." >&2
                continue
            fi
            if [[ -e "$DEST_PARENT/$NAME" ]]; then
                echo "Error: $DEST_PARENT/$NAME already exists. Choose a different name." >&2
                continue
            fi
            break
        done
        echo

        while [[ -z "$GOAL" ]]; do
            read -rp "Goal (what is this project for?): " GOAL
            [[ -z "$GOAL" ]] && echo "Goal cannot be empty." >&2
        done
        echo

        echo "Tier selects which template repo is cloned:"
        echo "  secure     - hardened template (github.com/${SECURE_REPO})"
        echo "  playground - permissive template (github.com/${PLAYGROUND_REPO})"
        PS3="Select tier: "
        select TIER in secure playground; do
            [[ -n "$TIER" ]] && break
            echo "Invalid choice, try again."
        done
        echo

        echo "Lifecycle determines whether a GitHub repo is created now:"
        echo "  short - local-only git repo, no GitHub involved (fast, disposable)"
        echo "  long  - creates a GitHub repo now via 'gh repo create'"
        PS3="Select lifecycle: "
        select LIFECYCLE in short long; do
            [[ -n "$LIFECYCLE" ]] && break
            echo "Invalid choice, try again."
        done
        echo
    fi

    if [[ "$PROMOTE" -eq 1 || "$LIFECYCLE" == "long" ]]; then
        echo "Repo visibility (a GitHub repo will be created):"
        local vis
        PS3="Select visibility: "
        select vis in private public; do
            case "$vis" in
                private) VISIBILITY="--private"; break ;;
                public) VISIBILITY="--public"; break ;;
                *) echo "Invalid choice, try again." ;;
            esac
        done
        echo
    fi

    echo "Summary:"
    if [[ "$PROMOTE" -eq 1 ]]; then
        echo "  Mode:        Promote existing project"
        echo "  Project dir: $DEST_PARENT/$NAME"
        echo "  Visibility:  $VISIBILITY"
    else
        echo "  Mode:        Create new project"
        echo "  Name:        $NAME"
        echo "  Goal:        $GOAL"
        echo "  Tier:        $TIER"
        echo "  Lifecycle:   $LIFECYCLE"
        echo "  Project dir: $DEST_PARENT/$NAME"
        [[ "$LIFECYCLE" == "long" ]] && echo "  Visibility:  $VISIBILITY"
    fi
    echo
    read -rp "Proceed? [Y/n] " confirm
    if [[ "$confirm" =~ ^[Nn] ]]; then
        echo "Aborted."
        exit 0
    fi
    echo
}

NAME=""
GOAL=""
TIER=""
LIFECYCLE=""
DEST_PARENT="${AGENTIC_PROJECTS_DIR:-..}"
VISIBILITY="--private"
PROMOTE=0

if [[ $# -eq 0 ]]; then
    run_wizard
fi

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
    rm -f README.md USAGE.md presentation.html docs/comparison.md \
          docs/allowlist.md docs/auditing.md docs/file-guide.md \
          docs/operations.md docs/providers.md docs/security.md \
          docs/spin-off-existing-repo.md docs/spin-off-new-project.md
    printf '# %s\n\nSee GOAL.md for what this project is for.\n' "$NAME" > README.md
    mkdir -p docs/input_data
    touch docs/input_data/.gitkeep
    cat > docs/input_data/README.md << 'INPUTEOF'
# Input data

Drop source material for this project here (notes, interview transcripts,
exports, reference documents, etc.). Nothing under this folder is generated
by the template — it exists purely as a conventional place to keep the raw
inputs an agent working on this project should read.
INPUTEOF
)

# ── Write GOAL.md ─────────────────────────────────────────────────────────
cat > "$PROJECT_DIR/GOAL.md" << EOF
# Goal

$GOAL

- **Tier:** $TIER (template: $TEMPLATE_REPO)
- **Lifecycle:** $LIFECYCLE
- **Created:** $(date -u +%Y-%m-%dT%H:%M:%SZ)
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
