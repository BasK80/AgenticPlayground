#!/usr/bin/env bash
# apply-opencode-provider-merge.sh — run from the HOST (not inside the
# container) because llm-switch.sh is a read-only bind mount there.
#
# Fixes a collision found while wiring ollama/github-copilot as opencode
# providers (wayfinder ticket 009): _opencode_write_config() replaced the
# *entire* `.provider` key on every use-anthropic-key / use-foundry /
# use-anthropic call (and on every new interactive shell, via
# _llm_apply_persisted). That silently wiped a hand-added `ollama` provider
# entry the moment any use-* command ran. Confirmed live: adding
# provider.ollama to opencode.json, then calling use-anthropic, reduced
# .provider back to {}.
#
# This patch makes _opencode_write_config() merge/clear only the
# `anthropic` and `azure` keys it owns, leaving any other configured
# provider (ollama, or anything added later) untouched.
set -euo pipefail

TARGET="${1:-.devcontainer/development/llm-switch.sh}"

if [[ ! -f "$TARGET" ]]; then
    echo "error: $TARGET not found — run this from the repo root, or pass the path as \$1" >&2
    exit 1
fi

if ! grep -q "jq --argjson p \"\$new_provider\" '.provider = \$p'" "$TARGET"; then
    echo "error: expected old _opencode_write_config body not found in $TARGET — already patched, or file changed upstream. Aborting without touching it." >&2
    exit 1
fi

cp "$TARGET" "$TARGET.bak"
echo "backed up to $TARGET.bak"

python3 - "$TARGET" <<'PYEOF'
import re, sys

path = sys.argv[1]
with open(path) as f:
    content = f.read()

old_func = '''_opencode_write_config() {
    # $1 = "anthropic-key" | "azure" | "clear"
    # Merges only the "provider" key into ~/.config/opencode/opencode.json so
    # that user settings (model, theme, etc.) survive provider switches.
    mkdir -p "$(dirname "$_OPENCODE_CONFIG")"

    local new_provider
    case "$1" in
    anthropic-key)
        if [[ -n "${ANTHROPIC_BASE_URL:-}" ]]; then
            new_provider=$(jq -n \\
                --arg key  "${ANTHROPIC_API_KEY:-}" \\
                --arg base "${ANTHROPIC_BASE_URL}" \\
                '{"anthropic":{"options":{"apiKey":$key,"baseURL":$base}}}')
        else
            new_provider=$(jq -n \\
                --arg key "${ANTHROPIC_API_KEY:-}" \\
                '{"anthropic":{"options":{"apiKey":$key}}}')
        fi
        ;;
    azure)
        # Resource name only — the API key must be stored once via '/connect'
        # inside opencode. Deployment name must match the model name.
        new_provider=$(jq -n \\
            --arg res "${ANTHROPIC_FOUNDRY_RESOURCE}" \\
            '{"azure":{"options":{"resourceName":$res}}}')
        ;;
    *)
        new_provider='{}'
        ;;
    esac

    if [[ -f "$_OPENCODE_CONFIG" ]]; then
        jq --argjson p "$new_provider" '.provider = $p' "$_OPENCODE_CONFIG" \\
            > "${_OPENCODE_CONFIG}.tmp" \\
            && mv "${_OPENCODE_CONFIG}.tmp" "$_OPENCODE_CONFIG"
    else
        jq -n \\
            --argjson p "$new_provider" \\
            '{"$schema":"https://opencode.ai/config.json","provider":$p}' \\
            > "$_OPENCODE_CONFIG"
    fi
}'''

new_func = '''_opencode_write_config() {
    # $1 = "anthropic-key" | "azure" | "clear"
    # Merges/clears only the "anthropic" and "azure" keys under .provider in
    # ~/.config/opencode/opencode.json, leaving any other configured provider
    # (e.g. a hand-added "ollama" entry — see wayfinder ticket 009) untouched.
    # Previously this replaced the whole .provider object, which silently
    # wiped out any such entry on every use-* call and on every new shell
    # (_llm_apply_persisted re-applies the persisted choice).
    mkdir -p "$(dirname "$_OPENCODE_CONFIG")"

    local patch
    case "$1" in
    anthropic-key)
        if [[ -n "${ANTHROPIC_BASE_URL:-}" ]]; then
            patch=$(jq -n \\
                --arg key  "${ANTHROPIC_API_KEY:-}" \\
                --arg base "${ANTHROPIC_BASE_URL}" \\
                '{"anthropic":{"options":{"apiKey":$key,"baseURL":$base}}}')
        else
            patch=$(jq -n \\
                --arg key "${ANTHROPIC_API_KEY:-}" \\
                '{"anthropic":{"options":{"apiKey":$key}}}')
        fi
        ;;
    azure)
        # Resource name only — the API key must be stored once via '/connect'
        # inside opencode. Deployment name must match the model name.
        patch=$(jq -n \\
            --arg res "${ANTHROPIC_FOUNDRY_RESOURCE}" \\
            '{"azure":{"options":{"resourceName":$res}}}')
        ;;
    *)
        patch='{}'
        ;;
    esac

    if [[ -f "$_OPENCODE_CONFIG" ]]; then
        jq --argjson p "$patch" \\
            '.provider = ((.provider // {}) | del(.anthropic, .azure) + $p)' \\
            "$_OPENCODE_CONFIG" > "${_OPENCODE_CONFIG}.tmp" \\
            && mv "${_OPENCODE_CONFIG}.tmp" "$_OPENCODE_CONFIG"
    else
        jq -n \\
            --argjson p "$patch" \\
            '{"$schema":"https://opencode.ai/config.json","provider":$p}' \\
            > "$_OPENCODE_CONFIG"
    fi
}'''

if old_func not in content:
    print("error: exact old function body not found — aborting without changes", file=sys.stderr)
    sys.exit(1)

content = content.replace(old_func, new_func)

with open(path, 'w') as f:
    f.write(content)

print(f"patched {path}")
PYEOF

echo "done. Diff:"
diff -u "$TARGET.bak" "$TARGET" || true
