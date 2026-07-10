#!/usr/bin/env bash
# Usage:  allow-all [ttl_seconds] | allow-all off | allow-all status
# Temporarily bypasses the ENTIRE firewall (any domain, any port) until the
# TTL expires. Mirrors `fw allow-all` in the firewall container; both write
# the same shared /policy state, and the firewall's watcher.sh is the only
# process that actually flips the live Squid ACL — this script just edits the
# marker files it watches.
set -uo pipefail
ALLOWALL_UNTIL=/policy/allow_all.until
ALLOWALL_EVENTS=/policy/allow_all_events.log
DEFAULT_TTL=300
MAX_TTL=3600

touch "$ALLOWALL_EVENTS" 2>/dev/null || true

arg="${1:-}"
case "$arg" in
  off)
    if [ -f "$ALLOWALL_UNTIL" ]; then
      rm -f "$ALLOWALL_UNTIL"
      echo "$(date +%s) $(date -Iseconds) off" >> "$ALLOWALL_EVENTS"
      echo "allow-all disabled — normal allowlist enforced again within ~5s"
    else
      echo "allow-all is already inactive"
    fi
    ;;
  status)
    if [ -s "$ALLOWALL_UNTIL" ]; then
      until_ts="$(cat "$ALLOWALL_UNTIL" 2>/dev/null || echo 0)"
      now="$(date +%s)"
      if [[ "$until_ts" =~ ^[0-9]+$ ]] && [ "$until_ts" -gt "$now" ]; then
        echo "allow-all: ACTIVE — $(( until_ts - now ))s remaining"
      else
        echo "allow-all: inactive"
      fi
    else
      echo "allow-all: inactive"
    fi
    ;;
  ''|*[0-9]*)
    ttl="${arg:-$DEFAULT_TTL}"
    if ! [[ "$ttl" =~ ^[0-9]+$ ]] || [ "$ttl" -lt 1 ]; then
      echo "ttl must be a positive integer (seconds)" >&2
      exit 1
    fi
    if [ "$ttl" -gt "$MAX_TTL" ]; then
      echo "note: ttl ${ttl}s exceeds the max of ${MAX_TTL}s — clamped" >&2
      ttl="$MAX_TTL"
    fi
    echo "$(( $(date +%s) + ttl ))" > "$ALLOWALL_UNTIL"
    echo "$(date +%s) $(date -Iseconds) on ttl=$ttl" >> "$ALLOWALL_EVENTS"
    echo "allow-all ACTIVE for ${ttl}s — ALL traffic (any domain, any port) now bypasses the firewall. Effective within ~5s."
    ;;
  *)
    echo "usage: allow-all [ttl_seconds] | allow-all off | allow-all status" >&2
    exit 1
    ;;
esac
